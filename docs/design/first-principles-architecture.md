# Grail: first-principles architecture review

2026-10-30. **Independent research recommendation, not an agreed design.** Drafted from the
self-contained architecture brief, then cross-checked against this repository's record (§9).
No compiler, checker extension, benchmark or proof was produced for this document.

Evidence labels used below:

- **[fact]** — checked this session against a cited primary or official source (§10).
- **[record]** — established by this repository's earlier experiments or evidence files.
- **[hyp]** — a hypothesis I believe but which nobody has established.
- **[rec]** — a recommendation for discussion.

Syntax throughout is illustrative only. Words such as `read`, `mut`, `take`, `@`, `where`,
`suspend` and `using` are placeholders for semantics, not keyword proposals.

---

## 0. Summary

**Central question.** Can programmers think mainly in values and operations while the compiler
handles ownership, borrowing and lifetimes, without hiding Rust's complexity in an expensive
inference engine?

**Answer.** Largely yes for *accesses*, and only partly for *stored views*.

- **Accesses.** Most code reads, mutates or consumes an argument for the duration of a call.
  Second-class parameter modes check this with cheap local dataflow. No lifetimes, no reference
  types and no annotations are needed, and errors read in value terms.
- **Stored views.** Some values keep other values borrowed, such as ASTs of substrings, iterators,
  closures and in-flight I/O. There is one irreducible concept here: *this value keeps that value
  alive and frozen*. Its information must cross module boundaries. It can be one concept rather
  than several, named by values rather than durations, inferred locally, and frozen into reviewed
  API files. It cannot be made invisible without losing modularity or API stability.

**Preferred architecture: rooted value semantics.** Programmers learn three concepts:

1. **Owned values.** Values move. Copies are explicit except for trivially copyable data.
   Destruction is deterministic.
2. **Accesses.** Every parameter is `read` (the default), `mut` or `take`. An access is
   second-class: it cannot outlive the call unless the function's contract says a result or a
   flow keeps it.
3. **Dependencies.** A value that is not fully owned carries a static, type-structured
   *qualifier*: the set of roots it keeps borrowed, each marked shared or exclusive. A root is a
   named variable, parameter or block temporary. This covers views, view-carrying records,
   iterators, closures, in-flight I/O and device operations, and retained capabilities. The only
   borrow rule is: **while a value is live, the roots in its qualifier are frozen if shared, or
   unusable if exclusive.**

Five smaller mechanisms sit beside that core, each kept separate on purpose:

- **Suspension.** A static `suspend` effect with no `await` syntax. Suspended computations are
  never droppable values, frames have stable addresses, and task scopes are structured.
- **Cleanup.** Implicit destruction that cannot fail or suspend, plus *finish-or-abandon*
  resources for cleanup that can.
- **Authority.** Capabilities are ordinary values.
- **Verification.** Contracts and a total logic fragment, translated to Lean and checked by its
  kernel.
- **Staging.** Compile-time evaluation of ordinary code, generating declarations that are then
  type-checked like any other code.

Generics use one coherent interface mechanism. Bodies are checked parametrically, compiled once
with witness tables in development builds, and specialised in release builds.

**Verdict.**

- **Genuinely removed:**
  - lifetime parameters and reference types in most signatures;
  - reborrow and two-phase-borrow special cases;
  - Rust's NLL "problem case 3" class of false rejections (a hypothesis to confirm in X2);
  - `Pin`;
  - the `Fn`/`FnMut`/`FnOnce` trio;
  - the `Send`/`Sync` pair for ordinary code;
  - async drop;
  - owned-buffer or leak workarounds that completion-based I/O needs when cancellation works by
    dropping futures;
  - a separate macro language.
- **Displaced, not removed:**
  - flow clauses when a function stores into caller storage;
  - explicit contracts on interface methods, foreign functions and public APIs (tool-written);
  - runtime generation checks for mutable aliased graphs;
  - fiber stack memory;
  - deliberately conservative rejections.
- **Not new in itself.** The ingredients are prior art: mutable value semantics, reachability and
  capture types, Swift lifetime dependence, Mojo origins, structured concurrency and Lean.
  The possible contributions are the *integration*, because one qualifier mechanism serves seven
  jobs (§1.14), and the cancellation, cleanup and contract-publication rules. These are claims to
  test, not results.
- **Largest risks:**
  - the share of real APIs that need more than the contract vocabulary (experiment X1);
  - fiber memory at very high task counts (X3);
  - runtime speed of witness-table generics in development builds (X4);
  - strong incumbents converging: Mojo 1.0 is open source [record]; Swift is extending
    nonescapable types [fact].

---

## 1. The architecture

### 1.1 Owned values

- Every binding owns its value. Passing a value with `take`, assigning it or returning it moves
  it, and later use of the source is an error.
- Only `copy` types are duplicated implicitly. These are bit-copyable types with no destructor
  and no exclusive qualifier, such as scalars, small plain records and shared views.
  Everything else requires explicit `.clone()`.
- No implicit copy-on-write and no implicit reference counting.
- Destruction runs at scope end, in reverse declaration order, for values that were not moved
  away. A `drop` body cannot fail or suspend. Scope-end destruction is preferred to Mojo's
  as-soon-as-possible destruction [fact] because guards and resources need predictable points.
  This is a minor decision.
- Layout is compiler-chosen unless declared, for example `layout(C)`. The layout of a non-opaque
  public type is part of its interface.

### 1.2 Accesses: second-class by default

Parameter modes:

- `read` — the default. Shared and immutable for the call; the argument is not copied.
- `mut` — exclusive for the call; writes are visible to the caller.
- `take` — ownership transfers into the callee.

Rules:

- An access is a *place*. The callee writes `x.f`, never `*x`.
- An access begins when the call begins, after all arguments are evaluated. So `v.push(v.len())`
  is ordinary code, with no two-phase-borrow rule.
- Aliasing between arguments is checked by paths. `f(mut x.a, read x.b)` is accepted.
  `f(mut a, mut a)` is rejected. Index paths collapse to the container: `f(mut v[i], read v[j])`
  is rejected, and disjoint element access goes through library split primitives such as
  `split_at_mut` and `pair_mut`.
- [rec] Call sites mark `mut` for non-receiver arguments, for example `sort(mut xs)`. Readers
  most need to see mutation of their own variables. Receivers are not marked: `xs.sort()` gets
  its mode from the method declaration. Moves are not marked, and use after a move is an error.
  The record's S2/S3 comparison remains open; this is my choice within it.
- One fixed *view coercion* is provided. An owned `String`, `Vec[T]` or `Box[T]` place passed
  where its view type (`Str`, `Slice[T]`, `ref T`) is expected is viewed. It is single-step,
  non-transitive, declared by the type's single `View` implementation, and never triggers method
  lookup. This is the only implicit conversion in the language.

Projections are ordinary functions that return scoped views (§1.3), such as `get_mut` or `entry`.
I recommend **no** Hylo-style `yield` accessors and no computed properties in v1. Post-access
fix-up code is an explicit guard with an infallible `drop`, or an explicit method. The brief rules
out executable properties, and yield accessors add a coroutine form to the core for a modest gain.

### 1.3 Dependencies: type-structured qualifiers on values

**Definitions.**

