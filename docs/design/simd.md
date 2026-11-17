# SIMD types: the decision record

Status: S1 built (branch `gaps16-simd`). S2-S6 approved and staged below. This supersedes the
SIMD parts of `simd-layout-parallel-loops.md` where they differ (marked), and the
pre-design note of the same name from commit ac15c72.

## The decisions

The director approved these on 2026-11-17. The four marked ⚠ change earlier decisions.

- **Types.** `f32x4` `f32x8` `f64x2` `f64x4` `i32x4` `i32x8` are built in (S1). `u8x16` `u8x32`
  `u32x4` `i64x2` come in S2. Masks `m32x4` `m32x8` `m64x2` `m64x4` (and `m8x16` `m8x32` in S2) are
  the result of a comparison.
  - A vector is a plain value. It is Copy, has no drop, and is a frame aggregate of 16 or 32 bytes
    with its lanes packed.
  - `align_of` is the element's, so `[f32x4; N]` overlays `[f32; 4N]`.
  - The 256-bit types exist on every target. A 128-bit-only target computes them as two halves.
- **Arrays are storage; vectors are values** (`fixed-arrays.md` §6). Getting lanes in and out is
  explicit:
  - `T::load(src, i)` and `v.store(dst, i)` take a slice (`&[T]`, `&mut [T]`) or an array reference
    (`&[T; N]`, `&mut [T; N]`).
  - There is one bounds check per vector: the last lane's index is checked as `src[i + lanes - 1]`
    would be. An `i` so large that the sum wraps fails the same check.
  - A vector of elements (`T[]`) is reached through `&v[:]`.
- **⚠ Aligned loads** (supersedes §2.1, "no aligned form"). `load_aligned`/`store_aligned` exist
  from S2 as a checked contract: one test and branch, and a misaligned address aborts with the
  address. It is never undefined behaviour.
- **Operations** (S1):
  - lane-wise `+ - * /` on floats, wrapping `+ - *` on integers, `& | ^` on integers and masks;
  - `min`/`max`;
  - compares `eq ne lt le gt ge` returning masks;
  - `mask.select(a, b)`, `mask.any()`, `mask.all()`, `mask.not()`;
  - `splat`, `new(lanes...)`, `lane(K)` with K a literal;
  - `sum`.
  - S2 adds shuffles, swizzles, conversions, `bits()`, and mask construction from bits.
  - A comparison operator on vectors is an error naming the method. A lane-wise compare is a mask,
    and `a < b` reading as a bool would be wrong.
- **Semantics are the scalar operation's, lane by lane**:
  - Compares are ordered except `ne`.
  - `min`/`max` follow the scalar rule (a NaN operand gives the other; a tie gives the first, so
    `min(+0.0, -0.0)` is `+0.0`).
  - Integer arithmetic wraps.
  - `sum` is the fixed halving tree: lane i of each level is `l[i] + l[i + n/2]`, down to one lane.
    It is what an SSE/NEON horizontal add does, and it is bit-identical on every target and
    backend.
- **⚠ `mul_add`**, approved for S4. It is fused and exact everywhere. Baseline x86-64 (no FMA) uses
  a correct software sequence, as C's `fma()` does through libm, documented as slow there. A
  `--cpu` level with FMA uses `vfmadd`.
- **⚠ ABI timing.** Inside Grail a vector is a frame aggregate.
  - A 16-byte vector is returned as two words in `%rax:%rdx`. The words cross through
    `simd.topair`/`simd.frompair`, so the storage stays vector-typed.
  - A 32-byte vector is returned through the destination the caller passes.
  - Arguments are passed by hidden pointer.
  - Lifted LLVM functions see SSA `<N x T>` values. Native register passing comes in S5;
    `extern "C"` vector types (`__m128` and friends, `float32x4_t`) in S4.
- **⚠ Runtime dispatch** (S6). A `@target(avx2) fn` is reachable only from another such function or
  under `if cpu::has(.avx2)`, a compiler-checked guard. Before that, S4 has build-wide `--cpu`
  levels exposed as `target.features`.

## As built (S1)

The front end writes each operation as one stream line, `simd.OP SHAPE [K]`, with fixed registers:
- the destination vector's address in `%rdi`;
- the operands' addresses in `%rsi`, `%rdx` and `%rcx`;
- a scalar in or out in `%rax`.

