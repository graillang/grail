# Closure bounds: saying `Send`, `Share` and "how long it borrows" in a signature

Status: design proposal (gaps12). The compiler is unchanged by this note. Claims are tagged
**[V file:line]** (read at 4ec508e; `n:` is `compiler/native.grl`), **[P nn]** (probe `pNN_*.grl` in
`docs/design/closure-bounds-probes/`, output quoted in section 1.6) or **[A]** (assumed, not
verified). Probes ran on Linux x86-64 with the compiler built from this worktree.

## 0. Decisions for the director

| # | Decision | Recommendation |
|---|---|---|
| D1 | Which mechanism? | **A: bounds written on the closure type** - `Fn<Send, s>(T) -> R`. Generic `F: Send` (B) already works and stays, but cannot be stored, queued or put in a handle; builtins (C) cannot be composed into an executor or a channel. |
| D2 | What does a bare `Fn(T) -> R` mean after this? | **Neither `Send` nor `Share`** (default-deny, like a `handle`). **In a parameter: borrows live for the call only. Anywhere else (field, element, result, type argument): no borrows.** Today it means "anything, unchecked", which is unsound [P 11, 12, 13, 14]. |
| D3 | Spelling | **`Fn<Send>(..)`, `Fn<Share>(..)`, `Fn<Owned>(..)`, `Fn<s>(..)`** in the angle list a nominal type already uses for lifetimes; alternatives in 2.1. A wrong spelling here is cheap to change before stage 1 and expensive after. |
| D4 | A "holds no borrow" bound on type parameters | **Add `Owned`** beside `Send`/`Share` (`R: Send + Owned`). Every builtin checks `contains_borrow(result)` and no signature can say it today. |
| D5 | The four soundness holes in section 1.5 are live in `lib/pool.grl` today | **Fix them with stage 1, not before**: the fix *is* D2. If stage 1 will not land soon, refuse a capturing closure at an `Fn` *field* now (a ten-line stopgap for P11). |
| D6 | Exclusive borrows in one `join` branch (point 3) | **No new borrow rule.** Type the worker branch `FnMut<Send>`; the existing loans already refuse two branches that reach the same data [P 09, 10]. |
| D7 | How a scope lifetime is made | **An ordinary region parameter that is both the body's capture bound and the scope type's region argument** (`scope<s,R>(body: FnMut<s>((&Threads<s>)) -> R)`), plus one rule (R-env, 2.4). No higher-ranked lifetimes, no outlives solver. |
| D8 | `contains_task` ("no `Task`/`Job` handle in a result or item") | **Drop it when the handles become library types** - open question Q1; it is the one builtin check this design does not re-express. |

### Decided by the director, 2026-11-16

The design is approved and is P0: it is a soundness fix (H3, H5) before it is a feature.

- **D1:** A. B stays as it is; C is what produced the holes.
- **D2:** as recommended; the non-parameter default is `Owned`, not an error (settles Q2).
- **D3:** `Fn<Send>(..)`, `Fn<Share>(..)`, `Fn<Owned>(..)`, `Fn<s>(..)` in the angle list. The owner
  may still ask for another spelling before stage 1 merges, so the spelling lives in one place in
  the parser and one in the formatter.
- **D4:** add `Owned`. **D5:** no stopgap; the fix is the design. **D6:** no new borrow rule for
  `join`.
- **D7:** accepted as the direction; the stage 5 plan (R-env and the scope types) goes to the
  director before it is built.
- **D8 / Q1:** `contains_task` stays while `Task`/`Job` are builtin kinds and goes when a handle is
  a move-only library record whose `wait`/`join` consumes it - in the same change, with a case
  showing a second wait is a move error.
- **Q3:** found and fixed first, as its own commit (section 5).
- **Q5:** deferred; what it would take is written down in 2.6.
- **Q6:** a named follow-up with a probe (section 5).
- **Order:** Q3; stages 0 and 1 together with `lib/pool.grl` re-typed; stage 3 after a count of
  what it would refuse; then stages 2 and 4 with the threads and scheduler branches.

## 1. What exists

### 1.1 A closure's type

- A type is `Ty { kind, arg, mode, regions, args, env }` [V n:63-74]. A closure is kind 20: `arg` the
  result, `args` the parameters, `mode` 0 `Fn` / 1 `FnMut`, `regions` the lifetimes it captured,
  `env` the environment record `.closure::ClosureN { __code, __drop, captures... }` [V n:29398-29456].
  `env` is part of the interned identity [V n:9213-9248], so two closures with one signature are two
  types.
- A closure *expression* has all of that. A closure type *written in a signature* has none of it:
  `Fn(T) -> R` parses to `intern_args(20, result, fnmut, [], params)` - no regions, `env` 0
  [V n:12541-12561].
- Passing the first where the second is expected succeeds whenever signature and mode agree:
  `callable_contract` compares the mode [V n:11021-11027], skips the regions for kind 20 with the
  comment "a closure that borrows is accepted where a plain `Fn(...)` is expected. The loan stays on
  the value" [V n:11040-11043], and never looks at `env`. **Inside the callee the parameter's type
  is the signature type: captures and borrows are erased.**
- The value is one representation whatever was captured: a heap record whose first word is the code
  pointer, called with a pointer to the slot holding it [V n:23974-23990]. So erasure costs nothing
  at run time; what is lost is only what the checker knew.
- `Fn` vs `FnMut`: a closure whose body writes a capture - including a store *through* a captured
  `&mut` - is `FnMut` [P 05; V decisions-b2-b6.md:481-486]; calling one takes an exclusive loan on
  the closure value for the call [V n:23962-23970]. An *unwritten* captured `&mut` is read-only in
  the body, so an `Fn` closure cannot write through one [V decisions-b2-b6.md:498-500]. `Fn` is
  accepted where `FnMut` is expected; a by-value `FnMut` parameter is called after `mut g = f` [P 25].