- **Root.** A local binding, a parameter (from the callee's side), or a block temporary.
  A block temporary is a materialised lambda environment or an extended temporary. A field path
  `x.f.g` is a sub-root. Index paths collapse to their container.
- **Qualifier.** A finite set of `(root-path, shared | exclusive)` pairs.
- **Where qualifiers attach.** To every *view-carrying position* of a type, not to the value as a
  whole:
  - the target of `ref T`, `Slice[T]`, `Str`, `mut ref T` and `MutSpan[T]`;
  - the environment of a closure;
  - the nominal slot of a record that declares view-carrying fields.
- **Type arguments.** A type argument carries its own positions. A `Vec[Str]` held in a local has
  shape `Vec[Str^{src}]^{}`: the vector's own storage is owned, and its elements view `src`.
  This structural indexing is what lets elements copied out of a container keep only the
  *elements'* dependencies rather than the container's. Experiment 02 found the flat
  alternative creates false rejections [record]. Reachability types put qualifiers on type
  components for the same reason [fact].
- **Owned and scoped.** A value is *owned* when every qualifier in its type is empty. Otherwise it
  is *scoped*. "Scoped" means bounded by its roots, not short-lived (§1.4).
- **Exclusive values are affine.** A value with any exclusive qualifier cannot be copied.
- **Nominal slots.** [hyp] A user record has one dependency slot: the union of its view fields
  that do not come from type arguments. Several named slots (`struct Pair @{short, long}`) are
  deferred. Field-sensitive tracking inside function bodies is free and kept. Across boundaries,
  one slot per nominal type is expected to cover nearly all real APIs; Rust structs with several
  lifetime parameters are uncommon. X1 tests this.

**The single borrow rule.**

At each program point, for every value `v` that is live there and every `(r, m)` in its
qualifier, the following holds.

- If `m` is *shared*: `r` and overlapping paths may be read and viewed again. They may not be
  mutated, moved or destroyed.
- If `m` is *exclusive*: `r` and overlapping paths may not be used at all except through `v`.

"Live" means a later use may observe the value. That includes uses through any value that
inherited part of its qualifier. Scope-end destruction counts as a use only if the type's `drop`
reads through its view positions. Compiler-generated destruction of containers of views does not
read them. A user-defined `drop` is assumed to read them unless it declares otherwise, which is a
trusted claim. This is the analogue of Rust's drop-check "eyepatch".

**Local inference** is two standard analyses per function:

- forward propagation of qualifiers over a finite, monotone lattice, with union as the join;
- backward liveness.

Then every access is checked against the qualifiers of the values live at that point.

- A local's qualifiers are *flow-sensitive type state*. They grow when values flow in and reset
  when the binding is reassigned. So locals never suffer the "invariant lifetime" errors Rust
  reports when a `Vec<&'a str>` is fixed too early.
- The referent of a first-class `mut ref T` is the exception. Its qualifiers are invariant for
  the reference's lifetime. They are solved as a local inference variable and written back to the
  root when the reference dies. This is ordinary local region inference, never exported.

**Why this avoids NLL problem case 3.** The dependency travels with the *value*, so a borrow
returned on one branch does not keep its root blocked on another branch. Lifetimes are not
regions that must cover every program point after creation (example E6). This is the
Polonius-style location sensitivity, built into the formulation instead of added later.
[hyp] Cost is linear in program points × live scoped values × qualifier size, with small
constants for ordinary functions. Experiment X2 tests this.

**Moves of roots.** Moving a root while a live value depends on it is rejected, even if the heap
bytes would not move. This conservative rule is lifted for exactly one packaging construct,
`Bundle` (§1.5, case 3). The general "rename the root on move" extension for heap-stable owners
is deferred.

### 1.4 What can escape which boundary

"Scoped" here means "bounded by and blocking its roots", not "short-lived". A scoped value may
live for the whole program if its root does.

| Boundary | Owned value | Shared-scoped value (views, read-capturing closures, iterators) | Exclusive-scoped value (`mut ref`, `MutSpan`, `IterMut`, `Entry`, mut-capturing closures) | Access (a parameter mode) |
| --- | --- | --- | --- | --- |
| Statement or block end | Yes | Yes, if its roots outlive the destination | Yes, same rule | Ends with its call |
| Return from function `f` | Yes | Only if its qualifier is within `f`'s result contract, which ranges over `f`'s parameters and never its locals | Same, and the caller's argument path stays exclusively blocked while the result lives | Cannot be returned; a view derived from it can, per the contract |
| Into caller storage through `mut m` | Yes | Only with a declared flow `x -> m`; the caller's `m` then keeps `x`'s roots | Same; the caller's root becomes exclusively blocked for as long as `m` lives | No |
| Into a local container, including heap containers | Yes | Yes; the container inherits the qualifier at that position | Yes; the container becomes affine | Through a view of it |
| Captured by a closure | By move | Yes; the closure's qualifier includes it | Yes; the closure becomes affine and not `Shareable` | Yes; the closure gains that root |
| Across a suspension point | Yes | Yes, because frames are address-stable | Yes | Yes |
| Into a child of a structured scope | Yes | Yes, if `Shareable` and the roots outlive the scope | Moved into exactly one child, unless `ThreadBound` | Through captures |
| Detached or service task, global storage, channel to an unrelated task | Yes, unless `ThreadBound` | **No** | **No** | No |
| `Bundle` owner/view package | — | The view may keep only the owner root | Owner frozen for the bundle's life | — |
| Module or package boundary | Yes | As the frozen contract states | As the frozen contract states | Modes are in the signature |

Answers to the brief's two specific questions:

- **Returned mutable spans are allowed.** `fn tail(xs: mut Vec[T], n: Int) -> MutSpan[T] @xs`
  returns an exclusive-scoped value. The caller's `xs` is unusable while the span, or anything
  that inherited from it, is live. The span may be stored in local containers, captured, held
  across suspension, or moved into one child task.
- **Stored scoped values are allowed.** `struct Parser { lex: mut ref Lexer, toks: Vec[Str] }` is
  a scoped record with qualifier `{lexer: exclusive, src: shared}`. It goes wherever such a value
  may go under the table.

### 1.5 The four cases

1. **AST over an external immutable buffer.** A zero-copy target. `parse(src)` returns
   `Expr @src`. The buffer is frozen while the AST is live, with no copies, no annotation inside
   the package, and an explicit contract in the public API file. Example E1.
2. **Containers and trees of views across generic and module boundaries.** A zero-copy target.
   Qualifiers travel inside type arguments, for example `Map[Kind, Vec[Token^{src}]]`, so generic
   code needs no annotations and keeps element dependencies separate from container storage.
   Example E2.
3. **A document owning its source and internal views.** Use the `Bundle[O, V]` library primitive,
   which needs a little language support.
   - `Bundle.build(owner, fn(src) => view)` checks that the closure's result keeps nothing but the
     fresh root `src`.
   - A bundle value is *owned*: its qualifier is empty, so it moves and returns freely.
   - `bundle.view()` re-roots the view's dependency onto the bundle: it returns `V @bundle`.
   - The owner type must be `StableBorrow`: views into it point into heap storage that does not
     move when the owner moves. Strings with inline small-string storage do not qualify.
   - The owner is frozen for the bundle's lifetime. Editing means `rebuild`: drop the view, mutate
     the owner, rebuild the view.
   - For editable documents, use offsets or ropes; the record shows checked offsets are a fast
     representation [record].
   - This is the pattern of Rust's `yoke`/`self_cell` crates, made sound by the qualifier
     discipline rather than by `unsafe` user code. Example E3.
4. **Mutable graphs with aliases, deletion and invalidation.** No reference discipline makes
   free aliasing, mutation, deletion and zero runtime checks safe without proof. Two library
   patterns are provided:
   - *Generational handles.* `Arena[T]` with copyable `Id[T]`. Access is a projection with a
     generation check (a load and a compare). Deletion returns the value, and stale ids return
     `None` or trap. `pair_mut` checks distinctness. A proof can discharge a check by proving
     `contains(id)`.
   - *Append-only regions.* Internal shared `ref`s and set-once edges allow cycles. There is no
     per-node deletion, and memory is freed at region end. This suits compiler IRs.

   Neither is a hidden runtime borrow check. Both costs are visible in the API. Example E4.

### 1.6 Contracts and modular checking

**A function's contract** has these components:

- `modes` — read, mut or take for each parameter.
- `result` — which *terms* the result may keep, per view-carrying position. A term is either:
  - `p` — the storage `p` refers to. For a `read` or `mut` parameter this is the caller's
    argument place. For a by-value view such as `s: Str`, it is the view's referent.
  - `p.deps` — only what the contents of that storage keep.

  A `take` parameter has only `p.deps`, because its own storage dies or moves on return.
- `flows` — for each `mut` parameter `m`, the terms that may be added to `m`'s qualifier,
  written `x -> m`.
- `callbacks` — each function-typed parameter is non-escaping (the default) or
  `escapes-into(result | m)`. Non-escaping callbacks receive fresh, per-invocation accesses.
- `effects` — `suspend` or not.
- `error` — the error type.
- `context` — the `using` list (§1.9).
- `declared properties` — opt-in only: `total`, `noalloc`, `nopanic`.

**Defaults**, used only where contracts cannot be inferred: interface (trait) methods, `extern`
declarations and function types.

- The result may keep every term of every parameter.
- No flows.
- Callbacks are non-escaping.
- No `suspend` unless written.

These defaults are permissive for implementers and conservative for callers.

**Refinement order.** `C1 ⊑ C2` when:

- the modes are equal;
- `C1`'s result terms, flows, callback escapes, effects, errors and contexts are each contained
  in `C2`'s.

A body satisfying `C1` may stand wherever `C2` is declared. Narrowing a public contract is
compatible for callers; widening breaks them. For an interface method, the declared contract is
an upper bound that every implementation must satisfy.

**Publication policy** [rec]:

| Scope | Policy |
| --- | --- |
| Inside a compilation unit (a module, mutually recursive declarations allowed) | Everything is inferred. Recursive SCCs reach a fixpoint over finite sets. |
| Between units of one package | Inferred contracts are exported in the binary interface artifact. Dependents are rechecked only when a contract *hash* changes (early cutoff). |
| Package public API | Contracts are frozen into a generated, human-readable, checked-in API file (`api/<pkg>.grli`). Every build compares inference with the file. Any difference is an error with a diff, accepted by `grail api accept` and reviewed like code. Tooling classifies each change by the refinement order as compatible or breaking. |
| Interface methods, `extern`, function types | Written contracts, defaults above. They cannot be inferred because the implementations are unknown or foreign. |

This is the API-dump practice of Kotlin's binary-compatibility validator and of
`cargo-semver-checks`, applied to ownership. Source signatures stay quiet, while the contract is
reviewable and stable. A body edit that changes which input a public result borrows from is
caught as the API change it is. The record's "never sell inference as API stability" is enforced
rather than merely advised. The IDE shows inferred contracts inline.

**Rebuild interfaces from source.** A consumer's compiler builds dependency interfaces from
dependency source, or accepts them from a trusted, reproducible builder. Experiment 02 showed that
a structurally valid but dishonest contract can mislead a client [record]. Binary metadata from a
package registry is therefore a cache, not an authority.

**Parametric generic checking.** A generic body is checked once:

- against its interface bounds;
- against an *opaque* qualifier for each type parameter;
- against the declared contracts of interface methods.

Soundness for every instantiation (F3) requires:

- no reflection on `T` in runtime code;
- interface-method contracts are declared rather than inferred per implementation;
- specialisation never changes meaning.

Generic parameters accept scoped types by default. Only operations that need escape demand a
bound: `T: Owned` for detached tasks and globals, `T: Shareable` for parallel callbacks.

**What invalidates dependents:**

- changes to a public signature, contract, effect or error type;
- layout changes of non-opaque types;
- added or removed impls, because of coherence;
- changes to `inline` or generic bodies, which affect release code generation only and not
  checking.

**What costs analysis time:**

- large recursive SCCs;
- dense qualifier sets. The record shows interning alone does not keep these compact [record].
- specialisation fan-out;
- heavy compile-time generation;
- proofs.

Budget policy: past a fixed per-function contract size or analysis budget, widen
deterministically (for example, "result keeps all parameters") and say so. Public APIs over budget
need a written contract.

**Prefer explicit annotation or restriction over clever inference in these cases:**

- public contracts (frozen);
- flows into caller storage;
- escaping callbacks;
- `suspend` on public functions;
- lending versus non-lending iterator interfaces;
- interface-method contracts;
- `extern` and `unsafe` contracts;
- contracts that break imprecise recursive SCCs.

Do *not* infer:

- ownership from callee bodies at call sites;
- mode-dependent overloads;
- conversions.

### 1.7 Generics, closures and pipelines

**Interfaces.**

- One mechanism: `interface` with methods and associated types. Each method declares its modes,
  contract and effects.
- Implementations are explicit. Coherence follows an orphan rule: an implementation lives with
  either the type or the interface.
- No overlapping implementations and no specialisation. Blanket implementations only in the
  interface's own module.
- No higher-kinded types in v1.
- Method lookup searches the type's own module, then interfaces imported in scope. Ambiguity is
  an error, resolved by a qualified call.
- `dyn I` existentials are explicit. An existential carries one qualifier slot for its hidden
  captures.

**Closures** without the `Fn` trio:

- Each lambda has a unique anonymous type.
- A parameter of type `fn(A) -> B` is non-escaping. The lambda is passed as a code pointer plus a
  pointer to an environment materialised in the *enclosing block*, so passing allocates nothing.
- A closure is stored in one of two ways:
  - with a type parameter or opaque type (`[F: Call(A) -> B]`, `some Iterator[T]`): unboxed and
    specialised;
  - as `take f: fn(A) -> B`: erased, with a box allocation when the environment is non-empty.
    The cost report shows it.
- Two derived properties replace `Fn`/`FnMut`/`FnOnce`:
  - **`Shareable`** — the closure has no exclusive captures. It is required for concurrent calls,
    because a closure that writes a captured `mut` variable must not be called from two threads.
  - **`Once`** — the closure moves out of its captures. It must be called through `take`.

  A sequential higher-order function accepts closures that are not `Shareable`. Re-entrancy is
  excluded because a closure cannot reach itself unless it captured itself, which exclusivity
  forbids.

**Pipelines.**

- `xs.iter().filter(fn(o) => o.paid).map(fn(o) => o.total).sum()` uses ordinary interface
  methods.
- The adaptors are shared-scoped values holding a `(code, env*)` pair. They allocate nothing and
  can be bound with `let` within the block.
- In release builds, `inline`-marked standard adaptors are always specialised on known lambda
  code. Constant-propagating the code pointer then inlines the lambda, which is how Rust-class
  loops are reached. The language specifies this guarantee for the standard adaptors so the
  optimisation does not depend on an inliner heuristic.
- Development builds keep indirect calls.
- Returning a pipeline from a function needs an owned closure inside an opaque `some Iterator[T]`
  result.

**Lending.** Two interfaces:

- `Iterator`, whose items keep `self.deps`;
- `Lending`, whose items keep `self`.

`for` accepts both, and most adaptors exist only for `Iterator`. Mutable iteration
(`for x in mut xs`) uses `IterMut`, a non-lending iterator. Its items are disjoint exclusive
views, split from `xs` by a trusted library primitive. Mutable *pipelines* over lending sources
are deliberately weak: use loops. This is a documented restriction, not an oversight.

### 1.8 Errors, cleanup and panics

**Errors.**

- `T ! E` is a result type, and postfix `?` propagates its error.
- `?` lifts an error only through a declared, unique, non-transitive `from` variant of the
  function's own error enum. User-defined conversions are not used.
- Private functions inside a unit may write `T ! _` to get an inferred closed union of errors.
  Public functions write `E`, which is recorded in the API file.
- There are no exceptions.

**Cleanup has two tiers.**

- **`drop`** runs implicitly at scope end and on error and cancellation exits. It cannot fail or
  suspend. Examples: freeing memory, releasing a lock, closing a descriptor while ignoring errors.
- **Finish-or-abandon resources** are for types whose correct disposal can fail or suspend:
  buffered writers, TLS sessions, transactions, temporary-file renames. Such a type declares:
  - `finish(take self) ! E` — may suspend and may fail. It must be called explicitly before any
    *normal* exit of a scope holding the resource. Omitting it is a compile error.
  - `abandon(take self)` — cannot fail or suspend. It runs implicitly on exits through `?`, an
    error return, or cancellation.

  The resource is linear on success paths and affine on failure paths. There is no async drop.
  Cleanup errors are ordinary values on the success path. Failure paths only abandon, so a second
  failure never has to be combined with the first.

  A user who wants to try `finish` on an error path writes it explicitly and chooses how to
  combine the two errors. If `finish` is cancelled at a suspension point, it returns `Cancelled`
  and abandons internally.

  Records that contain such resources inherit the obligation structurally. [hyp] I have not found
  this success-linear, failure-affine split as a named discipline in Rust, Austral or Vale; it
  needs a prior-art check.

**Panics** — bounds traps, overflow traps, `unwrap` of `None`, assertion failure — are bugs.
[rec] **v1 aborts the process.** This avoids unwind safety, poisoning, and the interaction of
cleanup with half-updated state. The cost is that one buggy request can take down a server, so
isolation belongs at process level.

Finish-or-abandon already defines failure-path cleanup. That makes later task-scoped unwinding
(run `abandon` and `drop`, poison mutexes, cancel siblings) a bounded extension rather than a
redesign.

**Allocation.**

- Allocation failure aborts by default. `try_` APIs and allocator values (such as request arenas)
  exist for systems that need control.
- Allocation is not a type-level effect. `noalloc` is a declared, checked property for kernels
  and real-time code.
- Deep recursive destruction uses iterative drop for recursive standard library types.

### 1.9 Authority, effects and retained dependencies

Keep the three apart:

| Question | Mechanism | Where it is visible |
| --- | --- | --- |
| What authority can this component exercise? | Possession of capability values (`Dir`, `Net`, `Clock`, `Entropy`, `Spawn`…). Only `main(sys: take System)` starts with any. No global I/O functions and no mutable globals. | Parameters, contexts, captures |
| What does the call do structurally? | Effects: only `suspend` is a surface effect. `total`, `noalloc` and `nopanic` are opt-in properties. | Signatures (public); inferred (private) |
| What does a value or closure keep alive, or retain authority over? | Its qualifier. Capturing `net` puts `net` in the closure's qualifier. | Inferred, queryable ("what keeps `src` borrowed?" / "which authority does this callback retain?"), and in contracts at boundaries |

- Capabilities are non-copy values, usually passed by `read`. Attenuation is ordinary methods,
  such as `fs.subdir("data")`. They need no special type theory: retention is tracked by
  qualifiers, and use by ordinary data flow.
- A package's *authority footprint* is the capabilities in its public signatures plus its
  `extern`/`unsafe` use. It is computed and reported, which is a supply-chain audit tool.
- An `extern` or `unsafe` block can bypass capability discipline. That is unavoidable, so such
  uses are always flagged in the footprint.

**Lexically resolved typed contexts can reduce plumbing safely** under these rules:

1. A function declares `using net: Net, log: Log`. This is part of its signature and its API
   file. Private functions may infer it.
2. A caller supplies a context by being inside `with net = …` or by having the same `using`
   requirement itself. Resolution matches **name and type together**, takes the innermost lexical
   binding, and treats ambiguity as an error. It never searches imports or globals and never
   constructs anything. Two `Dir` capabilities are not interchangeable because their names differ.
3. Contexts elaborate to ordinary parameters. They obey modes, exclusivity and affinity exactly
   as explicit arguments do.
4. A closure that calls a context-using function captures that context. The context appears in
   the closure's qualifier, so escape is checked like any other capture.

These rules reduce call-site plumbing, not signature plumbing: intermediate public functions
still declare `using`, which is the point. [rec] Ship explicit capability arguments first.
Add contexts as pure elaboration sugar in a second phase, after measuring plumbing in a corpus.
Adding sugar later is safe. Adding it first shapes every API around it.

### 1.10 Suspension, tasks, cancellation

The semantic commitments matter more than the implementation:

- **S1. Suspended computations are not values.** A task ends only when its function returns.
  Nothing can drop a half-run computation. This is the property that makes completion-based I/O,
  DMA and device operations over borrowed buffers sound. Rust futures are cancelled by not being
  polled again, which is why io_uring libraries resort to kernel-owned buffers, orphaned-operation
  tracking or deliberate leaks [fact].
- **S2. Frames are address-stable** while their call is active. Borrows across suspension are
  ordinary, and `Pin` has no reason to exist.
- **S3. `suspend` is a static effect.** Call sites have no `await`. Public functions declare
  `suspend`, and private ones infer it. Non-suspending code can run anywhere: as parallel jobs,
  in FFI callbacks, in interrupt-like contexts, and in kernels.
  - The static bit buys four things: cancellation points are exactly the suspension points (a
    function without `suspend` cannot be cancelled midway); blocking-lock guards are
    `NoSuspend`; `ThreadBound` values cannot live across suspension in migratable tasks; and
    jobs are separated from tasks.
  - *Higher-order rule:* a call's effects include the effects of the non-escaping function
    arguments it receives. Escaping function values carry effects in their type. There are no
    effect variables, and `map(xs, fetch)` "suspends because `fetch` does".
- **S4. Structured scopes.** `scope { s => … }` joins every child before it exits, on every exit
  path. Children may borrow anything whose roots outlive the scope.
- **S5. Cancellation is a request.**
  - A request flag is set per scope. Each suspending operation observes it, and only there, as a
    `Cancelled` error that ordinary `?` propagates.
  - An in-flight operation cancels cooperatively: submit a cancel, wait for the completion, then
    return `Cancelled`. The storage it uses stays alive the whole time, because the task's frame
    is still there (S1).
  - A deadline is a timed request. It never frees anything.
  - `race` and `first_success` cancel *and join* the losers before returning, so their latency
    includes the losers' acknowledgement time. That is the price of soundness; Trio pays the same.
  - A child that never reaches a suspension point keeps its parent waiting. That is a liveness
    problem, handled by process supervision, never by reclaiming storage.
- **S6. No ambient detached spawn.** Long-lived background work uses an explicit `Service` scope
  capability that `main` provides, and accepts only owned closures.

**Implementation** [rec]: start with stackful fibers plus stackless jobs.

- **Fibers.** Contiguous stacks: reserved virtual ranges with guard pages, committed lazily,
  pooled. Context switches save callee-saved registers. A generic higher-order function such as
  `map` is compiled once, whether or not its callback suspends.
- **Jobs.** Non-suspending parallel work, enforced by S3, runs on worker stacks with deque-push
  cost, Cilk/rayon style. Fine-grained data parallelism therefore never pays fiber cost.
- **FFI.**
  - A foreign call runs on the current stack and must fit its declared stack class. Large classes
    switch to a worker stack.
  - Calls declared `blocking` hand the carrier thread off, Go-style.
  - Foreign callbacks are typed as non-suspending.
- **Memory.** [hyp] The floor is one committed page, a guard page and a task header per fiber.
  At hundreds of thousands of idle tasks that is a real cost compared with Rust state machines.
  Go reduces it with 2 KB copying stacks, which require relocating pointers into the stack, and
  Grail cannot assume that [fact].
  - *Mitigations:* link-time stack bounds for non-recursive suspending call graphs, which allow
    exact-size stacks; and event-handler APIs for very large numbers of idle connections.
  - *Plan B:* frame lowering into stack-discipline task-allocator frames, as Swift does [fact].
    It preserves S1–S6 unchanged, but costs two code versions of effect-polymorphic generic
    functions. Experiment X3 decides.

### 1.11 Verification and staging

**Tiers** (never conflated in reports):

| Tier | What | In every build? |
| --- | --- | --- |
| T0 mandatory safety | Type, qualifier, effect and exhaustiveness checks; runtime bounds, overflow and generation traps | Yes |
| T1 routine analysis | Deterministic, budgeted, no SMT: range analysis to remove checks, runtime contract checks in debug, lints. Never fails a build on a timeout. | Yes |
| T2 proof search | SMT with proof reconstruction, Lean tactics, AI proposals. Produces certificates. | Verification lane only |
| T3 independent checking | The Lean kernel checks certificates against the Grail→Lean translation. An evidence manifest is keyed by hashes of body, contract and dependencies. | Verification lane; cached |
| T4 correspondence | Translation and compiler are trusted (stated as TCB). Differential testing compares the compile-time interpreter, Lean execution and native code. Translation validation is optional for small kernels. | Release and CI policy |

**Contract statuses.** Every contract has exactly one status:

- `checked` — at runtime;
- `proven(evidence-hash)`;
- `trusted(reason, owner)` — listed in the trust report;
- `unchecked` — documentation only.

Two rules follow:

- **Facts used by optimisation or unchecked access.** The optimiser and unchecked operations may
  use a fact only if it is `proven` with a matching evidence hash, or established by a runtime
  check that dominates the use.
- **`requires` justifying an unchecked operation.** It is checked at function entry unless every
  caller is verified.

So an unverified assumption is checked, established or rejected; it never silently authorises
anything.

**Logic.**

- `logic fn` definitions are total, pure and erased. They use mathematical `Int`, `Seq`, `Set`,
  `Map` and quantifiers.
- An ordinary function that is total and in the eligible subset can be lifted into logic, so the
  executable definition *is* the specification ingredient.
- Partial runtime functions are modelled with Lean's `partial_fixpoint` (Option-style monads or
  tail recursion, available since Lean 4.17) [fact], or an Aeneas-style divergence monad.
