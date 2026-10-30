# May bounds, must guarantees and interface invalidation

2026-10-30. [Experiment](../../research/experiments/refinement17/README.md),
[logic](../../research/experiments/instantiation11/Refinement.lean),
[evidence](../../research/evidence/refinement17-20261030/).
A small interval-domain result, not a compiler ABI, full function-subtyping algorithm or cache fix.

## Why this follows target coverage

The [transfer study](target-coverage.md) needs a target-coverage fact before precise collective
writeback. Root/lifetime upper bounds alone do not supply it. If a compiler exposes such guarantees,
its refinement and cache dependencies must preserve their meaning rather than applying a uniform
subset rule to every new metadata field.

The existing shared-data `Contract.refines` checks upper source bounds in its restricted fragment;
this does **not** demonstrate a bug there. The external proposal also discusses backward transfer.
This note specifies one factored semantic boundary a richer interface might use, not required new
user annotations or a claim that every contract must literally store two sets.

## The chosen abstraction

A normal-return footprint F satisfies an interval C when:

`C.must ⊆ F ⊆ C.may`.

The endpoints are target facts, not interchangeable with lifetime roots. The model fixes all other
interface structure. It does not model input preconditions, modes, source types, pointer validity,
resource multiplicity, per-result correlations, destructor effects, errors or ambient scope work.

An implementation interval refines a declared interval when:

| Component | Required containment |
| --- | --- |
| Possible footprint targets | implementation.may ⊆ declared.may |
| Guaranteed footprint targets | declared.must ⊆ implementation.must |

Strengthening guarantees and narrowing possibilities both reduce allowed behaviors. Widening a
published contract by adding possibilities or removing guarantees can break callers relying on the
old information. Merely changing an implementation while still proving the same public contract
need not change a coverage-dependent consumer check.

Consistency is `must ⊆ may`. The toy constructor rejects inconsistent normal-return intervals.
This is not a rule that diverging functions or specifications with no normal outcome are universally
invalid: those cases need a bottom/no-normal-return account outside this chosen inhabited domain.

## Checked law and finite controls

Four new Lean targets show:

1. A consistent interval models its lower and upper endpoints.
2. The structural refinement criterion preserves every modeled footprint.
3. Conversely, semantic implication entails that criterion for a consistent implementation interval.
4. Therefore structural refinement is equivalent to implication over **all footprint predicates**
   in this abstraction, not just the tested finite universes.

All four report no axiom dependencies. The previous audit allowances are unchanged; the shared runner
now checks six modules and 38 target reports. The theorem is not completeness of a real source type
checker. Restricting the behavior family with cardinality, ownership or other type facts can derive
more information than raw endpoints; the conditional coverage lemma is one such example.

The Python model independently enumerates interval behaviors and compares semantic implication with
the structural check. For universes of sizes 1..4:

| Targets | Consistent intervals | Interval pairs | Semantic mismatches | Bad may-only acceptances |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 3 | 9 | 0 | 2 |
| 2 | 9 | 81 | 0 | 24 |
| 3 | 27 | 729 | 0 | 218 |
| 4 | 81 | 6,561 | 0 | 1,776 |

There are 7,380 pairs and 2,020 bad may-only acceptances. Thirty-seven inconsistent endpoint pairs
are rejected at universe size 3. These are exhaustive finite domain checks, not source programs.
The Python implementation, serialization and proof correspondence are not themselves certified.

## Concrete toy cache failure

Both public versions have may set `{0,1,2}` and the same modeled lifetime context. Initially the
must set is `{0,1}`; later it is weakened to `{0}`. Footprint `{0,1}` satisfies the strong contract,
and `{0,2}` satisfies the weak one but not the strong one. This matches the essential transfer
choice without claiming to encode the entire Rust signature/authority state.

A caller check requiring coverage `{0,1}` succeeds under the old declaration and fails freshly under
the new one. A deliberately bad key hashing only may data is unchanged, so the in-memory cache
reuses True. A key including both endpoints changes. This is a semantic collision caused by omitted
information, not a SHA-256 cryptographic collision or a production compiler implementation.

A body changed to `{0,2}` while retaining the old strong declaration instead needs rejection at the
producer's contract verification boundary. Hashing a lying declaration more completely cannot make
it honest. The earlier forged-artifact trust gap remains separate from invalidating a truthful
changed interface.

## Implications, not an adopted format

- If coverage is inferred from existing provenance/type/count facts, depend on those checked facts;
  a separate must field or user annotation may be unnecessary. Complete relational contracts can
  express implication without this particular interval factorization.
- Analysis-budget widening may lose guarantees. Do not preserve a caller acceptance based on facts
  the new public interface no longer supplies, or label an unproved stronger declaration verified.
- A semantic-memory fingerprint must include all relevant stable facts or their derivation
  dependencies. This model normalizes only finite set ordering, not arbitrary alpha-renaming,
  logical equivalence or a full target/type schema.
- Equal aggregate footprint contracts do not preserve result order, arbitrary value behavior,
  destructor semantics, imported proof evidence or optimized/inlined code. Those have their own
  contracts/body/ABI dependencies. No build-speed or proof-maintenance performance claim follows.
- Set footprints omit multiplicity and matching loan frames. This law does not prove no duplication,
  correct mutable writeback, source projection, scope acknowledgment or machine erasure.

The transfer checker now reads the actual shared-corpus count rather than printing its earlier fixed
34. Its regression was run against the 38-target corpus in owned scratch, leaving historical reports
unchanged. Remaining work is the compositional ownership/state judgment and practical inference,
not adding more finite aliases to this already quantified interval theorem.
