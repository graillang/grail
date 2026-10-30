# Dependency state-transformer results

2026-10-30. A bounded extension of the shared-view research IR, **not a Grail compiler or adopted
memory model**. [Specification and proof obligation](../../research/experiments/transforms05/SPEC.md),
[runner](../../research/experiments/transforms05/run_experiment.py),
[raw evidence](../../research/evidence/transforms05-20261030/).

## Question

Can a separately checked generic function describe clearing/replacing borrowed data without either
retaining every old source forever or accidentally dropping a returned old value's dependency?
This tests the mutation gap in the [rooted-value review](rooted-values-review.md), not a new syntax.

The experiment separates **base shape** from **per-value dependency state**. Two values can have the
same base T and different dependency sets. A generic T is restricted to view-data: unit, shared views,
records and lists thereof. It excludes owning byte buffers, exclusive references, callbacks, arbitrary
destructors and pending operations. Parameter access/move modes are supplied in the typed IR, not
inferred from ordinary source syntax.

## Contract rule tested

Each result or mutable post-state position contains a union of `pre(argument,path)` sources. An
opaque prefix route forwards the actual descendant positions of T. Every mutable parameter has an
explicit post-state: no missing clause means either "preserve" or "empty".

| Operation | Returned dependencies | Stored post-state dependencies |
| --- | --- | --- |
| append(cache, x) | none | pre(cache) ∪ pre(x) |
| clear(cache) | none | empty |
| replace(cache, incoming) | pre(cache) | pre(incoming) |
| take_all(cache) | pre(cache) | empty |
| swap(a, b) | none | a = pre(b), b = pre(a) |
| maybe_clear(cache) | none | pre(cache), conservatively |
| clear_then_append(cache, x) | none | pre(x), not pre(cache) |

These are schematic whole-value summaries; the actual artifacts retain record/payload positions.
Both result and post-state are instantiated using **one entry snapshot**. Resolving the return after
updating cache would mistakenly make an old returned value depend on the new contents. Sequentially
resolving swap against updated actuals would similarly lose one side's old state.

Only exact, disjoint storage places can be strongly updated. Separate record fields qualify;
overlapping mutable/read or mutable/move accesses do not. Taking a concrete Copy view is different:
its descriptor is snapped before mutable access and points into an external owner, not into the
mutated slot. Taking a noncopyable container consumes its caller binding. No container element-slot
references or backing-storage borrows are present. These restrictions are essential, not incidental.

## Executed evidence

- **19 focused tests** protect source erasure, old returns, snapshots, generic field forwarding,
  safe public-bound widening, conditional moves, caller alias rejection and ownership transfer.
- **11 hand-written providers plus 200 generated acyclic providers**, seed 20261030.
- **1,527 concrete executions; 3,054 returned/post-state values checked**, with no missing-dependency
  counterexample found. Generic fixtures instantiate six ground shapes and list sizes 0, 1 and 2.
  Generated providers use fixed view payloads, up to ten generated top-level steps, and at most two
  generated branch sites. This is a finite test population, not all typed programs.
- The independently written concrete interpreter manipulates sequence/record contents rather than
  applying inferred transformers. It shares the base type representation/unifier, so it is not an
  independently implemented type system. Branches enumerate all finite choice bits for each case;
  unions deliberately lose correlations.
- **10/10 body-hidden client decisions matched**; the same ten traces have eleven concrete executions
  because maybe_clear has two choices. Clients use explicit drops of dead bindings, not general
  liveness inference. Concrete validity is checked at call/use boundaries.
- Bubblewrap exposes only the artifact, client traces and five consumer/type implementation files:
  no provider IR, inference implementation or concrete oracle. The mounted inventory is checked.

The reuse trace clears the cache, expires the old source generation, creates fresh views from the
renewed generation of the same source binding, appends and uses the cache. It is accepted. Append
without clearing retains the old source. Replacement allows releasing the old source after dropping
the returned old value, but rejects release while that value remains live. Clearing only the left
field releases its old source while retaining the right field's dependency.

## Public bounds and trust

The comparison checks a sufficient refinement condition: each inferred result/post source set must
be a subset of the corresponding public upper bound, with the same shapes and modes. Clear(empty)
refines a conservative preserve(old) bound; preserve(old) does not refine a promised empty bound.
The conservative bound is safe but may falsely retain old sources. No principal-contract theorem or
complete semantic subtyping algorithm follows.

A direct clear and a take-all-then-drop implementation have different body hashes and the same
memory-contract hash. This is a demonstration of stable **dependency interfaces**, not permission to
reuse value-correctness proofs, optimized caller code or arbitrary compiler caches across body changes.

A schema-valid artifact claiming a no-op has clear's empty post-state fools the body-hidden client.
The concrete trace then exposes an expired retained view. The producer-side refinement check rejects
that body against the promised bound, assuming the producer is honest/correct. Serialization checks,
hashes and passing examples do not remove the producer/artifact from the TCB.

## Validation and remaining obligations

Ruff, formatting, project Pyright and unit/integration experiments pass. The initial installed Borg
LSP check incorrectly reported missing project imports: a controlled protocol probe found that it
omitted workspaceFolders and Pyright 1.1.412 selected a nonexistent default root. The harness fix was
committed/pushed separately as
[3e320675](https://github.com/borg-ml/agent/commit/3e320675), with 33 focused LSP tests passing.
The already-running Borg process was not hot-replaced. Its earlier false-import/partial-workspace
reports are retained as diagnostic evidence, not presented as clean project validation. A final
direct Pyright LSP run with the corrected workspace-folder initialization checks all nine source
files with zero diagnostics; its source hashes and protocol settings are retained.

The specification states a restricted preservation obligation and an induction outline; there is
**no completed formal proof**. Strong updates through heap aliases, first-class exclusive views,
loans into container storage, self-reference/Bundle projection, loops, failure post-states, general
resource destruction and cancellation acknowledgment remain outside this experiment. Qualified
mutable-reference variance has not disappeared merely because the prototype separates base types
from dependency state.

No allocation reuse, native compilation latency, machine-code safety or runtime performance was
measured. The eleven fixture contracts are 139–325 compact JSON bytes each; the full 211-contract
module is 53,544 compact bytes. These are representation observations for this population, not
metadata-size or fast-build guarantees.

**Recommendation:** retain explicit pre/post state transformers as a candidate interface mechanism.
Next test error exits and cleanup ownership, then connect call access, escaping authority and Bundle
projection to the same preservation statement. Do not adopt the full architecture on these results.