The lowerings:
- **LLVM** (`llvm.grl` `lift_simd`) turns each line into vector IR: `load <4 x float>`, `fmul`, a
  `select` chain for min/max, `fcmp`+`sext` for masks, `shufflevector` halving for `sum`. clang then
  picks SSE2, AVX or NEON.
- **Native** (`machine.grl` `simd_expand`) lowers each line to scalar lanes on x86-64, AArch64 and
  RV64. It uses only the instructions scalar code already uses, so the internal assemblers need
  nothing new.
  - On x86-64 the lines are expanded as the text is written, or by the in-process assembler as it
    reads them.
  - On AArch64 and RV64 they are expanded in `machine::lower`.

Packed SSE2/NEON for the native backend is S3.

A `simd.` line is an unknown instruction to the text optimiser (`ir.grl`), as an `atom.` line is.
Nothing is forwarded or moved across it.

**What it took to keep vectors in registers** (`tools/test-simd.mjs` pins the result):
1. Assignment copies lanes into the variable's own storage (`simd.copy`). Rebinding to fresh words
   made the variable's address a phi of two allocas.
2. Frame copies of vectors are `simd.copy` lines, not word moves, so every access to the storage is
   `<N x T>`.
3. The lifter forgets a `simd.` line's address registers after it. Otherwise it passes them to every
   later call as arguments, the cold `rt_trap` of an overflow check included, and the allocas
   escape.
4. 16-byte results cross as `topair`/`frompair` bitcasts, not i64 stores into the vector's storage.
5. Slice loads use the typed accessors `rt_slot4`/`rt_slot` with their header fact. The lifter then
   reads `data` and `len` once, outside the loop, and a loop bound of the shorter length lets LLVM
   drop both checks.

**Measured** (x86-64, `bun tools/bench-simd.mjs`): the dot product of two 4096-element `f32`
slices, one accumulator, against `bench/simd_dot.c` with SSE2 intrinsics and the same horizontal
sum (clang -O2, heap arrays, a length clang cannot see). Both are one `movups`×2 / `mulps` / `addps`
loop.
- On one core of the shared machine (load 65), the fastest of 21 runs: Grail with LLVM 0.179 ns per
  element, C 0.171 (1.046×); medians 0.194 and 0.184 (1.054×). That is within S1's interim 10%;
  S2's target is 5%.
- The native backend's scalar lanes take 3.5 ns per element, about 20×. That is S1's expected cost,
  until S3.
- The three builds compute the same dot product.

**Tested**:
- `tests/simd/oracle.grl` checks every S1 operation on every S1 type lane by lane against the scalar
  operation, on signed zeros, infinities, NaN, subnormals, the largest finite values and i32
  wraparound. 0 lanes differ, and the checksum of every lane's bits is identical on x86_64, aarch64
  and riscv64 with both backends. A copy with one wrong reference reports 100 differing lanes.
- The corpus has `simd-*` (basics, oracle, the inlined loop, the bounds check, five rejections).
- `tools/test-simd.mjs` fails on any stack access in the loop. The compiler before change 4 above
  fails it.

Found on the way: `same_type` did not compare an `Atomic<T>`'s element, so an `Atomic<u8>` passed
for an `Atomic<u64>` (`atomic-element-is-part-of-the-type`).

## Stages

Each stage lands through the landing service.
- **S1 (this):** the types above; arithmetic, compare, select, min/max, splat/new, load/store, sum,
  lane, mask any/all/not; LLVM vectors; native scalar lanes; the oracle; the dot benchmark.
- **S2:** `u8x16` `u8x32` `u32x4` `i64x2` `m8x*`; shuffles and swizzles; conversions and `bits()`;
  `load_aligned`/`store_aligned`; the mat4 and AoS-to-SoA benchmarks; LLVM parity within 5% on all
  three.
- **S3:** native packed SSE2 and NEON for `simd.` lines (the internal assemblers learn their
  encodings); RV64 stays scalar lanes.
- **S4:** `extern "C"` vector ABI; `--cpu` levels and `target.features`; `mul_add`.
- **S5:** native vector registers and register passing.
- **S6:** `@target` with `cpu::has` dispatch.
