# Symbolic summary application and the entry snapshot

2026-10-30. [Model](../../research/experiments/instantiation11/Instantiation.lean),
[runner/reproduction](../../research/experiments/instantiation11/README.md),
[evidence](../../research/evidence/instantiation11-20261030/).
This proves another boundary of the [restricted core](preservation-core.md), not of a full Grail
frontend, memory model or serialized artifact implementation.

## Question

Can a producer analyze symbolic pre-sources once, then a caller substitute its current root sets
without needing to analyze the body again? Do replacement, swap and branch joins retain the same
meaning when several symbolic sources map to the same root or to no roots?

For this pure grammar the answer is yes, with one immutable entry substitution. This is a standard
set-substitution/abstract-analysis result, not a claimed novel analysis or universal compilation
performance result.

## Mathematical contract

A substitution σ maps each symbolic source to a root predicate. Instantiating q means a caller root
r occurs if some symbolic source s occurs in q and σ(s) contains r. The mapping need not be injective,
and its images may be empty or overlap arbitrarily. Instantiation preserves empty support, unions,
slot writes and branch joins.

Induction over the complete command grammar proves:

`instantiateState(σ, analyze(symbolicInputs, program, symbolicEntry))`

`= analyze(instantiateInputs(σ, symbolicInputs), program, instantiateState(σ, symbolicEntry))`.

There is one σ for the entire tuple of mutable post-states and saved result. It does not change
between resolving output positions. The theorem quantifies arbitrary substitutions, payloads,
finite program sizes and branch choices; it is not a finite sample of aliases or programs.

The canonical symbolic entry gives each slot, input and initial saved register its own pre-source
singleton. A producer's `summary(program)` analyzes these seeds. The caller's `snapshot` maps each
pre-source to the corresponding entry bound. Instantiating the seeds recovers the caller's entry
state and input bounds, so instantiating the precomputed summary equals direct abstract analysis.

The saved-register source models existing tracked data across commands. A source-language function
return convention might initialize it empty or use different bindings; this does not introduce a
hidden language parameter or prove that lowering.

## Coverage and public bounds

`imported_summary` combines substitution commutation with core10 preservation: covered concrete
inputs, a related entry state and a concrete execution imply the post-state is covered by the
instantiated summary. `instantiate_below` shows widening survives substitution, so `imported_public`
also accepts a checked wider symbolic public bound.

Root-source overlap is intentionally allowed. Two shared payloads can require the same owner;
union is idempotent and does not count loans. That fact does **not** permit overlapping mutable
places, duplicate exclusive capabilities or early release of one of several pending operations.
Those remain separate authority/operation-identity obligations. The concrete state is still made
of independent mathematical slots, not an arbitrary aliased heap.

A producer still needs the correct body-to-summary relation and checked public inclusion. A caller
still needs truthful current inputs/entry bounds. The theorem does not infer them from a signature,
prove a JSON decoder or authenticate a module. The logical model has a program parameter and
execution premise; the runner's separate Lean compilation is not a body-hidden Grail build pipeline.

## Why the entry snapshot matters

The checked counterexample starts with slot 0 requiring source 0 and slot 1 requiring source 1.
Resolving `pre(slot 0)` at entry contains source 0. After writing slot 1's support into slot 0,
re-reading that same pre-source no longer contains source 0. A swap's other output or returned old
value would lose a dependency if output resolution mutated the substitution this way.

This is consistent with the [call-activation study](call-activation-boundary.md): if later argument
effects may mutate the target, the snapshot for mutable entry state must cover the state at actual
activation, not merely the state at first place encounter. A stale bound that misses newly appended
data fails the coverage premise; this theorem does not make the caller check that premise correctly.
Materialized value loans, moved targets, selector effects and backing-storage validity are still
outside this grammar. No general delayed-borrow or source evaluation-order rule follows.

## Checked evidence and trust

The runner reuses the pinned Lean 4.35.0 toolchain and no-network/home sandbox. It copies immutable
input snapshots, freshly compiles the unchanged core, and only then imports that output. Reports
retain both source hashes, exact commands, outputs, compiler version/hash, runner hash and all
13 target axiom dependencies (seven existing plus six new).

The new equality, application and snapshot-counterexample proofs use only standard `propext` and
`Quot.sound`; function extensionality is derived from quotient soundness in this Lean foundation.
The substitution-widening proof has no axiom dependencies. There are no introduced domain axioms,
proof holes or classical-choice dependencies in these targets. This is not an audit of Lean, its
standard library, compiler, host or kernel, and local coverage assumptions remain assumptions.

Ruff, format, CLI Pyright and correct-workspace direct Pyright LSP check the Python runner. Old
running Borg diagnostics remain subject to the two already-fixed source issues described in the
[core checkpoint](preservation-core.md); partial/false-import reports are retained, not called clean.

## Remaining discriminating boundary

This establishes source-set substitution for a flat pure-data grammar. It does not prove structured
field/payload routes, opaque generic-T forwarding, strong-update disjointness, first-class mutable
referent state, loops, liveness inference, errors, cleanup or native lowering. In particular, no
proof connects this substitution function to transforms05's actual instantiation/serialization code.

The next useful question is the structured/opaque-T boundary, not more finite root aliases in this
already universally quantified theorem. Keep interface size/precision, authority preservation and
artifact provenance as distinct open gates; ordinary compilation need not invoke Lean or an SMT solver.
