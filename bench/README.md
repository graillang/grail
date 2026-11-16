# bench

- `fnv`, `matmul`, `nbody`, `sieve`, `sort`: each `NAME.grl` has a C twin `NAME.c` that prints the
  same numbers; `bun tools/bench.mjs [NAME...]` times the pair and reports the ratio.
- `alloc_threads.grl`: allocator scaling - 1, 2, 4, 8, 16 and 24 pool workers each allocate and free
  small vectors and records; prints the rate per worker count. Build and run it directly.
- `alloc_handoff.grl`: allocator hand-off - pool workers allocate, the main thread frees. Build and
  run it directly. Both are explained, with numbers, in `docs/design/allocator.md`.
- `ffi_call.grl` / `ffi_call.c`: the cost of a foreign call - 10M calls of libc's `labs`, best of
  five rounds, and the same loop without the call, so `ffi_call_only` is the call alone. The C twin
  is built with `-fno-builtin`, so its `labs` is a real call through the PLT as Grail's is. The bar:
  a Grail call costs what the C call costs. `bun tools/bench.mjs ffi_call` times the pair.
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

`bench/rivals/` holds a Rust, a Go and a Zig twin of each program (and of `ffi_call`, which is on
`gaps12-sched`), plus the scheduler twins (`sched-rayon/`, `sched_tbb.cpp`).
`bun tools/bench-rivals.mjs` times all of them against Grail's two builds, and
`bun tools/sched-rivals.mjs` the scheduler against rayon and oneTBB; the tables are in
`docs/design/runtime-parity.md`, "Against other languages". `bench/results/` holds their latest
results as JSON (`--json`), which the book's Performance chapter draws; `just bench-results`
refreshes them.

`xform` and `dot` are the loops of `docs/design/simd-layout-parallel-loops.md` (section 1.3), which
records what stands between each backend and C on them.
- `mutex.grl`: one `Mutex` taken 20000 times per contender with a short hold, at 1, 2, 8 and 24
  contenders; wall and CPU ms. Build and run it directly; numbers in `docs/design/parking.md`.
- `shard_read.grl`: a read-mostly map behind one `Mutex` and behind one `sync::RwLock`, 24 tasks;
  the measurement behind `concurrent_map`'s shard lock (`docs/design/parking.md`).
