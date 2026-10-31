# Checked by-value generic functions

Run `python research/experiments/templates39/check.py` from the project with the existing Rust,
pinned nightly, clang and configured TinyCC build. No downloads, models or external edits.

The gate retains full suite/clippy checks, mixed-profile source-hidden template linking, recursive
cleanup/error traces, independently executed stable/nightly Rust controls, and a 1,600-case frozen
`a1351ad` replay. Generated invalid/nonterminating IR is compile/lower only, never executed.
The replay compares C exactly and interfaces after removing only the changed empty schema envelope.

Three samples measure universally checked templates, concrete materialization, repeated-instance
memoization and serialized body decode/rechecking at 0/16/64/256 sites. A separately compiled lexer
returns borrowed-span/owned-spelling records through generic Result, then scanner loops move them
through Option and identity, hash contents and clean each iteration. Producer source is removed.
A fixed host shim supplies 950,272 bytes / 131,072 tokens; public-driver objects use all three native
profiles. Rust supplies independent results. This is a compiler-relevant workload, **not** the real
seed port. Native artifact integrity/reproducibility checks are also in the integration suite.

`cleanup.grl` is consumed by the native allocator/ASan/UBSan test. Exact allocator probes preserve
malloc/realloc/free builtins; production optimizing flags are unchanged. Rust's independently
executed owned wrappers observe logical destructor order, not identical allocator implementation.
General typed-reference invariance/writeback, arbitrary-element heap containers, unequal ownership
joins and stage-2/stage-3 bootstrap remain separate hard gates, not excluded requirements.
