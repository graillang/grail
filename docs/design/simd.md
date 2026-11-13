# Portable vectors (`lib/simd.grl`)

Status: **design only, not implemented.** This note is the decision record for the SIMD workstream
item: what the facility is, how each target would lower it, and what has to be true before the packed
path is turned on. Nothing in the tree implements it yet, and no program can call it, so nothing in
the tree is wrong about it either.

## The shape of the facility

Grail has no 128-bit value type and no generic parameter over a lane count, so the facility is
*monomorphic types plus free functions*, one type per (element, lane) pair, in the stdlib:

| type | lanes | element | size | alignment |
| --- | --- | --- | --- | --- |
| `simd::Vec4f` | 4 | f32 | 16 B | 16 B |
| `simd::Vec2d` | 2 | f64 | 16 B | 16 B |
| `simd::Vec4i` | 4 | i32 | 16 B | 16 B |
| `simd::Vec16u8` | 16 | u8 | 16 B | 16 B |

Each is a plain value (a record of 16 bytes, no aliasing, drop-free, `transferable`), so it copies and
moves like an `f64` pair and cannot point into anything. `load`/`store` take the same views slices
take (`&[T]`, `&mut [T]`) and require `offset + lanes <= len`, checked like a slice chunk, so a vector
load never reads past a view. A `&[T]` element-slice view (the loop-carried form) is a slice whose
`len` is a multiple of the lane count; the API's `chunks(lanes)` is the documented way to get one.

Operations, per element kind - all as free functions so the names are explicit about the lanes:

- arithmetic: `add`, `sub`, `mul`, `div` (floats), `min`, `max`, and for integers the saturating
  `add_sat`, `sub_sat`;
- comparisons producing a mask of all-ones/all-zeros lanes: `lt`, `le`, `eq`, `gt` (with `select` to
  apply a mask, `and`/`or`/`xor`/`not` for mask and integer bitwise work);
- movement: `splat`, `load`, `store`, `shuffle` (a compile-time lane permutation), `select`,
  `reduce_sum`, `reduce_min`, `reduce_max`;
- `Vec16u8` alone: `eq` + `movemask` (`u32`, one bit per lane), which is what makes a memchr scan
  possible.

Every operation is *element-wise with lane order preserved*, and every floating-point operation rounds
once per lane exactly as the scalar operation does, so `Vec4f` arithmetic has the same results as four
scalar `f32`s and a vectorised reduction differs from a scalar one only where the order of summation
differs - which is why the reduction is specified as a fixed tree (`((a0+a1)+(a2+a3))`), not as
"whatever the target does".

## Lowering

The front end already picks a lowering per target for every accessor it calls, so the vector builtins
follow the same route: the *front end* emits them (they are recognized like `rt_*` accessors), and the
portable fallback is the emitted scalar sequence, not a different source module.

| target | lowering | notes |
| --- | --- | --- |
| x86-64 (Linux, Windows, macOS) | SSE2 packed: `movaps/movups`, `addps/subps/mulps/divps/minps/maxps`, `paddd`, `paddb`, `paddusb`, `pminub`, `cmpps`/`pcmpeqd`, `por/pand/pxor`, `pshufd`, `movmskb`, scalar horizontal reduction | SSE2 is baseline on x86-64, so no feature detection and no `-mavx`; `align 16` on the stdlib's stack slots, `movups` for the view-taking forms since a slice's alignment is 1 |
| AArch64 | NEON packed: `ldr q`, `fadd/fmul/fmin/fmax v.4s`, `add v.4s`, `uqadd v.16b`, `cmeq/cmgt`, `tbl` for a lane shuffle, `addv` for the reduction | NEON is baseline on AArch64 v8 |
| RISC-V 64 | portable scalar fallback | no V extension assumed, so the lanes are four/four/two/sixteen scalar operations; `machine.grl` translates the scalar float ops it already handles |
| LLVM backend | `<4 x float>` and friends: `insertelement`/`shufflevector`/`fadd`/`fcmp`/`select`, `load <4 x float>`/`store` | the lifter has to learn the packed instructions as *typed vector* values; today an unrecognised instruction keeps the whole function on the native path |

The **fallback rule**: an operation with no packed lowering emits the scalar lane sequence, so every
target produces the same numbers and only the speed differs. A vector operation is therefore never
"silently wrong on an unsupported target", which is the property that makes a portable facility worth
having at all.

## Why it is not in the tree yet

The blocker is the value type, not the instructions. Grail values are one word; a 16-byte vector is
either a memory buffer (then every operation is a pointer triple, which the ownership rules make
awkward, and `Vec4f` stops being a plain value) or a new ABI class (two words, with its own passing,
returning, spill and drop rules in `native.grl`, `machine.grl`, `llvm.grl` and the interface form).
The second is the design above; it is a multi-day change to the ABI and the lifter, and landing half
of it (builtins over buffers, no ABI class) would produce a facility that is *called* SIMD but is a
pointer API with different aliasing rules - worse than not having one.

The first increment, when someone picks this up: the ABI class and `Vec4f` alone (record of four
`f32`s passed as one 16-byte value, `align 16`), `splat`/`load`/`store`/`add`/`mul`/`reduce_sum`,
SSE2 on x86-64 and the scalar sequence elsewhere, plus the numeric-equivalence tests and a
`bench/dot.grl` that measures the vector kernel against the scalar one. `Vec4i`, `Vec16u8` (and with
it memchr) and the NEON/LLVM lowerings follow the same shape once the ABI class is settled.

## Measurement it has to pass

`tools/bench.mjs dot` - a dot product over two `f32` arrays, 64M multiply-adds, kernel written twice
(scalar and vector) in one program - is the benchmark the increment should be judged on: the vector
kernel should be within ~10% of C `-O2 -ffp-contract=off` on x86-64, and the scalar kernel is what
the fallback costs. The equivalence test is not a benchmark: `tests/native-cases.json`'s
`simd-dot-matches-scalar` and `simd-memchr-matches-scalar` compare the vector path against a scalar
reference over a deterministic input set (powers of two, both signs of zero, denormals, all-ones
masks) and must be bit-identical for the `f32` operations.
