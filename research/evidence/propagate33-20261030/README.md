# Postfix propagation checkpoint

Commands, expected accept/reject, outputs and code/control hashes are retained in `checks.json`.
The full suite is replayed on stable and pinned modern nightly, with explicit clang/TinyCC mixed
composition. Rust controls execute accepted programs only; negatives compile only. No host Rust
selection, model or provider was changed.

Native tests link actual selected immutable objects to the independently compiled allocator wrapper.
They check complete release traces, not only total balance. Pending call arguments release in the
same 3 / 2 / 4 / 1 order as the independent Rust Drop tracer. Condition failure releases iteration
temporaries before enclosing owners; Option None needs no fabricated error payload. Prior mutation
remains visible, explicitly falsifying any interpretation of propagation as rollback.

The annotation pipeline preserves borrowed source span / owned token name on success, and returns
an owned error string from a source-hidden decimal parser on failure. Input examples yield
49 / 5 / 7 / 8; writes before failure remain 9. This is default recursive destruction, not custom
user destructors, a sanitizer run or a formal correctness proof.

Cost samples expose checking/build engineering overhead of repeated '?' expansion. They are
synthetic wall times, not guaranteed bounds or a self-hosted compiler benchmark. Generic Result/
Option, general typed references/invariance, generic collections, remaining control-flow joins,
the real seed port and deterministic self-compilation are still required.
