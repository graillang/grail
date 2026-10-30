# Concrete tagged values / unwrap checkpoint

`checks.json` retains all commands, outputs, expected accept/reject results and source/test/control
hashes. Stable and pinned modern nightly run full conformance (including native tests); explicit
clang↔TinyCC replays use source-hidden producer interfaces. No model/provider or host Rust default
was changed. Rust negatives only compile, never execute.

Native programs cover owned token names plus borrowed spans, success/error payload sizes, nested
sum destruction, explicit default discard, ignored payload cleanup in empty arms, Option/unit,
unit C/LLVM ABI, abort on Result error, recovering match, variant-order invalidation and surviving
previous artifacts/executables. An allocator wrapper checks actual selected-backend objects for
balanced allocation/free, double free and final release order. It is not a formal alias proof or
sanitizer result. A source-hidden decimal parser checks empty/invalid/overflow/max-u64/leading-zero
inputs, plus 32 deterministic valid values and invalid suffixes against host Rust parsing.

The executable Rust control prints 8 / 11 / 7, then the same seven explicit decimal outcomes as the
Grail client. The unanchored-lifetime error constructor is accepted; local borrowed errors and views
into owned error storage are rejected by both languages.

`costs-before.txt` observed avoidable full-table cloning and clearing inactive flags. `costs.txt`
observes current source. The reversible zero-context optimization patch and pre-optimization hashes
of the two changed core files permit replay in an isolated checkpoint worktree. Samples are wall
times, not strict bounds or a full pre-change artifact; use fresh repeated runs for comparisons.
64 variants shrank from 76,609 to 16,759 C bytes and roughly 10.8 to 0.33 ms lowering in the initial
samples. Flat-branch checker cloning cost from returns31 remains open before self-hosting claims.

See `docs/design/tagged-enums.md`: concrete payloads only, generic Result/Option, general typed
references, richer patterns, `?`, generic containers and self-hosting remain required future work.
