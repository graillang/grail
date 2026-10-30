# Terminating ownership paths

Run `python research/experiments/returns31/check.py` from any directory. Requires stable Rust,
clang, the existing private `nightly-2026-10-29` toolchain, and the configured memory01 TinyCC tree.
The host Rust selection is not changed. Generated binaries/targets stay under ignored `.work`.

Stable and pinned nightly execute the accepted Rust reference (2 / 1 / 2) and reject the two
compile-only lifetime/alias controls. No negative control is executed. Native Grail checks the same
payload lengths and resumed source growth, plus exact allocation/free behavior and C/LLVM exit
execution; the driver compiles hidden providers with either clang or explicitly selected TinyCC.

The cost harness is synthetic, not a full compiler benchmark. Counts/columns: flat return branches,
source bytes, emitted C bytes, release-seed check seconds, C lowering seconds. Checks retain source
hashes and expected acceptance per command; historical evidence is not overwritten by future gates.
