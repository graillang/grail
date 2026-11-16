# Run-time parity

Grail has three pillars: the safety of Rust, a build fast enough not to think about, and - decided on
2026-11-16 - **run time on a par with the fastest compiled languages.** The game this language is
being built beside is a demanding one, and a language that is safe and builds quickly but runs at a
third of the speed is not a candidate for it. `docs/design/compile-speed.md` is the record for the
second pillar; this note is the record for the third.

## The claim, stated so it can be checked

**A release build of a Grail program runs as fast as the same algorithm written in C or Rust and
built with `-O2`; it is safe by default; and where a safety check cannot be proved away, what it
costs is measured and published here.**

| build | against `clang -O2` | measured by |
| --- | --- | --- |
| release (LLVM backend), scalar code | within 1.2x | `bun tools/bench.mjs` with `GRAIL_BACKEND=llvm` |
| release, a loop C vectorises | parity | the `xform` benchmark (bench/, with the float work) |
| release, hand-written SIMD types | parity with C intrinsics | with the SIMD stage |
| development (native backend) | within 3x of scalar C | `bun tools/bench.mjs` |

The development build is the native backend: it exists to compile quickly, as Go's compiler and
Zig's debug backend do, and it is what the tests run. It is not what ships.

## Where it stands (2026-11-16, before any of the work below)

`bun tools/bench.mjs --rounds 5`, Grail's time over C's, taken on a loaded machine (the spread
between rounds was large; read these to one significant figure):

| program | native backend | LLVM backend |
| --- | --- | --- |
| fnv (integer hashing) | 5.8x | 1.4x |
| sieve | 4.6x | 1.3x |
| sort | 3.0x | 1.5x |
| matmul (floats) | 315x | 1.4x |
| nbody (floats, records) | 23x | 4.5x |

and from the design notes' own probes: a 1M-element `f32` transform is 259 ms on the native backend,
0.70 ms on the LLVM backend, 0.23 ms in scalar C and 0.077 ms in vectorised C
(`docs/design/simd-layout-parallel-loops.md`); 1M three-field records take 68 MB against 13 MB in C
and three to six times the time once allocation order and vector order differ
(`docs/design/unboxed-values.md`).

The gate records both columns on every run (`runtime-bench-native`, `runtime-bench-llvm`), after
every other leg has finished so nothing runs beside them.

## What stands between here and the claim

None of it is research; all of it is in progress or planned, in this order.

1. **Floats on the native backend are calls.** Every float operation calls the runtime, and an `f32`
   result is rounded in software. Hardware rounding and inline operations are being done first
   (branch `gaps12-float`).
2. **The optimiser of the native backend has not seen a jump target since 2026-11-13.** A comparison
   in `ir::label_number` was changed from "starts with the unit prefix" to "is the unit prefix", so
   every label read as unknown and liveness, dead-code removal and the peephole pass ran in their
   most conservative mode (branch `gaps12-optlabels`).
3. **`grail build` cannot reach the LLVM backend.** `--release` will mean the LLVM backend with
   `clang -O2`, per module, through the build store.
4. **What the LLVM backend is given.** It lifts the native stream back into LLVM IR, which loses
   pointer provenance, leaves each bounds check as an early exit that reloads the length, and says
   nothing of what the borrow checker proved about aliasing. That is why a simple loop is 3x to 9x
   off. Hoisting the checks, keeping provenance and stating `noalias` come before the SIMD types,
   because they speed up every loop.
5. **Value representation.** A record is a heap block, so a vector of records is a vector of
   pointers. Flat vectors of records, records in frames, then packed layout
   (`docs/design/unboxed-values.md`).
6. **Explicit SIMD types**, for the loops no compiler vectorises: a strict floating-point reduction
   is one (C at `-O2` does not vectorise a dot product either).
7. **Threads.** One scheduler for jobs and tasks, per-thread allocation, pinned threads
   (`docs/design/concurrency-model.md`).

## Against other languages

Since 2026-11-16 every performance claim is measured against the best existing languages, not
against Grail's own past numbers. The bars:

- **Release build (LLVM backend)**: parity with `clang -O2` on every benchmark, within noise.
- **Development build (native backend)**: faster than Zig Debug, Rust's dev profile and Go.

