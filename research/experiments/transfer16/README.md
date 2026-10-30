# Target transfer and coverage

[Findings and exact limits](../../../docs/design/target-coverage.md).

```sh
# Repository root; existing Rust/Python/bubblewrap and core10's pinned Lean cache.
python -m research.experiments.core10.check --fetch  # once, if needed
python -m research.experiments.transfer16.check
ruff check research/experiments/transfer16 research/experiments/instantiation11/check.py
ruff format --check research/experiments/transfer16 research/experiments/instantiation11/check.py
pyright research/experiments/transfer16 research/experiments/instantiation11/check.py
rustfmt --edition 2024 --check research/experiments/transfer16/*.rs
```

Five Rust cases: three compile/run, two reject E0499 and never execute. Fresh-target replacement
uses explicit allocation/leak under the same Rust signature as permutation; no Grail leak policy
is adopted. `model.py` enumerates 2,140 injective target/write cases for each of four post-bound
rules. The checked-cover rule assumes a truthful producer fact; no source certificate is produced.

The checker also invokes the existing Lean runner, now five modules/34 audited targets, and retains
its report. Six new Coverage targets prove conditional finite-list target coverage, mathematical
uniform post-bound update and closed counterexamples. Only its two counting-based targets may use
standard classical choice; previous audit limits are unchanged. No domain axioms or proof holes.
The theorem does not establish real pointer validity, authority, destructors or compiler correctness.
