# Bundle projection and ownership probes

These distinguish real accessor/variance/lifetime contracts, not keyword choices or an implemented
Grail Bundle. Failure modes: moving an owning AST from shared access; duplicating exclusive access;
shortening an invariant container; installing an outside short borrow; freeing a bundle before a
returned view; confusing a borrowed owner with fully owned data; dropping owner before dependent.
Compiler probes and running the accepted cases are the appropriate guards here, not Python tests of
expected strings or a new compiler implementation.

```sh
python -m research.experiments.bundle07.check
ruff check research/experiments/bundle07
pyright --project research/experiments/bundle07
```

Requires Linux/bubblewrap, installed Rust, and exactly one already-cached copy of each:
self_cell 1.3.0, yoke 0.8.3, stable_deref_trait 1.2.1. No packages are installed or fetched.
The runner verifies archive SHA-256 values matching the existing dependency lock, and verifies every
cached Rust source file against its archive contents. This is provenance, not a soundness certificate.

Libraries compile directly with rustc, without Cargo/build scripts/procedural macros. self_cell has
no optional features enabled; yoke and stable_deref_trait enable alloc only. Each library source
mount is read-only. The probes compile/run without network or home access; only the selected Rust
toolchain, experiment sources and writable ignored `.work` are exposed.

Eighteen expected results: nine compile and run, nine are rejected. Uncoded lifetime diagnostics are
matched by semantic message families, not filenames; other rejections require the expected error
code. A missing dependency or tool failure does not count as an expected lifetime rejection.

The noncovariant callback can return a covariant shared str projection. It cannot return a shortened
reference to the entire invariant Cell. Both behaviors matter; do not interpret the failing container
escape as a ban on all reference returns.

[Design assessment](../../../docs/design/bundle-boundary.md) and raw evidence under
`research/evidence/bundle07-20261030`. There is no crate safety audit, Miri run, allocation count,
performance benchmark or proof of a hypothetical Grail implementation.
