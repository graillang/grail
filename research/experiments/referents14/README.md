# Mutable referent state

[Findings and exact scope](../../../docs/design/mutable-referent-state.md).

```sh
# Repository root; existing Rust toolchain, Python and bubblewrap.
python -m research.experiments.referents14.check
ruff check research/experiments/referents14
ruff format --check research/experiments/referents14
pyright research/experiments/referents14
rustfmt --edition 2024 --check research/experiments/referents14/*.rs
```

Eleven isolated Rust cases: three compile/run, six reject old-source release with E0505,
and two reject temporary-source lifetime with E0597 (one restores before expiry, one is
actually unsafe without restoration). No rejected program is executed. Compiler version,
commands, diagnostics, source hashes and positive execution status are retained.

`model.py` explores a finite single-cell world under five metadata policies, plus eight
named traces. The concrete world and metadata transfers are separate; they share operation
identities/incoming source meanings, not a type checker. Complete finite-state exploration
is not a general proof. The two precise models rely on one affine handle, blocked parent
access and stable cell identity; these are premises, not inferred source-language facts.

Aeneas source inspection is read-only and selected, with pinned commit/file hashes. No
third-party build, proof replay, accepted-program claim or benchmark is implied. Python
checks the model on the host; Rust compiler/execution uses the existing bounded no-network,
no-home, read-only-toolchain sandbox. There is no mandatory runtime borrow graph here.