`bun tools/bench-rivals.mjs [--runs N] [NAME...]` builds every program in `bench/` that has a C
twin, plus its Rust, Go and Zig twins in `bench/rivals/` (the same algorithm and the same output,
idiomatic, not hand-vectorised), each the way its users build it, checks that every output agrees
with C's, and prints three tables: CPU time, the same programs built for the host CPU, and
user-space instructions. With `GRAIL_SCHED_TREE` naming a checkout of `gaps12-sched` (and
`GRAIL_SCHED_COMPILER` its compiler) it adds `ffi_call`, which is only on that branch.

| column | command |
| --- | --- |
| Grail-native | the native backend, `--overflow=checked` (tools/native.mjs `compileProgram`) |
| Grail-LLVM | `--backend=llvm --overflow=wrap`, then `clang -O2` on the IR: the release build |
| C -O2 | `clang -O2 -ffp-contract=off` (+ `-fno-builtin` for ffi_call, its `bench-cflags` line) |
| Rust rel | `rustc --edition 2021 -C opt-level=3`: cargo's release profile for one crate |
| Go | `go build` with `GOAMD64=v1` (the default). Go has one build; `-gcflags='-N -l'` is a debugger's build that Go users neither ship nor test with, so it is not used, and Go appears in both bars |
| Zig RF | `zig build-exe -O ReleaseFast -mcpu=baseline` |
| Rust dev | `rustc --edition 2021 -C opt-level=0 -g`: cargo's dev profile (debug assertions and overflow checks on) |
| Zig Debug | `zig build-exe -O Debug -mcpu=baseline` (0.14's default backend for it, LLVM) |

**Same ISA.** Every column targets baseline x86-64 (SSE2), which is what clang, rustc, Go and Grail
emit by default. Zig defaults to the host CPU (AVX-512 on this machine), which is why an earlier
reading counted 0.06 G instructions for Zig's xform_f32 against C's 0.30 G; with `-mcpu=baseline`
it is 0.34 G. A second table builds C, Rust, Go and Zig for the host (`-march=native`,
`-C target-cpu=native`, `GOAMD64=v3`, `-mcpu=native`) and sets Grail-LLVM, still baseline, against
them.

**Same work.** No round may be dead code. In sieve only the last round's count was printed and in
matmul only the last round's product was read, so a compiler could drop every round but one. Now
sieve's next limit depends on the previous count (the sum of the counts is printed), matmul writes
`a[round] = c[round]` after each round, and xform folds `x[pass]` into the next pass's scale. This
was changed in the C and Grail programs too. The others already chain: fnv's hash runs through all
the rounds, sort folds each round into its check, dot changes `x` and sums every pass, and nbody's
steps follow one from another.

**Same data structures, where the language has them.** Grail has no fixed-size array type; a table
static is a vector too. nbody's C, Rust, Go and Zig twins use fixed arrays, as the benchmark always
has, and Grail's uses vectors: that is recorded below as a language gap, with its cost measured in C
(`bench/rivals/nbody_heap.c`). matmul's C twin uses `static` arrays where every other twin
allocates, so `bench/rivals/matmul_heap.c` is C with the same data structure as the others.

**Measurement.** CPU time is user + sys from `getrusage`, every thread included
(`tools/rivals/measure.c`), best of three runs taken round by round, because the host is shared.
ffi_call reports its own per-call time. The instruction table is user-space instructions from
`perf_event_open`, inherited by every thread; load does not move it. LLVM would inline libc's
`labs` in the ffi twins, so they are built to keep it a call: Rust with `#![no_builtins]`, Zig with
`-fno-builtin`, C with `-fno-builtin`. Go calls C through cgo, the only way Go calls C. ffi_call
measures `gaps12-sched` a4521aa, the FFI path after its no-thread-pointer-switch change
(about 3 ns, where it was about 660 ns).

Measured 2026-11-16 on 24 cores, load average 16 to 24. clang 23.1.4, rustc 1.98.0, go1.27.3,
zig 0.14.1. Grail is `gaps13-int` db2d35e plus this branch's benchmark changes; ffi_call is
`gaps12-sched` a4521aa.

CPU seconds. The last two columns are Grail over the best competitor of its bar: native against the
best of Go, Rust dev and Zig Debug; LLVM against the best of C, Rust rel, Go and Zig RF.

| program | Grail-native | Grail-LLVM | C -O2 | Rust rel | Go | Zig RF | Rust dev | Zig Debug | native / dev best | LLVM / release best |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dot_f32 | 0.694 | 0.132 | 0.129 | 0.131 | 0.133 | 0.127 | 1.162 | 0.535 | 5.22x | 1.04x |
| dot_f64 | 0.439 | 0.134 | 0.130 | 0.132 | 0.134 | 0.130 | 1.179 | 0.533 | 3.29x | 1.03x |
| fnv | 2.888 | 0.551 | 0.542 | 0.544 | 0.546 | 0.543 | 6.098 | 1.779 | 5.29x | 1.02x |
| matmul | 1.171 | 0.229 | 0.207 | 0.205 | 0.248 | 0.206 | 4.738 | 1.529 | 4.72x | 1.12x |
| nbody | 0.579 | 0.187 | 0.105 | 0.097 | 0.107 | 0.062 | 1.344 | 0.822 | 5.40x | 3.03x |
| sieve | 1.926 | 0.622 | 0.535 | 0.592 | 0.603 | 0.603 | 3.666 | 1.625 | 3.20x | 1.16x |
| sort | 2.116 | 1.170 | 0.871 | 0.922 | 0.960 | 1.263 | 5.223 | 3.379 | 2.20x | 1.34x |
| xform_f32 | 0.429 | 0.130 | 0.019 | 0.021 | 0.097 | 0.024 | 1.120 | 0.234 | 4.44x | 6.80x |
| xform_f64 | 0.405 | 0.147 | 0.034 | 0.036 | 0.102 | 0.037 | 1.122 | 0.243 | 3.96x | 4.37x |
| ffi_call (ns per call) | 2.40 | 1.83 | 1.75 | 1.64 | 20.78 | 1.74 | 5.74 | 2.79 | 0.86x | 1.12x |

User-space instructions, in billions, from the same builds:

| program | Grail-native | Grail-LLVM | C -O2 | Rust rel | Go | Zig RF | Rust dev | Zig Debug | native / dev best | LLVM / release best |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dot_f32 | 7.98 | 1.37 | 0.73 | 0.77 | 1.63 | 0.76 | 15.37 | 4.25 | 4.88x | 1.88x |
| dot_f64 | 6.47 | 1.27 | 0.73 | 0.77 | 1.63 | 0.76 | 15.37 | 4.25 | 3.96x | 1.75x |
| fnv | 61.54 | 3.29 | 2.79 | 3.22 | 6.18 | 3.02 | 71.94 | 27.40 | 9.96x | 1.18x |
| matmul | 17.02 | 5.06 | 1.35 | 1.36 | 3.38 | 1.35 | 61.65 | 20.87 | 5.04x | 3.74x |
| nbody | 12.79 | 4.69 | 1.33 | 1.03 | 2.20 | 0.78 | 21.56 | 14.61 | 5.82x | 6.05x |
| sieve | 25.73 | 5.48 | 2.88 | 2.83 | 3.42 | 2.91 | 37.28 | 13.25 | 7.51x | 1.94x |
| sort | 25.69 | 8.90 | 4.26 | 5.15 | 7.09 | 6.40 | 69.14 | 30.87 | 3.62x | 2.09x |
| xform_f32 | 9.80 | 3.08 | 0.30 | 0.35 | 2.04 | 0.34 | 13.68 | 4.87 | 4.80x | 10.23x |
| xform_f64 | 8.09 | 3.67 | 0.58 | 0.67 | 2.04 | 0.66 | 13.67 | 4.87 | 3.96x | 6.29x |
| ffi_call (whole program) | 5.60 | 0.77 | 0.88 | 0.90 | 16.05 | 0.78 | 8.30 | 3.85 | 1.45x | 0.99x |

References: C written another way, against the C twin and Grail-LLVM.

| reference | it | C twin | Grail-LLVM | Grail-LLVM / it |
| --- | --- | --- | --- | --- |
| nbody_heap.c: nbody with `p`, `v`, `m` malloc'd, Grail's data structure | 0.106 s | 0.105 s | 0.187 s | 1.77x |
| matmul_heap.c: matmul with malloc'd arrays, as the other twins | 0.221 s | 0.207 s | 0.229 s | 1.04x |
| ffi_fnptr.c: C calling `labs` through a pointer it cannot see through | 1.68 ns | 1.75 ns | 1.83 ns | 1.09x |

The same programs built for this CPU (Grail-LLVM still baseline):

| program | C native | Rust native | Go v3 | Zig native | Grail-LLVM | LLVM / best |
| --- | --- | --- | --- | --- | --- | --- |
| dot_f32 | 0.130 | 0.133 | 0.132 | 0.131 | 0.132 | 1.02x |
| dot_f64 | 0.132 | 0.132 | 0.133 | 0.129 | 0.134 | 1.04x |
| fnv | 0.543 | 0.544 | 0.548 | 0.540 | 0.551 | 1.02x |
| matmul | 0.202 | 0.199 | 0.244 | 0.200 | 0.229 | 1.15x |
| nbody | 0.108 | 0.102 | 0.104 | 0.066 | 0.187 | 2.85x |
| sieve | 0.586 | 0.593 | 0.620 | 0.653 | 0.622 | 1.06x |
| sort | 0.879 | 0.902 | 0.956 | 1.203 | 1.170 | 1.33x |
| xform_f32 | 0.021 | 0.026 | 0.062 | 0.020 | 0.130 | 6.40x |
| xform_f64 | 0.038 | 0.040 | 0.092 | 0.035 | 0.147 | 4.24x |
| ffi_call (ns) | 1.80 | 1.73 | 20.56 | 1.76 | 1.83 | 1.06x |

On these programs the native-CPU option buys almost nothing in time. These loops are bound by
latency or memory, or (xform) already vectorised with SSE. Go with `GOAMD64=v3` prints other
digits for nbody: with FMA available it fuses `x*y+z`, which its spec permits. That is reported,
not a failure.

**Where the release bar is met.** fnv, dot_f32 and dot_f64 are within 4 %, the noise of this host,
and ffi_call matches a C call through a function pointer (1.09x). These are time parities only.
Grail-LLVM retires 1.2x (fnv) to 1.9x (dot) the instructions of C: the loop-carried multiply or
add chain sets the pace and hides the extra instructions. They are the bounds checks and header
reloads below, and a loop with more independent work would show them.

**Where it is missed, and why** (read from the generated code, `objdump` of the `.ll.o`):

- **xform_f32 6.8x, xform_f64 4.4x (10.2x and 6.3x the instructions): the loop is not
  vectorised.** C, Rust and Zig emit packed `mulps`/`mulpd`; Grail's `scale_add` is scalar. Each
  iteration re-reads both slices' lengths and data pointers from their headers
  (`cmp 0x8(%rdi),%r15`, `mov (%rdi),%rcx`) and keeps both bounds checks inside the loop. The
  store to `x[i]` may, as far as LLVM is told, alias those headers, because the lifted IR has no
  provenance and no `noalias`. A loop whose checks cannot be hoisted cannot be vectorised. This is
  item 4 of "What stands between here and the claim". Go does not vectorise either and runs
  0.097/0.102: Grail is near Go here, not near C.
- **nbody 3.0x (6.1x the instructions)**: the same reloads in the inner `k` loop. After every
  store to `v[...]` the data pointers and lengths of `p`, `v` and `m` are loaded again, and about
  eight bounds checks run per iteration. Of the 3.0x, the data structure accounts for nothing in C:
  nbody_heap.c, with C's arrays on the heap, runs as fast as the fixed-array twin (0.106 s against
  0.105 s). So the cost is the reloads and checks, not the heap. Zig, at 0.062 s, unrolls the whole
  pair loop over its fixed arrays. **Language gap: no fixed-size arrays.** Grail cannot state
  "15 doubles" in a type, so no compiler can unroll on it as Zig does. Items 4 and 5.
