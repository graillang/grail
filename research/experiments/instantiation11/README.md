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

The runner snapshots the two Lean sources into owned `.work/inputs`, mounts them read-only,
freshly compiles `Core.olean`, then checks `Instantiation.lean` against that output. It stops
on a failed core compile rather than using an older output. Both commands run without network
or home access. It records both source hashes, compiler/runner hashes, command outputs and
13 target axiom reports. Only standard `propext` and `Quot.sound` are allowed; proof holes,
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
axioms, admitted proofs or classical-choice dependencies in the reported targets.
