# Modern Rust checking baseline

[Findings](../../../docs/design/rust-next-baseline.md). Seven cases × seven configurations,
with separate switch-validation controls and native runs only for known-safe positives.

```sh
# Repo root. Private toolchain installation; does not change the host default.
RUSTUP_HOME="$PWD/research/experiments/rust_next20/.work/rustup" \
  rustup toolchain install nightly-2026-10-29 --profile minimal --no-self-update
python -m research.experiments.rust_next20.check
```

Requires the installed stable toolchain, the pinned private nightly, bubblewrap and Python.
The runner fetches public official documentation/manifest snapshots, retaining their hashes in
`research/evidence/rust-next20-20261030/checks.json` and downloads in ignored `.work`.
It does not install tools itself, switch providers or change the default Rust toolchain.

The existing referents14 cases are reused without modification. `temporary_escape` is required
to reject in every tested configuration and is never executed. The other two referent-state
rejections are safe patterns under a stronger model, not unsafe programs falsely called safe.
No arbitrary accepted negative, trait-unsoundness exploit or compiler-speed comparison is run.