- Ghost code is checked not to flow into runtime values.
- Fixed-width arithmetic traps. Each operation is partial in the model, and proofs either show it
  cannot overflow or accept the trap as an outcome.
- Floating point is largely outside proof scope initially.
- Concurrency and protocols are modelled separately (Quint/TLA+-style models and ITF trace
  replay) and are not part of the functional translation.

**Why mutable value semantics pays here (the MVS adequacy property).**

- [hyp] For the eligible subset — no interior mutability, concurrency, FFI or exclusive
  references stored in containers:
  - `mut` parameters translate to in/out values;
  - `read` parameters and shared views translate to plain values, because frozen sharing is
    observationally copying;
  - functions returning `mut ref` translate to Aeneas-style forward/backward pairs.

  None of these needs prophecy variables.
- Exclusive references stored in unbounded containers (`Vec[mut ref T]`) are where
  RustHorn/Creusot-style prophecies become necessary. They stay out of the eligible subset until
  needed.
- The precise boundary must be checked against Aeneas's documented subset [record].

**Intent.** AI may propose specifications, invariants, proofs and repairs. Specifications carry
provenance: `proposed` until a named human `accepted` them. Tools flag tautological specifications
derived mechanically from the body. A "verified" report shows which accepted specifications were
proven and lists the trusted base. Shared definitions reduce duplicated implementation and
specification work. They do not establish intent.

