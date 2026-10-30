# Early-return checkpoint

`checks.json` retains commands, environments, expected acceptance, exit codes, full outputs and
hashes of seed source/tests, allocator fixture and independent controls. Negative Rust controls are
compile-only. No provider or model was changed; host Rust defaults remain untouched.

Full stable and pinned-nightly suites include native allocator, source-hidden module and artifact
checks. Explicit TinyCC replay selects actual immutable objects for the new return tests. Native
assertions compare both owned-field return lengths (2 / 1), source growth after a captured-span
return (2), exact live allocation counts and final free order. Independent Rust agrees on 2 / 1 / 2.
Primitive LLVM returns execute the same empty/hit/miss inputs as C (8 / 9 / 7). Allocation auditing
covers memory release/double-free/leak behavior; it is not a formal alias proof or sanitizer run.

`costs.txt` is one local wall-time sample per synthetic branch count; columns are count, source
bytes, emitted C bytes, check seconds, C lowering seconds. Cumulative checker state cloning shows
roughly quadratic scaling. This known seed engineering cost remains to address before claiming
representative compiler/self-hosting performance; do not interpret it as a completed Grail workload
or as an interface/type-system complexity bound.

See `docs/design/return-cleanup.md` for precise functionality and still-open ownership-join work.
`!` unwrap-or-abort and `?` propagation are selected syntax only at this checkpoint, not implemented.
