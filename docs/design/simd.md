# SIMD types: the decision record

Status: S1-S3 and S4a (`mul_add`) built. S4b (`--cpu` levels), S4c (the `extern "C"` vector ABI), S5 and S6 approved and staged below. This supersedes the
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

## As built (S2)

**Types added.** `u8x16` `u8x32` `u32x4` `u32x8` `i64x2` `i64x4`, and the masks `m8x16` `m8x32`.
- Unsigned lanes compare and order as unsigned: `lt`/`le`/`gt`/`ge`, `min`/`max`.
- A lane is read zero-extended, as a `u8` or `u32` word is held.
- `u8` lanes wrap at 8 bits, `sum` included.

**Operations added.**
- **Shuffles.** `v.shuffle(i0, .., iN-1)` makes lane j v's lane i_j. `v.shuffle2(w, ..)` indexes v
  followed by w, so indices are below 2N. Indices are literals checked at compile time. In LLVM IR
  they are one `shufflevector`, which clang turns into `shufps`, `unpcklps` and `movlhps` as the
  pattern allows. Natively they are lane copies.
- **Conversions.**
  - `to_f32()` on i32 lanes gives the nearest f32.
  - `to_i32()` on f32 lanes truncates toward zero and saturates to the i32 range; a NaN lane is 0.
    That is LLVM's `fptosi.sat` semantics, written as `fptosi` and three `select`s. The selects are
    defined for out-of-range lanes because the poison lane is never the chosen operand.
  - `bits()` reinterprets f32 lanes as u32 and f64 lanes as i64. `T::from_bits` goes back.
- **`load_aligned`/`store_aligned`** (decision 1 above). One `and`/`cmp`/`je` on the address, and a
  misaligned address fails with `address A is not N-byte aligned` (`rt_fail` kind 20). Only then is
  the access an aligned one to LLVM (`copya`, `copyd`: the source, respectively the destination,
  aligned to the vector's size; the frame side keeps the element's alignment).
- **Arrays.** Agreed with /root/fixed_arrays: an array keeps its element's alignment. An
  alignment request on an array field waits for a benchmark that needs one (AVX loads splitting
  cache lines, S4); until then aligned access stays the user's checked contract.

**Measured** (x86-64; `bun tools/bench-simd.mjs` for time, callgrind for instructions; the machine
was at load 50-77, where instruction counts are the steadier figure). The twins are
`bench/simd_{dot,mat4,aos}.c`: SSE2 intrinsics, the same operations in the same order, heap arrays
and a count clang cannot see. Every build computes the same result.

| benchmark | Grail LLVM / C, instructions | time, fastest of 21 | time, median |
|---|---|---|---|
| mat4: 1024 column-major 4x4 products | 74.0 / 71.0 per matrix = 1.04 | 0.71x | 1.10x |
| aos2soa: 4096 xyzw records to 4 arrays | 7.0 / 6.0 per record = 1.17 | 1.12x | 0.98x |
| dot (S1): 4096 elements | 2.09 / 1.19 per element = 1.75 (clang unrolls 4x around the same dependency chain) | pinned in S1: 1.046x | 1.054x |

- mat4's inner loop is clang's for the intrinsics: `movups` ×5, `shufps` ×4, `mulps` ×4, `addps` ×3
  per column.
- aos2soa's loop is C's instruction for instruction: four loads, `unpcklps`/`unpckhps`/`movlhps`/
  `movhlps`, four stores. It adds one bound compare and the overflow branch of `j += 16`, three
  instructions per four records. Both bounds are stated in the loop condition, each in the form its
  accesses index by (`j + 16 <= src.len()`, `i + 4 <= n`). A bound written through `src.len() / 4`
  leaves four checks in the loop, because LLVM cannot carry it through the division.
- The native backend's scalar lanes are 20-37x C, as expected until S3.

**Tested.**
- `tests/simd/oracle2.grl`: u8x16, u32x4 and i64x2 against the scalar operations on edge values;
  shuffles against their index tables; `to_i32` against the truncate/saturate/NaN rule and `to_f32`
  against the scalar conversion; `bits`/`from_bits` round trips. 0 lanes differ on all three targets
  and both backends, and a broken reference reports 284.
- Corpus: `simd-s2-surface`, `simd-oracle-s2`, `simd-load-aligned-checks-the-address`, and three
  rejections.

## As built (S3a: native SSE2 on x86-64)