- **sort 1.34x (2.1x the instructions)**: per merged element, 4 to 5 bounds checks and a reload of
  both vectors' headers after the store into `tmp`. Item 4.
- **sieve 1.16x (1.9x the instructions)**: the strided store loop re-reads the vector's length
  and data pointer from its header on every store (`mov 0x8(%r12),%rdx`, `mov (%r12),%rdx`)
  and checks the index each time. C's loop is a store and an add. Item 4.
- **matmul 1.12x (3.7x the instructions)**: the inner product reloads `a`'s and `b`'s headers and
  checks both indices each step. The sum is a serial `mulss`/`addss` chain in every language
  (strict IEEE), which hides most of the 3.7x. Against C with the same heap arrays (matmul_heap.c)
  the gap is 1.04x. Item 4.

**Where the development bar is missed: everywhere but ffi_call** (2.2x to 5.4x the best of Go,
Rust dev and Zig Debug in time, 3.6x to 10x in instructions). Grail-native is faster than Rust's
dev profile on every row, and slower than Zig Debug and Go on every row but ffi_call. The native
backend's code, read from its `.s`:

- **A widening integer conversion is a runtime call.** fnv's `u64(data[i])` compiles to `movzbq`
  and then `call rt_int_cast` per byte. That makes 61.5 G instructions against Go's 6.2 G and Zig
  Debug's 27.4 G, about 107 per byte against Go's 11.