- **Through a generic parameter nothing is erased.** `fn needs<F:Send>(f: F)` instantiated with a
  closure binds `F` to the closure's own type, environment included, and the bound sees the capture
  [P 06]; so does a record `Boxed<F>` [P 18]. But an `F` cannot be *called* (`unknown function f`
  [P 07]) and there is no callable bound to make it so (`F: Fn()->R` is a parse error [P 17]).

### 1.2 `Send` and `Share`

`transfer_capability(ty, shared)` walks a type structurally; `shared` 0 asks "may move to another
thread", 1 "may be used from several at once" [V n:9296-9502]:

| Type | Send | Share |
|---|---|---|
| integers, floats, bool, text, byte vectors | yes | yes [V n:9308-9310] |
| record / enum | every field (or an audited `unsafe struct ...: transferable, shareable`) | same [V n:9436-9467] |
| `handle H;` | only if declared `transferable` | only if declared `shareable` [V n:9349-9367] |
| `&T` | `T: Share` | `T: Share` [V n:9431-9435] |
| `&mut T` | `T: Send` | no [V n:9423-9430] |
| `&mut [T]`, mutable view | `T: Send` | no [V n:9316-9327] |
| `Mutex<T>` | `T: Send` | `T: Send` [V n:9400-9403] |
| `Scope<C>` | no | no [V n:9312-9314] |
| `Task<R>`, `Job<R>` | `R: Send` | no [V n:9404-9420] |
| type parameter | its declared proof bits | same [V n:9334-9344] |
| `dyn I`, `T::Item`, `CStr`, C pointers, `cfn` | no | no [V n:9329-9332, 9371-9380] |
| closure **with** `env` | every capture | every capture [V n:9469-9491] |
| closure type **from a signature** (`env` 0) | **yes, vacuously** | **yes, vacuously** [V n:9473-9475; P 11, 12] |

The reference rows are already point (3)'s wording: "exclusive borrows of transferable data,
shared borrows of shareable data". A bound `T: Send` / `T: Share` is a bit in the declaration's
bounds mask (parsed at [V n:10225-10236], `+`-separated [V n:10296]) and is checked at every
instantiation by `require_constraints` [V n:9688-9709], called for generic functions at
[V n:23522, 23723] and for nominal types at [V n:9718, 10378, 11923, 21808].

### 1.3 What each builtin checks

| Builtin | Checks | Expressible in a library signature today? |
|---|---|---|
| `require_parallel_closure(fty, shared)` [V n:26862-26874] | if `shared`: the closure is not `FnMut`; every capture in `env` classifies | `FnMut`: yes (parameter typed `Fn`). Captures: **no** - `env` is erased at the parameter [P 01, 16] |
| `contains_borrow(ty)` [V n:11161-11243] | a reference, view or slice anywhere; a closure whose `regions` are non-empty | **no** bound says it; and a signature closure type has no regions, so it answers "no borrow" for any erased closure |
| `parallel_map` [V n:26877-26966] | callback `Fn`, captures `Share`; item and result `Send`; context `Share`, not owning; result holds no borrow; no `Task`/`Job` in item or result | item/result/context `Send`/`Share`: yes. The rest: no |
| `parallel_for_chunks` [V n:26985-27063] | slice exclusive; element `Send`, no `Task`; callback `((&mut [T])) -> unit`, `Fn`, captures `Share` | all but the captures |
| `parallel_spawn` [V n:27078-27112] | closure passed by value; no parameters; captures `Send`; **closure holds no borrow**; result `Send`, no borrow, no `Task` | only `R: Send` |
| `task_scope` [V n:27208-27255] | context not owning and not `&mut`, `Share`; body is a **capture-free `fn`** (kind 12, `callee_signature` [V n:27186-27195]) taking `(&Scope<C>, C)`; result holds no borrow or `Task` | the shapes yes; "result holds no borrow" no |
| `spawn(scope, item, f)` [V n:27258-27318] | `f` is a capture-free `fn`; item and result `Send`, **no borrow**, no `Task` (`require_sendable_owned` [V n:27196-27205]) | `Send` only |

Two things follow. A task in a `task_scope` cannot capture anything today: it is a named function
given one owned item and the scope's shared context; the lifetime `s` in `fn body<s>(sc: (&s
Scope<u64>), ..)` [V tests/concurrency/scope_tasks.grl:11] is the function's own region parameter
and brands nothing. And every missing row is one of three facts: *what the closure captured is
`Send`/`Share`*, *the closure holds no borrow*, *this type parameter holds no borrow*.

### 1.4 Lifetimes, loans and bonds

- A function declares region parameters with its type parameters (`fn put<a, d>(...)`), and they
  label references `(&a T)` and nominal types `Holder<d>` [P 23]. There is no outlives relation
  between two names and no `'static` [A: none found in the parser].
- The checker is place-based: `ownership.grl` holds places and loans [V ownership.grl:14-43]; a
  *bond* says a live value holds a loan [V n:3977-3995], and a loan ends when no live holder is
  bonded to it (`close_loans` [V n:4075-4100]).
- A closure expression moves a captured reference in, pointer and loan together; the lifetime of
  the borrowed place becomes one of the closure type's `regions`; a local source is region 0
  [V n:29380-29387, 28693-28711]. Inside the body a captured reference is re-borrowed from the
  environment, whose lifetime is the body's region 1 [V n:28713-28718].
- At a call, a result labelled with an input's region takes that input's loans (`call_bonds`
  [V n:4334-4380]). A value stored through a reference parameter into storage whose type names a
  region must come from exactly that region, and never from a local:
  `captured writeback violates invariant lifetime` [V n:4445-4467; P 24]; after such a call the
  caller's loan stays live as long as the holder does [P 23]. **This is the mechanism a scope needs,
  and it already works for references.**
