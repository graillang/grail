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
- `ffi_call.grl` / `ffi_call.c`: the cost of a foreign call - 10M calls of libc's `labs`, best of
  five rounds, and the same loop without the call, so `ffi_call_only` is the call alone. The C twin
  is built with `-fno-builtin`, so its `labs` is a real call through the PLT as Grail's is. The bar:
  a Grail call costs what the C call costs. `bun tools/bench.mjs ffi_call` times the pair.
# Benchmarks

Each `NAME.grl` has a C twin `NAME.c` that prints the same numbers. `bun tools/bench.mjs [NAME...]`
builds both (C with `clang -O2 -ffp-contract=off`), checks the outputs agree and prints the times
and the ratio; `GRAIL_BACKEND=llvm` builds the Grail side through the LLVM backend, and `--rounds N`
pairs the runs on a busy machine. See the header of `tools/bench.mjs`. The `simd_*` programs take a
round count and print their own timing line, so `bun tools/bench-simd.mjs` times them against their
intrinsics twins instead.

| program | what it measures |
|---|---|
| `fnv` | a serial integer hash chain over bytes |
| `sieve` | strided byte stores |
| `sort` | element moves in a `u64[]` |
| `nbody` | `f64` arithmetic with eight element accesses per inner iteration |
| `matmul` | an `f32` inner product with a loop-carried sum |
| `xform_f32`, `xform_f64` | `x[i] = x[i] * a + y[i]` over one million elements: the simple loop C vectorises, so the ratio is the distance to vectorised C |
| `hashmap`, `bintrees`, `strings`, `json`, `dyncall`, `iterchain`, `ecs` | engine-shaped work: a million-key hash map, allocation-heavy binary trees, split/parse/format of a million lines, a 10 MB JSON parse and serialise, a `dyn` call per element, an iterator chain over ten million elements, and a structure-of-arrays entity update; each has C, Rust, Go and Zig twins and its own section in the book's Performance chapter |
| `dot_f32`, `dot_f64` | a strict-IEEE dot product over one million elements: a serial sum C does not vectorise, so the ratio is the distance to scalar C |

`bench/rivals/` holds a Rust, a Go and a Zig twin of each program (and of `ffi_call`, which is on
`gaps12-sched`), plus the scheduler twins (`sched-rayon/`, `sched_tbb.cpp`). The engine-shaped programs (`hashmap`,
`bintrees`, `strings`, `json`, `dyncall`, `iterchain`, `ecs`) and `chan` also have a C++20 twin,
`NAME.cpp` (`std::unordered_map`, `std::unique_ptr` nodes, `std::string`, a `std::variant` DOM,
virtual functions, ranges views, `std::vector<float>` columns, a mutex/condition-variable channel);
each file's header states its idiomatic choice. So do the run-time programs and `ecs_par`
(`std::span`, `std::inner_product`, `std::transform`, `std::merge`, `std::vector<bool>` for the
sieve, and `std::jthread` per frame, with `CPP_THREADS` setting the workers). bench-rivals builds every
`NAME.cpp` it finds with `clang++ -std=c++20 -O2 -ffp-contract=off` plus the file's own
`// bench-cflags:` line, and -pthread when it includes `<thread>`. A twin must print exactly what
the C twin prints. A program without a C++ twin has no C++ figure.
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
- `chan.grl`: a bounded channel at 1:1, 4:1 and 4:4 and a ping-pong, against crossbeam-channel, Go's
  chan and mutex+condvar rings in C and Zig; run by `tools/bench-rivals.mjs chan`.
