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
