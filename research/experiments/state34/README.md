# Checker state falsification and cost replay

Run `python research/experiments/state34/check.py` with the existing stable Rust, private pinned
nightly, clang and configured memory01 TinyCC. Host defaults remain unchanged. The runner extracts
only seed source/Cargo manifests from the pinned baseline revision into a fresh ignored directory,
builds before/after probes, and compares acceptance and output hashes. It never executes generated
raw programs: they intentionally include invalid cases and nonterminating loops.

`probe.rs` generates 1,200 raw IR / 400 source cases deterministically. `cost.rs` measures flat
branches / propagation at 32, 128, 512 and 1,000 sites. Cost columns: kind, count, source bytes,
C bytes, release-seed checking seconds, C emission seconds. Three before/after runs retain raw
samples and medians; timing ratios are not flaky hard gates. Outputs must remain byte-identical.

Frozen before state is commit 2dea0f1; `before.json` records its full hash and the original compiler/
16 output hashes. Full conformance/native/Rust controls remain part of the same replay. See
`docs/design/checker-state.md` for the failed intermediate freshness hypothesis and the bounded
scalar-definedness bitmap that repaired it before landing.
