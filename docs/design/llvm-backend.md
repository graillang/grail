# LLVM backend

Status: design, 2026-11-09. Approved direction: LLVM is the optimizing backend; the native
backend stays for fast debug builds and bootstrap. The LLVM version is pinned (system 23.x).

## Why

Measured on the cluster LOD builder (`grail-meshopt` `clod::build`, four builds of a 4 600-triangle
mesh, identical output): C++ `-O2` 0.027 s, Grail 6.3 s, about 230x. The optimised Grail code for
`clod::edge_sq` (three subtractions and a sum of squares) is about 220 instructions:

- every value lives in an 8-byte frame slot and is reloaded around each operation; `optimize.grl`
  promotes only a few hot slots to callee-saved registers and has no register allocator;
- every floating-point operation is a call: `rt_f64_op(op, a, b)` dispatches on an operation code
  to `raw_fadd`/`raw_fmul`/..., and every `f32` result is rounded by a further `rt_f32_round` call
  (998 and 772 call sites in that program; only ten float instructions are inline);
- every element of a non-byte vector is an 8-byte word, so `f32[]` and `u32[]` use twice the
  memory and bandwidth of C;
- index arithmetic is overflow-checked and every access is bounds-checked, with nothing hoisted
  out of loops.

Baseline from `tools/bench.mjs` (native backend, best of three, outputs identical to C):

| benchmark | C `-O2` | Grail native | ratio |
| --- | --- | --- | --- |
| fnv (byte loop, wrapping multiply) | 0.682 s | 50.155 s | 73.6x |
| matmul (256x256 `f32`) | 0.268 s | 84.363 s | 315.0x |
| nbody (`f64`) | 0.147 s | 3.960 s | 26.9x |
| sieve (bytes, bounds checks) | 0.805 s | 14.019 s | 17.4x |
| sort (`u64` merge sort) | 1.207 s | 3.491 s | 2.9x |

## Where LLVM plugs in

The front end emits a closed word-machine instruction stream spelled as x86-64 (NATIVE.md,
*Implementation boundary*). `optimize.grl` rewrites it and `machine.grl` lowers it to AArch64 and
RV64. The LLVM backend is a third lowering of the same stream, in `compiler/llvm.grl`, emitting
textual LLVM IR that `clang -O2 -c` turns into an object for any target LLVM supports.

Stage 1 lowers the stream as it is:

- each Grail function becomes an LLVM function; machine registers and the frame become allocas
  that `mem2reg`/SROA promote, so LLVM's register allocator, inliner, GVN and loop passes apply;
- flags are modelled explicitly: a compare records its operands and the following `jcc`/`setcc`
  becomes an `icmp`; checked `+ - *` sequences become `llvm.*.with.overflow` plus a branch to the
  abort path, so the checks stay but become cheap and hoistable;
- memory accesses are `load`/`store` of the stream's widths through `inttoptr`; no `nsw`/`nuw`,
  no fast-math flags, `-ffp-contract=off` semantics (no FMA formation), so results stay
  bit-identical with the native backend;
- the private calling convention (up to six words in, one or two out) becomes LLVM's C
  convention for Grail-to-Grail calls; extern C calls keep the ABI lowering the front end already
  performs;
- atomics map to LLVM atomics; `raw_syscall`, `raw_win32` and the thread pointer become
  target-specific inline asm; functions that switch stacks (`raw_switch`, `raw_thread_clone`)
  stay native assembly linked alongside.

### Prototype results (2026-11-09)

A throwaway Python lowering of the raw stream (no `optimize.grl`) to LLVM IR, compiled with
`clang -O2` and linked with the functions it could not lift (stack switching, `%rsp` users,
indirect calls, jump-table targets) as native assembly, produced identical output on all five
benchmarks:

| benchmark | C `-O2` | native | LLVM | LLVM vs native | LLVM vs C |
| --- | --- | --- | --- | --- | --- |
| nbody | 0.147 s | 3.960 s | 1.339 s | 3.0x faster | 9x |
| matmul | 0.268 s | 84.363 s | 1.393 s | 61x faster | 5x |
| sort | 1.207 s | 3.491 s | 2.590 s | 1.3x faster | 2.1x |
| sieve | 0.805 s | 14.019 s | 3.567 s | 3.9x faster | 4.4x |
| fnv | 0.682 s | 50.155 s | 4.903 s | 10x faster | 7x |

What mattered, in order:

1. Lifting the runtime too (drop helpers, allocator, atomics as LLVM atomics, `syscall` as inline
   asm) so LLVM can inline element access and push; until then hot loops called native code and
   LLVM was slower than the native backend.
2. Check failures as a `noreturn cold` call: with six-argument `rt_abort` calls, the element
   accessor `rt_slot` cost 260 against an inline threshold of 225.
3. `internal` linkage for functions native code does not name.
4. `rt_f32_round` (a 199-line software rounding routine called after every `f32` operation) as
   `fptrunc` + `fpext`, which rounds identically: matmul 9.76 s -> 1.39 s.

Requirements found on the way: LLVM may emit `memset`/`memcpy` calls, so the backend supplies
them (Grail programs have no libc); `.L` data labels and inline constant pools must be renamed or
hoisted before two objects can link; debug sections that name function-local labels keep those
functions native.

The remaining gap to C is front-end output: a view allocated and freed per byte access in some
loops (fnv), 8-byte elements for `f32[]`, and bounds checks without loop versioning.

Stage 2 carries type information into the stream so both backends benefit: inline float
arithmetic (no `rt_f64_op`), real `f32` values instead of rounded binary64 words, 4-byte
elements for `f32[]`/`u32[]`/`i32[]`, and pointer-typed loads so LLVM's alias analysis works.

Stage 3, only if measurements still demand it: a typed SSA IR emitted directly by the front end.

## Verification

- A benchmark suite (`tools/bench.mjs`) times Grail against C `-O2` on meshopt simplify, clod,
  JPEG/PNG decode, zlib inflate and the Borg wire codec, and records the ratio per backend.
- The LLVM backend must pass the full native suite (660 cases) and every package suite, and
  produce byte-identical program output to the native backend.
- Self-compilation through LLVM must produce a compiler whose output matches the native-built
  compiler's output byte for byte.

## Not in scope here

LLVM does not change Grail's semantics: overflow and bounds checks, ownership checks and the
deterministic float rules all stay.
