# Mutable referent state and writeback

2026-10-30. [Experiment](../../research/experiments/referents14/README.md),
[model](../../research/experiments/referents14/model.py),
[evidence](../../research/evidence/referents14-20261030/).
This investigates the remaining first-class mutable-access boundary, not a Grail checker or a
soundness proof for generic mutable references.

## Three facts a mutable handle must not conflate

A pointer to a cell has a storage requirement B. The cell's current view may require external
source A, later C, later A again. Exclusive authority determines who may inspect/change that cell.
The storage can stay live and the pointer remain unchanged while the referent's dependencies change.

Tracking only B is insufficient: a later read through the handle can still use expired A or C.
Permanently retaining every source ever stored is conservative but prevents useful source release.
Updating only the handle's private contents summary is also insufficient if parent access resumes
with an old summary. The new state must be available wherever the next legal access occurs.

This is not a criticism that the external rooted-value proposal ignores invariance: it explicitly
acknowledges invariant referents and an F1 target. The question is what rules establish that target
with changing referent contents, stored access and generic code.

## Rust boundary actually tested

Eleven isolated Rust cases use shared `&str` data in a stack cell and ordinary exclusive access:

| Cases | Observed result |
| --- | --- |
| Direct slot reassignment; direct reset after a handle ends; direct temporary assignment/restoration | compile and run (3) |
| Inline write through a live handle; copy-old then write; helper set/replace; handle stored in Cursor; ended handle then parent read | reject E0505 at old-owner release (6) |
| Temporary source installed then restored through persistent handle | reject E0597 (1) |
| Temporary source left installed, then used after its scope | reject E0597, genuinely invalid referent lifetime (1) |

The direct assignment cases show this is not a universal inability to reuse sources. The inline and
ended-handle cases show that callee opacity alone does not explain the difference. The reference
lifetime in the mutable referent type is invariant; these signatures do not express a flow-sensitive
change from old-source to new-source support. This is a precision/design boundary, **not a Rust
soundness bug or claim that every equivalent API is impossible in Rust**. An explicit direct reset
is a working control. No runtime cost comparison was measured.

The intended stronger programs still need real rules: after writing C, release A only if no old
returned view remains; before a short C ends, restore/remove C from every live location/result.
A live storage-B handle does not itself justify either operation.

## Finite competing-rule model

The world contains one stable cell B, immutable source owners A/C, one affine mutable handle and
one optional saved old view. Views hold actual source identities. Metadata separately holds upper
bounds. Sources expire at most once; storage is not reused or relocated. Parent access and a second
handle are excluded while the unique handle is active. All policies keep B for that handle.

Writes/restores require their incoming source alive. Replace saves the old view before updating.
Ending a handle resumes parent access. Freeing B drops the cell view, not the external source or a
copied old result. Explicit drop removes the saved view. Data is live until these modeled drops;
there is no general last-use/liveness inference or custom destructor.

The concrete validity oracle checks that all live cell/result views name live sources and that a
live handle has allocated B. Metadata decisions and transfers do not inspect the concrete view's
source identity. Exploration visits every accepted, concretely valid state and outgoing structural
action for each policy, stopping a branch at its first rejection or validity failure. Cycles are
visited by state, not by imposing a sampled trace/depth limit.

| Rule | States | Transitions | Accepted invalid edges | Rejected valid edges |
| --- | ---: | ---: | ---: | ---: |
| Monotone carrier capture, written back | 78 | 674 | 0 | 30 |
| Storage-only active dependency checks | 28 | 182 | 6 | 0 |
| Precise carrier-local state, no writeback | 72 | 596 | 20 | 24 |
| Precise carrier state plus writeback | 38 | 272 | 0 | 0 |
| Current state keyed by cell/place | 28 | 182 | 0 | 0 |

Counts are state/action edges, not numbers of distinct source programs. Totals are 244 states and
1,906 transitions across five different metadata systems. This is complete exploration of this
finite model, **not arbitrary heaps, resources, programs or a kernel-checked proof**.

Shortest distinctions:

- Storage-only: borrow, expire A. The handle's storage is live but its cell contains expired A.
- No writeback: borrow, write C, end handle, expire C. Parent metadata still names A while the
  resumed cell contains C. Reading that cell would use an expired referent.
- Monotone capture: borrow, write C, expire A is valid concretely but rejected.
- Precise styles reject expiring A with a live returned old view, but permit dropping it then
  releasing A. An old result can survive B's release because it points into external A, not B.
- Both precise styles permit restoring A before C expires, while rejecting expiry with C retained.

Eight named trace controls, including unsafe cases, are retained alongside graph results.

## Two viable information placements, not one required runtime graph

One model updates a place-indexed state immediately. The other lets the unique carrier own the
current contents state while the parent is unavailable, then writes it back on access return.
Both preserve the same necessary information in these cases. Neither result requires that this
information survive at runtime: it could be private checker state/ghost information. Neither proves
that such an erased inference/checking algorithm works for the full language or stays cheap.

An illustrative, **not adopted**, contract for replacement through stored unique access would keep
storage/authority unchanged, give the result `pre(contents(cursor))`, and give the target contents
`pre(incoming)`. Base T stays fixed while its current dependency state changes. This is not a
covariant conversion of `&mut T` or permission to duplicate exclusive access.

At minimum a general design needs:

1. A unique authority/frame relationship to the exact referent, including moved/stored handles.
2. Validity of the current contents state while that carrier may read it.
3. Correct old-result capture, new-state update and parent/owner writeback.
4. Reborrow/read-only-child restrictions: suspended parent state cannot be resumed too early.
5. Stable storage and complete exit behavior, including errors, dropping stored handles and cleanup.
6. A generic/interface account of referent effects, not only the carrier's lifetime roots.

Unknown places, dynamic indices, multiple handles, branches/loops, nested exclusive data, heap
reachability/liveness, callback escape, exceptions and suspension remain outside this model.

## Precedent and proof status

Pinned Aeneas `de16f3cf877976e966906dc890f63dcb418884fa` represents concrete mutable borrows as
`VMutBorrow(id, value)` and mutable loans as `VMutLoan(id)`. `give_back_value` documents reinserting
the borrow's current value at its original owner and checking exactly one receiving loan. Its
abstraction machinery is more substantial than this toy. Selected source hashes are retained;
no Aeneas build, proof replay or acceptance of the Rust-rejected cases is claimed. This is precedent
for value-carrying borrow/writeback semantics, not an assertion of a novel primitive.

The pure dependency/shape proofs assume fixed payload dependency predicates and do not establish
this mutable-reference lifecycle. Reusing them needs a checked embedding: for example, fixed
carrier-storage dependencies plus a separate well-formed reachable-cell state, or an affine
value-carrying loan discipline. Calling a heap-dependent predicate the same `deps` does not supply
that theorem. Do not advertise the current model as proving general F1 or selecting a final design.