- A closure argument is the exception: its parameter type names no region, so `call_bonds` hands
  its loans to the call's *result* whatever the result is [V n:4352-4366]. That keeps a returned
  closure honest [P 19] and nothing else: a result type that holds no borrow does not keep the data
  in place [P 13, 22 - cause not isolated, A], and a callee that stores the closure anywhere but its
  result is not seen at all [P 14].

### 1.5 What goes wrong today

`lib/pool.grl:13-22` says the closure's captured environment is checked and that a handle "captured
by the closure" is refused by name; `:33-40` and `:123-128` say `pool::spawn` refuses a callback
that captured a borrow. Both are true of the builtins called directly [P 02, 04, 15] and false
through the wrappers, because the wrapper's parameter type erased what the builtin would have
inspected:

| | Program | Direct builtin | Through `lib/` |
|---|---|---|---|
| H1 | job captures a thread-affine `handle` | refused [P 02] | **accepted, runs** [P 01] |
| H2 | `Fn` holding `&mut` shared by every worker | refused [P 15] | **accepted** [P 16] (reads only: an unwritten `&mut` capture is read-only) |
| H3 | job borrows `data`; `data` is moved while the job runs | refused [P 04] | **accepted; one run printed `4 1`, another aborted (exit 134)** [P 13] |
| H4 | record field typed `Fn()->u64` holding a handle capture, sent as a `parallel_map` item | - | **accepted, runs** [P 11] |
| H5 | callee pushes a borrowing closure into a longer-lived vector | - | **accepted; SIGSEGV** [P 14] - not a concurrency bug: any `Fn` parameter |

And one thing refused that should be accepted: a `pool::join` branch that writes through its own
exclusive borrow, because `first` is typed `Fn` so it can be routed through `parallel_map` [P 05;
V lib/pool.grl:116-121]. The second branch may already do it [P 08].

### 1.6 Probe output

