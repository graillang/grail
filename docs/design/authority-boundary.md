# Lifetime roots, authority transfer and reborrowing

2026-10-30. [Experiment 08](../../research/experiments/authority08/README.md),
[raw results](../../research/evidence/authority08-20261030/checks.json).
Fifteen Rust probes: nine compile/run, six reject as intended. A bounded ghost model checks 45
partitions and 19,668 access queries with no discrepancy. **No Grail checker or soundness proof.**

## Do not argue against a weaker proposal

The external proposal already includes root **field paths**, conservative index collapse, trusted
split primitives, a distinction between Iterator items keeping self.deps and Lending items keeping
self, and a permission-instrumented target statement F1. It also acknowledges invariant referents
for first-class mutable references. This note is about filling those rules in, not claiming that
the proposal has only unstructured lifetime sets or bans ordinary mutable iteration.

## Three cases that need different meanings

| Operation | Lifetime/source obligation | Authority behavior |
| --- | --- | --- |
| Borrow through a mutable carrier | Result cannot outlive that carrier loan merely because its stored reference is longer-lived | Parent access restricted while child is live |
| Move old reference out with replacement | Returned old value retains its own original source; slot contains replacement | Old authority transfers, no persistent borrow of slot |
| Consume/split a span | Outputs retain underlying source, not a discarded handle's storage | Input authority moves into disjoint outputs |

These are semantic roles, not adopted Grail syntax or automatically inferred contracts in this
experiment. The [pre/post prototype](experiment-results-05.md) tests replacement for shared view-data;
it does not yet carry exclusive authority or implement these general reference rules.

### A temporary child restricts, then releases, its parent

An exclusive child prevents parent reads/writes to the borrowed portion. A shared child permits
parent reads but not writes there. After the child's last use, the parent's rights can resume.
The accepted parent_resumes and shared_child_read probes and the corresponding rejected writes
exercise this distinction. Observable destruction can extend liveness; these scalar reference probes
have no such destructor.

"There is a later use of parent" does not mean its full authority is active throughout the interval.
It may remain a live value while its permission is temporarily delegated. Conversely, moving the
parent Span into a consuming split makes that binding unavailable even after both children end.
The consumed-parent probe rejects after the children's last uses, not merely during their borrows.

### A carrier loan is not the stored value's entire source lifetime

Rust rejects a function claiming to return &'long mut T from &'short mut &'long mut T without the
necessary outlives relation. Otherwise a caller could regain access through the slot while a child
still holds overlapping exclusive access. Returning a view bounded by the short loan works.

Replacing the slot with another valid mutable reference and returning the old stored value works;
the caller may then use the returned old authority and the replacement independently. This is move
transfer, not an extended borrow of the slot. Its result must not be accidentally re-rooted onto the
already-updated slot, echoing experiment 05's entry-snapshot requirement.

There is a complementary accepted case: a function moves its input reference into a block-local
handle, reborrows the referent and returns it after that handle's block ends. The underlying owner
still lives. Tying every derived view to the *storage lifetime of every intermediate handle* would
be unnecessarily restrictive. A rule must distinguish keeping data alive from restricting a value's
current authority. It may encode that distinction in one internal representation; it cannot ignore it.

### Non-lending mutable iteration transfers disjoint parts

Two IterMut results remain usable after the iterator itself is dropped. The items retain the
underlying source, not its iterator object's storage. A custom next(&mut self) -> &mut Item instead
lends from self and prevents advancing while the first result is still used. That is the expected
Iterator/Lending distinction, not evidence that one interface can express both without a contract.

The remaining iterator state and returned item must own disjoint authority. A primitive can split
the remaining span and update it while transferring one part into the item. Returning such an item
is not the same operation as reborrowing a reference still stored in an aliased carrier. Field paths
admit known-disjoint fields; direct indexed borrows conservatively reject in the tested Rust case.
The split API supplies the disjointness guarantee for indexed storage.

Rust often implicitly reborrows when passing &mut to a function. The split_reborrows probe therefore
must not be called a consuming-parent test. The separate Span::split(self) probe moves a noncopyable
wrapper and tests actual consumption. No matching Grail coercion/receiver convention is assumed.

## What source-root summaries do and do not establish

Under the proposal's collapsed-index summary, both pairs can have the same two qualifiers:

```text
valid:   span(data[0..2]), span(data[2..4])   -> (data, exclusive), (data, exclusive)
invalid: span(data[0..4]), span(data[0..4])   -> (data, exclusive), (data, exclusive)
```

A summary that only sees those pairs cannot establish which construction is valid. That is not an
impossibility result for rooted types. Affinity prevents arbitrary duplication; trusted split
primitives or checked source bodies can ensure that returned view values satisfy their type's
permission invariant. A client may rely on that well-formedness without exporting concrete ranges or
allocating runtime loan nodes. An arbitrary FFI constructor cannot acquire the same guarantee merely
by presenting plausible root metadata.

The ghost model's active permissions require disjoint writes, with shared reads allowed to overlap.
A child temporarily removes parent write rights on its range, and an exclusive child also removes
parent read rights there. The interval checker agrees with a separate finite cell-set implementation
for n ≤ 8. Split assumes a valid, unencumbered mutable input; the Python descriptors do not
enforce affine binding use. This is a comparison of small algebraic rules, **not** inference from source or an
unbounded proof. Parent/child links in this model are supplied, not inferred. It does not choose the
compiler representation of "through this view" or a general borrow-join algorithm.

## Minimal proof obligations before expanding the prototype

1. Define validity of shared/exclusive view values, including their actual permitted storage and
   stable owner, separately from an upper bound on possible source dependencies.
2. State primitive construction/transfer/reborrow rules: no overlap is fabricated, taking moves
   authority, borrowing restricts its source, and consuming splits conserve the input's permission.
3. Define exactly when access is "through" a view or descendant. Parent liveness, partial field
   freezing and authority resumption cannot be inferred from a root set's cardinality.
4. Distinguish returned stored values from borrows of mutable storage. Generic mutable referent
   invariance, current contents and post-state writeback still need their own preservation rules.
5. Give module contracts a meaning that composes lifetime bounds, call modes and well-formed view
   results. The producer/primitive trust boundary from earlier experiments remains in force.
6. Prove a tiny sequential core before including Bundle, effects, async cleanup or native lowering.
   Bounds and analysis budgets must remain explicit. These tests establish no Go-like build speed.

A richer semantic permission model does not require a richer user syntax. Conversely, removing names
such as reborrow or FnMut does not by itself discharge the underlying access obligations.

## Prior-art check, not a new discovery

[Aeneas at de16f3cf](https://github.com/AeneasVerif/aeneas/tree/de16f3cf877976e966906dc890f63dcb418884fa)
represents borrow/loan identities and symbolic abstractions; its join interface explicitly discusses
fresh reborrows, information loss and fixed points. Its README links the ICFP 2022 translation and
ICFP 2024 symbolic borrow-checking formalizations. This was selected source inspection, not a replay
of those proofs or evidence that all present implementation paths are verified. Its structured
avalue children must not be confused with a simplistic universal parent-loan tree.

[Hylo's draft specification at 6f4c6451](https://github.com/hylo-lang/specification/blob/6f4c645101bac80dbb7bd5833cf07c8cbf699bd1/spec.md)
describes last-use binding lifetimes, consuming/reinitializing mutable bindings and projections.
That is relevant precedent for access/value separation, not an executed current-Hylo performance
comparison or a proof about Grail. The earlier former/current compiler distinction still applies.
