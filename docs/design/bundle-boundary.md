# Bundle construction, projection and external dependencies

2026-10-30. [Eighteen isolated Rust probes](../../research/experiments/bundle07/README.md),
[raw results/source provenance](../../research/evidence/bundle07-20261030/checks.json).
This refines the [rooted-value review](rooted-values-review.md); no Grail Bundle is implemented or
adopted. The external proposal already freezes the owner and prescribes rebuilding to edit it.
That is a real restriction, not an omission to criticize as unrestricted owner mutation.

## What the probes establish

Nine compile and run; nine reject for the intended reason with pinned compiler/crate provenance.
All user probe code uses safe Rust; the libraries contain unsafe internals. The accepted paths use
unique heap ownership or an ordinary borrowed cart, **not Rc/Arc**. Passing examples do not audit
those internals or prove general soundness.

| Boundary | Executed observation |
| --- | --- |
| Shared Vec-of-view projection | Covariant lifetime shortening is accepted |
| Shared Cell-of-view projection | Whole-container lifetime shortening is rejected |
| Owning AST from shared access | Moving the AST out is rejected; shared AST projection works |
| Exclusive view in shared storage | Shared read reborrow works; duplicate exclusive access rejects |
| Owned AST plus source | self_cell constructs, moves and projects a zero-copy AST over its own String |
| Inline owner bytes | self_cell stabilizes them before constructing the dependent view |
| Noncovariant dependent | Scoped callback can update a Cell to another slice of the same owner |
| Selected shared field from noncovariant dependent | Returning str from the callback works |
| Whole invariant dependent from callback | Shortened Cell reference escape rejects |
| Outside short-lived references | Builder capture and later insertion both reject |
| Returned projection after bundle drop | Rejected |
| Normal destruction | Observed dependent drop before owner drop |
| Owned versus borrowed cart | Yoke supports both; the borrowed cart's external lifetime is not erased |

The callback distinction is important. It would be wrong to say "noncovariant means no references
can be returned." The actual successful signature is a str projection tied to the Document borrow.
The rejected one exposes Cell<&str> with a shortened inner lifetime, allowing later insertion if
such a conversion were permitted. The probes separate these cases rather than assuming the answer.

## An accessor cannot return arbitrary V by value from shared access

An AST can own its node vector while borrowing token text. That does not make the AST Copy.
`view(): V` must mean an explicit shared projection/access, a permitted copy, or a consuming transfer.
It cannot silently clone an owning AST merely to make the signature work. The actual self_cell
accessor returns a reference to the dependent family; Yoke get likewise returns a shared reference
to a lifetime-rebound family output.

A shared projection containing an exclusive reference does not duplicate it. Reading through that
reference as shared is possible; extracting another exclusive reference through shared access is
not. If Grail admits exclusive dependents, their construction and access need corresponding authority
rules; the readonly builder shown in the proposal does not automatically supply unique access.

## Re-rooting requires a rule, not necessarily user-written lifetime variables

The inspected Yokeable contract represents a family indexed by a borrow lifetime. Its safety
conditions require appropriate covariance, matching representation and destruction before the data
borrowed from. Its mutation method additionally restricts captured borrows and the callback's input
lifetime so mutation cannot install a fresh shorter reference or self-reference into movable data.

self_cell checks covariance before generating borrow_dependent. Noncovariant types instead use a
higher-ranked callback API. Selected covariant projections can still escape tied to the outer borrow;
the whole invariant container cannot be retyped to that shorter lifetime.

Grail could derive internal root parameters, family projections and variance from data structure
shape. This is not a demand for source-level lifetime parameters or general higher-kinded types.
But the compiler/interface meaning must preserve the distinction between an internal owner root and
a temporary accessor borrow. Simply replacing every occurrence by a shorter root inside Cell is not
justified. Read-only projection, mutable dependent access and dependency replacement need separate
rules. The [normal-state transformer](experiment-results-05.md) excludes shared interior mutation;
it does not prove this case safe.

## Two stability strategies, different costs

The proposal's StableBorrow condition permits moving the owner descriptor while its referents remain
at fixed heap addresses. Inline small-string storage does not satisfy that strategy unaided.

self_cell uses a different strategy: allocate a joined owner/dependent cell, place the owner in its
final location, then invoke the builder. Its successful inline-byte-array probe borrows bytes inside
that owner and keeps the address across a semantic move of the outer handle. Thus an extra stable
cell allocation can support owners that are not stable under moving the owner itself. Boxing such
an owner before using a stable-deref cart is another formulation.

This is not evidence that stable storage is unnecessary, nor that the extra allocation is free.
The macro source explicitly allocates the joined cell; no allocation-count or timing benchmark was
run. Pointer equality is a finite observation, not proof for every optimizer or mutation. Keep the
cost policy explicit: reuse already-stable owner storage, require explicit boxing, or offer a visibly
allocating constructor. No choice is adopted here.

## "Owned bundle" needs an owned owner—or outward dependencies

Hiding the internal owner-to-view edge does not erase an owner's existing external borrows. A Yoke
with a borrowed cart retains that lifetime in its outer type even though its stored view template
contains 'static. Attempting to return it as a fully static/owned cart is rejected.

For generic Bundle[O,V], either require O to be genuinely owned for an always-owned result, or retain
O's external dependency positions in the Bundle's exported qualifier. Merely owning a descriptor or
an outer allocation is not ownership of every source reachable through it. The String-owning example
in the proposal meets the owned-owner case; the generic statement needs the bound or propagation rule.

## Lifecycle and evidence boundary

The source implements dependent-before-owner drop and a guard for partial construction. The normal
order is exercised, including a dependent destructor that reads its still-live owner. Construction
panic/cancellation, destructor failure and arbitrary asynchronous dependents were not executed.
Those must connect to the [cleanup ownership rule](cleanup-boundary.md), not inherit a blanket safety
claim from the ordinary AST case. Rebuild must drop all internal dependent views before mutating or
moving the underlying owner, and must reject while external projections remain live.

Pinned packaged source inspected/executed:
- [self_cell 1.3.0](https://github.com/Voultapher/self_cell/tree/93cb06e430e7516ac9b436029a15127782b6c2b6/src)
- [yoke 0.8.3](https://github.com/unicode-org/icu4x/tree/a954ec29392c0225453404cb1f6a77f0ded27089/utils/yoke/src)
- [stable_deref_trait 1.2.1](https://github.com/storyyeller/stable_deref_trait/tree/30002b4228f7cdee309217b6bf6eee099dda0b00/src)

The exact crate feature/edition flags, archive/source hashes, compiler version, diagnostics and runs
are retained. No tracing GC, mandatory reference counting or user unsafe block was needed for these
particular examples. This does not establish a general Grail representation, inference algorithm,
ABI, runtime cost or verified lowering.

**Candidate v1 boundary:** first specify an owned stable owner, a checked owner-rooted constructor,
shared projection of a suitable view family, and dependent-before-owner cleanup. Treat mutable
projection, invariant-family access and borrowed owners as explicit extensions/alternatives rather
than pretending that an unrestricted pair of type parameters already specifies them.
