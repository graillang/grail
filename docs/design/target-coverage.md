# Lifetime support versus target coverage

2026-10-30. [Experiment](../../research/experiments/transfer16/README.md),
[coverage lemmas](../../research/experiments/instantiation11/Coverage.lean),
[evidence](../../research/evidence/transfer16-20261030/).
A conditional transfer result, not a Grail mutable-reference checker or general resource theorem.

## The particular precision claim

If a caller updates every returned unique handle, may it conclude that every original input target
was updated? Not from arity/uniqueness and lifetime validity alone. It needs a target-transfer fact.
This matters for writing back current referent dependency state, not just keeping handle storage live.

The external proposal already names Aeneas-style forward/backward pairs for returned mutable
references and excludes stored exclusive references from its initial functional-proof subset.
This study isolates one obligation such an account must satisfy; it does not claim the proposal
lacks root paths or that the shared-data Python prototype incorrectly implements unique references.
That prototype explicitly excludes them.

## Same Rust type signature, different effects

Two safe helpers have the same type:

`route<'a, T: Default>(&'a mut T, &'a mut T, bool) -> (&'a mut T, &'a mut T)`

One only permutes its inputs. The other returns the left input and a fresh `Box::leak` target,
possibly permuted, leaving the right input unchanged. With integer targets, writing 9 through both
results produces `(9, 9)` in the first case and `(9, 2)` in the second. Both branches compile/run.
A partial-write control changes only one original target. Aliased inputs and duplicated returned
access each reject with E0499. Three positives execute; two negatives are compiler-only.

The fresh allocation/leak is explicit. This does not recommend safe leak or mandatory allocation
for Grail. It shows the claim needs additional restrictions when fresh/foreign targets are possible.
A closed move-only API may supply them. The lifetime parameter establishes validity, not equality
of the returned targets to the original target set. No native source-release or performance claim
follows; the changing borrowed-data boundary remains the one studied in referents14.

A Grail contract could distinguish these helpers using exact target provenance, ownership/frame
transfer or backward-state information. The claim is **not** that they share every possible Grail
contract. In particular, a qualifier defined as exact address/target origin is stronger than the
lifetime-support projection tested here. Existing root paths could carry useful facts if their
semantics and checking rules establish them; no extra public lifetime slots are proved necessary.

## Finite loss-of-information experiment

For n = 1..4, enumerate every injective n-handle output mapping into n original logical targets
plus one fresh target, and every subset of handles written to a uniform new dependency. All mappings
already satisfy output uniqueness. The output-to-target mapping is hidden from the modeled caller.
We inspect only original caller cells after returned accesses end; fresh leaked storage is not a
live caller-owned cell. Other live bindings/pending work are outside the model.

Every original cell starts with its own old-source dependency. The incoming view's dependency is
`new`. Lifetime upper alternatives are deliberately coarse; they do not identify exact targets.
The scalar support illustration maps original targets to a common owner root and the fresh target
to no external lifetime requirement. The aggregate supports can be identical while target sets differ.
This is one lossy projection, not a claim that all qualifier designs erase exact provenance.

| Candidate post-bound rule | Cases missing dependencies | Missing edges | Extra edges |
| --- | ---: | ---: | ---: |
| Strongly update every may-target after any write | 1,955 | 4,437 | 4,437 |
| Weakly union old/new at every may-target | 0 | 0 | 7,742 |
| Strong update all originals once all n outputs were written | 119 | 119 | 7,295 |
| Same final update only with a truthful exact-cover fact; otherwise weak | 0 | 0 | 7,623 |

There are 2,140 cases per rule, 8,560 rule comparisons; 442 cases have a permutation/cover witness.
Extra edges measure imprecision against each concrete mapping, not an unsoundness count or a claim
that hidden-mapping source programs must be accepted. Weak update remains a valid conservative choice.
The model also records a missing-edge witness with no fresh targets for premature strong may-update.

The toy producer computes the cover fact from its primitive mapping. The consumer does not read the
mapping, but trusts that fact. No actual Rust/Grail source-to-certificate checker is implemented;
a forged fact reintroduces the problem. This is the same implementation/provenance boundary as the
earlier dishonest-artifact experiments, not a new independent certification pipeline.

## Six kernel-checked targets

`no_fresh_cover` proves for arbitrary finite lists of logical Nat target IDs:

- every output target is an original target (no outside targets);
- outputs have no duplicates;
- output and original lists have equal lengths;
- therefore every original target occurs among the outputs.

This is target identity, not raw numeric pointer equality: disjoint logical places, including
zero-sized cases, require an appropriate embedding. No-allocation alone is not the first premise;
a foreign existing target could violate it too.

`overwrite_member` proves a uniform mathematical post-bound update reaches every listed target.
`complete_transfer` combines the two statements. It does not authorize copying arbitrary T,
execute destructors or prove physical writes/liveness. Those are separate primitive/typing premises.
Two closed counterexamples show why arity without membership, or membership without uniqueness, is
insufficient. A sixth theorem equates the illustrated lifetime unions despite different coverage.

The two counting-based targets use standard `propext`, `Quot.sound` and `Classical.choice` through
Lean's finite-list cardinality lemma. The audit allows choice **only** for these two targets;
the previous 28 retain their earlier limits. Other new targets use the recorded standard axioms,
not introduced domain axioms or admitted proofs. The runner now checks five modules and 34 targets.
Historical reports are not rewritten. This is an unbounded list-level conditional theorem, not a
proof of arbitrary source programs, type inference or ABI erasure.

## What to carry forward

For a closed move-only primitive, distinctness + no outside targets + cardinality can be a derived
fact rather than a user annotation. Split/partition primitives may instead provide region-coverage
facts; their domain is richer than this list of cells. Opaque T can contain many resources, so
counting T values is not automatically counting target resources.

If a call exposes only lifetime upper bounds, keep conservative state rather than invent exact
coverage. If precise collective writeback/release is promised, identify the checked transfer fact
that justifies it. A type-constructor invariant, exact target qualifier or backward summary may
supply it; the experiment does not mandate one representation or a runtime graph.

The remaining task is composition: mutable target state, affine ownership/frame handoff, destructor
effects, scope-owned work and control-flow joins must agree under a practical inferred interface.
Root support, allowed shape and conditional coverage lemmas are useful pieces, not the missing full
well-formedness/erasure proof. The architecture remains provisional.