**Four staging operations, kept distinct:**

1. **Compile-time evaluation.** A deterministic interpreter over typed IR runs ordinary functions.
   It has no capabilities except a `Build` capability exposing declared, hashed input files. It
   runs under fuel and memory budgets, emulates target floating point, and cannot observe pointer
   identity.
2. **Generic specialisation.** A compiler choice that never changes meaning.
3. **Declaration generation.** Compile-time code builds typed syntax through a reflection API
   (`derive`-like). The output is type-checked like hand-written code and cached by input hash.
   This replaces macros. It is not a second generics mechanism: no duck-typed templates.
4. **Proving generated code.** Generated code is verified like any code. Proving the generator
   correct for all inputs is deferred research.

### 1.12 Parallelism, devices, FFI

**Independence and determinism.**

- Exclusive qualifiers and `Shareable` closures establish race freedom: `par_chunks_mut`,
  `split_at_mut` plus scoped spawn, `par_map` with `Shareable` callbacks. Scheduling is separate:
  the program says `par`, and the compiler only proves legality.
- A legal loop is not automatically parallelised. Profitability needs a schedule.
- Kernels may carry Halide-style schedules separate from their algorithm.
- *Errors:* `par_map` of a fallible function returns the **lowest-index** error. This is
  deterministic, and may wait for lower indices to finish. `par_map_any_err` is the explicit
  faster alternative.
- *Floating point:* `sum()` keeps sequential order. `sum_tree(block)` is deterministic for any
  thread count. `sum_unordered()` is explicit and may vary between runs.
- Purity alone establishes neither termination nor failure-order independence.

**Devices.**

- Kernels are a restricted subset checked by existing machinery: no `suspend`, `noalloc`, no
  recursion, no `dyn`, only device-buffer capabilities. They are lowered through MLIR or SPIR-V
  only when kernels exist.
- `DeviceBuf[T]` is owned. Uploads, launches and downloads return **in-flight operation
  values**, whose qualifiers hold the host and device buffers they use (shared or exclusive).
  The same scoped-value and S1 rules as I/O apply: the CPU cannot touch a buffer until the
  operation completes, and cancellation waits for completion. This is the same mechanism with no
  new kind.
- *Admission:* `gpu.alloc` is fallible. Static capacity claims take the form of a `Reservation`
  obtained fallibly at start-up. Allocation within a reservation is then infallible, and the
  assumption is explicit and checked once. Shared devices still need fallible admission.
