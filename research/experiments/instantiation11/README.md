# Symbolic pre-source instantiation

This extends the [pure core10 model](../core10/README.md), without modifying it.
[Results and limits](../../../docs/design/symbolic-instantiation.md).

```sh
# Repository root; Linux x86-64, Python 3.14+ and bubblewrap.
python -m research.experiments.core10.check --fetch   # once; shared pinned toolchain
python -m research.experiments.instantiation11.check --output /tmp/instantiation11.json
ruff check research/experiments/instantiation11/check.py
ruff format --check research/experiments/instantiation11/check.py
pyright research/experiments/instantiation11/check.py
```

Alternatively `instantiation11.check --fetch` obtains the same official pinned toolchain in
core10's ignored cache, not a second installation. No global Lean/Lake/Mathlib installation.

The runner snapshots the six Lean sources into owned `.work/inputs`, mounts them read-only,
freshly compiles Core, Instantiation, Routes, Shapes and Coverage, then checks `Refinement.lean`. It stops
on any failed import compile rather than using an older output. All six commands run without
network or home access. It records all six source hashes, compiler/runner hashes, outputs and
38 target axiom reports. Standard `propext`/`Quot.sound` are allowed; only two Coverage counting targets may also use
`Classical.choice`. Proof holes,
missing reports and the known kernel-check bypass setting fail the accidental-hole audit.
This is not a hostile-source certificate validator or an independent compiler/kernel audit.

## New checked targets

- `instantiate_analyze`: substituting symbolic sources with root sets commutes with every core
  command, arbitrary finite sequences and nondeterministic branches.
- `instantiate_below`: a wider symbolic public bound remains wider after substitution.
- `summary_application`: pre-source singleton seeds and one caller entry snapshot recover the
  same abstract result as analyzing directly on that caller state.
- `imported_summary`: combine that equality with core10's concrete coverage theorem.
- `imported_public`: combine it with a checked symbolic public upper bound.
- `changed_snapshot_loses_source`: a closed counterexample to resolving a pre-source again
  after overwriting its slot.

Source mappings may be overlapping, many-to-one or empty sets. This concerns dependency
support, not physical place aliasing or exclusive authority. Preconditions still require
covered concrete inputs and a related entry state. The saved-register pre-source is part
of the mathematical state, not a proposed hidden source-language parameter.

Function extensionality in the new equality proofs uses Lean's standard quotient-soundness
axiom (`Quot.sound`), alongside propositional extensionality. There are no introduced domain
axioms, admitted proofs or classical-choice dependencies in this initial symbolic target group.

## Structured-route extension

[Routes.lean](Routes.lean) adds eight targets for exact suffix forwarding, its slicing
implementation, root substitution, supported dependency positions and subtree replacement.
See [results and remaining typing premises](../../../docs/design/structured-routes.md).
The earlier 13-target evidence records the initial two-module version; that checkpoint includes
three modules and 21 targets. All compiled imports are rebuilt before the final check.

## Dependency-shape extension

[Shapes.lean](Shapes.lean) adds seven targets connecting successful formal path projections
and same-T descendants to substitution, plus checked counterexamples to stronger claims.
See [scope and representation premises](../../../docs/design/shape-substitution.md).
That checkpoint checks four modules and 28 targets; the current coverage extension is below.

## Target-coverage extension

[Coverage.lean](Coverage.lean) adds six conditional target-list/post-bound statements and
counterexamples. [Transfer results](../../../docs/design/target-coverage.md) explain why these
are not lifetime-support or general mutable-reference theorems. That checkpoint is five modules
and 34 targets; the earlier 13/21/28-target reports remain historical.

## Refinement extension

[Refinement.lean](Refinement.lean) adds four no-axiom interval-domain targets for may/must
contract implication. [Refinement results](../../../docs/design/contract-refinement.md) delimit
its completeness and toy cache experiment. Current checks are six modules and 38 target reports.
