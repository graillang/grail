# bench

- `fnv`, `matmul`, `nbody`, `sieve`, `sort`: each `NAME.grl` has a C twin `NAME.c` that prints the
  same numbers; `bun tools/bench.mjs [NAME...]` times the pair and reports the ratio.
- `alloc_threads.grl`: allocator scaling - 1, 2, 4, 8, 16 and 24 pool workers each allocate and free
  small vectors and records; prints the rate per worker count. Build and run it directly.
- `alloc_handoff.grl`: allocator hand-off - pool workers allocate, the main thread frees. Build and
  run it directly. Both are explained, with numbers, in `docs/design/allocator.md`.
