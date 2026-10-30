# Argument evaluation, snapshots and call activation

2026-10-30. [Experiment 09](../../research/experiments/calls09/README.md),
[raw results](../../research/evidence/calls09-20261030/checks.json).
A test of hypothetical rules around the proposal's "access begins after arguments are evaluated."
**Not a Grail frontend or a reported bug in the existing experiment 05.**

## A stable named place is not an early snapshot of its contents

Consider the schematic call:

```text
preserve(mut cache, append_and_return_unit(mut cache, view(source_b)))
```

If the language permits the later argument to mutate cache before outer activation, preserve's
entry state is the cache **after** that append. Applying its pre(cache) postcondition to a snapshot
captured when the first argument's place was encountered can forget source_b. A caller may then
incorrectly end that source while retained data still views it.

Replacing the later argument with clear shows the opposite error: an early snapshot retains old
sources even though the actual call enters with an empty container. This can look conservative in
one example but is not a generally sound rule; append introduces previously absent sources.

The model reuses experiment 05's inferred entry-relative preserve contract. The concrete interpreter
instead changes actual list contents. The missing-source witness checks that an invalidation allowed
by the wrong summary leaves a retained reference at an expired owner generation.

A language can instead reserve/freeze the pending place and reject nested mutations. Then the
example is not admitted, and this counterexample does **not** refute that different design. Delayed
activation plus permitting the mutation is the premise that requires the later snapshot.

## A materialized view is already a value with a loan

```text
inspect(view(cache_storage), grow_and_return_unit(mut cache))
```

The first argument's view exists before evaluating the second argument. Deferring parameter accesses
does not justify ignoring that value's storage dependency during evaluation. A storage-invalidating
mutation must be rejected, or another independently sound freshness/ownership rule must prevent the
later use. The tested wrong policy postpones the loan and provides no such substitute.

The model's mutations deliberately increment the backing-storage epoch. It does not claim that every
real append invalidates existing memory. A general API may need conservative root freezing unless a
more precise primitive contract proves stability/disjointness.

There is another boundary even without later argument effects:

```text
clear_then_read(mut cache, view(cache_storage))
```

Copying the view descriptor before activation does not make its referenced storage disjoint from
the mutable argument. A callee is entitled to rely on valid exclusive/shared entry permissions; it
could clear the mutable container before reading its other view. Incoming value dependencies must
participate in activation checks, not just aliases between explicit place arguments.

Experiment 05 permits some Copy take arguments to be snapped before mutation. There the views refer
to **external owners, not the mutated slot's storage**, and container backing-storage views are
excluded. The present counterexample is outside that domain, not a retroactive failure of its rule.

## Finite results and reference behavior

The model enumerates 259 sequences over six effects, length 0..3, in three call forms. Each policy
has 777 comparisons; counts reflect this constructed population, not real-code defect frequency.

| Hypothetical policy | Invalid calls admitted | Calls losing sources | Calls retaining extra sources |
| --- | ---: | ---: | ---: |
| Late entry state; eager materialized-value loans; activation alias check | 0 | 0 | 0 |
| Early state while still permitting later argument mutation | 0 | 114 | 116 |
| Defer materialized-value loan without another freshness check | 152 | 0 | 0 |
| Ignore incoming copied view's loan at activation | 4 | 0 | 0 |

The baseline policy also rejects no valid modeled calls. Source-loss/extra-source counts can overlap
on a call. Repeated no-op sequences are distinct cases; the four alias admissions represent the same
basic bug with 0..3 no-ops. All policies check target availability at activation. A target moved by
an argument is not made usable by having named its place earlier.

Five isolated Rust probes match expected results:
- push(len) compiles/runs using Rust's existing two-phase receiver borrow behavior.
- A nested mutable receiver call rejects (E0499).
- Mutating after materializing a storage view rejects (E0502).
- Mutable/storage-view entry alias rejects (E0502).
- Moving the target while preparing the call rejects (E0505).

A Grail rule accepting the stable-place nested mutation could intentionally be more permissive than
these Rust forms. These probes are a semantic reference, not a translation or proof for that choice.

## Place evaluation still needs a specification

The successful model only names one stable local slot. It does not capture addresses into arrays,
boxes or computed selectors. "Evaluate arguments, then form accesses" does not resolve all of:

- If the address of an indexed/pointee place is computed early, what keeps it valid while later
  arguments mutate, move or replace its container?
- If the implementation retains a root-plus-selector locator and resolves it later, which selector
  values are captured early, when are bounds checked, and which mutations change the final target?
- Are effectful selectors prohibited, sequenced explicitly into temporaries, or supported with
  separate address-stability obligations?
- When do loans from evaluating the callee closure and earlier value arguments begin and end?

For example, changing the timing of a failing bounds check can change whether a later argument's
side effect happens. This is observable evaluation semantics, not merely an optimization detail.
Conservative reservation/rejection, a restricted stable-place grammar, or precisely defined deferred
resolution are possible choices. No alternative is adopted or proved here.

## Candidate elaboration obligations

For the stable-place subset, investigate this order:
1. Evaluate callee/value expressions in specified order, retaining their actual loans and effects.
2. Preserve stable place identities without pretending their data has already been passed.
3. After argument evaluation, check initialization, live value loans and mutual access permissions.
4. Snapshot dependency **state at activation**, instantiate all outputs from that snapshot, call,
   and commit normal post-state changes together.
5. Handle failures/suspension during argument evaluation separately; an unstarted call cannot erase
   effects or cleanup obligations already created by an argument.

The current comparison excludes computed places, failure/suspension, arbitrary aliases, generics of
first-class exclusive views and closure evaluation. It establishes no frontend implementation,
compiler complexity bound, Go-like speed or unbounded safety theorem. The next step is a small
well-specified place/evaluation core, not another surface shorthand or a full compiler.
