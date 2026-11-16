# bench

- `fnv`, `matmul`, `nbody`, `sieve`, `sort`: each `NAME.grl` has a C twin `NAME.c` that prints the
  same numbers; `bun tools/bench.mjs [NAME...]` times the pair and reports the ratio.
- `alloc_threads.grl`: allocator scaling - 1, 2, 4, 8, 16 and 24 pool workers each allocate and free
  small vectors and records; prints the rate per worker count. Build and run it directly.
- `alloc_handoff.grl`: allocator hand-off - pool workers allocate, the main thread frees. Build and
  run it directly. Both are explained, with numbers, in `docs/design/allocator.md`.
- `atomics.grl`: one uncontended load, store, fetch_add, swap and compare_exchange on an
  `Atomic<u64>`, a Mutex round trip, 24 jobs on one fetch_add and an SPSC ring of release stores and
  acquire loads (`atomics all`); `atomics OP:N` runs one op N times, for callgrind at two N. The
  numbers before and after the inline `atom.*` ops are in `docs/design/concurrency-stages-5-7.md`,
  "Stage 7: as built".
# Benchmarks

Each `NAME.grl` has a C twin `NAME.c` that prints the same numbers. `bun tools/bench.mjs [NAME...]`
builds both (C with `clang -O2 -ffp-contract=off`), checks the outputs agree and prints the times
and the ratio; `GRAIL_BACKEND=llvm` builds the Grail side through the LLVM backend, and `--rounds N`
pairs the runs on a busy machine. See the header of `tools/bench.mjs`.

| program | what it measures |
|---|---|
| `fnv` | a serial integer hash chain over bytes |
| `sieve` | strided byte stores |
| `sort` | element moves in a `u64[]` |
| `nbody` | `f64` arithmetic with eight element accesses per inner iteration |
| `matmul` | an `f32` inner product with a loop-carried sum |
| `xform_f32`, `xform_f64` | `x[i] = x[i] * a + y[i]` over one million elements: the simple loop C vectorises, so the ratio is the distance to vectorised C |
| `dot_f32`, `dot_f64` | a strict-IEEE dot product over one million elements: a serial sum C does not vectorise, so the ratio is the distance to scalar C |

`xform` and `dot` are the loops of `docs/design/simd-layout-parallel-loops.md` (section 1.3), which
records what stands between each backend and C on them.
- `mutex.grl`: one `Mutex` taken 20000 times per contender with a short hold, at 1, 2, 8 and 24
  contenders; wall and CPU ms. Build and run it directly; numbers in `docs/design/parking.md`.
- `shard_read.grl`: a read-mostly map behind one `Mutex` and behind one `sync::RwLock`, 24 tasks;
  the measurement behind `concurrent_map`'s shard lock (`docs/design/parking.md`).
