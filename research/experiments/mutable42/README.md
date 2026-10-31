# Mutable capture witness/writeback gate

Run `python research/experiments/captures41/check.py --mutable`. The maintained shared harness chooses
this workload and frozen readonly baseline `3d5eaa18`; it does not download tools or delegate models.

The independent Rust control executes unique replacement/Option pop, cursor mutation and Result
cleanup with owned names. Both Rust compilers reject bad stored-lifetime/invariance cases. Grail
executes source-hidden core/cells/client modules across development/release/TinyCC profiles, numeric
C/LLVM descriptor exchange, exact instrumented destruction and optimizing ASan/UBSan. Production
objects check result/leak freedom separately: `-O2` may elide unused temporary allocations. Disabling
allocator builtins is confined to the instrumentation probe, not production profiles.

Checking costs include unchanged plain/numeric-reference/readonly corpora and mutating 1/8/32/64
captures across 16/64/256 calls. Frozen replay never executes invalid/nonterminating generated IR.
The mutable lexer advances a stored remaining span while returning borrowed token spans with owned
spellings and Result propagation; the scanner covers 950272 bytes / 131072 tokens. Its comparison is
the prior readonly cursor workload, not an artificially slow control. Both require stable artifacts
and linked executable hashes across repeated source-hidden builds. The ABI/program differ, so this
is composition evidence, not an isolated instruction comparison or whole compiler benchmark.

General joins and heap collections, regular recursive references, the real seed port and self-hosting
remain required. In particular, the closed external loop-state check is an interim safety barrier,
not an approved exclusion of safe changing-state programs.
