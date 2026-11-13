# Named arguments and parameter defaults

Decision: **accepted, both parts.** This note is the plan of record for named call arguments and for
parameter defaults; both land together because they are one mechanism read from two ends.

## The call site

```grail
compile(&h, entry, &modules, output, target, flags, iface, verify, diag);   // today
compile(h: &h, entry: view(o.file), modules: &modules, output: view(out), flags: flags);  // after
```

A call may name an argument `name: value` when the callee is a function the parser resolved by name
(a plain call, a generic call, a method call). Positional and named arguments may be mixed, and every
positional argument must come before the first named one: `f(1, y: 2)` is legal, `f(1, y: 2, 3)` is
not. That rule is what makes an argument's *slot* a function of its own text and the declaration
alone, without the reader simulating the evaluation order.

A name is a **slot**, not an evaluation order. Arguments are still evaluated left to right exactly as
written, so `f(b: 1, a: 2)` evaluates `1` and then `2` and fills slot `b` and slot `a`. Two-phase
borrow ordering (`&mut place` arguments taken last, so `f(&mut c, c.pos)` works) is unchanged and
composes with naming: it decides *when* a written argument is taken, naming decides *where* it goes.

Nothing about the type of the call changes. A named argument is checked against its parameter exactly
as a positional one is, in the same code path, with the same literal adoption, view coercion,
ownership transfer and loan. There is therefore no second set of rules to keep in step, and the
refinement prover that replaces a parameter's predicate name with the argument's term sees the same
spans it saw before.

## What is refused, by name

Each refusal names the parameter and the callee, because a call with ten arguments is a call where
"I don't know which one you mean" is not an answer.

- **A name the declaration does not have**: *no parameter named `y` in `compile`*, with the help *its
  parameters are `h`, `entry`, `modules`, `output`, `target`, `flags`, `iface`, `verify`, `diag`*. The
  full list is the point: it is the signature, handed over at the moment the reader needs it.
- **A parameter supplied twice**: *parameter `flags` of `compile` is given twice* (naming where the
  first one is would need a second site; the call is one line, so the caret on the second one is
  enough).
- **A positional argument after a named one**: *a positional argument cannot follow a named one*,
  pointing at the offending value, with the help *write the named arguments last, or name this one
  too*.
- **A parameter with no argument and no default**: *call to `compile` leaves `verify` without an
  argument, and `verify` has no default*.

The rejections are checked while the argument list is scanned, before any argument is compiled, so a
call that names one parameter wrongly is reported once, at the name, rather than after five arguments
have emitted code.

## Defaults: in

```grail
fn compile(..., iface: &d [u8] = view(""), verify: u64 = 0, diag: &k [u8] = view("")) -> u64
```

A default is a **value the callee supplies when the argument is absent**, compiled at the *call site*
in the *caller's* context, with the same ownership rules as an argument. Four consequences follow,
and each of them is the reason a simpler rule was rejected:

- **It is compiled, not fetched.** The default is a token range that the compiler parses where the
  call is, with the parameter's type as the expected type. So `n: u8 = 0` is a `u8`, not a `u64`
  whose conversion would be the caller's problem, and an owned default (`b: Buf = Buf::new()`) is
  built in the caller's frame and moved in, which is exactly what passing it would cost.
- **The caller's names are the names.** A default expression's free names resolve where the call is
  written, so a default should be written from literals, constants, functions and fully qualified
  paths. A default that names the defining module's private items works for a caller in that module
  and is an unknown-name error for an importer — the interface carries the *text*, and the text is
  compiled by the importer.
- **Defaults are evaluated after the written arguments**, in parameter order, so a default can call a
  function that borrows the caller's state without fighting the two-phase rule; a default may not
  name another parameter (parameters are not bindings at the call site).
- **A defaulted argument cannot discharge a `where` predicate at the call site.** The prover
  substitutes a parameter's name with the *argument's own term*; a value nobody wrote has no term, so
  the call takes the callee's checked entry instead of the proved one. Under `@strict`, where the
  proof is required rather than attempted, such a parameter must be passed explicitly — the
  diagnostic is the existing one and the fix is the obvious one.

### Gaps are not allowed

A parameter with a default may not be followed by one without:

```grail
fn f(a: u64 = 1, b: u64)        // refused
fn f(a: u64, b: u64, c: u64 = 3)  // fine
```

*parameter `b` has no default while `a` before it does*, with the help *give `b` a default too, or
move it before `a`*. Allowing the gap would make `f(1)` mean "`b` gets 1" in one reading and "`a`
gets 1, `b` is missing" in another; with the rule, omitting arguments always means omitting a
suffix, which is what the positional reading requires. Named arguments technically rescue the gap
(`f(b: 1)` names the one that is missing) but the declaration-level rule is the one a reader of the
declaration can check locally, and a default followed by a required parameter is nearly always a
mistake in the signature rather than a use.

### Every parameter must be supplied exactly once

No parameter may be left without a value (which is the refusal above), none twice, and an argument
whose slot is a parameter the receiver already filled (`self`, in a method call) is a duplicate. This
is the invariant that keeps the rest of the compiler's machinery untouched: an argument list, once
checked, is a full, ordered vector of `count` values, which is what `emit_resolved_call` has always
been given.

## Generic functions

Parameter names belong to the **template**, not to an instantiation: `fn id<T>(x: T)` names `x` for
every `T`. So a named call is resolved once (`x` is slot 0) and then type-checked per instantiation
exactly as the positional call is — the inference that fixes `T` from the argument's type runs after
the argument has been placed in its slot, so `id<u64>(x: 1)` is a `u64` and `id(x: 1)` infers `T`
from `1`. A default is compiled per instantiation too, with the *bound* formal type as its expected
type, so `fn zero<T>(n: u64 = 0)` costs one default per call site and no special machinery.

## Interface files

An importer has no declaration to read, so both halves travel:

- `param N "name"` for every parameter with a name (`pnames` already existed for refinement proofs;
  it now carries every parameter, not only the refined ones);
- `default N "text"` for every parameter with a default, carried as its source text and rebuilt on
  the importing side as a virtual source, exactly as a refinement predicate is (`pred_of_text`).

Carrying the text rather than a value is the only shape that works: a default is compiled at the
call site in the caller's context, so the importer needs the *expression*, not a constant. The
alternative — freezing a default into a constant when the interface is written — would evaluate it
once, in the defining module's context, which is a different language: it could not build an owned
value in the caller's frame, could not adopt the parameter's type per instantiation, and would make
a defaulted `Rc`-like value shared rather than fresh. Interfaces are versioned, read and written by
the same compiler build, and the manifest pins their bytes, so the two new line kinds cost a
regeneration and nothing else.

## What did not change

- Fixed arity: a default is a value for a parameter that exists, never a way to vary the parameter
  count.
- A closure or function *value* has no parameter names to name, so a call through a value is
  positional: *named arguments need a declared parameter list*.
- A variadic `extern "C"` declaration's *fixed* parameters can be named (their names are recorded for
  exactly this), but the `...` arguments have no parameter to name: they are positional, and a call
  that passes them cannot name anything, because a positional argument may not follow a named one.
  Such a declaration cannot give a parameter a default either - the C signature is the declaration.
- `self` cannot have a default.