- **`f32` arithmetic goes through `f64`.** Every `f32` multiply is `cvtss2sd`, `mulsd`,
  `cvtsd2ss`, with the value moved through a general register between steps (xform_f32, dot_f32,
  matmul).
- **Every access is bounds-checked against a length re-read from memory**, and loop variables live
  in stack slots (`incq -56(%rbp)`, `movq -104(%rbp),%rcx` in fnv's loops).

## The scheduler against rayon and oneTBB

The bar: match or beat Rust's rayon and C++'s oneTBB on join cost, spawn cost, fib(32) by nested
join, and a frame loop's tail latency. Both rivals are available offline here: rayon 1.12.0 /
rayon-core 1.13.0 from the cargo registry (`bench/rivals/sched-rayon`, `cargo build --release`) and
oneTBB 2023.2 from the system (`bench/rivals/sched_tbb.cpp`, `g++ -O2 -std=c++20 -ltbb`), so no
substitute was needed.

`bun tools/sched-rivals.mjs [--rounds R]` runs Grail's `bench/sched.grl` and `bench/frame.grl` from
the scheduler branch (`GRAIL_SCHED_TREE`, here `gaps12-sched` a4521aa, read-only) against the twins,
which print the same `name value unit` lines. Grail is built three ways: `grail build --no-cache`
(native), the LLVM backend with `--overflow=wrap` (release), and the release build with
`GRAIL_WORKERS` set to the CPU count. That last column is like for like: rayon starts one worker per
CPU beside the main thread, and oneTBB's default arena has one slot per CPU, the main thread's
included. Grail's default is also one worker per CPU, which is why that column matches the release
one. The twins:

- **join**: `rayon::join` / `tbb::parallel_invoke`, 100k times with trivial halves, from the main
  thread and (rivals only; sched.grl has no such row) from inside the pool.
- **spawn and wait**: a scope with one spawn (rayon) / `task_group::run` + `wait` (oneTBB), against
  Grail's `pool::spawn` + `pool::wait`.
- **burst**: 100k spawns into one scope or task group, then all waited for.
- **fib(32)**: serial, and by nested join with the cutoff at 12 (28,656 joins), from the main
  thread and from inside a task.
- **frame**: frame.grl ported. 600 frames of 32 systems (every third forks four), an in-place
  parallel pass over 1M elements in leaves of 4096 (`par_chunks_mut(4096)` /
  `parallel_for(blocked_range(.., 4096), simple_partitioner)`) and a render step on the main thread.
  Beside them run an I/O thread that sleeps 5 ms per round and records how late it woke, and an
  importer that never waits. rayon has no priorities, so its importer forks onto the same pool;
  oneTBB's runs in a `task_arena` of low priority and the frame in one of high priority, the
  equivalent of Grail's Background and Frame classes. The frame checksums of all three agree.

These are wall-clock times measured inside each program: a join's cost and a frame's latency are
times, not CPU totals. So each figure is the median of nine rounds, interleaved, run with nothing
else of this work beside it. Measured 2026-11-16 on 24 CPUs, load average 18 to 30. The ratio is
Grail over the best rival; for importer rounds it is the best rival over Grail.

| | Grail-native | Grail-LLVM | LLVM, 24 workers | rayon | oneTBB | native / best | LLVM / best |
| --- | --- | --- | --- | --- | --- | --- | --- |
| join from the main thread (ns) | 2561 | 2803 | 2863 | 6611 | 125 | 20.5x | 22.4x |
| join on a worker (ns) | - | - | - | 25 | 138 | | |
| spawn a job and wait (ns) | 2758 | 2455 | 2566 | 8196 | 153 | 18.0x | 16.1x |
| task spawn+join, one at a time (ns) | 7481 | 12424 | 12021 | - | - | | |
| burst of 100k spawns, per spawn (ns) | 1487 | 2335 | 2359 | 800 | 164 | 9.1x | 14.2x |
| fib(32) serial (us) | 10325 | 8514 | 7904 | 4034 | 2716 | 3.8x | 3.1x |
| fib(32) nested join, from main (us) | 6961 | 7378 | 8723 | 1196 | 947 | 7.4x | 7.8x |
| fib(32) nested join, in a task (us) | 6790 | 7499 | 7644 | 845 | 596 | 11.4x | 12.6x |
| frame median (us) | 2230 | 985 | 790 | 358 | 357 | 6.3x | 2.8x |
| frame p99 (us) | 3809 | 2061 | 2418 | 2763 | 3299 | 1.4x | **0.75x** |
| frame max (us) | 5737 | 3043 | 3340 | 3544 | 5973 | 1.6x | **0.86x** |
| 600 frames (ms) | 1441 | 632 | 548 | 264 | 299 | 5.5x | 2.4x |
| I/O task worst lateness (us) | 3098 | 1874 | 2432 | 1000 | 2607 | 3.1x | 1.9x |
| importer rounds (more is better) | 2586 | 1581 | 1563 | 3635 | 8983 | 3.5x | 5.7x |

CPU seconds per whole run (median): Grail-LLVM sched 4.39, frame 3.81; rayon 15.08 and 2.68
(rayon's idle workers spin); oneTBB 0.68 and 3.31.

**Met**: the frame loop's tail. Grail-LLVM's p99 and worst frame are the best of the three
(0.75x and 0.86x). Its Frame class runs ahead of the importer, as oneTBB's high-priority arena
should, and rayon cannot, having no priorities.

**Missed, and why:**

- **A join allocates.** Each level of `pfib` allocates two closure records (`rt_rec`), and
  `pool::join` allocates two more and an `Option` for the second result (`rt_enum`) before calling
  `rt_parallel_with`: about five heap allocations per join. rayon's join puts a job that lives in
  the caller's stack frame on the local deque and allocates nothing (25 ns on a worker); oneTBB's
  `parallel_invoke` is 138 ns.
- **The main thread is not a worker.** A join or spawn from `main` is posted to the pool and the
  main thread waits to be woken: 2.5 to 2.9 us. rayon has the same arrangement and pays more
  (6.6 us); oneTBB's main thread is a slot of its arena and pays 125 ns.
- **The serial work is slower before any scheduling.** Serial fib(32) is 3.1x oneTBB's in the
  release build, with no scheduler involved. Grail's calling convention carries three hidden
  registers (`rsi`, `r8`, `r9`) through every call and saves five callee-saved registers per frame,
  where g++ turns one of fib's two recursions into a loop. The same per-call cost is in every
  system's `mix` loop, hence part of the 2.8x frame median.
- **fib(32) by nested join barely beats serial fib**: 7.5 ms against 8.5 ms on 24 workers (1.1x),
  where rayon gets 4.8x and oneTBB 4.6x. The allocations above are on every join's path; whether the
  allocator's cross-thread frees or the steal path dominate has not been profiled yet (there is no
  `perf` on this host).
- **The importer gets fewer rounds by design**: at most a quarter of the workers run Background
  jobs (`docs/design/concurrency-model.md`), where oneTBB lets its low-priority arena take every
  idle thread.

## What safety costs, and what was decided about it

- **Bounds checks stay**, in every build. They are removed where the refinement prover has the fact,
  hoisted out of loops whose bound is the loop's own, and absent inside the parallel-loop builtins,
  which state that their slices are equally long. What is left is one predictable branch where the
  index really is unknown. This is the arrangement Rust has.
- **Integer overflow is checked in development builds and wraps in release builds.**
  `--overflow=checked|wrap` and a per-package manifest key override either; `wrapping_add`,
  `wrapping_sub` and `wrapping_mul` always wrap. An overflow bug therefore stops a development build
  and wraps silently in a release build - the trade Rust makes - so test suites run with the checks
  on (`--release --overflow=checked` is an optimised build that still traps). The refinement prover
  must not depend on the mode: it is to be sound under wrapping in both, proving that arithmetic
  cannot wrap where the facts say so, so both builds accept exactly the same programs.
- **Floating point is strict**: no fast-math, no implicit fused multiply-add, a specified order for
  reductions. That is C at `-O2`, and it is what lets the two backends be each other's test oracle.
  A NaN result is a quiet NaN and its payload bits are not specified.
- **Small plain records copy.** A record with no owned fields of at most four words copies on
  assignment as a number does; a larger one is move-only and copied with `.copy()`.

## How a regression is caught

The gate's two `runtime-bench` legs print one line each (`runtime-bench (native): fnv 5.8x, ...`).
They do not fail on a ratio yet: the numbers above are not ones to defend. When a row reaches its
target it gets a threshold, in the same change that reaches it.
