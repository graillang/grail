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

`bun tools/bench-rivals.mjs [--runs N] [--metric cpu|instructions] [NAME...]` builds every program
in `bench/` that has a C twin, plus its Rust, Go and Zig twins in `bench/rivals/` (the same
algorithm and the same output, idiomatic, not hand-vectorised), each the way its users build it,
checks that every output agrees with C's, and prints one table. With `GRAIL_SCHED_TREE` naming a
checkout of `gaps12-sched` (and `GRAIL_SCHED_COMPILER` its compiler) it adds `ffi_call`, which is
only on that branch. The exact builds:

| column | command |
| --- | --- |
| Grail-native | the native backend, `--overflow=checked` (tools/native.mjs `compileProgram`) |
| Grail-LLVM | `--backend=llvm --overflow=wrap`, then `clang -O2` on the IR: the release build |
| C -O2 | `clang -O2 -ffp-contract=off` (+ `-fno-builtin` for ffi_call, its `bench-cflags` line) |
| Rust rel | `rustc --edition 2021 -C opt-level=3`: cargo's release profile for one crate |
| Go | `go build`. Go has one build; `-gcflags='-N -l'` is a debugger's build that Go users neither ship nor test with, so it is not used, and Go appears in both bars |
| Zig RF | `zig build-exe -O ReleaseFast` |
| Rust dev | `rustc --edition 2021 -C opt-level=0 -g`: cargo's dev profile (debug assertions and overflow checks on) |
| Zig Debug | `zig build-exe -O Debug` (0.14's default backend for it, LLVM) |

The figure is CPU time (user + sys from `getrusage`, every thread; `tools/rivals/measure.c`), best
of three runs taken round by round, because the host is shared; ffi_call's figure is the per-call
time the program measures itself. Twins whose libc call LLVM would otherwise inline (`labs`) are
built so it stays a call: Rust with `#![no_builtins]`, Zig with `-fno-builtin`, as C with
`-fno-builtin`. Go calls C through cgo, the only way Go calls C.

Measured 2026-11-16, load average 24 to 28 on 24 cores (19 to 28 for the ffi_call row);
clang 23.1.4, rustc 1.98.0, go1.27.3, zig 0.14.1, Grail at `gaps13-int` db2d35e (ffi_call:
`gaps12-sched` a4521aa). Seconds of CPU; the last two columns are Grail over the best competitor
of its bar (native: the best of Go, Rust dev, Zig Debug; LLVM: the best of C, Rust rel, Go, Zig RF).

| program | Grail-native | Grail-LLVM | C -O2 | Rust rel | Go | Zig RF | Rust dev | Zig Debug | native / dev best | LLVM / release best |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dot_f32 | 0.724 | 0.140 | 0.135 | 0.138 | 0.153 | 0.135 | 1.321 | 0.546 | 4.74x | 1.03x |
| dot_f64 | 0.514 | 0.145 | 0.138 | 0.140 | 0.146 | 0.137 | 1.645 | 0.551 | 3.52x | 1.06x |
| fnv | 4.339 | 0.573 | 0.564 | 0.567 | 0.581 | 0.568 | 7.275 | 2.602 | 7.47x | 1.02x |
| matmul | 1.259 | 0.244 | 0.215 | 0.212 | 0.278 | 0.217 | 5.337 | 1.651 | 4.52x | 1.15x |
| nbody | 0.697 | 0.213 | 0.106 | 0.108 | 0.128 | 0.070 | 1.740 | 1.074 | 5.44x | 3.03x |
| sieve | 2.785 | 0.874 | 0.813 | 0.824 | 0.812 | 0.827 | 4.640 | 2.426 | 3.43x | 1.08x |
| sort | 2.482 | 1.258 | 1.026 | 1.132 | 1.135 | 1.371 | 6.093 | 3.917 | 2.19x | 1.23x |
| xform_f32 | 0.464 | 0.124 | 0.019 | 0.022 | 0.114 | 0.019 | 1.102 | 0.240 | 4.06x | 6.60x |
| xform_f64 | 0.359 | 0.144 | 0.045 | 0.052 | 0.129 | 0.034 | 1.162 | 0.249 | 2.79x | 4.19x |
| ffi_call (ns per call) | 2.41 | 2.00 | 1.95 | 1.57 | 20.83 | 1.75 | 5.74 | 2.79 | 0.87x | 1.28x |

**Where the release bar is met**: fnv, dot_f32, dot_f64 (within 6 %, which is the noise of this
host), sieve (8 %, borderline). ffi_call is 1.03x of C; Rust's loop around the call is tighter.

**Where it is missed, and why** (read from the generated code, `objdump` of the `.ll.o`):

- **xform_f32 6.6x, xform_f64 4.2x: the loop is not vectorised.** C, Rust and Zig emit packed
  `mulps`/`mulpd`; Grail's `scale_add` is scalar. Each iteration re-reads both slices' lengths and
  data pointers from their headers (`cmp 0x8(%rdi),%r15`, `mov (%rdi),%rcx`) and keeps both bounds
  checks inside the loop, because the store to `x[i]` may, as far as LLVM is told, alias those
  headers: the lifted IR has no provenance and no `noalias`. A loop whose bounds checks cannot be
  hoisted cannot be vectorised. This is item 4 of "What stands between here and the claim". Go,
  which does not vectorise either, is at 0.114/0.129: Grail is near Go here, not near C.
- **nbody 3.0x**: the same reloads in the inner `k` loop - after every store to `v[...]` the data
  pointers and lengths of `p`, `v` and `m` are loaded again and about eight bounds checks run per
  iteration. C and Zig have fixed-size arrays (Zig, at 0.070, unrolls the whole pair loop); Grail's
  `f64[...]` literal is a heap vector. Items 4 and 5.
- **sort 1.23x**: per merged element, 4 to 5 bounds checks and a reload of both vectors' headers
  after the store into `tmp`. Item 4.
- **matmul 1.15x**: the inner product reloads `a`'s and `b`'s headers and checks both indices each
  step; the sum itself is a serial `mulss`/`addss` chain in every language (strict IEEE), so the
  gap is the checks and reloads. Item 4.

**Where the development bar is missed - everywhere but ffi_call** (2.2x to 7.5x the best of Go,
Rust dev and Zig Debug; Grail-native is faster than Rust's dev profile on every row and slower than
Zig Debug and Go on every row but ffi_call). The native backend's code, read from its `.s`:

- **A widening integer conversion is a runtime call.** fnv's `u64(data[i])` compiles to `movzbq`
  and then `call rt_int_cast` per byte: 61.5 G instructions retired against Go's 6.2 G and Zig
  Debug's 27.4 G (about 107 per byte against Go's 11).
- **`f32` arithmetic goes through `f64`.** Every `f32` multiply is `cvtss2sd`, `mulsd`, `cvtsd2ss`,
  with the value moved through a general register between steps (xform_f32, dot_f32, matmul).
- **Every access is bounds-checked against a length re-read from memory**, and loop variables live
  in stack slots (`incq -56(%rbp)`, `movq -104(%rbp),%rcx` in fnv's loops).

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
