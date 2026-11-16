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