```
p01 wrapper, handle capture      1                                    (accepted)
p02 direct, handle capture       error: cannot transfer job capture `h`: h is thread-affine (a foreign handle with no audited classification)
p03 wrapper, job returned        error[E0010]: returned borrow escapes its declared input lifetime
p04 direct, borrow capture       error: a job handle may outlive this statement, so its callback cannot capture a borrow: move the value in instead
p05 join, first writes &mut      error: a closure that mutates a captured value is FnMut, not Fn: ...
p06 F: Send, closure + handle    error[E0012]: type does not satisfy Send: (closure () u64 (named .closure::env1)) is thread-affine (...)
p07 f() through F                error[E0002]: unknown function `f` in `main`
p08 join, second writes &mut     26                                   (accepted, correct)
p09 join, both branches use `a`  error[E0006]: use of moved, borrowed or partially initialized value: `a` was moved, ...
p10 join, &a and &mut a          error[E0008]: borrow conflicts with active access
p11 Fn field launders handle     1                                    (accepted)
p12 Fn param into F: Send        7                                    (accepted)
p13 wrapper job, data moved      4 / 1 exit 0;  4 then exit 134       (accepted, use after free)
p14 stash borrowing closure      exit 139                             (accepted, SIGSEGV)
p15 direct, Fn shares &mut       error: cannot share closure capture `ra`: an exclusive borrow cannot be shared
p16 pool::map, Fn shares &mut    2                                    (accepted)
p17 F: Fn()->R                   error: expected `,`, found `(`
p18 Boxed<F>: Send               error[E0012]: type does not satisfy Send: Boxed<(closure () u64 (named .closure::env1))> is thread-affine (...)
p19 id(closure), data moved      error[E0007]: move of unavailable or borrowed value
p20 local closure, data moved    error[E0007]: move of unavailable or borrowed value
p21 F: Share, closure with &mut  error[E0013]: type does not satisfy Share: (closure [0] () u64 ...) is an exclusive borrow cannot be shared
                                 (the `F: Send` call on the line before, an FnMut writing through &mut, is accepted)
p22 non-generic wrapper of p13   ok                                   (accepted)
p23 store &d into Holder<d>      error[E0007]: move of unavailable or borrowed value   (the loan outlives the call: correct)
p24 store &local into Holder<d>  error: captured writeback violates invariant lifetime (correct)
p25 by-value FnMut, writes &mut  7 / 7                                (accepted, correct)
p26 dyn over a borrowing record  error: a dyn value cannot hold borrowed data: its lifetime would be lost   (correct)
p27 dyn over an `Fn` field       exit 134                             (accepted; called after the frame is gone)
```

## 2. The design

**A closure type in a signature states three things besides its parameters and result: how it may
be called (`Fn`/`FnMut`, exists), what its captures may cross (`Send`, `Share`), and how long its
captures borrow (a region). They are checked once, where a closure value with a known environment
is converted to that type, and carried in the type from then on.**

### 2.1 Grammar

```
closure-type := ("Fn" | "FnMut") [ "<" bound { "," bound } ">" ] "(" [ type { "," type } ] ")" "->" type
bound        := "Send" | "Share" | "Owned" | region-name
type-bound   := "Send" | "Share" | "Owned" | interface      // in `<T: ... + ...>`; `Owned` is new
```

- `Send`, `Share`: the captures classify, by the table in 1.2. `Share` on `FnMut` is an error at the
  declaration (an environment that is written cannot be shared - today's `require_parallel_closure`).
- At most one of `Owned` or a region name. `Owned`: no capture holds a borrow. A region name `s`:
  every borrow the closure holds comes from `s`. Neither written: **in a parameter's own type, a
  fresh region for that parameter** (it borrows for the call; the callee may call it and pass it on,
  not keep it); **in any other position, `Owned`**.
- `Owned` as a bound on a type parameter: the type holds no borrow (`contains_borrow` is false).
  `Send`, `Share` and `Owned` are reserved names already or would be [V n:15907].

Why inside `<...>`: a nominal type already takes its lifetimes there (`Holder<d>` [P 23]), an
uppercase reserved word and a lowercase region cannot be confused, and nothing is appended after
the result type, where `Fn() -> Fn() -> R + Send` would be ambiguous. Alternatives if the director
prefers: a prefix (`Send Fn() -> R`), or a suffix clause (`Fn() -> R where Send, s`).

### 2.2 What a closure type stores

No new field. `mode` gains bits: 1 `FnMut` (today), 2 `Send`, 4 `Share`, 8 `Owned`. `regions` holds
the one written or implied region for a signature type; a closure expression's type keeps its
captured-region list and its `env` as today. The interface row for a closure type is already
`(closure mode regions (params) result ENV)` [V docs/design/separate-compilation.md:157-160], so
the bounds are in the signature row with no new syntax; `Owned` on a type parameter is one more bit
in the bounds mask beside `Send`/`Share` (bit 8; bit 4 marks a value parameter [V n:10191-10208]).
The interface format version changes because old readers accept only modes 0 and 1 [A].

### 2.3 The typing rule

Converting a value of closure type `A` to an expected closure type `E` (argument, assignment,
field initialiser, element, return) requires, besides today's signature match:

1. **Call mode.** `A` is `Fn`, or `E` is `FnMut` (today's rule [V n:11405-11418]).
2. **Capabilities.** For each of `Send`, `Share` that `E` states:
   - if `A` has an environment (it came from a closure expression, or through a generic parameter),
     every capture classifies under `transfer_capability` - today's `require_closure_captures`, moved
     from five builtins to one place;
   - if `A` is itself a signature type, `A` states the same bound.
   A named `fn` is capture-free and has all three.
3. **Borrows.**
   - `E` is `Owned`: `A` holds no borrow (its region list is empty, or it is `Owned`).
   - `E` names a region `r`: each region `A` holds is `r`. At a call, `r` is instantiated like the
     region of a reference parameter: if `r` labels other arguments or the result, the closure's
     loans are bonded to those holders (`call_bonds`, generalised from "to the result" to "to what
     the signature names" [V n:4352-4380]) and a capture from a local is refused where `r` is
     storage that outlives the local, exactly as `&local` is today [P 24]; if `r` labels nothing
     else it is the call itself, and the loans end when the call's temporaries do.
4. Dropping a bound is always allowed (`Fn<Send, Owned>` where `Fn` is expected); adding one never.

And one change to classification: `transfer_capability` and `contains_borrow` on a closure type
with **no** environment answer from the type's own bits and region instead of "yes" and "no"
[V n:9473-9475, 11189-11193]. That closes H4 and the generic route [P 12] with no further rule: a
record with a field `Fn() -> u64` is not `Send`; with `Fn<Send>() -> u64` it is, and whoever built
it was checked at the field initialiser.

Inside a function, a parameter typed `Fn<r>(..)` is a value holding a borrow from `r`, like a
record `Holder<r>` parameter: returning it or storing it into storage that does not name `r` is the
existing writeback/escape error. That closes H5. The library function that genuinely hands a
call-scoped closure to another thread (`pool::join`) does so in an `unsafe module`, through the
unsafe core's raw `(code, env)` entry; the signature is its contract and its body is what is
audited - the same division `unsafe struct ...: transferable` already has.

### 2.4 Scopes: borrows that outlive a named lifetime

```grail
pub fn scope<s, R: Owned>(body: FnMut<s>((&Threads<s>)) -> R) -> R;
impl Threads<s> { pub fn spawn<T: Send + Owned>(self: (&Self), f: FnMut<Send, s>() -> T) -> ScopedThread<s, T>; }
```

`s` is an ordinary region parameter, chosen at the call like any other. It appears twice on
purpose: as the *body's* capture bound, so everything the body captured lives at least `s`; and as
the scope object's region argument, so everything stored in the scope must come from `s`. One rule
connects them:

> **R-env.** When a closure expression is checked against an expected type `Fn<s>(..)` /
> `FnMut<s>(..)`, then inside its body the environment's lifetime *is* `s`.

Today the environment is the body's region 1 and parameter regions are separate [V n:28713-28718];
R-env makes them one number when the expected type says so. Then, in
`thread::scope(|t| { t.spawn(|| use(&x)); ... })`:

- a spawned closure that captures the body's own captures holds region `s`: accepted by 2.3(3);
- one that captures a local of the body holds region 0: refused, the error P24 gives for a
  reference;
- its loans are bonded to the scope object, a parameter of the body, so they stay live to the end
  of the body: the body cannot touch `x` again while a thread may [P 23 is this for references];
- two spawned closures that both capture `&mut x` conflict at the second capture - the first loan
  is still held (point 3, for scopes);
- `R: Owned` and `T: Owned` keep a `ScopedThread<s, T>` or a reference from leaving through the
  result, as `task_scope` checks by hand today [V n:27237-27239].

It is sound for any `s` the caller picks: a longer `s` only demands more of the body's captures,
and no region instantiated at a call is shorter than the call. `Threads<s>` has no public
constructor. Limitation: the body must be a closure *expression* at the call (or bound with the
type written), because R-env needs the expected type; a pre-built closure value will have its
spawns refused. `task_scope` and `pool::scope` are the same signature with a context parameter.

**Assumed, to be prototyped first (stage 5):** that bonding a closure's loans to a holder reached
through a *shared* reference (`self: (&Self)`) behaves as P23 shows for `&mut` [A]; if not,
`spawn` takes `(&mut Self)`, which a scope body can supply.

### 2.5 Point (3): exclusive borrows in one branch

Nothing new is needed for `join`; the pieces exist and only the signature is wrong.

- A branch that writes through a captured `&mut` is `FnMut` [P 05]. A job runs once on one worker,
  so the worker branch is `FnMut<Send>`, not `Fn<Share>`; `Send` of `&mut T` is `T: Send` and of
  `&T` is `T: Share` [V n:9421-9435] - the SIMD note's sentence, verbatim
  [V origin/gaps12-simd-design docs/design/simd-layout-parallel-loops.md:478-480].
- "Nothing else can touch the data until the join": each branch's closure holds its loans from the
  moment it is written, both are arguments of one call, and two that overlap are refused before the
  call is checked [P 09, 10]. The loans end with the call's temporaries - at the join.
- A parallel loop's callback runs on several workers at once: `Fn<Share>`. It cannot hold an
  exclusive borrow (`&mut T` is never `Share`), and it cannot reach the slice being split because
  that argument is an exclusive loan of the whole of it [V lib/pool.grl:101-104].

### 2.6 Interactions

- **`Fn` / `FnMut`.** Orthogonal to the bounds, except `FnMut<Share>` is refused. `Fn<Send>` is "one
  thread at a time, any thread"; `Fn<Share>` is "several at once".
- **Generic `F`.** Unchanged: an un-erased closure type satisfies `F: Send`, `F: Share`, `F: Owned`
  structurally [P 06, 18]. A callable bound (`F: Fn() -> R`) is not proposed: it buys a
  monomorphised call and costs a specialisation per closure, and nothing in the concurrency model
  needs it. It can be added later without touching this design.

  *What it would take (Q5, deferred).* Every `map`/`for_chunks`/`sort_by` callback is an indirect
  call through the closure's code word [V n:23974-23990], which the optimiser cannot inline, and
  run-time parity with C and Rust is a pillar (`docs/design/runtime-parity.md`). The pieces:
  (1) a bound `F: Fn(T) -> U` / `F: FnMut<Send>(T) -> U` in the generic list - the parser reads a
  closure type after `:` where it reads an interface name today [P 17; V n:10225-10260] - recorded
  per parameter beside the interface constraints; (2) in the generic body, a value of type `F` is
  callable with that signature and mode [P 07], and the bound's `Send`/`Share`/region are what the
  body may assume of it; (3) at instantiation the bound is checked by rule 2.3 against the closure
  type `F` is bound to, which still has its environment [P 06]; (4) a closure expression passed for
  `F` takes its parameter types from the bound, as `closure_hint` does from an `Fn` parameter
  [V n:28894-28911]; (5) the specialisation's call `f(x)` is emitted as a direct call to that
  closure's body symbol, which is known because `env` names the closure - this is the whole gain,
  and it is where inlining becomes possible. The cost is one copy of the library function per
  closure expression and a named-function argument needing its own zero-capture closure type.
  Nothing in 2.1-2.4 changes: the bound reuses the closure-type grammar and rule 2.3 verbatim, so
  `pool::map<T, U, F: Fn<Share>(T) -> U>(items: T[], f: F)` can replace the erased signature
  later, function by function, where a benchmark says the indirect call matters.
- **`dyn I`.** Erased the same way, but default-deny already: it is neither `Send` nor `Share`
  [V n:9329-9332] and is refused borrowed data where it is built [P 26]. So the object has no hole
  of its own; what it lacks is a way to say more (`dyn<Send> I`, `dyn<s> I`) - follow-up F1 in
  section 5. A borrow does get behind a `dyn` today through a record with an erased `Fn` field
  [P 27], which D2 closes.
- **Records, vectors, channels.** The field or element type carries the bounds, so
  `chan::bounded<FnMut<Send>((&Ctx)) -> unit>` is a `Send` channel of closures and the executor
  mailbox is a library type. The default outside a parameter is `Owned`, so a stored closure that
  borrows must name its region and the record must carry it: `struct Deferred<d> { run: Fn<d>() -> unit }`.
- **Interface files.** 2.2. The bound is part of the type, the type is in the signature row, and an
  importer checks a call with no body. Nothing about a *callee's* captures crosses a module edge.
- **Existing code.** Sequential callbacks (`vecs::sort_by(v, f: FnMut(T, T) -> bool)`) keep
  compiling: a parameter's default is "borrows for the call". What changes: a function that
  *returns or stores* a closure it was given must now say so (`Fn<a>`), and a closure stored in a
  field or returned while holding a borrow must name the region - today accepted silently, and the
  cases that break are the H5 shape [P 14]. How many corpus programs do either is not measured [A].

### 2.7 Diagnostics

```
error: cannot transfer closure capture `h`: h is thread-affine (a foreign handle with no audited classification)
  = note: `thread::spawn` takes `f: FnMut<Send, Owned>((&Ctx)) -> R`: the closure runs on another thread

error: this closure borrows `data` (through `view`), and `pool::spawn` takes an `Owned` closure:
       the job may outlive this statement; move the value in instead

error: this closure borrows `local`, which does not live as long as the scope `s`
  = help: declare `local` before the `thread::scope` call

error: cannot share closure capture `ra`: an exclusive borrow cannot be shared
  = note: `pool::chunks_mut` calls `f: Fn<Share>((&mut [T])) -> unit` from several workers at once

error: `Fn() -> u64` says nothing about what it captured, so it is not `Send`
  = help: write the field as `Fn<Send>() -> u64`

error: `FnMut<Share>` is not a type: a closure that writes its captures cannot be shared; use a Mutex
```

The first line of each is today's text where one exists (`capability_fail` [V n:9584-9617]); the
note names the parameter that asked.

### 2.8 The library signatures

```grail
module pool;

pub struct Pair<A, B> { first: A, second: B }
pub enum Class { Frame, Normal, Background }

// Both branches may borrow the caller's frame; `first` may run on a worker. Each is called once.
pub fn join<A: Send + Owned, B: Owned>(first: FnMut<Send>() -> A, second: FnMut() -> B) -> Pair<A, B>;

// Callbacks called from several workers at once: Fn, captures Share, borrows for the call.
pub fn map<T: Send + Owned, U: Send + Owned>(items: T[], f: Fn<Share>(T) -> U) -> U[];
pub fn run<U: Send + Owned>(count: u64, f: Fn<Share>(u64) -> U) -> U[];
pub fn for_chunks<T: Send + Owned, U: Send + Owned>(data: T[], grain: u64, f: Fn<Share>(T[]) -> U) -> U[];
pub fn chunks_mut<T: Send>(data: (&mut [T]), grain: u64, f: Fn<Share>((&mut [T])) -> unit) -> unit;
pub fn range<C: Share>(n: u64, grain: u64, ctx: (&C), f: Fn<Share>(u64, u64, (&C)) -> unit) -> unit;
pub fn reduce<C: Share, R: Send + Owned>(n: u64, grain: u64, ctx: (&C), zero: R,
        leaf: Fn<Share>(u64, u64, (&C)) -> R, merge: Fn<Share>(R, R) -> R) -> R;

// A handle that may outlive the frame: nothing borrowed goes in or comes out.
pub fn spawn<R: Send + Owned>(f: FnMut<Send, Owned>() -> R) -> Job<R>;
pub fn wait<R: Send + Owned>(job: Job<R>) -> R;

// N jobs that may borrow whatever the body captured.
pub fn scope<s, R: Owned>(class: Class, body: FnMut<s>((&Jobs<s>)) -> R) -> R;
impl Jobs<s> { pub fn spawn(self: (&Self), f: FnMut<Send, s>() -> unit) -> unit; }
```

```grail
module thread;

pub fn spawn<R: Send + Owned>(cfg: Config, f: FnMut<Send, Owned>((&Ctx)) -> R) -> Thread<R>;
pub fn join<R: Send + Owned>(t: Thread<R>) -> R;
pub fn try_join<R: Send + Owned>(t: Thread<R>) -> R |? TaskFailure;
pub fn detach<R: Send + Owned>(t: Thread<R>) -> unit;
pub fn scope<s, R: Owned>(body: FnMut<s>((&Threads<s>)) -> R) -> R;
impl Threads<s> {
    pub fn spawn<T: Send + Owned>(self: (&Self), cfg: Config, f: FnMut<Send, s>((&Ctx)) -> T) -> ScopedThread<s, T>;
}
pub fn with_current<R>(f: FnMut((&Ctx)) -> R) -> R?;

pub fn executor(ctx: (&Ctx), capacity: u64) -> Executor;                 // Executor: Send + Share
impl Executor {
    pub fn call<R: Send + Owned>(self: (&Self), f: FnMut<Send>((&Ctx)) -> R) -> R;   // waits: may borrow
    pub fn post(self: (&Self), f: FnMut<Send, Owned>((&Ctx)) -> unit) -> bool;       // queued: may not
}
```

Differences from `concurrency-model.md` 2.1/2.3, all forced by what a signature must now say:
`join`'s first branch is `FnMut<Send>` (was `Fn`); the scope signatures lose the separate context
`C` (the body captures it; `Jobs<s>`/`Threads<s>` take a region, not a type); `thread::detach`
needs no extra rule because `spawn` is already `Owned`; the task form is
`task::scope<s, R: Owned>(body: FnMut<s>((&Tasks<s>)) -> R)` with
`Tasks<s>.spawn<T: Send + Owned>(f: FnMut<Send, s>(CancelToken) -> T) -> Task<s, T>`. `Jobs<s>`,
`Threads<s>` and `Ctx` are neither `Send` nor `Share`, by an ordinary non-`Send` field or the
declaration - no builtin kind 14 [A: that a record can be declared so; `handle` and unclassified
pointers already are].

### 2.9 Each builtin's check, re-expressed

| Check today | Becomes |
|---|---|
| `require_parallel_closure(.., 1)`: not `FnMut`, captures `Share` | parameter `Fn<Share>(..)` |
| `require_parallel_closure(.., 0)`: captures `Send` | parameter `FnMut<Send>(..)` |
| `contains_borrow(closure)` in `parallel_spawn` | `<Owned>` on the closure type |
| `contains_borrow(result / item)` | `R: Owned`, `T: Owned` |
| item / result / context / element classify | `T: Send`, `C: Share` (exist) |
| "context is a shared reference or plain value" | `ctx: (&C)`, or the body captures it |
| "closure passed by value", arity, `unit` result | the parameter's written type |
| "slice must be exclusive" | `data: (&mut [T])` (exists) |
| `task_scope` body takes `&Scope<C>`; `spawn` takes a scope reference | `Tasks<s>` and its method |
| `Scope<C>` never `Send`/`Share` | the library type's own classification |
| `contains_task` | **not expressed** - Q1 |

### 2.10 Library handles (director's note, 2026-11-16)

Q3 was a builtin handle (`Job<R>`) that owned a closure while its type showed only the result. When
`Job`, `Task` and `Thread` become library records over the unsafe core the same question returns,
and one of two rules must cover each handle - checked by a case when stage 2 moves `pool::spawn`:

- **The handle is `Owned` by construction.** `Thread<R>` and `Job<R>` take `FnMut<Send, Owned>`
  closures and an `R: Owned` result, so nothing they hold is a borrow and there is no loan to keep.
  This is the rule for every handle that may outlive its frame.
- **The handle names the region in its type.** `ScopedThread<s, T>`, `Task<s, T>`: the closure is
  `FnMut<Send, s>`, the handle is `Handle<s, ..>`, and the ordinary region rules keep the loan for as
  long as the handle lives.

A library handle that stores a borrowing closure behind a raw pointer *without* either rule is
exactly Q3 again; `may_hide_borrow` cannot see through a raw pointer, so an `unsafe struct` holding
one must state `s` in its type or take only `Owned` closures. That is a rule for the unsafe module's
author, recorded here so the stage 2 review checks it.

## 3. Why not B or C

- **B alone (generic `F` with bounds).** Half of it exists and is kept. But the concurrency model
  must *store* closures: in a `Thread<R>`'s start record, a job record, a mailbox, a channel. Those
  are erased by construction, so an erased closure type that carries its bounds is needed whatever
  B does - and once it exists B adds only a monomorphised call. B also needs a callable bound and
  closure-parameter inference through `F` [P 07, 17], says nothing about lifetimes by itself, and
  makes every `spawn`/`join`/`map` call site a new specialisation of the library function, in a
  compiler whose build time is watched [V docs/design/compile-speed.md exists; cost not measured, A].
- **C (a fixed set of intrinsics).** It is what exists, and section 1.5 is what composing them in a
  library produces: the checks live on the builtin's own argument and are lost one wrapper up. Any
  fixed set also has to grow for each new shape (`Executor.call`, a channel of closures,
  `Once.get_or_init`, `Condition.wait_with`), and the director has ruled that such a gap is to be
  fixed in the language (concurrency-model.md, Q4).

## 4. Staged plan

Each stage is a compiler change plus corpus cases, and after stages 2, 3 and 4 one construct leaves
its builtin. Files: `compiler/native.grl` unless stated.

| Stage | Change | Corpus: accept | Corpus: refuse | Risk |
|---|---|---|---|---|
| **0. `Owned` and classification of erased closures** | `Owned` type-parameter bound (parser [n:10225], `require_constraints` [n:9688], bounds mask, interface row). `transfer_capability`/`contains_borrow` answer from the type's bits for an environment-less closure [n:9473, 11189]. No syntax for closures yet, so an erased closure is simply not `Send`/`Share`. | `R: Send + Owned` with a vector result | P11, P12 (now errors); `R: Owned` with `&T` | programs that send records holding `Fn` fields stop compiling until stage 1 gives them `Fn<Send>` - land 0 and 1 together if any exist in the corpus |
| **1. Bounds on closure types** | grammar 2.1 [n:12541]; mode bits; rule 2.3 (1), (2), (4) in `require_type`/`callable_contract` [n:11004, 11369]; `Owned` half of (3); interface reader/writer [n:39599, 40040] and format version; `fmt.grl`, `docgen.grl` spell the type | `Fn<Send>` field holding a plain capture; `fn` value to `Fn<Send, Share, Owned>`; dropping a bound | P01, P16 shapes written against a `<Send>`/`<Share>` parameter; borrowing closure to `<Owned>`; `FnMut<Share>`; adding a bound to an erased value | type identity: `Fn<Send>()` and `Fn()` are distinct interned types that convert one way - every `same_type` on closures must go through the conversion, or generic inference will report mismatches |
| **2. `thread::spawn` and `pool::spawn` off their builtins** | `lib/thread.grl` over the unsafe core; `pool::spawn` with the 2.8 signature; delete `parallel_spawn`'s capture and borrow checks [n:27100-27112] (the builtin, if it survives as the raw entry, is `unsafe module` only) | `tests/pool/job_handle.grl` unchanged | P01, P13 as corpus cases with the new diagnostics | the unsafe core's raw entry must not be reachable from safe code |
| **3. Regions on closure types; call-scoped parameters** | region half of 2.3 (3): a signature closure type carries a region; `call_bonds` bonds by named region and loses the closure special case [n:4352-4366]; a closure parameter is a borrow holder in the callee | P19, P20, P25 unchanged; a callback stored in a callee-local vector | P14 (H5); a parameter closure returned as `Fn` | the migration in 2.6: functions that return or keep a closure parameter. Run the corpus once with the check as a warning to count them before making it an error |
| **4. `pool::join` with borrowing branches** | `join` with the 2.8 signature over the scheduler's fork (or, before the scheduler lands, over the stage-2 raw spawn in an `unsafe module`) | P05 (now accepted, prints 33); P08; a branch holding `&T` of `Share` data | P09, P10 unchanged; a branch capturing `&H` of a non-`Share` handle | none in the checker - this stage is a signature |
| **5. R-env and `thread::scope` / `pool::scope` / `task::scope`** | R-env in `closure_literal` [n:29153, 28716]; bonds to a holder named by the region (2.4); library scopes; delete `task_scope`/`spawn` builtins and kind 14 | scope body spawning two threads on disjoint `&mut`; on one shared `&` | body-local captured by a spawned closure; `x` used in the body after a thread borrowed it mutably; two threads capturing `&mut x`; `ScopedThread` returned from the body | the assumption in 2.4 (shared-receiver bonds) and that region 1 can be unified with a parameter region without disturbing closure bodies that never asked. Prototype on references first: P23/P24 through `(&Self)` |
| **6. Loops and the rest** | `map`, `run`, `for_chunks`, `chunks_mut`, `range`, `reduce`, `Executor`, channels of closures; delete `parallel_map`, `parallel_for_chunks` checks and `require_parallel_closure` | `tests/pool/*` | P15/P16 shape through `pool::map` | `contains_task` (Q1) |

Stages 0-1 are worth doing even if the rest slips: they close H1, H2 and H4 for every wrapper that
adopts the bound, and `lib/pool.grl` can adopt it the same day by re-typing its parameters while
still calling the builtins.

## 5. Open questions

- **Q1. `contains_task`.** Builtins refuse a `Task`/`Job` handle inside an item or result
  ("a second wait would free one record twice" [V n:27072, 27109]). No bound expresses it. Is it
  still needed when `Thread<R>`/`Job<R>` are move-only library records with an ordinary drop? If
  yes it needs its own answer (a non-`Send` handle is the obvious one, but `Task` is `Send` today
  [V n:9404-9411]).
- **Q2. Spelling and the non-parameter default** - decided (D2, D3).
- **Q3. Why P13/P22 accepted - answered and fixed.** `call_bonds` did bond the closure's loans to
  the `Job<R>` temporary. They were lost one step later, when that temporary moved into its
  binding: `move_value` carries bonds to the new place only if the type shows a borrow, is not
  concrete, or `may_hide_borrow` [V n:6098]; and `hide_walk` treated `Job<R>` as only as
  borrow-capable as `R`, so `Job<u64>` could hide nothing. A job handle owns the closure it runs
  whatever `R` is. Fixed in `hide_walk` (kind 29 answers true); P13 and P22 are now
  `error[E0007]: move of unavailable or borrowed value`. It does not generalise to other results:
  a value can only carry a closure it does not show through a closure-typed field, a `dyn`, a
  generic parameter (all already "may hide") or a builtin handle, and `Job` was the one builtin
  handle that owns a closure (`Task` is spawned from a capture-free `fn` with an owned item
  [V n:27186-27205]). Results of *other* types that a callee fills from a stashed closure are H5,
  which is stage 3. Cases: `job-handle-holds-closure-loan-generic`, `-wrapper`,
  `job-handle-in-record-holds-closure-loan`, `job-handle-loan-ends-at-wait`.
- **Q4. A closure that borrows and is `Send` crossing a *task* boundary inside a scope**: tasks
  migrate between workers, so `Tasks<s>.spawn` needs `Send` of everything held across a suspension,
  which this design states only for captures. Locals held across a wait are the task design's
  question, not this note's.
- **Q5. Callable bounds on `F`** (B's other half) - deferred; say if a zero-indirection `join` is
  wanted for the frame loop, where the closure call is the only indirect call left.
- **F1 (was Q6). Bounds on `dyn`.** `dyn I` is erased like `Fn(..)` but is already default-deny:
  never `Send`/`Share`, never holding a borrow [P 26]. The follow-up is the same angle list -
  `dyn<Send> I`, `dyn<Share> I`, `dyn<s> I` - checked where a concrete value is boxed, so an
  interface object can cross a thread or hold a borrow honestly. Until D2 lands a borrow reaches
  behind a `dyn` through an erased `Fn` field [P 27]; `closure-bounds-probes/p27` must be a
  refusing corpus case when stage 0 lands.
- **Q7. How much existing code returns or stores a closure parameter** (stage 3 migration) - needs
  one corpus run, which this note was told not to make.

## 6. Implementation status (gaps12-closures)

- **Q3 fix** - `hide_walk` answers "may hide a borrow" for a job handle (commit a39c615).
- **Stages 0 and 1** - built. `Fn<Send|Share|Owned>(..)` and `FnMut<..>(..)` parse
  (`closure_bounds_list`; spelling in `closure_bound_bit` / `closure_bounds_text`); the bounds are
  bits 2/4/8 of a closure type's `mode` (bit 16 marks a closure seen during template validation);
  `closure_converts` is rule 2.3 (1), (2), (4) and the `Owned` half of (3); an environment-less
  closure is classified by its own bits (`transfer_capability` denial codes 12, 13);
  `Owned` is bit 8 of a type parameter's bounds (`owned_walk`). A closure argument converted to a
  bounded signature type keeps its loans through `call_bonds` (`closure_stated_borrower`).
  Interface format 6. `lib/pool.grl` re-typed per 2.8, except `join`'s first branch, which is
  `Fn<Send>` until stage 4. Every probe except P13/P14/P22/P27 (hole cases, covered by the Q3 cases
  or by stage 3) is a corpus case `closure-bounds-p*`, plus 22 cases for the feature itself.
- `fmt` keeps `Fn<Send, Owned>` and any generic argument list on one line (it split them at the
  comma). `docgen` needed no change: it prints signatures from source text.
- **Not built yet:** `Fn<s>` (stage 3, refused with "not implemented yet"), P14/H5, P27.

### 6.1 The `Owned` rule, refined (director, 2026-11-16)

`Owned` (and the non-parameter default) means: **every region of every borrow in the closure's
environment appears among the regions of the closure's own type (its parameters or its result). A
borrow the type does not name makes it not `Owned`.** Whatever stores the closure then carries the
region in its own type (`Iter<(&a K)>`) and the existing region checks follow it. This is what
`borrow_walk` already said of a closure type from a signature (kind 20: a result naming a lifetime
no parameter supplies is a borrow the value holds); `closure_hidden_regions` is now the one rule for
closure expressions too. A borrow of a local (region 0) can never be named.

The stage 3 count with this reading: 0 refusals in the corpus, Abundance and Borg. The 8 lazy
adapters of `lib/iter.grl` (`map`, `filter`, `flat_map`, `filter_map` as methods, `from_fn`,
`from_step`, `map`, `filter`) take `FnMut<Owned>(..)`; hashmap `keys`/`values`/`iter` compile as
before. Cases `closure-owned-*`.

**Limit found while enforcing it on a field.** Typing `Iter<T>`'s own field `step: FnMut<Owned>`
refuses `iter::map` itself: its step closure captures the source `Iter<(&a T)>` and yields `U`, so
`a` is in no part of the closure's type. That borrow is kept today by loan flow (a generic call's
result keeps its arguments' loans, `may_hide_borrow`), not by the type. So the non-parameter default
`Owned` cannot be enforced on fields as stated: either such a field names the region
(`Iter<a, T>`), or the rule counts a capture whose type is an aggregate holding the loan as
flow-tracked. Open question Q8; the field stays a bare `FnMut` until it is decided.
