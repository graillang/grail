# Generic `Result`/`Option`, and `?` over any two-member shape

This closes the largest remaining gap in the error story: the language now has generic
`Result<T, E>` and `Option<T>` in the standard library, and postfix `?` works on **any** shape with
one success member and one failure member instead of on two specific variant-name spellings.

Three things were already true in the compiler and are reused unchanged, not re-implemented:

- Generic **enums** specialise exactly like generic structs. `enum Res<T, E> { Ok(T), Err(E) }`
  parsed, type-checked, laid out, matched, dropped and emitted into an interface before this
  change; `lib/core.grl`'s `OptionStorage<T>` (the type `T?` names) is a generic enum the whole
  standard library already depends on.
- A **result union** `S |? F` and an ordinary union `S | F` are structural two-member shapes with a
  fixed layout and their own propagation path.
- `?` already returned through ordinary checked return cleanup, generating checked
  `Match`/`Variant`/`Return` operations: no unwinding, no new ABI, no exception runtime.

What was missing was the *general* rule. `?` accepted a two-variant enum only when its variants were
literally named `Ok`/`Err` or `Some`/`None`, there was no `Result`/`Option` a program could name, and
a refused shape produced a diagnostic that named neither the type nor its members. This note records
the decisions behind fixing those.

## How a generic enum specialises

There is one **template** `Decl` per declared enum (`is_enum = 1`, `types = ` number of type
parameters). Nothing is copied per instance at declaration time. An instance is a type: interning
`(8, declaration, args)` on demand (`intern_args`) makes `Res<u64, string>` one identity, so two
spellings of the same instantiation are the same type id, and `same_type` is identity comparison.

Everything else is expressed in terms of the *substituted* field types, which is why generic enums
needed no separate machinery from generic structs:

- **Layout.** An enum value is one word: a heap cell `{tag, payload word}` (`rt_enum`). The cell is
  the same 16 bytes for every instance, so an instance's C layout never depends on its payload
  widths. The payload's *type* is `field_type(instance, variant)`, i.e. the template's field type
  with the instance's arguments substituted (`bind_types`). A payload that is itself a generic
  instance (`Res<Res<u64, string>, string>`) or a reference (`Res<&a u64, E>`) is just another
  substituted field type: construction, extraction, bond transfer and drop all read it from there.
- **Construction/destruction.** `Res::Ok(v)` builds the payload as the substituted field type, moves
  it into the cell and transfers the value's bonds to the cell (so a borrowed payload keeps its
  loan). Drop visits only the active variant's payload leaf; the other alternative's flags are
  never read. A `Res<u64[], E>` payload is released exactly once on whichever arm runs.
- **Checking a body.** `bind_types` maps each template parameter to the instance's argument; an
  opaque parameter cannot be duplicated, indexed or assumed numeric, and each instantiation is
  checked with concrete types in place. Untyped-parameter bodies are validated once for what is
  true of every instantiation.
- **Interfaces (B1).** An interface writes the template as `type m::Res enum params=2` plus one
  `variant Ok (tparam 0 0 [])` line per variant, and carries the template body text. A client that
  reads `Result<T, E>` from an interface specialises it from those declarations, so an
  interface-first build of a function returning `Result<T, E>` needs no source and no ABI addition.

### Monomorphisation keys

A specialisation's identity is the canonical **type key** of the instance, not the spelling at the
use site:

```
key := "(8:0 M:0" + " " + "m::Res" + " " + key(arg 0) + " " + key(arg 1) + ")"
```

i.e. the kind, mode and region arity, the declaring `module::Name`, then each type argument's key
recursively (depth-capped at 16 with a cycle marker; the walk is finite by construction). Lifetime
*values* are erased from specialisation identity by `canonical_type` (a reference's region still
matters inside a body, but two instances that differ only in which region fills a slot share one
emitted helper), and opaque body aliases are erased there too. Function specialisations, drop
helpers and vtables are named `<template>#<first 64 bits of SHA-256(key)>`, emitted weak so two
objects agree; this is the same scheme generic structs already use, unchanged. Enum instances and
struct instances therefore share one key space, and `Res<u64, string>` and a record of the same name
in another module can never collide.

Limits are the existing generic ones: type-expression depth 64, expanded layout nodes 4096,
parameters/variants/fields 64, declarations 4096, plus the specialisation expansion limit. There is
no new cap and no new invalidation rule.

## `?` over any two-member shape