- Device residency alone is not all of GPU safety. Barriers and convergence need their own rules,
  as the record notes for Descend [record].

**FFI.**

- An `extern` declaration states:
  - modes and dependency contracts;
  - `suspend` (never) and the `blocking` property;
  - stack class;
  - `ThreadBound` and `Shareable` properties;
  - callback escape;
  - the authority it uses.
- Every `extern` declaration is trusted and appears in the trust report and authority footprint.
- Bindings generated from C start raw and unsafe. A reviewed wrapper supplies the safe contract.
- Common Rust signatures could map mechanically, since lifetimes map to qualifier terms.
  [hyp] That makes Rust interoperability tractable for common signatures.
- LLVM IR cannot recover intent, so contracts live at the source level.

### 1.13 Compilation pipeline and build policy

- **Units.** Packages form an acyclic graph. A package's modules form an acyclic graph of
  compilation units. Mutual recursion is allowed within a unit.
- **Per unit:**
  1. Parse files (cached per file).
  2. Resolve names.
  3. Type-check per declaration.
  4. Infer qualifiers and effects per strongly connected component.
  5. Export contracts.
  6. Lower to typed IR.
  7. Generate code.

  Checking happens before code generation and needs only dependency interfaces.
- **Interface artifact.**
  - *Checking section:* types, layouts of non-opaque types, signatures, contracts, effects and
    impls. It is hashed for early cutoff.
  - *Code-generation section:* `inline` and generic bodies as typed IR. It affects only
    downstream release code generation.

  The record shows Go's export data already carries generic and inline bodies [record]; this
  split is a known technique.
- **Development builds.**
  - Code is generated per function.
  - Generics use witness tables: dictionaries plus layout witnesses, as in Swift. Editing a
    generic body recompiles one body.
  - Small `inline` generics such as `Option` methods and iterator adaptors are specialised,
    because calling them through witnesses costs more than specialising them.
  - There is no cross-unit inlining beyond those, and linking is incremental.
- **Release builds.** Full specialisation, with polymorphisation of instances that share a
  layout. Cross-unit inlining. Optimised LLVM.
- **Measured basis.** The record measured that optimisation and specialisation, not generic
  checking, dominates build cost in its fixture [record].
- **Backend.** Start with one: LLVM, with an unoptimised development pipeline. Measure, then
  decide on Cranelift for development builds; its own benchmarks are workload-specific [record].
  Use MLIR only for kernels.
- **Caching and cost visibility.** Everything is content-addressed: parsing, checking, code
  generation, compile-time results and proofs. `grail cost` reports, per function:
  - allocations;
  - boxed closures;
  - remaining runtime checks (bounds, overflow, generation);
  - specialisation count;
  - fiber stack class;
  - contract widening.

### 1.14 How the mechanisms reinforce each other

- **One qualifier mechanism** serves seven jobs:
  1. borrow checking;
  2. closure capture;
  3. retained-authority tracking;
  4. borrowing by structured tasks;
  5. in-flight I/O and device operations;
  6. parallel independence (exclusive splits);
  7. the functional translation for proofs.

  It also drives diagnostics such as "what keeps X alive?". This turns the Haskell
  accidental-retention lesson around: retention is a static, queryable fact [record].
- **One static effect bit (`suspend`)** serves six jobs:
  1. cancellation points;
  2. the lock rule;
  3. thread affinity;
  4. the job/task split;
  5. kernel restrictions;
  6. FFI callback typing.
- **S1 (non-droppable suspended computations)** makes cancellation and cleanup coherent and makes
  finish-or-abandon sufficient.
- **Contracts** serve separate compilation, API stability and the verification inputs.
- **Mutable value semantics** keeps both the checker and the proof translation first-order in the
  common case.

---

## 2. The strongest alternatives

| Alternative | Strength | Why not the foundation |
| --- | --- | --- |
| **Strict mutable value semantics plus offsets and handles** (Hylo-pure) | Fewest concepts. The record shows offsets are fast [record]. | Cases 1 and 2 become offset plumbing: every access needs the source passed in, and offsets used with the wrong source are not caught by types. The brief makes these zero-copy view APIs requirements. Hylo itself allows captured projections (rule 10 of its specification), so even Hylo is not "pure" in this sense [record]. Keep offsets as a library idiom for case 3. |
| **Rust-style origins as type parameters** (Rust lifetimes, Mojo origins [fact]) | The most expressive known modular design. Mature. | Named origin parameters spread through every view-carrying type. First-class `&mut` brings invariance, reborrowing and two-phase rules. Lifetimes as regions cause NLL problem case 3, which Polonius is still fixing on nightly [record]. My proposal keeps its expressiveness but names roots by parameter and uses flow clauses. |
| **Regions as the foundation** (Cyclone, MLKit, Verona, Vale [fact]) | Bulk ownership. Graphs and compiler IRs are natural. | Signatures need region polymorphism, roughly the same burden as lifetimes. Memory is retained until the region ends. Per-object deletion needs reference counting, garbage collection or generations. Verona's dynamic region and behaviour-oriented concurrency work [fact] relies on runtime mechanisms. Kept as a library pattern (§1.5, case 4). |
| **Uniqueness or linear functional languages with in-place update** (Clean, Futhark, Cogent, Koka with functional-but-in-place) | Verification-friendly. Cogent's certifying compiler [record]. | Shared immutable views without reference counting still need borrowing, so this converges on the proposal or copies data. Koka's Perceus relies on reference counting [record]. Linear-everything (Austral [fact]) is verbose for ordinary code. |
| **Whole-program root inference** (Goose [record]) | Annotation-free. Normalised root classes avoid an explosion of specialisations [record]. | Fails the separate-compilation requirement as documented. A modular variant would converge on per-parameter contracts, which is this proposal. Goose roots also give no exclusivity, so shared-memory concurrency needs more. |
| **Capture and separation checking** (Scala capture checking, System Capless, System Capybara; reachability types [fact]) | The best theory for qualifiers. Coq-mechanised soundness for polymorphic reachability [fact]. | It lives in garbage-collected languages and does not reclaim memory. Adopt its metatheory, not its runtime model. |
| **Generational references everywhere** (Vale [fact]) | Simple aliasing model. | A check on every dereference is the routine runtime checking the brief excludes. Used only for handles. |

I prefer the proposal for three reasons:

1. It is the smallest design I can find that meets cases 1 and 2 without runtime mechanisms.
2. Most code never touches its dependency layer.
3. The same layer pays for captures, authority, tasks, I/O and devices.

The point I am least sure of is whether one slot per nominal type, flow clauses and fresh callback
accesses cover enough real APIs (X1).

---

## 3. Worked examples

Conventions:

- `Str` is a UTF-8 view; `String` is owned.
- `Slice[T]` and `MutSpan[T]` are views; `ref T` and `mut ref T` are first-class views.
- `@x` in a result clause means "may keep x".
- `x -> m` means "after the call, `m` also keeps what `x` keeps".

Inside a package these clauses are inferred. They appear here because they are what the public
API file would show.

**E1 — case 1: AST over an external buffer, and the invalid mutation.**

```grl
pub type Expr = enum { Name(Str), Num(I64), Call(Str, Vec[Expr]) }  // view-carrying: one slot
pub fn parse(src: Str) -> Expr ! ParseError @src

let text = fs.read_string("main.grl")?
let ast = parse(text)?            // ast: Expr^{text}; no bytes copied
text.clear()                      // rejected
print(ast)
```

```text
error: `text` is modified while `ast` still reads from it
  12 | let ast = parse(text)?      `ast` contains text views into `text` (contract: parse keeps `src`)
  13 | text.clear()                `clear` needs exclusive access to `text`
  14 | print(ast)                  `ast` is used here, so its views are still needed
help: finish using `ast` before line 13, or parse a copy: `parse(text.clone())`
```

**E2 — case 2: containers of views across generic and module boundaries.**

```grl
// package lex, compiled separately
pub type Token = { kind: Kind, text: Str }
pub fn tokens(src: Str) -> Vec[Token] @src

// package util, generic, compiled separately; its API file records no dependency on `xs`
pub fn group_by[T: Copy, K: Hash + Eq](xs: Slice[T], key: fn(T) -> K) -> Map[K, Vec[T]]

// client: provider bodies unavailable
let src = fs.read_string(path)?
let toks = lex.tokens(src)                            // Vec[Token^{src}]
let by_kind = util.group_by(toks, fn(t) => t.kind)    // Map[Kind, Vec[Token^{src}]]
drop(toks)                                            // OK: by_kind keeps `src`, not `toks`
src.clear()                                           // rejected: by_kind's tokens view `src`
```

`group_by` is checked once with an opaque qualifier on `T`. The qualifier `src` reaches the
result through `T`. No annotation is written and no instantiation is reanalysed.

**E3 — case 3: a document owning its source and views.**

```grl
pub type Doc = Bundle[String, Expr]

pub fn load(fs: Dir, path: Str) -> Doc ! LoadError suspend {
    let text = fs.read_string(path)?
    Bundle.build(text, fn(src) => parse(src))?   // the closure's result may keep only `src`
}
pub fn names(doc: Doc) -> Vec[Str] @doc {
    doc.view().names().collect()                 // view(): Expr @doc
}
let d = load(fs, "a.grl")?
let moved = d                                    // fine: Doc is owned; String bytes are heap-stable
let ns = names(moved)
// moved.rebuild(...) here would be rejected while `ns` is live
```

