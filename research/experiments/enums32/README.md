# Tagged ownership and postfix unwrap

Run `python research/experiments/enums32/check.py`. Requires stable Rust, clang, the existing private
nightly-2026-10-29 toolchain, and memory01's configured TinyCC tree. Host Rust selection is unchanged.
Generated binaries/targets stay under ignored `.work`. Stable/nightly execute the accepted Rust
reference and compile-only reject the two lifetime controls; negative controls are never executed.

Native tests use hidden producer sources and selected immutable objects, allocator wrappers, nested
sums, both mixed ABI directions, stale-variant-layout rejection and preserved old executables. Result
failure aborts; matching recovers errors. A decimal parser handles boundary values and differentially
checks a deterministic 32-value corpus plus invalid suffixes against the Rust standard parser.

Cost columns: variant count, source bytes, C bytes, release-seed check seconds, C lowering seconds.
The harness is synthetic, not a completed compiler workload. Current source is hashed in checks.json.
To compare before-lowering behavior in an isolated worktree, reverse-apply the retained optimization
patch with `git apply --reverse --unidiff-zero`, rebuild and rerun the harness. Do not modify a dirty
working tree to replay it. Historical wall-time samples are observations, not guaranteed bounds.