The operand must be a **shape with exactly one success member and one failure member**:

| operand | members | success member |
| --- | --- | --- |
| enum, two variants | its first and second variant | `Ok`/`Some` by name; otherwise the first declared variant |
| ordinary union `S \| F` | exactly two | the first member |
| result union `S \|? F` | its declared success and failure partition | its success member(s) |

The three rows differ in exactly one thing: whether the type *states* which member is the failure.
A result union states it (`|?` separates the failure alternatives), so `?` reads that partition
whatever its arity - `u64 | bool |? string` still propagates its two success members, and a union
with several failure members still maps each to a matching alternative in the caller. An ordinary
union does not state it: position says "the first member is the success", and with a third member
nothing says whether it is a success or a failure, so it is refused rather than guessed at.

The variant-name knowledge is kept **only** for the two conventional families: `Ok`/`Err` and
`Some`/`None` mean what they have always meant, in either declaration order (`enum E { Err(F),
Ok(T) }` still propagates `Ok` as the success). Any other two-variant enum is ordered by
declaration, so `enum Out<V, F> { Good(V), Bad(F) }` propagates `Good`. That rule is total, needs no
inference, and never guesses from payload types - a payload type appearing on both sides would
otherwise make the meaning of `?` depend on instantiation.

Union members are positional already (a union is unordered and `?` takes the first member as the
success), so nothing changes there except the member count.

The **enclosing result** must be able to receive the failure unchanged:

- same enum declaration, with a failure payload type identical to the operand's, or
- a union containing the operand's failure member type (the union path retags the value:
  `rt_enum_retag` keeps the payload and rewrites the tag).

The success payload is extracted, the cell released, and the payload's bonds transferred to the new
binding; the failure path returns the value as it is, dropping the other owners by the ordinary
reverse-binding rules. `!` (`unwrap`) uses the same membership rule but aborts on failure and
therefore needs no enclosing result.

### Conversion: there is none, implicitly

The existing rule stands: **no implicit `From`**. `?` never converts a failure payload, changes its
mode, or borrows it into the caller's error type. A success payload may differ from the enclosing
result's success member - the payload is extracted, so its own type is what it is - but the failure
must match exactly. A layer that wants a different error type writes the conversion
(`errs::from_os(e, view("while opening /x"))`), which is where the ownership of the new error is
decided and visible. The one looseness that predates this note is kept and made explicit: when the
declaration is the same and only the success argument differs, the failure object is returned
untouched, which is sound because a two-variant cell is a tag plus one payload word and the payload
on that path has the same type either way.

### Three members: refused, naming the shape

A shape that leaves the failure ambiguous is refused: an enum with three or more variants, an
ordinary union with three or more members, and a record (which is not a shape for `?` at all):

```
error: `?` needs a shape with one success member and one failure member; `u64 | string | bool` has 3 members
error: `?` needs a shape with one success member and one failure member; `e4::Three` has 3 variants (Ok, Err, Also)
```

The diagnostic names the type, every member (or variant) name, and the count. It replaces the old
"unwrap requires two-variant Option/Result" / "unwrap requires Ok/Err or Some/None variants" pair,
which named neither the type nor its members; and it is what makes `?` a rule about shape rather
than about the spelling of two variant names.