**E4 — case 4: a mutable graph with deletion.**

```grl
type Node = { label: String, out: Vec[Id[Node]] }
var g = Arena[Node].new()
let a = g.add(Node { label: "a", out: [] })
let b = g.add(Node { label: "b", out: [] })
g[a].out.push(b)                      // generation-checked projection
let old = g.remove(b)                 // returns the Node; copies of `b` become stale
for e in g[a].out {
    match g.get(e) { Some(n) => visit(n), None => {} }   // stale ids yield None
}
let (x, y) = g.pair_mut(a, c)?        // checked a != c; both exclusive views of g
```

**E5 — the brief's `remember`: storing a borrowed input into caller storage.**

```grl
fn remember(cache: mut Vec[Str], s: Str) where s -> cache {
    cache.push(s)
}

fn index(doc: String) -> Vec[Str] @doc {          // doc: read String
    var cache = Vec.new()
    for line in doc.lines() { remember(mut cache, line) }    // cache keeps doc
    cache
}

fn bad(cache: mut Vec[Str], tmp: String) {        // no flow declared
    remember(mut cache, tmp)                       // rejected
}
```

```text
error: `bad` would store a view of `tmp` into `cache`, but `tmp` is only borrowed for this call
help: declare `where tmp -> cache` so callers keep `tmp` alive as long as `cache` (a public
      API change), or make the cache own its text (`Vec[String]`) and push `tmp.clone()`
```

On the caller's side, after `remember(mut cache, text)`, the qualifier of the caller's `cache`
grows to include `text`. A later `drop(text)` is rejected while `cache` is live, and the
diagnostic cites the `s -> cache` contract. The flow clause names parameters, not lifetime
variables. A generic version, `fn remember[T](cache: mut Vec[T], x: T)`, needs no clause at all,
because `T` carries its qualifier and the types agree.

**E6 — conditional return of a mutable borrow (NLL problem case 3).**

```grl
fn get_default(m: mut Map[Int, String], k: Int) -> mut ref String @m {
    match m.get_mut(k) {
        Some(v) => v,
        None => { m.insert(k, String.new()); m.get_mut(k).unwrap() }
    }
}
```

The `None` branch holds no live value depending on `m`, so it is accepted. Rust's current borrow
checker rejects the equivalent program pending Polonius. [hyp] X2 must confirm this does not
reintroduce Polonius's cost.

**E7 — a callback cannot retain its argument; a loop can.**

```grl
var keep = Vec.new()
names.for_each(fn(n) => keep.push(n.view()))     // rejected
for n in names { keep.push(n.view()) }           // accepted: keep now keeps `names`
```

```text
error: cannot keep `n` after the callback returns
  `for_each` lends each element only for one call (its callback contract is non-escaping).
help: use a `for` loop, which lets `keep` borrow from `names` directly
```

**E8 — lending iteration.**

```grl
var dec = Decoder.new(file)
while let Some(rec) = dec.next()? {   // Lending: rec keeps `dec`
    process(rec)
    // saved.push(rec)                 // rejected: `rec` is in `dec`'s reusable buffer,
}                                      //           which the next `next()` overwrites
```

**E9 — entry API with a declared flow, and split for parallelism.**

```grl
fn count(words: Slice[Str], m: mut Map[Str, Int]) where words.deps -> m {
    for w in words { m.entry(w).or_insert(0) += 1 }
}
fn sort_halves(xs: mut Slice[I64]) {
    let (l, r) = xs.split_at_mut(xs.len() / 2)     // disjoint exclusive views of xs
    scope { s => s.spawn(fn() => sort(l)); s.spawn(fn() => sort(r)) }
}
```

`words.deps` means "the texts the words view, not the slice storage itself".

**E10 — a pipeline with no allocation.**

```grl
let total = orders.iter().filter(fn(o) => o.paid).map(fn(o) => o.total).sum_checked()?
```

The lambda environments live in the block. The adaptors are shared-scoped values. In release
builds the standard adaptors are specialised and inlined.

**E11 — read into a borrowed buffer under cancellation and deadline.**

```grl
fn read_exact(f: File, buf: mut Slice[U8]) ! IoError suspend {
    var off = 0
    while off < buf.len() {
        let n = f.read(mut buf[off..])?    // in-flight op holds buf exclusively; on cancel it
        if n == 0 { return error(.Eof) }   // waits for kernel completion, then returns Cancelled
        off += n
    }
}
fn fetch(net: Net, url: Url) -> Bytes ! FetchError suspend {
    scope(deadline: 5.s) { s =>
        let a = s.spawn(fn() => http_get(net, mirror(url, 1)))
        let b = s.spawn(fn() => http_get(net, mirror(url, 2)))
        s.first_success([a, b])    // cancels and joins the loser before returning
    }
}
```

**E12 — finish-or-abandon.**

```grl
resource type Writer { fd: Fd, buf: Vec[U8] }
    finish(take self) ! IoError suspend   // flush + fsync + close
    abandon(take self)                    // discard buffer, close ignoring errors

fn save(dir: Dir, name: Str, data: Slice[U8]) ! IoError suspend {
    var w = dir.create(name)?
    w.write_all(data)?          // on error: w is abandoned automatically
    w.finish()?                 // omitting this is a compile error
}
```

**E13 — capability contexts (phase-two sugar).**

```grl
fn main(sys: take System) ! AppError suspend {
    let cfg = load_config(sys.fs.subdir("etc/app")?)?
    with net = sys.net, log = Log.to(sys.stderr) { serve(cfg)? }
}
pub fn serve(cfg: Config) ! ServeError suspend using net: Net, log: Log { … }
```

**E14 — verification boundary.**

```grl
logic fn sorted(xs: Seq[Int]) -> Bool = forall i j. i < j < xs.len -> xs[i] <= xs[j]

fn insert_sorted(xs: mut Vec[I64], x: I64)
    requires sorted(xs)
    ensures sorted(xs) && xs.multiset == old(xs).multiset.add(x)
{ … }
// Lean image: insert_sorted : Vec I64 → I64 → Result (Vec I64)   (mut ⇒ in/out)
// Status in builds: `checked` in debug; `proven(h)` only after T3 accepts a certificate for hash h
```

**E15 — data-parallel loop and a device operation.**

```grl
xs.par_chunks_mut(4096).for_each(fn(c) { for x in mut c { x *= scale } })  // Shareable, no suspend
let t = xs.par().map(fn(x) => x * x).sum_tree(block: 4096)                   // deterministic
gpu.upload(img.pixels(), mut din).wait()?    // host view held until completion
gpu.launch(blur, grid(img), din, mut dout).wait()?
```

---

## 4. Where complexity is removed and where it is displaced

| Complexity in incumbents | Status in this design | Where it went |
| --- | --- | --- |
| Lifetime parameters on functions and structs | Mostly removed | Parameter-named result clauses and flows, inferred within a package and frozen in API files |
| `&`/`&mut` parameter types, auto-deref, `&&T`, `as_ref` | Removed | Parameter modes and one fixed view coercion |
| Reborrowing, two-phase borrows | Removed as rules | Accesses start at the call |
| NLL problem case 3 | Removed [hyp] | Value-carried dependencies; cost to be measured (X2) |
| Variance puzzles | Hidden for locals | Invariant only under first-class `mut ref`, solved locally |
| Higher-ranked trait bounds for callbacks | Mostly removed | Fresh per-call accesses by default. Retention needs a loop or an explicit escaping signature. |
| `Fn`/`FnMut`/`FnOnce` | Removed | Two derived properties: `Shareable` and `Once` |
| `Send`/`Sync` | Mostly invisible | `Shareable` (structural) and `ThreadBound` (opt-in), mostly relevant to library and FFI authors |
| `Pin`, self-referential futures | Removed | Stable frames (S2) |
| async/await coloring syntax | Removed | The `suspend` effect remains, and its cost is fiber memory or plan B code duplication |
| Owned-buffer or leak workarounds for completion I/O under drop-cancellation | Removed | S1; cost is cancellation latency, because losers are joined |
| Async drop | Removed | Finish-or-abandon; cost is explicit `finish` calls |
| Self-referential owning documents | Supported narrowly | `Bundle`: frozen, heap-stable owner; `rebuild` to edit |
| Mutable aliased graphs | Not solved by the type system | Handles with runtime generation checks, or regions without deletion, or proofs |
| Macros | Removed | Compile-time evaluation plus checked declaration generation; cost is an interpreter and its budget |
| API instability from inference | Removed | API files: a review step and some churn |
| Whole-program analysis | Removed | Conservative rejections, budgets, deterministic widening |

Restrictions accepted deliberately:

- no mutation, move or destruction of a root while its views are live;
- no index-sensitive borrowing;
- callbacks cannot retain their arguments;
- no borrowed values in detached tasks;
- panics abort;
- no comptime reflection in generic bodies;
- one dependency slot per nominal type;
- weak lending pipelines.

Runtime work accepted: bounds and overflow traps (T1 removes many), generation checks for
handles, boxing for erased escaping closures, fiber stacks, and witness-table indirection in
development builds.

---

## 5. What emerges naturally, what needs separate machinery, what to defer

