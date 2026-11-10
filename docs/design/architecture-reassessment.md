# Grail architecture reassessment: stored mutable access and the remaining gate

2026-10-30. Reviews research on `main` at
[c2d1708](https://github.com/graillang/grail/tree/c2d1708/docs/design), and the earlier proposal at
[d7fb6bf](https://github.com/graillang/grail/blob/d7fb6bf/docs/design/first-principles-architecture.md).
This is an independent recommendation, not an adopted design. No checker, model or proof was built
for it.

Labels:

- **[established]** — shown by the repository's executed, finite-checked or Lean-checked research,
  within that research's stated premises.
- **[choice]** — a design decision I recommend.
- **[unresolved]** — claimed here but not demonstrated.

Relative paths below refer to `main@c2d1708`. For example, `mutable-referent-state.md` means
`docs/design/mutable-referent-state.md` at that commit.

---

## 0. Verdict

**Resolve one named gate first: G1, the exclusive-target state discipline.** Run it as milestone 0
of the compiler prototype, in the prototype's own IR and checker code, not as another standalone
model. It has fixed acceptance criteria and a fallback concession declared in advance (§8). If it
passes, continue the prototype unchanged. If it fails, take the fallback and continue the prototype
anyway. Either way, the research programme does not grow.

- **The goals do not conflict, as far as the evidence shows.** Several *sound* designs are known.
  None is known to meet the goals *together*:

  | Known sound design | Why it misses the goals |
  | --- | --- |
  | Rust-style invariant referent lifetimes | Needs lifetime bookkeeping; rejects helper replacement and temporary restoration (referents14) |
  | Monotone capture | Over-retains sources: 30 valid transitions rejected in referents14 |
  | Strictly second-class mutation | Gives up stored mutable access |

- **The central gate now has a specific candidate rule** [choice]:
  - **State lives with places.** Content-dependency state is always attached to a *place*: a
    concrete local or field, a summary position, or a symbolic parameter place. It is never
    attached to a reference.
  - **Two separate facts per exclusive position.** Each exclusive position records what it
    **blocks** and which places it **may target**.
  - **Strong versus weak writes.** A write through a reference is a strong update exactly when its
    may-target set is a single non-summary place, and a weak (union) update otherwise.
  - **Contracts are upper bounds only.** They are per-outcome (Ok / Err / unreachable) and contain
    no must-facts, so refinement is covariant and the interval-polarity problem never arises.

  Under this rule, writeback happens only at call boundaries, which experiment 05 already does for
  `mut` parameters. No runtime borrow state is needed.
- **Not demonstrated.** The rule has not been shown to compose across stored references, generic
  helpers, containers, destructors, failure and loops. That composition *is* G1.
- **Fallback concession C1.** If G1 fails: generic type parameters exclude values that contain
  exclusive access unless they opt in (Swift's `Escapable` default is the precedent), and heap
  containers of exclusive references are not allowed. This is smaller than going strictly
  second-class.

---

## 1. Evidence status

### 1.1 Established by the research

| Result | Source | Premises that limit it |
| --- | --- | --- |
| Pre/post dependency transformers cover every concrete execution (append, clear, replace, take, swap, branch union) | `preservation-core.md` (Lean) | Pure list/slot grammar; independent numbered slots; no references, errors or loops |
| Symbolic pre-sources instantiate correctly from **one** entry snapshot; re-reading after a write loses sources | `symbolic-instantiation.md` (Lean, with counterexample) | Same grammar |
| Suffix-preserving generic routes and same-T shape substitution keep descendant positions separate | `structured-routes.md`, `shape-substitution.md` (Lean) | Dependency-shape model, not the implementation's type checker |
| Storage-only tracking and carrier-local state without writeback are unsound. Monotone capture is sound but rejects 30 valid edges. **Place-keyed state and carrier state with writeback both have 0 invalid accepts and 0 valid rejects.** | `mutable-referent-state.md` (exhaustive finite model) | One cell, one handle, two sources |
| Rust rejects helper-replace-then-release-old, writes through live or stored handles followed by release, and temporary restoration through a persistent handle. It accepts the same reassignments made directly to the slot, with no live handle. | referents14 probes | A precision boundary, not a Rust bug |
| Lifetime support does not determine target coverage. Exact cover follows from distinct outputs, no outside targets and equal cardinality | `target-coverage.md` (Lean and finite) | List-level identities |
| May-subset / must-superset refinement is sound and complete for footprint intervals. A cache key built from may-facts only goes stale when a must-fact weakens | `contract-refinement.md` (Lean and 7,380 pairs) | Interval domain only |
| Forgetting a scoped-thread handle in Rust stalls scope exit; safety is kept by retaining storage | `opaque-resource-boundary.md` (observed, plus std inspection) | One Rust version |
| Cleanup tied to user handles is unsafe on error exits. A scope-owned registry retained until acknowledgment is safe, and "any acknowledgment clears all" is unsafe | `cleanup-boundary.md` (finite graphs, N ≤ 3) | Read-only shared buffer; abstract acknowledgment |
| Late entry snapshots are required if later arguments may mutate a target; materialised views carry loans immediately | `call-activation-boundary.md` (finite) | Stable named places |

### 1.2 Not established by anyone

- Soundness of any rule for exclusive references that are stored, forwarded generically, or
  contained in heap collections.
- Composition of dependency state with authority, destruction, failure outcomes and scope work.
- The cost of inference and the size of contracts on realistic programs.
- Diagnostics people can act on when state is flow-sensitive.

Every soundness claim for the full language is still unsupported.

### 1.3 What I now consider wrong or underspecified in d7fb6bf

1. **Invariant referent qualifiers solved locally and written back when the reference dies.**
   Replaced by place-keyed state (§2). Writeback when a reference dies is unnecessary and fragile
   for stored or forwarded references.
2. **Additive flows such as `s -> cache`.** These are not complete mutation contracts. Replaced by
   per-outcome pre/post transformers, as the assessment in `rooted-values-review.md` §1 argued.
3. **Exclusive qualifiers written as `(root, exclusive)`.** This conflated what a reference blocks
   with what it targets. These are separate facts (§2.2).
4. **One merged slot per nominal type.** Replaced by derived per-field positions for non-opaque
   records. Opaque types export declared ports, defaulting to one.
5. **`Shareable` and `Once` replacing `Fn`/`FnMut`/`FnOnce`.** Insufficient
   (`rooted-values-review.md` §2). Keep the *call receiver mode* (read, mut or take) separate from
   the thread-sharing properties.
6. **First-class in-flight operation values with `abandon`.** Wrong. Pending work must be owned by a
   scope registry (§2.5, I5).
7. **"Accesses begin after argument evaluation."** Underspecified. Replaced by explicit
   reservation (§2.3, R11).
8. **Finish-or-abandon in generic code.** Needs an implicit `Discardable` bound, or containers
   silently discard success-linear resources (§4).
9. **No failure outcomes in contracts.** Added (§2.4).
10. **`Bundle.view(): V` by value.** Wrong for an owning V. Use a shared projection of a covariant
    view family, as in `bundle-boundary.md`'s candidate v1 boundary.

---

## 2. Recommended minimal semantic core

### 2.1 Where each kind of information lives

| Layer | Contents | What it never contains |
| --- | --- | --- |
| **Source types** (written by the user) | Base types with no lifetimes or qualifiers; parameter modes `read`, `mut`, `take`; `suspend` on public functions; error types; `mut ref T`, `ref T` and view types; resource kinds (must-finish types); `?Discardable` opt-outs; contracts on interface methods, `extern` and function types (defaults cover the common case) | Lifetime or origin variables; target sets; post-states |
| **Exported contracts** (inferred within a package; frozen in the API file at the package boundary) | Per outcome: result routes, post-state routes for every mutable position (including referent positions inside parameters), may-target sets and blocks expressed over symbolic entry positions, scope-registration routes, deferred type-dependent operations, the `suspend` effect. Per type: field positions, drop contract, `Shareable`/`ThreadBound`/`Discardable`. Opaque callables expose a call contract. | Must-facts or lower bounds; whole-program facts |
| **Compiler-private context** (per program point) | Σ: the qualifier tree of every live place (concrete, field, summary, symbolic); qualifiers of live values; carrier-restriction links; reservations; liveness; outcome correlation for the result of the immediately preceding call; local closure contracts; budgets | Anything at runtime |
| **Runtime state** | Scope registries (outstanding operations, cancellation flags); task frames and stacks; generation counters only for opt-in arena handles; bounds and overflow traps | Borrow flags, reference counts, tracing metadata, loan graphs |

### 2.2 Static vocabulary [choice]

- **Place.** Any of:
  - a local;
  - a field path, such as `x.f.g`;
  - a heap content place, such as `box.↓`, which is exact;
  - a **summary** position: `v.*` for collection elements, or a recursive-type fold;
  - a **symbolic** place inside a callee, such as `h.↓` or `c.p.↓`, standing for whatever the caller
    maps it to.
- **Qualifier tree.** One entry for each view-carrying position of a value's base type:
  - *Shared position:* `support`. The roots whose storage this data reads. They must stay live, and
    they are frozen against mutation and moves.
  - *Exclusive position:* two fields.
    - `blocks` — the roots or carriers restricted while this value lives.
    - `targets` — the **may-set** of places this reference reads and writes through. It may
      include a `fresh` pseudo-place.
  - *The referent of an exclusive position is not stored in the tree.* Reading it resolves to
    `⋃ Σ[targets]`.
- **Generic calls.** Base types carry no qualifiers. At a generic call, each type argument is
  instantiated with a *qualified* type taken from the entry snapshot. This is how a callback's
  results get uniform dependencies without higher-order contracts.
- **Examples.**
  - `mut ref b`: blocks `{b}`, targets `{b}`.
  - A reborrow through carrier `h`: blocks `{h}`, targets `targets(h)`.
  - A part of a split of `v`: blocks `{(v, part i of split k)}`, targets `{v.*}`.

### 2.3 Rules for the sequential core

**Places and references.**

| Rule | Operation | Requirement and effect on state |
| --- | --- | --- |
| R1 | Read place `p` | `p` is available and not exclusively blocked by any other live value. The data read has state `Σ[p]`. |
| R2 | Write `p := e` | `p` is available and not blocked. If `p` is exact: strong update `Σ[p] := q(e)`. If `p` is a summary: `Σ[p] ∪= q(e)`. |
| R3 | Shared view `ref p` | Support is `{root(p)}`. The referent is `Σ[p]`, frozen while the view lives. |
| R4 | Exclusive reference `mut ref p` | Blocks `{p}`, targets `{p}`. |
| R5 | Write through a reference `*h := e` | If `targets(h) = {t}` and `t` is not a summary: strong update `Σ[t] := q(e)`. Otherwise, for every `t` in `targets(h)`: `Σ[t] ∪= q(e)`. |
| R6 | Read through a reference `*h` | Gives `⋃ Σ[targets(h)]`. |
| R7 | Projection through a reference | If `h` is not live afterwards, it is **moved** and the result inherits `blocks(h)`. Otherwise it is a **reborrow**: the result has blocks `{h}`, and `h` is restricted while the result lives. Targets narrow to the projected sub-place in both cases. |

**Lifetimes, ownership and resources.**

| Rule | Operation | Requirement and effect on state |
| --- | --- | --- |
| R8 | Move | Ownership and the qualifier tree move with the value. The source becomes unavailable. |
| R9 | Value ends | A value whose type has a trivial drop ends at its last use. A value with a drop contract stays live until scope end or an explicit `drop`, at which point its drop contract is applied. Ending a value releases its blocks and support, and restricted carriers resume. |
| R10 | Invalidate, move or free root `r` | No live value's support or blocks contains `r`. No live place's Σ mentions `r`. No live scope's registry state mentions `r`. |

**Calls.**

R11 is the most detailed rule, so its steps are listed in order.

1. **Evaluate arguments left to right.** A place argument *reserves* its root.
   - Later arguments may read a reserved place, but may not mutate or move it. So `v.push(v.len())`
     works, and a nested `mut cache` mutation inside the same call is rejected.
   - Materialised view values carry their loans immediately.
2. **Activation check.** The blocks of all exclusive arguments must be pairwise disjoint, allowing
   overlap only between different parts of the same trusted split. No shared argument's support may
   be exclusively blocked by another argument.
3. **Entry snapshot.** Snapshot the state of every position reachable from the arguments *at
   activation*. This includes the referent positions of exclusive references carried inside
   argument values.
4. **Instantiate the contract** per outcome.
5. **Commit post-states.** Each mutable position is committed back to the caller's places:
   - strongly, if its caller-side target is a single exact place;
   - weakly, if it is a may-set or summary, or if two parameters map to the same summary place.

**Control flow and scopes.**

| Rule | Operation | Requirement and effect on state |
| --- | --- | --- |
| R12 | Outcomes | If the call's result is discriminated by `?` or `match` as its *next* use, keep the per-outcome states along the corresponding paths. Otherwise join them. An unreachable outcome (⊥) contributes nothing to a join. A reachable outcome with empty dependencies contributes its post-state. |
| R13 | Branches and loops | Joins are pointwise unions of Σ, supports, blocks and targets. Loops iterate to a fixpoint over a finite lattice. |
| R14 | Closures | Creating a closure infers a call contract over its capture positions. A direct call applies it. A higher-order function whose contract says "calls `f`" makes the caller apply the closure contract's fixpoint (zero or more calls). |
| R15 | Scope registry | `s.start(op)` moves the operation's support and blocks into `Σ[s]`. Its handle is a shared view of the registry entry. Scope exit joins all registered work on every exit path, which is a latent `suspend` effect. After exit, `Σ[s]` is released. Releasing one operation's loans before exit needs operation identity and is deferred to G2; v1 retains them until the scope joins. |
| R16 | Suspension | No static state change. Cancellation is an `Err(Cancelled)` outcome at suspension points. |

**Interior mutability** (deferred to G2, rule stated now). Positions inside `Cell`- or `Mutex`-like
types are *frozen-state* positions. A write through shared access must satisfy
`q(incoming) ⊆ Σ[position]`: the state cannot grow and cannot be strongly updated. This restates,
in state terms, the variance restriction that Rust and yoke impose.

### 2.4 Contracts [choice]

Notation: `⊑` reads "bounded by". `pre(x)` is the entry state of position `x`. Routes are
suffix-preserving for type-variable positions.

```text
contract f = {
  modes, effect: suspend?,
  outcomes: { ok: Summary | ⊥,  err: Summary | ⊥ },     -- cancellation is an err
  deferred: [ drop T at P, call F at P, method I.m on P ]  -- for opaque types only
}
Summary = {
  result  ⊑ Routes,                  -- includes blocks/targets of exclusive result positions
  post    : mutable position ↦ Routes,
  scope   ⊑ Routes                   -- work registered in caller-provided scopes
}
Routes  = position ↦ set of ( pre(entry position) | fresh )
```

**Upper bounds only.**

- Exactness is derived, never declared: a may-target set of size 1, together with the type
  invariant that a live reference always has a valid target, means "exactly this place".
- Changing a target set from `{b}` to `{b, fresh}`, or a post-state from `pre(new)` to
  `pre(new) ∪ pre(*h)`, *grows* an upper bound.
- So refinement is componentwise subset per outcome, with ⊥ below everything, and a cache key over
  the whole contract is complete.
- This deliberately drops coverage-based collective strong updates (§5.3). That is how the
  polarity problem in `contract-refinement.md` is avoided rather than solved. If must-facts are
  ever added, their keys must follow that study's interval law.

### 2.5 Invariants and how they compose

| Invariant | Statement |
| --- | --- |
| **I1 Ownership** | Every allocation has one owner path, or is registered in a scope, or is leaked. Moves transfer ownership. |
| **I2 Support** | Every root in a live value's support, or in a live place's Σ, is allocated and not moved. Shared support roots are not mutated. |
| **I3 Authority** | The blocks sets of live exclusive positions are pairwise disjoint, modulo trusted split parts and carrier restriction. A blocked root is used only through its blocking value. |
| **I4 State coverage** | For every place `p`, `Σ[p]` covers the actual dependencies of `p`'s contents. For every live exclusive position, the actual referent's dependencies are covered by `⋃ Σ[targets]`, and the actual target is in `targets`. |
| **I5 Scope work** | Every pending operation is registered in a live scope whose state retains its loans. A scope's frame cannot end before its registry is empty. Acknowledgment means that operation's last access is over. |
| **E1 Effects** | Suspension happens only in task contexts. Cancellation is observed only at suspension points, as an error outcome. |

**Composition.**

- I4 is the generalisation of the Lean `Related` invariant, with places instead of numbered slots.
- I3 is what makes strong updates sound: a single exact target, plus exclusivity, means no
  unseen alias wrote to it.
- I2 and I5 justify R10.
- I1 and I5 together mean that safety never depends on a destructor running (§4).

---

## 3. The decisive example, worked

Setup. `a`, `c` and `t` are owned `String`s; `b` is a cell holding a view.

```grl
type Cursor = { p: mut ref Str }
var b: Str = a.view()               // Σ[b] = {a}
var cur = Cursor { p: mut ref b }   // cur.p: blocks {b}, targets {b}
```

**The helper**, compiled separately and generic:

```grl
fn replace[T](h: mut ref T, new: take T) -> T { let old = take(*h); *h = new; old }
// inferred contract:
//   ok:  result ⊑ pre(*h);   post(*h) ⊑ pre(new)
//   err: ⊥
```

**P1 — stored access, generic helper, returned old value, release.**

```grl
let old = replace(cur.p, c.view())
// R7:  cur.p is used again later, so it is reborrowed: child blocks {cur.p}, targets {b}
// R11: entry snapshot pre(*h) := Σ[b] = {a};  pre(new) = {c}
//      commit: targets {b} is exact → strong update Σ[b] := {c};  old.support = {a}
drop(old)                // old ends
drop(a)                  // R10: is `a` in any live support, Σ or scope? Σ[b] = {c}, old dead → ACCEPT
print(*cur.p)            // R6: ⋃Σ[{b}] = {c}; c live ✓
drop(cur)                // blocks on b released
print(b)                 // Σ[b] = {c} ✓   (Rust rejects this program at `drop(a)`: E0505)
```

Answers to the brief's questions:

| Question | Answer |
| --- | --- |
| What keeps B valid? | `b` is in `cur.p`'s blocks, so R10 forbids moving or freeing it while `cur` lives. |
| What blocks conflicting access? | The same blocks set: a direct use of `b` is rejected while `cur` is live (R1/R2). At the call, R11 rejects, for example, `replace(cur.p, b.view())`, because the second argument's support is exclusively blocked. |
| Where does B's changing state live? | Always in `Σ[b]`. Inside `replace` it is the symbolic place `h.↓`. The call commits it back. |
| What transfers the state back? | Nothing at reference end. The only transfer is R11's commit at call return. |
| When can A be released? | When `old` is dead and no live place's Σ contains `a`. Here, immediately after `drop(old)`. |

**P2 — temporary insertion and restoration.**

```grl
{   let t = String.from("T")
    *cur.p = t.view()          // R5 strong: Σ[b] := {t}
    use(*cur.p)
    *cur.p = a.view()          // Σ[b] := {a}
}                              // t ends: no live state mentions t → ACCEPT  (Rust: E0597)
```

The same through a helper that restores before it returns, including on error:

```grl
fn with_temp[T, R, E](h: mut ref T, tmp: take T, body: fn(mut ref T) -> R ! E) -> R ! E {
    let old = replace(h, tmp)      // Σ[h.↓] = pre(tmp)
    let r = body(h)                // the higher-order contract applies body's writes to h.↓ (conservative)
    *h = old                       // h.↓ is exact inside the callee: strong, Σ[h.↓] := pre(entry *h)
    r                              // both outcomes: post(*h) ⊑ pre(*h)
}
```

The contract shows the temporary never leaks, so the caller may end `t` after the call on both
outcomes. If the author instead writes `let r = body(h)?` before restoring, the err outcome becomes
`post(*h) ⊑ pre(tmp) ∪ …`. The caller's diagnostic then says: "on the error path `b` still holds a
view of `t`". A guard whose destructor restores the old value gives the same contract through its
drop contract (R9).

**P3 — failure after mutation and failure before mutation.**

```grl
fn install[T](h: mut ref T, new: take T, fail: Bool) -> T ! Failed[T] {
    let old = replace(h, new)
    if fail { return error(Failed { payload: old }) }
    old
}
// ok:  result ⊑ pre(*h);           post(*h) ⊑ pre(new)
// err: err.payload ⊑ pre(*h);      post(*h) ⊑ pre(new)      -- no rollback

fn try_install[T](h: mut ref T, new: take T, ok: Bool) -> Unit ! Nope {
    if !ok { return error(Nope) }   // `new` dropped; *h untouched
    *h = new
}
// ok:  post(*h) ⊑ pre(new)
// err: post(*h) ⊑ pre(*h); err ⊑ ∅      -- reachable outcome with empty deps (≠ ⊥)
```

Caller:

```grl
match install(cur.p, c.view(), f) {          // R12: discriminated immediately → correlated
    Ok(old)  => { drop(old); drop(a) },        // Σ[b] = {c}, old ended → ACCEPT
    Err(e)   => { drop(a); use(e) },           // e.payload.support = {a} → REJECT drop(a)
}
let r = try_install(cur.p, c.view(), g)       // stored, not discriminated next
log("tried")
// R12 join: Σ[b] = {a} ∪ {c}. So drop(a) and drop(c) are rejected while b is live,
// even on the path where only one of them is really needed. This is the cost of the sound join.
```

**P4 — generic forwarding, nested exclusive data, choice.**

```grl
fn pass[T](x: take T) -> T { x }                 // ok: result ⊑ pre(x), suffix-preserving
let cur2 = pass(cur)                              // cur2.p: blocks {b}, targets {b}
*cur2.p = c.view()                                // exact → strong

var slot = Cursor { p: mut ref b1 }
let old = replace(mut ref slot, Cursor { p: mut ref b2 })   // T = Cursor
// old.p: blocks {b1}, targets {b1}.   Σ[slot.p] := blocks {b2}, targets {b2}
*old.p = c.view(); drop(old); use(b1)            // b1 is free again → ACCEPT

fn pick[T](x: take T, y: take T, s: Bool) -> T    // ok: result ⊑ pre(x) ∪ pre(y); deferred: drop T
let r = pick(Cursor{p: mut ref b1}, Cursor{p: mut ref b2}, s)
*r.p = c.view()                                   // targets {b1, b2} → WEAK: both gain {c}
```

**P5 — a container of references** (a known loss of precision).

```grl
var v: Vec[mut ref Str] = [mut ref b1, mut ref b2]   // v.*: blocks {b1, b2}, targets {b1, b2}
for r in mut v { *r = c.view() }                        // weak: Σ[b1] ∪= {c}, Σ[b2] ∪= {c}
drop(v)
drop(a)            // REJECT while b1 or b2 is live, even though every element was overwritten
```

Rust also rejects this: the element lifetime is invariant. Making it acceptable would need a
coverage must-fact, which v1 deliberately does not have.

**P6 — carrier reborrow, resumption, consumed split.**

```grl
{ let q = mut ref *cur.p          // blocks {cur.p}, targets {b}; cur.p restricted
  *q = c.view()                   // Σ[b] := {c}
  /* use(cur.p) → REJECT: restricted by q */ }
*cur.p = a.view()                  // q ended; cur.p resumes → ACCEPT
let (l, r) = span.split_at(m)      // take span: span unavailable afterwards, even once l and r end
```

**P7 — work outliving its handle.**

```grl
scope { s =>
    let h = s.start(read_into(mut buf))   // Σ[s] gains buf (exclusive); h is a view of the entry
    forget(h)                             // harmless: the registry, not h, owns the work
    fallible()?                           // error exit: scope joins (latent suspend), then releases
}
```

Unlike Rust's scoped threads (`opaque-resource-boundary.md`), forgetting the handle neither releases
the buffer early nor stalls the scope, because completion is tracked by the registry rather than by
the handle's destructor.

**Can this stay modular and inferable through generic containers and helpers?** [unresolved; this
is G1]

- Every contract above mentions only symbolic entry positions.
- Generic T is forwarded by suffix-preserving routes, which is the proved shape-substitution
  setting.
- Containers become summary places.
- Operations that depend on T's concrete type (drop, call, interface method) are deferred and
  instantiated by the caller (§4).
- No callee needs the caller's place names, and no caller needs the callee's body.

---

## 4. Composition: ownership, state, authority, destruction, scopes

Explicit assumptions. A safety claim is only as strong as these.

| | Assumption | Consequence |
| --- | --- | --- |
| **A1** | Trusted primitives (`Vec`, `split_at`, the arena, `Bundle`, `unsafe` blocks) satisfy their declared contracts, including that split parts are disjoint. | They are part of the TCB, exactly like Rust's standard library. |
| **A2** | The compiler's checker and contract producer are correct. Consumers rebuild dependency interfaces from source. | Registry artifacts are never trusted. Experiment 02's forged-artifact result stands. |
| **A3** | Leaks are tolerated: **safety never depends on a destructor running**. | See the note on leaks below. |
| **A4** | Destructors cannot fail or suspend, but may block and may write through their own exclusive references. | For opaque T, a drop is approximated as `⋃Σ[targets(T)] ∪= q(T)`. This is sound because a destructor can only install data it can reach. Concrete types use their inferred drop contracts. |
| **A5** | Deferred type-dependent operations. | Generic code records "drop T at P", "call F at P" or "method I.m on P". The caller instantiates the concrete contract. `dyn` and erased callables use their declared contracts or the A4-style default. |
| **A6** | Panics abort the process. | The only outcomes are ok and err. Adding unwinding later means a third outcome joined conservatively. |
| **A7** | There is no mutable global state. Interior mutability exists only in library types that use the frozen-state rule. | |
| **A8** | Backend acknowledgment is honest: the io_uring mapping follows `cleanup-boundary.md`. | Acknowledgment is the terminal completion event, not the cancel request or `-EALREADY`. |
| **A9** | Fixed evaluation order and reservation (R11). | Computed index or pointee places evaluate their selector early, bounds-check at activation, and reserve their container. |

On **A3, leaks**:

- Leaks are possible through optional reference-counted library types, FFI, `exit` and abort.
- So I5 owns pending work, and `forget` (only for `Discardable` T) statically ends that value's
  loans without running its destructor.
- Must-finish resources are not `Discardable`. Generic type parameters carry an implicit
  `Discardable` bound, so `Vec[Writer]` requires a container that explicitly supports it.
- The cost is one implicit bound, which appears in error messages.

**Effects versus captured authority.**

- `suspend` (plus latent scope-join suspension) is an effect of a computation.
- A capability is a value, so retaining it is a support entry in a qualifier.
- Dropping a closure ends its retention. Calling it may suspend.
- The two are never inferred from each other.

---

## 5. Separate compilation: what is inferred, serialised and expensive

### 5.1 Inferred and serialised

- **Per public function:** the §2.4 contract, two outcomes at most.
- **Per public type:**
  - derived field positions for non-opaque types; declared ports for opaque types;
  - the drop contract;
  - `Discardable`, `Shareable` and `ThreadBound`;
  - layout, for non-opaque types.
- **Per interface:** declared method contracts.
- **Per opaque returned callable:** its call contract.

Inference happens within a package, iterating to a fixpoint over SCCs. At the package boundary,
results are frozen into the generated, reviewed API file: the d7fb6bf policy, kept unchanged.

### 5.2 Where cost or size can grow

| Risk | Why | Bound or widening |
| --- | --- | --- |
| Dense routes | Experiment 02: 128 × 128 distinct sets | Per-function budget. On overflow, widen each position to the union of all type-compatible entry positions. |
| Many live exclusive references in loops | Σ × targets × supports per program point | Finite lattice. Liveness keeps live sets small in practice [unresolved: measure]. |
| Recursive SCCs with mutable generic parameters | Contract fixpoint | Monotone and finite. Budget, then the same widening. |
| Per-outcome summaries | At most ×2 | Correlated only for the immediately next discrimination (R12). |
| Closures in loops | Fixpoint of the call contract | Finite. |
| Recursive types | Unbounded paths | Folded into summary positions. |

### 5.3 Sound widenings and what each one loses

| Widening | Precision lost |
| --- | --- |
| Weak update through a may-target or summary target | Release of overwritten sources (P5) |
| Index collapse | Releasing state per element |
| Outcome join | Releasing on one path only (P3) |
| Budget widening | False "still borrowed" errors at clients |
| Conservative drop for opaque T | Restore-on-drop precision in generic code only |
| No coverage must-facts | Collective writeback through permuting helpers (`target-coverage.md`). Callers get weak updates there. |

None of these widenings loses soundness. Each is a source of explainable false rejections, which
must be named in diagnostics.

---

## 6. Alternatives under the full goals

| Alternative | Simpler? | Verdict |
| --- | --- | --- |
| **Rust-style lifetime parameters with invariant referents**, plus inference for private code | Simpler to implement, using known algorithms | Fails "no routine lifetime bookkeeping" for structs and generic APIs. Less precise (P1 and P2 rejected). Not simpler for users. |
| **Strictly second-class exclusive access** (Hylo-like): `mut` parameters, local `inout` bindings and projection calls only; no exclusive access stored in values | **Genuinely simpler checker:** G1 disappears, and experiment 05 plus the shared-data proofs already cover most of it | Loses `Cursor`/`Formatter`-style sinks, iterator values over mutable items, `Entry` values, collections of references, and lending adaptors. Pushes APIs into callbacks, and `?`/early return inside callbacks is awkward. The brief rules callbacks out as a universal replacement. **This is the natural concession if G1 and C1 both fail.** |
| **Fallback C1**: G1's rule, but generic parameters and heap containers exclude exclusive-access-containing types unless opted in | Moderately simpler: deferred generic operations and summary targets mostly disappear | Keeps stored references in records and returned spans. The cost is opt-in boilerplate for generic containers of references, as in Swift. **Declared fallback.** |
| **Regions** (Verona, Cyclone style) | Simpler aliasing inside a region | Region polymorphism in signatures is bookkeeping. Memory is retained until the region ends. Deletion needs runtime mechanisms. |
| **Generational references everywhere** (Vale) | Simple | A check on every dereference is effectively runtime borrow checking. Excluded. |
| **Uniqueness with functional update** (Futhark, Cogent) | Simple semantics | Stored zero-copy views still need borrowing, so it converges on this core. |

No alternative is simpler while meeting every goal. The real choice is between G1's full rule and
the bounded concessions C1 and strict second-class access. That choice is what G1 tests.

---

## 7. Readiness: start the prototype now, in this order

**Yes, start an end-to-end prototype now.** Its first milestone *is* G1, implemented in the language
intended for the compiler, so that the checker survives into the prototype. Stop adding standalone
Python models.

The first question it must test is G1 composition: stored, forwarded and contained exclusive
references, failure outcomes, deferred generic operations and loops, under separate compilation.

### 7.1 Milestone 0 deliverables

1. **Front end.** A minimal surface syntax and typed IR covering:
   - records and enums (including `Option` and `Result`) and generic functions and records;
   - `Vec` as a trusted primitive, `Str`/`String`, `ref` and `mut ref`;
   - closures, both non-escaping and stored;
   - the `read`/`mut`/`take` modes, loops, branches, `?` and `match`;
   - destructors;
   - `scope`/`start` with registry semantics, but no real asynchrony.
2. **Checker** implementing R1–R16 and per-outcome, upper-bound contracts with budgets.
3. **API-file serialisation** and checking of clients without access to provider bodies, from the
   first day.
4. **Reference interpreter as oracle**, written separately from the checker. It models place
   identities, owner generations, views carrying `(owner, generation)`, exclusive-reference targets
   and dynamic authority, and flags stale reads, writes through dead targets and conflicting
   access. It uses no reference counting or garbage collection that could hide bugs.

### 7.2 Staging: what may wait and what may not

| Reasonable to defer | Would evade the central problem |
| --- | --- |
| Native code generation and optimisation (the interpreter comes first) | Excluding exclusive references stored in records, heap containers or generic T |
| Fiber runtime and real I/O. The R15 semantics and latent `suspend` stay in. | Excluding failure outcomes, or treating failure as rollback |
| Interior mutability (G2), with its rule fixed now | Excluding destructors on generic T, or `forget` |
| Precise early release of individual operations (G2) | Excluding carrier reborrows and consumed splits |
| `dyn`, FFI beyond stubs, `Bundle`, compile-time evaluation, verification translation, devices, thread sharing | Excluding closures that capture `mut` and are called by generic higher-order functions |
| Surface syntax polish | Whole-program checking, or skipping body-hidden clients |
| | Excluding loops, which removes fixpoint costs |
| | An oracle that cannot detect stale views |

---

## 8. G1: bounded experiment and acceptance criteria

### 8.1 Corpus

- §3 P1–P7, with every listed variant.
- §9's must-accept and must-reject programmes.
- **Exhaustive enumeration** of IR programs up to: 3 owners, 3 cells, 2 references (stored or bare),
  1 record level, 6 statements, one generic helper call, one error outcome and one loop.
- **10⁵ random programs** from a fixed seed.

### 8.2 Acceptance criteria

| | Criterion | Pass condition |
| --- | --- | --- |
| **AC1** | Soundness (bounded) | Zero accepted programs that the oracle flags, over the full enumeration and the random set. |
| **AC2** | Precision | Every §9 must-accept programme is accepted, and every must-reject programme is rejected. Diagnostics name the place, value and outcome. |
| **AC3** | Modularity | Decisions with bodies hidden equal whole-program decisions on the corpus, except listed precision differences. I expect none. |
| **AC4** | Upper-bound contracts suffice | No must-accept programme needs a must-fact. Every behavioural change to a helper (replace → append, or adding a fresh target) shows up as API widening. |
| **AC5** | Cost | On a generated scaling family (straight-line and looped functions of 10²–10⁴ statements, 10–10³ places, 1–50 live exclusive references), checker time grows at most near-linearly. A fitted exponent of 1.3 or below is my proposed threshold. Median contract size is reported, and widening triggers only above the declared budget. |
| **AC6** | Proof (needed before *claiming* soundness, not before continuing the prototype) | Lean preservation of I4 for the sequential IR: places, symbolic places, exclusive may-targets, strong and weak updates, per-outcome commits. I3 is a stated premise, separately checked by the oracle within the AC1 bounds. No domain axioms. |

### 8.3 Stop rule

The corpus is fixed in advance. Failing cases are fixed by changing the *rule*, not by extending the
corpus.

### 8.4 Fallback

If AC1 or AC2 fails because of a need for carrier-local state, must-facts, or deeper correlation:

1. Adopt C1.
2. Re-run AC1–AC3 under C1.
3. Proceed.

If C1 also fails, adopt strictly second-class exclusive access and proceed. That is the smallest
concession consistent with the remaining goals.

---

## 9. Falsification programmes

**Must accept.** Rejection by the checker falsifies the precision claim.

- **F1** — P1: replace through a stored cursor, drop the old view, release `a`.
- **F2** — P2: temporary insertion and restoration through a stored handle; and through
  `with_temp` on both outcomes.
- **F3** — P3: correlated release on the ok path.
- **F4** — P4: a cursor through `pass[T]`, then a strong write; nested `replace` with `T = Cursor`.
- **F5** — Linked-list tail cursor: `cur = mut ref (*cur).next` in a loop (a move-reborrow by R7),
  then append at the tail.
- **F6** — A closure capturing `mut cache`, called by a generic higher-order function in a loop with
  views of `s1`; then release an unrelated `s2`.
- **F7** — P7: a forgotten handle plus an error exit; the scope returns once the work completes.

**Must reject.** Acceptance by the checker means it is unsound.

- **N1** — Release `a` while `old` is live.
- **N2** — `install`'s err path: release `a` while the payload is live; release `c` while `b` is
  live.
- **N3** — A temporary left installed through a stored handle, then `t` ends while `b` is live.
- **N4** — Two references presented as distinct split parts but derived from the same part.
- **N5** — Use a restricted carrier while its child is live; use a consumed span after its parts end.
- **N6** — Install a view of `b` into `b` through `b`'s own exclusive reference.
- **N7** — Two operations on one buffer, one acknowledged, then release.
- **N8** — Change a helper body from replace to append under an unchanged API file: producer-side
  rejection.

**Expected false rejections.** These are documented costs, not falsifiers unless frequent.

- P5 (weak container writes);
- P3's undiscriminated join;
- permuting helpers.

**Scale and practice falsifiers.**

- **S1** — AC5 fails: superlinear checker time on the scaling family, or routine widening on
  ordinary code.
- **S2** — Classify ~40 real Rust APIs with `&mut` in structs or returns: `fmt::Formatter`,
  `HashMap::entry`, `iter_mut` with `peekable`, `Vec::drain`, `split_at_mut`, `Cursor`, slice
  `chunks_mut`, `BTreeMap::range_mut`, and others. Count those needing must-facts, deeper
  correlation or inexpressible contracts. If more than a small fraction need them, take C1. The
  threshold is a product choice.

---

## 10. Final verdict

**Resolve G1 first, as milestone 0 of the prototype, with criteria AC1–AC5 and fallback C1.** AC6 is
required before any soundness claim. Then proceed to the following milestones, in this order:

1. **M1.** Native code generation for the sequential core, plus a zero-copy parser benchmark against
   Rust.
2. **M2.** Structured concurrency runtime: fibers, the R15 registry, cancellation outcomes, backend
   acknowledgment mapping.
3. **M3.** Separate-compilation pipeline and build-latency measurement.
4. **M4.** Verification translation for the eligible subset.

**Remaining risks once G1 passes:**

1. **Inference cost and contract size** at package scale. AC5 measures only a synthetic family.
2. **Diagnostics** for flow-sensitive state and joined outcomes. This needs a user study; it is
   decisive for "Go-like simplicity".
3. **Defaults** for interface-method and `extern` contracts (lending versus non-lending, entry-like
   methods). This is where user-written bookkeeping remains, mostly for library authors.
4. **Interior mutability under the frozen-state rule** (G2), and precise operation release (G2).
5. **Async implementation cost:** fiber memory, or the duplication cost of the alternative lowering.
   The semantics are fixed either way.
6. **Runtime speed of development-build generics** under witness tables.
7. **Correctness of trusted primitives and `Bundle`.**
8. **An honest TCB:** checker, contract producer, primitives, runtime registry and acknowledgment
   mapping, backend, and, for optional proofs, the translation and the Lean kernel. Ordinary builds
   need no SMT and no Lean.

**Facts, choices and open claims, kept separate:**

- **Facts:** §1.1.
- **Choices:**
  - place-keyed state;
  - separate blocks and targets;
  - exactness derived from singleton may-sets;
  - upper-bound per-outcome contracts;
  - immediate outcome correlation;
  - reservation at argument evaluation;
  - deferred generic operations with conservative defaults;
  - scope-owned work;
  - leak tolerance with an implicit `Discardable` bound;
  - panics abort.
- **Open claims:**
  - that these choices compose soundly (AC1, AC6);
  - that they are precise enough for real APIs (AC2, S2);
  - that they stay cheap (AC5, S1).
