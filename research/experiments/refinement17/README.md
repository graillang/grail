# Contract polarity and toy cache dependencies

[Findings and exact scope](../../../docs/design/contract-refinement.md).

```sh
# Repository root; existing Python/bubblewrap and the pinned core10 Lean cache.
python -m research.experiments.refinement17.check
ruff check research/experiments/refinement17 research/experiments/instantiation11/check.py research/experiments/transfer16/check.py
ruff format --check research/experiments/refinement17 research/experiments/instantiation11/check.py research/experiments/transfer16/check.py
pyright research/experiments/refinement17 research/experiments/instantiation11/check.py research/experiments/transfer16/check.py
```

The model covers every consistent may/must interval and footprint behavior for target universes
1..4 (7,380 interval pairs). It tests a deliberately incomplete may-only comparator and toy
in-memory cache against the full interval semantics. Neither is a compiler implementation.

Four new logical Lean statements prove soundness/completeness in this interval abstraction,
with no axiom dependencies. The shared runner checks six modules and 38 targets. It retains
per-target allowances: only the existing two Coverage counting targets may use classical choice.

A full type/effect/ownership contract is not just this interval. Modes and preconditions,
multiplicity, per-output target relation, source/body authentication, error/cleanup behavior and
ABI/code/value-proof dependencies remain outside this model. No production cache is fixed.
