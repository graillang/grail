# Experiment 02: modular origin and capture contracts

2026-10-30. **Positive feasibility evidence for a restricted typed IR—not a settled Grail memory
model, production compiler or soundness proof.**

Sources: [experiment](../../research/experiments/contracts02/README.md),
[semantic scope](../../research/experiments/contracts02/SPEC.md),
[exported contracts](../../research/evidence/contracts02-20261030/contracts.json),
[raw measurements](../../research/evidence/contracts02-20261030/scaling.json),
[stress evidence](../../research/evidence/contracts02-20261030/stress.json).

## Main results

1. The producer infers field-specific view/capture origins from types, access modes and expression
   bodies. No lifetime names or result-origin annotations are supplied. Fourteen fixture functions
   converge in 15 body analyses; their canonical interface occupies
   **3,909 bytes**. This is only a small synthetic fixture, not a realistic package-size result.
2. All **26 isolated clients** match expected acceptance/rejection with provider IR and inference
   code unavailable. An additional provider composes its result from imported contracts without
   imported bodies. The import-interface hash changes when an imported origin contract changes.
3. **21 unit tests** pass. They include recursion, generic forwarding, field sensitivity, access
   conflicts, local escape, callback escape, unsupported operations, budgets, schema errors and
   deterministic serialization. The root-index and naive lookup give the same expected decisions.
4. **200 generated provider cases** check 447
   returned dependency structures against the separate concrete evaluator, with no omitted origins.
   **1,000 generated linear clients** agree with a separate allocation-generation model: zero false
   accepts and zero false rejects in that narrow grammar. These are seeded finite tests, not an
   empirical soundness guarantee for the language or proof for unbounded programs.

## What actually got inferred

Conceptually, without committing Grail syntax:

```text
choose(a,b): result may refer into a or b
pair(a,b): result.short refers into a; result.long refers into b
capture(a): the captured source retains a
identity[T](x): every borrowed component of result preserves the corresponding component of x
parse(source): every leaf text in the constructed tree refers into source
leaves(tree): result views preserve the tree payload's sources, not the temporary tree descriptor
visit(source, callback): callback gets an invocation-scoped item; it cannot retain that item
```

The parser-shaped fixture is manually authored dependency IR, not automatic inference from the
Rust parser in experiment 01. Parsing behavior, bounds, error paths and AST allocation are not modeled.
Types and parameter access conventions remain explicit inputs. The callback rule comes from a
fixed scoped primitive, not discovered higher-rank polymorphism for arbitrary user implementations.

Field-sensitive future uses matter. Ending the short-lived owner while only `pair.long` will be
used is accepted. Using the whole pair later keeps both owners and rejects that end. Flattening
both fields to one union creates a demonstrated false rejection. This supports preserving paths,
not accepting arbitrarily expensive path/branch sensitivity everywhere.

Callback escape is rejected through direct storage, returned values, aggregates, captured-value
records and generic identity forwarding. Capture aliases conflicting with a modifying visit are
also rejected. None of this implements scheduling, async suspension or real closure execution.

## Compactness: common cases succeed, dense cases remain a problem

Opaque generic forwarding uses **216 bytes** for the function contract whether
instantiated on 16 or 1,024 borrowed fields. Applying it still traverses the actual borrowed shape:
compact export is not constant-time processing of an arbitrarily large argument type.

For 128 output fields and 128 possible input sources:

| Dependency pattern | Relations | Distinct source sets | Interned function bytes | Uninterned function bytes |
| --- | ---: | ---: | ---: | ---: |
| shared | 16,384 | 1 | 15,141 | 733,091 |
| distinct | 16,256 | 128 | 727,441 | 727,441 |

Shared means every field can depend on the same source set. Distinct means each field depends on
all inputs except a different one. Interning helps the first case substantially and not the second.
The dense fixture's input IR is also large (about 400 KB); these measurements are not a lower bound
showing that small source must create huge summaries. Richer symbolic set encodings may compress
this pattern too. **What failed is the assumption that set interning alone guarantees compact
summaries.** Budgets, abstraction boundaries and conservative widening still need a policy.

## Analysis cost versus implementation cost

A reverse-ordered chain of 1,024 forwarding functions takes 2047 analyses, not a full
module sweep for every link, using a dependency worklist. The warm Python median is approximately
30.2 ms, with input/serialization/schema checks included. This is not a Grail compilation
benchmark, a native checker implementation, or Go build-speed evidence.

For 1,024 independent owners and 4,096 client steps, the naive lookup median is
287.0 ms versus
16.1 ms with a root-indexed query. Both run the same
semantics; unit and generated-client tests compare their decisions. An inefficient data structure
must not be mistaken for a fundamental inference barrier. The index can still scan many entries
when many views share one root; no universal linear-time client analysis claim follows.

Five observations after warmup, in one Python process on a shared host, with raw samples retained.
No stable-frequency or exclusive-CPU control. These timings motivate algorithm choices, not product
performance promises. The explicit record/type/relationship sizes explain the workload better than
LOC/s or a single aggregate throughput number.

## Critical trust boundary demonstrated—not solved

A contract claiming `pick(a,b)` returns a view into a can be structurally valid even if the provider
actually returns b. The deliberately forged artifact is accepted by the client decoder/checker; a
client can then incorrectly be permitted to end b. The separate concrete evaluator detects this
particular mismatch. The test passes by **exposing that trust assumption**, not by certifying a
forged artifact safe.

Source/import digests identify dependencies; they are not proof of semantic honesty, signatures,
or a trusted certification chain. The current inference implementation and export artifact are in
the TCB, like ordinary compiler type exports. Grail must never treat arbitrary AI-authored or
package-supplied interface metadata as independently proved. A checkable certificate or separately
validated producer/translation is future work. There is no mathematical verification badge here.

## Limitations and revised recommendation

This experiment is deliberately read-view-oriented. It does not handle owned-value moves, exclusive
view returns, general loops/branches in clients, heap aliasing, self-reference, node allocation/drop,
arbitrary higher-order functions, real effects/capabilities, FFI or async cancellation. Recursive
source enumeration has an explicit fuel bound; truncated/zero-result tests are not silently counted
as exhaustive checks. Generated provider stress cases are acyclic; the separate recursive fixture
has reported bounded unfolding, not a termination proof.

The result supports pursuing modular inference **without choosing permanent ownership syntax or
promising Rust's full expressive envelope**. The next design boundary is general mutation and
escaping mutable state: which view-carrying aggregates/closures remain easy to summarize, and which
need explicit access/region contracts? Before expanding the checker, write the small formal
preservation statement for the existing fragment and then test a small control-flow/mutation
extension against the same adversarial discipline. Do not respond by building the full compiler.
