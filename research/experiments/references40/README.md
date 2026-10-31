# Lifetime-free typed storage gate

Run `python research/experiments/references40/check.py` with existing stable/pinned-nightly Rust,
clang and the configured TinyCC root. No downloads/models/external changes. The gate rebuilds
`85ec12d`, replays identical compile/lower-only cases, compares old/new plain loop costs, and measures
actual typed numeric reference updates at 32/128/512/1000 sites. Invalid/nonterminating generated
IR is never executed.

Native integration executes the real `seed/examples/references` library with provider source
removed, all native profiles/mixed directions, C/LLVM pointer returns, repeated deterministic builds,
real owner exchange, complete free traces and optimizing sanitizer probes. Rust controls independently
execute scalar results and logical recursive drop order. Instrumented C preserves allocator builtins;
production optimizing flags are unchanged.

This is storage groundwork, **not** acceptance of the captured-reference invariance/writeback hard
gate. Lifetime-bearing referents are still explicitly unsupported. Do not count those syntax/type
rejections as a proof that the required general typed-reference/container programs are implemented.

The 1 MiB counter workload repeatedly updates a record through a separately compiled typed mutable
reference. Module compile/link/runtime medians and raw samples cover all three native profiles,
with independent Rust checksums and repeated artifact/executable identity checks. The fixed host
shim includes input generation and process overhead; it is not an isolated kernel benchmark.