Multi-failure result unions (`S |? F1 |? F2`) are therefore no longer propagatable; a layer that can
fail two ways names one error type (`errs::Report`, or a module's own error enum) and matches the
member types at the point it converts. This is the trade the "exactly two members" rule buys: the
meaning of `?` no longer depends on how many failure alternatives a type happens to list.

## The standard library

`lib/result.grl` (new) declares the two shapes and the combinator set that is honest today:

```grl
pub enum Result<T, E> { Ok(T), Err(E) }
pub enum Option<T> { Some(T), None }
```

`Option` **is** the type `T?` names. The sugar used to name a hidden `core::OptionStorage<T>`; that
declaration moved here, was renamed `Option`, and made public. Two option types - `T?` and
`Option<T>` - would be a trap: `Option::Some(x)` would not be assignable to `u64?` and `!`/`?` would
apply to one and not the other. `lib/core.grl` now says `use result;`, so every program and module
that could write `T?` before still can, and `Option::Some(5)` and `5?` are the same value of the
same type. The old name is gone rather than aliased: `core::OptionStorage` is an internal spelling
that no source could use anyway (the compiler hid it), and it appears in no user program.

Combinators, all in ordinary Grail and all instantiated per use:

| type | method |
| --- | --- |
| `Result<T, E>` | `is_ok`, `is_err`, `ok`, `err`, `unwrap_or`, `map`, `map_err` |
| `Option<T>` | `is_some`, `is_none`, `unwrap_or`, `map`, `ok_or` (→ `T \| E`), `to_result` (→ `Result<T, E>`) |

`map` takes `FnMut(T) -> U` and returns a new value, so it composes with closures; `ok`/`err`
consume the value and return an `Option` holding the chosen payload. No combinator panics: the ones
that cannot fail return a value or a shape, and `!` stays the explicit abort.

`ok_or` answers the union `T | E` rather than a `Result`, and that is deliberate: it is what the
method has always answered (it lived in `core` before), a caller that matches it by member type
(`u64(n) => ...`) keeps compiling, and a union needs no type argument at the call site. `to_result`
is the same conversion into the generic enum for a pipeline that is `Result`-shaped throughout, so
both shapes are one method away from an optional value and neither is privileged.

### One option type, and where its tag comes from

`Option<T>` is declared `{ Some(T), None }` - success first, like `Result`. Nothing may assume a
tag: a bare `None` used to store tag `0` in `adopt_value` because the old storage enum happened to
declare `None` first. That constant is gone; `none_tag` reads the variant's position from the
declaration, so the tag follows the type. (This is also why `Option` could not simply be a second
name for the old storage enum: hiding one builtin assumption behind another is how the two types
would have drifted apart.)

### Why the concrete error types stay

Whether `errs::Report`, `io::Error` and `fs::Error` should become generic is a different question
from whether `Result` is, and the answer is no, module by module:

- **`io::Error`** is the leaf: a concrete enum of the platform's failures with a couple of
  library-detected ones. Its variants carry no generic payload (a code, or a byte offset), so
  nothing would be parameterised; it is what a `Result`'s `E` is.
- **`fs::Error`** is a path plus an `io::Error`. That is exactly the thing a generic `E` cannot
  express (it is data about *this* failure, not a type parameter), and it is already the failure
  member of every fs signature - `fn read(path: &[u8]) -> u8[] |? Error`. `u8[] |? fs::Error` is
  the `Result<u8[], fs::Error>`-shaped value this workstream was asked for; it needed `?` to work on
  a two-member shape, not a new type. Migrating it to `Result<u8[], fs::Error>` would rewrite every
  fs call site and every `match` on the failure to say the same thing in longer form.
- **`errs::Report`** is the carrier that makes multi-layer errors usable: root message, context
  frames, typed origin, captured stack, all owned. It is used as an `E` (`-> u8[] |? errs::Report`),
  and an `E` is already the variable part; making the carrier generic would parameterise what it
  carries a *type* of failure for - a different design (typed cause chains) that buys nothing here.
- **`dns::Error`** is a concrete enum of protocol failures (`Malformed`, `Timeout`, `Transport`,
  `NoNameServer`, ...): genuinely n-valued, so it is not a two-member shape and must not be forced
  into one. `parse_response -> Response |? Error` keeps it.
- **`net`** returns `TcpStream |? io::Error`; there is nothing to parameterise.

So the migration is a *decision not to migrate*, and the net win is elsewhere: a program (and the
next stdlib module) can now write `Result<T, E>` and `Option<T>` by name, `?` accepts either the
generic enum or the module's union with the same rule, and the two shapes interoperate at a boundary
by an explicit conversion the caller writes.

## Evidence and limits

Cases (`tests/native-cases.json`, `resgen-`): success and failure with both generic enums; a payload
that is itself a generic instance and one that is a reference; a two-member enum whose variants are
not named `Ok`/`Err` (propagating by declaration order, in both orders); `?` through three layers; the
three-member union and three-variant enum refusals with their diagnostics; an interface-first build
of a function returning `Result<T, E>`; the stdlib's `T |? fs::Error` meeting `Result<T, fs::Error>`
at one written conversion; and a drop/leak case whose payload owns memory on both arms, under the
runtime's end-of-main live-allocation check.

Not claimed: variance or subtyping between instances, inference of a generic constructor's type
arguments outside the written-result rule (`Result::Ok(x)` in a `let` still needs its type), implicit
`From`, multi-failure `?`, or generic `Drop`/interface implementations beyond what existed. Typed
cause chains in `errs` remain future work.