- **Emerges from the core:**
  - memory safety;
  - data-race freedom;
  - borrowing by scoped tasks;
  - safety of completion I/O and device operations;
  - visibility of retained authority;
  - legality of parallel splits;
  - capability security (except FFI);
  - functional translation for the eligible subset;
  - "what keeps this alive" diagnostics.
- **Needs separate but small machinery:**
  - the `suspend` effect and fiber runtime;
  - finish-or-abandon;
  - contract and API-file tooling;
  - logic fragment and Lean translation;
  - compile-time interpreter and reflection;
  - `Bundle`;
  - arenas and handles;
  - the kernel subset and MLIR path;
  - `extern` contracts;
  - schedules.
- **Defer:**
  - typed contexts (phase two);
  - multi-slot nominal types;
  - yield accessors;
  - renaming roots when a heap-stable owner moves;
  - user-defined effect handlers (the record's P09 already excludes them);
  - task-scoped panic unwinding;
  - automatic parallelisation;
  - GPU support beyond a prototype;
  - cross-language verification;
  - verified compilation;
  - dependent types in the runtime language;
  - higher-kinded types;
  - lending adaptors;
  - batching à la Haxl, as an explicit library over structured scopes.

---

## 6. Dangerous counterexamples, formal statements, decisive experiments

### 6.1 Counterexamples the design must reject, or accept, correctly

1. **Invalidation through a callee.**
   - `let v = xs.view(); grow(mut xs); use(v)` is rejected at the call.
   - A callee cannot invalidate its caller's views, because the caller cannot pass `mut xs` while
     `v` is live.
2. **Generic laundering.**
   - `identity[T](x: T) -> T` and `store[T](dst: mut Vec[T], x: T)` must preserve qualifiers
     through `T`.
   - The record's forwarding tests cover the shared-view half [record]. Exclusive and flow halves
     are untested.
3. **Closure argument-to-capture flows.**
   - `let add = fn(s: Str) { cache.push(s) }; add(t); drop(t); use(cache)` is rejected.
   - The closure's parameter type is fixed at creation, so the flow is local.
   - A callback of a higher-order function receiving a fresh access cannot flow its argument.
4. **Drop check.**
   - A `Vec[Str]` dropped after its source at scope end is accepted.
   - A user type whose `drop` reads its views, in the same position, is rejected.
   - Getting the "eyepatch" default wrong is unsound.
5. **`Bundle` with an owner that is not stable.** An owner with small-string storage must fail
   `StableBorrow`.
6. **Two children capturing `mut a`.** Rejected, with the hint "use a Mutex, or split `a`".
7. **Blocking mutex guard across `suspend`.** Rejected. **`ThreadBound` value across `suspend` in
   a migratable task.** Rejected.
8. **Foreign callback calls suspending code.** Rejected by the callback type.
9. **Deadline elapses while a kernel read is in flight.** The operation must complete or be
   acknowledged before `buf`'s frame unwinds. The record's Quint model already shows that early
   release produces a counterexample trace [record].
10. **Forged interface.** A registry artifact claims `pick(a, b)` keeps only `a`. It must not be
    trusted: rebuild it from source [record].
11. **Imprecision from conditional dependencies.** After
    `let r = if c { a.view() } else { b.view() }`, `a.clear()` is rejected. The diagnostic must
    say "may refer to `a`" and not invent certainty.
12. **Dense qualifier blow-up.** The 128×128 distinct-set pattern [record] must widen
    deterministically within budget.
13. **Interface-method mismatch.** An implementation that returns a view into `self` where the
    interface declared a non-borrowing result is rejected at the implementation.
14. **Floating-point reduction and compile-time floating point.** A parallel sum must not
    silently differ from the sequential one. Compile-time float results must match the target.
15. **Liveness under cancellation.** A child that never suspends blocks its parent's join. This
    is accepted behaviour and must be documented, never "fixed" by freeing storage.

### 6.2 Formal statements to establish, smallest first

- **F1. Safety of the core.**
  - *Scope:* first-order core plus views, `mut ref`, closures, scoped values and `Bundle`.
  - *Statement:* well-typed programs never reach an *instrumented-semantics* violation. Every
    heap location carries an owner and the permissions currently granted, and the semantics gets
    stuck on use-after-free, on a write while a shared qualifier is live, or on an access that
    bypasses a live exclusive qualifier.
  - *Proof:* progress and preservation, mechanised in Lean.
  - *Prior art:* reachability-type metatheory in Coq [fact]; RustBelt; Tree Borrows.
- **F2. Modular contract soundness.** If a body checks against contract `C`, `C ⊑ C'`, and a
  client checks against `C'`, then linking them preserves F1's invariant. The refinement order of
  §1.6 is the object.
- **F3. Parametricity.** A generic body checked with opaque qualifiers is safe for every
  instantiation.
- **F4. MVS adequacy.** For the eligible subset, the operational result and post-state equal the
  Lean image applied to the inputs.
- **F5. Cancellation safety.**
  - *Statement:* in a small-step semantics with tasks, scopes, in-flight operations and
    deadlines, no storage is reclaimed while referenced by an incomplete operation or a live
    child.
  - *Order:* model-check first, by extending `research/experiments/quint03`, then prove.
- **F6. Finish-or-abandon.** On every terminating execution, every resource is finished on normal
  exits and abandoned on failure exits, exactly once.

### 6.3 Decisive experiments (cheapest first, with kill criteria)

- **X1. Contract-vocabulary corpus** (hand work, days).
  - *Method:* express about 40 real Rust APIs in the §1.6 vocabulary and count named-variable
    needs, `Bundle` needs, handle needs and inexpressible cases. APIs: serde `Deserialize<'de>`,
    `str::split`, `HashMap::entry`, `Vec::drain`, `split_at_mut`, iterator adaptors,
    `thread::scope`, `regex::Captures`, rayon, petgraph, tokio `AsyncRead`, nom parsers, hyper
    bodies, and others.
  - *Kill or pivot:* if more than about 10% need more than the vocabulary, adopt Mojo-style
    origin parameters and compete on other axes.
- **X2. Mutation-extended checker.**
  - *Method:* extend `contracts02` with `mut` modes, flows, loops, branches, moves, `mut ref`
    results, drop check and closures. Test against an independent allocation and permission
    oracle on E5–E9 and the counterexamples above.
  - *Measure:* analysis cost on generated large functions.
- **X3. Fiber economics.**
  - *Measure:* creation, switch and resident memory at 10⁴–10⁶ tasks; FFI call cost; stack-bound
    coverage on a sample server.
  - *Compare:* Rust (tokio) and Go.
  - *Pivot:* to plan B (§1.10) without changing semantics.
- **X4. Development-build generics.**
  - *Measure:* witness tables against specialisation on generic-heavy code, both compile time and
    the runtime ratio.
  - *Builds on:* experiment 01's 256-type fixture [record].
- **X5. Lean translation spike.**
  - *Method:* hand-translate five functions (a `mut` parameter, a view-returning function, a
    `mut ref` return, a loop, a `Bundle` reader) and prove one property each.
  - *Measure:* translation size and proof effort.
- **X6. Diagnostics study.** Ten programmers, eight cases, mocked Rust and Grail errors.
  Measure repair time and how often they predict errors correctly.
- **X7. Cancellation model.** Extend the existing Quint model with children, in-flight operations
  and finish-or-abandon. Report sampled bounds, never claim universality [record].
- **X8. Optional prototype route.**
  - *Idea:* elaborate a Grail subset to lifetime-annotated Rust, so rustc acts as an independent
    oracle for most of the safe subset.
  - *Limits:* E3, E6 and E11 exceed what rustc accepts, so they need `unsafe` or runtime crates
    there. Compile speed is not representative.

---

## 7. Differentiation

**Incumbent limitations this design targets:**

| Incumbent | Limitations |
| --- | --- |
| Rust | Lifetimes spread through view-carrying types. `Pin` and `Send` bounds. Cancellation by drop, which forces completion-I/O libraries onto kernel-owned buffers or tracking of orphaned operations [fact]. No async drop: the 2026 project goals still treat it as needing foundational work [fact]. Polonius only on nightly [record]. Build cost dominated by optimisation in the record's fixture [record]. Verification through external tools with documented subset limits [record]. |
| Swift | Reference counting and copy-on-write by default for classes and escaping closures. Nonescapable types and lifetime dependence still evolving: annotations still experimental, inout-dependence semantics still debated, and a 2025 inout-dependence miscompilation fix [fact]. Strong evidence this area is hard even for a well-resourced team. |
| Mojo | Origins overlap this design [fact], and Mojo 1.0 is open source [record]. No integrated proof path found. |
| Go | Garbage collection; data races possible. |
| Zig | No memory safety. Templated generics are not checked parametrically. |
| Hylo | Research stage. |
| OCaml/OxCaml, Lean, Koka | Garbage collection or reference counting [record]. |
| Eio | Shows capabilities plus direct-style structured concurrency in practice, over garbage collection [fact]. |

**What could genuinely differentiate Grail:**

1. **Research mechanisms** — possible, unestablished:
   - one value-named, type-structured qualifier discipline serving the seven jobs of §1.14;
   - non-droppable suspended computations plus stable frames, giving sound direct-style
     concurrency over *borrowed* completion I/O with no garbage collection;
   - finish-or-abandon;
   - a mutable-value-semantics-shaped proof translation free of prophecies for the common subset.
2. **Engineering advantages users would see:**
   - Rust's safety envelope with noticeably fewer concepts (§4);
   - faster development builds from witness tables, early cutoff and API files;
   - diagnostics in value terms;
   - capability security with authority footprints;
   - contract statuses and a trust report;
   - compile-time code instead of two macro languages.
3. **Adoption and commercial value:**
   - Supply-chain authority footprints are a concrete, sellable security story.
   - A language whose safety and contracts are checked mechanically suits AI-generated code. The
     record notes others already position in this space [record].
   - Infrastructure targets (parsers, protocol stacks, storage engines, firmware) value no
     garbage collection, capabilities and optional proofs together.
   - The cost is a cold-start ecosystem. Excellent C interoperability, and Rust interoperability
     via mapping lifetimes to contracts, are prerequisites, not features.

**What would demonstrate the advantage:**

- X1 coverage of at least about 90% with fewer named dependency variables than lifetime
  parameters in the matching Rust;
- X6 repair time measurably better than Rust;
- a completion-I/O server with borrowed buffers, safe and without `Pin`;
- a development-build loop on about 100 kLOC competitive with Go, from a later prototype;
- runtime within a few percent of Rust on parser, server and numeric suites;
- one verified component with kernel-checked proofs and its trusted base stated.

**Extend an existing language instead?**

- *Rust:* sacrifices lifetimes and `&mut`, `Pin`, the drop-cancellation model and build
  architecture. Gains the ecosystem.
- *Swift:* sacrifices predictable ownership costs (classes, escaping closures and existentials
  are reference-counted) and type-checker speed.
- *Mojo:* ties Grail to Python-superset goals.
- *Hylo:* shares mutable value semantics but lacks first-class views and fibers, and is research
  stage.

My judgement is that a new language is justified **only if** X1, X3 and X4 come out well. Until
then, the cheapest high-value path is experiments, possibly through X8. I see no case for
pivoting to a verification wrapper before that evidence exists.

---

## 8. Five foundational decisions to discuss next

1. **Memory model.**
   - *Proposal:* rooted value semantics. Second-class accesses; type-structured qualifiers (shared
     or exclusive) on values; first-class shared and scoped exclusive views; `Bundle` for case 3;
     handles and regions for case 4.
   - *Rejected as foundations:* strict mutable value semantics only, and type-level
     origin/lifetime parameters.
   - *Recommendation:* adopt as the research baseline, with X1 as the kill test.
2. **Contract publication.**
   - *Proposal:* inferred within a package; exported with early cutoff between units; frozen,
     generated, reviewed API files at package boundaries; written contracts for interface
     methods, `extern` and function types; the refinement order defines compatibility;
     interfaces rebuilt from source.
   - *Recommendation:* adopt.
3. **Concurrency semantics.**
   - *Proposal:* S1–S6. Suspended computations are not values, frames are stable, `suspend` is a
     static effect without call-site `await`, scopes always join, cancellation is an error at
     suspension points, there is no ambient detached spawn. Implementation starts with fibers
     plus jobs, with plan B ready.
   - *Recommendation:* adopt the semantics now and the implementation after X3.
4. **Cleanup and failure.**
   - *Proposal:* `drop` cannot fail or suspend; finish-or-abandon resources; panics abort in v1;
     errors are values with declared lifting only; aborting on allocation failure by default,
     with fallible APIs.
   - *Recommendation:* adopt finish-or-abandon and panic-abort for v1. Revisit unwinding after
     the language is used for servers.
5. **Generics, staging and proof boundary.**
   - *Proposal:* one coherent interface mechanism with parametric checking; witness tables in
     development builds and specialisation in release; compile-time evaluation as checked
     declaration generation; Lean kernel; the four contract statuses; nothing unverified ever
     licenses an optimisation or an unchecked access; logic restricted to total definitions.
   - *Recommendation:* adopt, measuring X4 and X5 before committing to the development-build
     policy and the eligible proof subset.

---

## 9. Relation to the existing record

The architecture was drafted from the brief before I read the ledger in detail. Afterwards I
cross-checked it against `decisions.md`, the memory-model competition, experiment results 01 and
02, the review response and the Quint lessons.

Caution: the earlier external review recorded in the
[external-review response](opus-review-response.md) and this review were both produced by AI
models of the same family. Where they agree — fibers, a single surface
effect, must-close resources, scoped exclusivity — **do not count the agreement as independent
confirmation.**

- **Consistent with ledger proposals:** P01, P02, P05, P07, P08, P09, P10, P11 and P12.
- **Answers the ledger's demand for a precise escape boundary:** the table in §1.4. This is
  where earlier proposals were least precise.
- **Refinements:**
  - Qualifiers are *type-structured*, following experiment 02's field-sensitivity result.
  - Flow clauses name parameters rather than origin variables.
  - API files sit at **package** level, with inferred contracts across modules inside a package.
  - Typed contexts are phase-two sugar, resolved by name and type together.
  - Suspension's semantic commitments (S1–S6) are separated from the fiber choice.
- **Divergences to discuss:**
  - Panic aborts in v1, where the ledger is undecided.
  - Finish-or-abandon refines the earlier "linear must-close" proposal. It is linear only on
    success paths, so there is no double fault.
  - No yield accessors in v1.
  - One dependency slot per nominal type, with multi-slot deferred.
  - NLL problem case 3 is claimed to be removed by the formulation. That is a hypothesis for X2.
- **Unchanged open items in the ledger:** stackful versus lowered frames (now a measured decision
  with fixed semantics); certificates for SMT theories; GPU barrier and convergence rules; the
  allocation-failure policy for embedded libraries.

---

## 10. Sources checked for this review

All accessed 2026-10-30, as search-result excerpts of the listed pages unless noted. These checks
confirm documented designs, not implementation guarantees. Repository evidence is cited as
[record]; see [`sources.md`](sources.md).

| Topic | Source |
| --- | --- |
| Reachability types (polymorphism, freshness, separation; Coq-mechanised soundness; subsumes the core of Scala capture types) | Wei, Bračevac, Jia, Bao, Rompf, POPL 2024, https://doi.org/10.1145/3632856 · https://arxiv.org/abs/2307.13844 |
| Second-class values | Osvald et al., OOPSLA 2016, https://doi.org/10.1145/2983990.2984009 (bibliographic record only) |
| Scala capture tracking in generic data (System Capless) | OOPSLA 2025, https://arxiv.org/abs/2509.07609 |
| Scala separation checking (System Capybara: `Mutable`, `update`, `consume`) | https://arxiv.org/abs/2607.09383 |
| Swift lifetime dependence (experimental; borrow versus copy dependence; inout defaults and fixes) | https://forums.swift.org/t/pitch-3-compile-time-lifetime-dependency-annotations/84968 · https://forums.swift.org/t/lifetime-dependencies-and-conditionals/83594 · https://forums.swift.org/t/pitch-2-lifetime-dependencies-for-non-escapable-values/78821. Compiler pull requests and commits appeared only as search excerpts and were not individually audited. |
| Swift async frames and task allocator | https://forums.swift.org/t/how-is-an-async-function-actually-executed/79684 · https://forums.swift.org/t/why-stackless-async-await-for-swift/52785 |
| Hylo bindings and copies | https://docs.hylo-lang.org/language-tour/bindings |
| Mojo conventions, origins, ASAP destruction | https://docs.modular.com/mojo/manual/values/ownership · https://docs.modular.com/mojo/manual/values/lifetimes · https://www.modular.com/blog/deep-dive-into-ownership-in-mojo |
| Completion I/O versus drop-cancellation | https://without.boats/blog/io-uring/ · https://without.boats/blog/ringbahn-ii/ |
| Rust async drop status | https://rust-lang.github.io/rust-project-goals/2026/roadmap-just-add-async.html |
| Eio switches, cancellation, capabilities | https://github.com/ocaml-multicore/eio · https://ocaml.org/p/eio/0.15 |
| Go goroutine stacks (2 KB start, copying growth; secondary sources) | https://golang.design/under-the-hood/en/part4memory/ch14stack/ |
| Lean `partial_fixpoint` | https://lean-lang.org/doc/reference/latest/Recursive-Definitions/Partial-Fixpoint-Recursion |
| Austral (linear types and capabilities) | https://borretti.me/article/introducing-austral · https://borretti.me/article/how-capabilities-work-austral |
| Vale generational references and regions (status unconfirmed) | https://vale.dev/roadmap · https://verdagon.dev/blog/zero-cost-memory-safety-regions-overview |
| Verona behaviour-oriented concurrency | OOPSLA 2023, https://doi.org/10.1145/3622852 |

The following were not separately re-checked this session and are stated from general knowledge:

- Swift's non-escaping closure default;
- Rust's `thread::scope`;
- Trio cancel scopes;
- Kotlin's binary-compatibility validator and `cargo-semver-checks`;
- the `yoke` and `self_cell` crates;
- Aeneas backward functions;
- RustHorn and Creusot prophecies;
- Tree Borrows;
- Go's dictionary-based generics.

Each is a well-known public design, and none carries a quantitative claim here.