`machine.grl` `simd_x86_packed` lowers each `simd.` line to packed SSE2 when SSE2 gives exactly the
result the scalar lanes give, and otherwise falls back to the lanes.
- **Packed:** lane arithmetic (`addps`/`subps`/`mulps`/`divps`, the `pd` forms, `paddb`/`paddd`/
  `paddq` and the subtracts), `andps`/`orps`/`xorps` for bitwise ops and masks, compares
  (`cmpps`/`cmppd`, signed `pcmpgtd`/`pcmpgtb`, `pcmpeq`), select and mask `not`, `splat`
  (`shufps`/`pshufd`/`movlhps`), the float `sum` as the same halving tree
  (`movhlps` + `add`, then `shufps $85` + `addss`), copies, `any`/`all` through `movmskps`/
  `pmovmskb`, and `to_f32` (`cvtdq2ps`).
- **min/max** on floats keep the scalar rule: `cmpps $1` selects the smaller, then two `cmpps $3`
  (unordered) masks give a NaN operand's partner. `minps` would return the second operand for a NaN
  and for ±0 ties, so it is not used. Unsigned bytes use `pminub`/`pmaxub`; i32 uses
  `pcmpgtd` + blend.
- **4x32 shuffles** are one `shufps` when each half of the result comes from one operand, and two
  through a gathered register otherwise. That covers broadcasts, `unpck`-style interleaves and
  `movlhps`/`movhlps`.
- **Still scalar lanes** (SSE2 has no exact instruction): i32/i64 multiplies, unsigned and 64-bit
  integer compares, `to_i32` (saturating), lane reads, 8-lane or 64-bit shuffles.

Every load is a `movups` into a register: a legacy SSE memory operand must be 16-byte aligned, and
a vector's storage is aligned to its element. The internal assembler encodes the new forms. The 42
forms in the test file, including high registers and immediates, are byte-identical to clang
(`tools/asm-oracle.mjs`). The corpus's SIMD cases pass with `GRAIL_ASM_ORACLE=1`.

**Measured** (native, x86-64, fastest of 7 runs against the C twins, at load ~60):

| benchmark | S1/S2 scalar lanes | S3a SSE2 |
|---|---|---|
| dot | ~20x C | 8-10x C |
| mat4 | 37x C | 7.5x C |
| aos2soa | 25x C | 10-17x C |

The remaining gap is that every native vector op goes through memory: two `movups` loads and one
store per operation, and the stream's vectors live in frame slots. Keeping vectors in xmm registers
across ops is S5. The LLVM backend is unchanged.

## As built (S3b: native NEON on AArch64)

`machine.grl` `simd_a64_packed` is the AArch64 counterpart of S3a, with the same coverage. It uses
`ldr q`/`str q` and v0..v5 as scratch: the optimiser keeps floats in v17..v23 and the conversions
use d16.
- **Packed:** lane arithmetic (`fadd`/`fsub`/`fmul`/`fdiv`, `add`/`sub`, `mul` for 8- and 32-bit
  lanes), `and`/`orr`/`eor`, compares (`fcmeq`/`fcmgt`/`fcmge`, `cmeq`/`cmgt`/`cmge`, unsigned
  `cmhi`/`cmhs`, `not` for `ne`), select (`bsl`), splat (`dup`), copies, `to_f32` (`scvtf`),
  integer min/max for 8- and 32-bit lanes (`smin`/`smax`/`umin`/`umax`).
- **Float min/max** use `fcmgt` + `bsl`, then `fcmeq a,a` + `bsl` for a NaN `a`. NEON's `fmin`
  propagates NaN, which the scalar rule does not.
- **`any`/`all`:** `umaxv`/`uminv` over the mask's bytes. A mask lane is all ones or all zeros, so
  that answers for any lane width.
- **The float `sum`:** `ext #8` + `fadd`, then `faddp`. That is `(l0 + l2) + (l1 + l3)`, the same
  tree as every other lowering.
- **Still scalar lanes:** 64-bit multiplies and min/max, `to_i32`, lane reads, shuffles. NEON's `tbl`
  needs an index vector from memory; the shuffles the benchmarks use (`zip`/`uzp`/`ext`/`dup`) are
  the next step if AArch64 native shuffles matter.

`asm_a64` learned the `q` registers, `vN.T` and `vN.T[K]` operands, and these forms. The 41 forms of
the test file are byte-identical to clang's, and so is the aarch64 SIMD corpus
(`tools/asm-oracle.mjs --target aarch64`). Both SIMD oracles and every `simd-*` case give the same
results under qemu-aarch64 as on x86-64 and with LLVM. RV64 stays on scalar lanes (the V extension
is not in the RV64GC baseline).

There are no native timings for AArch64: under qemu-user they measure the emulator, not the code.
The x86-64 numbers above show what packed code buys over the lanes.

## As built (S4a: `mul_add`)

`a.mul_add(b, c)` on f32 and f64 vectors computes `a * b + c` in each lane with one rounding, and
gives the same bits on every target and backend:
- **AArch64:** NEON `fmla`.
- **RV64:** `fmadd.s`/`fmadd.d` per lane. RV64GC has them in F and D.
- **LLVM on those two:** `@llvm.fma.v4f32` and friends, which lower to the same instructions.
- **Baseline x86-64:** it has no fused instruction, so each lane calls the runtime's software fused
  multiply-add, `rt_fma32`/`rt_fma64`. That is what C's `fma()` does there through libm. Calling
  per lane also keeps LLVM from turning `llvm.fma` into a call to a libm the program does not link.

The software routine uses integers only:
- the exact product of the significands is 128 bits, built from 32-bit halves;
- `c` is aligned to it with a sticky bit;
- the sum is rounded once to nearest-even, with subnormals and overflow;
- infinities, NaN and zero products are decided on the bits, and exact cancellation gives +0.

It is slow, tens of instructions per lane, and documented as such. `--cpu` levels with FMA use
`vfmadd` (S4b).

**Tested.** `tests/simd/fma.grl` runs 200,000 f32 and 100,000 f64 lanes against
`tests/simd/fma_reference.c` (C's `fmaf`/`fma` on the host): random bit patterns, edge values
(zeros, infinities, NaN, subnormals, the largest finite values) and `c = -(a * b)`. With that `c`
the result is exactly the product's rounding error, so an unfused multiply-add gives 0 and fails.
The checksum is identical on x86_64, aarch64 and riscv64 with both backends. `fmla` and the RV64 R4
`fmadd` encodings are in `tests/asm/simd-aarch64.s` and `simd-riscv64.s` (byte-identical to clang),
together with S3b's NEON forms.

## As built (S4b: `--cpu` levels)

`grail build --cpu=x86-64|x86-64-v2|x86-64-v3|x86-64-v4|native`. `native` reads the machine's flags
from /proc/cpuinfo.
- The driver packs the level into the build flags. The compiler receives `--cpu=x86-64-vN`, which is
  in the cache key. A release build's clang gets `-march=x86-64-vN`.
- Every lifted function says `"target-cpu"="x86-64-vN"`, because a ThinLTO link's code generation
  does not see `-march`; without it `llvm.fma` became calls to libm's `fma`/`fmaf`.
- `@if target.features.NAME` answers by target and level: x86-64-v2/v3/v4 per the psABI, `neon` and
  `fma` on AArch64, `d` and `fma` on RV64. An unknown name is an error that lists the known ones.
- At v3 and above, `mul_add` is `vfmadd231ps`/`pd` natively (VEX-encoded by the internal assembler,
  in `tests/asm/simd-x86_64.s`) and `llvm.fma` under LLVM. `tests/simd/fma.grl` still matches C on
  both.
- Other targets refuse `--cpu`.

Not done: the `extern "C"` vector ABI (S4c), stopped here by the wrap-up order.

## Stages

Each stage lands through the landing service.
- **S1 (this):** the types above; arithmetic, compare, select, min/max, splat/new, load/store, sum,
  lane, mask any/all/not; LLVM vectors; native scalar lanes; the oracle; the dot benchmark.
- **S2 (built):** `u8x16` `u8x32` `u32x4` `i64x2` `m8x*`; shuffles; conversions and `bits()`;
  `load_aligned`/`store_aligned`; the mat4 and AoS-to-SoA benchmarks. Swizzle sugar (`.xyzw`) is
  left for when a program wants it; `shuffle` covers it.
- **S3 (built):** native packed SSE2 (S3a) and NEON (S3b) for `simd.` lines (the internal assemblers
  learn their encodings); RV64 stays scalar lanes.
- **S4:** `extern "C"` vector ABI; `--cpu` levels and `target.features`; `mul_add`.
- **S5:** native vector registers and register passing.
- **S6:** `@target` with `cpu::has` dispatch.
