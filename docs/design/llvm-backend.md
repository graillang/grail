# LLVM backend

Status: stage 1 integrated (`compiler/llvm.grl`, `--backend=llvm`) on Linux x86-64, AArch64 and RISC-V 64, 2026-11-09. Approved direction: LLVM is the optimizing backend; the native
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

### Integrated backend (stage 1)

`compiler/llvm.grl` implements the prototype's lowering in Grail. Through it every executable
native case (209) produces the same output and exit status, and the benchmarks run:

| benchmark | C `-O2` | native | `--backend=llvm` |
| --- | --- | --- | --- |
| fnv | 0.651 s | 50.155 s | 6.574 s |
| matmul | 0.255 s | 84.363 s | 2.142 s |
| nbody | 0.117 s | 3.960 s | 1.213 s |
| sieve | 0.718 s | 14.019 s | 3.718 s |
| sort | 1.071 s | 3.491 s | 2.674 s |

Self-compilation: the compiler built through `--backend=llvm` (1 053 of its functions lifted)
compiles the full compiler source to output byte-identical with the native-built compiler's
(28 851 897 bytes) in 7.9 s instead of 35.3 s. Lowering the compiler takes 597 s and `clang -O2`
190 s on the loaded build machine; making `llvm.grl` itself faster is the next item, since it
runs in the native-built compiler during bootstrap. Allocation-free register lookup took it to
499 s; sampling the rest shows allocator traffic, not lowering logic: every `view(x)` allocates and
later frees a heap descriptor (`rt_view`/`rt_slice`/`.D4`), and `view("...")` rebuilds and
UTF-8-checks its literal each time (`rt_string_lit`). Passing views as a pointer/length pair
without allocation is the first stage-2 item: it speeds every Grail program on both backends,
the compiler included, and is the same cost that dominates the fnv benchmark.

### After the first front-end and lowering fixes (2026-11-09)

Three changes after stage 1 closed most of the gap to C:

- `bytes[i]` with a simple index reads the sequence directly instead of building, borrow-tracking
  and freeing a temporary view per access (front end; both backends benefit);
- repeat literals `T[v; n]` replace push loops for zero-filled buffers (language);
- one `alloca` per frame slot when every frame access is a constant offset below rbp, so taking
  one local's address no longer pins the whole frame in memory (LLVM lowering).

| benchmark | C `-O2` | `--backend=llvm` | ratio |
| --- | --- | --- | --- |
| fnv | 0.581 s | 0.679 s | 1.2x |
| sieve | 0.616 s | 0.747 s | 1.2x |
| sort | 0.985 s | 1.458 s | 1.5x |
| nbody | 0.109 s | 0.248 s | 2.3x |
| matmul | 0.204 s | 0.657 s | 3.2x |

What remains is mostly `f32`: elements are 8-byte words holding binary64 values, so LLVM cannot
narrow `fptrunc(fmul double)` to a float multiply or vectorize 4-byte lanes. Storing `f32[]`
elements in 4 bytes (stage 2) fixes both.

On AArch64 and RISC-V the word machine returns rax:rdx in x9:x2 (t0:a2) while C returns in x0:x1
(a0:a1), so IR functions are defined as `NAME.ll`, native code reaches them through a thunk named
`NAME`, and IR reaches native functions through `NAME.c`; function addresses always name the
native-convention entry.

Stage 2 carries type information into the stream so both backends benefit: inline float
arithmetic (no `rt_f64_op`), real `f32` values instead of rounded binary64 words, 4-byte
elements for `f32[]`/`u32[]`/`i32[]`, and pointer-typed loads so LLVM's alias analysis works.

### Stage 2a: 4-byte elements

`f32[]`, `u32[]` and `i32[]` become narrow vectors: the same `{data, len, cap}` header, with `len` and
`cap` counted in elements and a 4-byte stride. Values in registers do not change (an `f32` is still
held as its binary64 value, integers as words), so only the element boundary moves:

- load: a 32-bit load, then `cvtss2sd` for `f32`, sign extension for `i32`, zero extension for `u32`;
- store: `cvtsd2ss` for `f32` (exact, because every held `f32` is already representable), the low
  32 bits for the integers; then a 32-bit store.

The element width is a property of the static type, so the compiler picks the narrow runtime routines
(`rt_push4`, `rt_fill4`, `rt_at4`, ...) the way it already picks `rt_pushb` for bytes; the header
carries no width. Ordering and equality compare the 32-bit units, which order exactly as the words
the same values occupy in a word vector.

References. Every element stays borrowable (`&mut v[i]`, `for x in &mut v`, a `&mut` to a narrow
field of an `extern "C"` record, and a byte of `u8[]`). A reference to a sub-word type (`f32`, `i32`,
`u32`, `i16`, `u16`, `i8`, `u8`) is a pointer whose top bit (63) says how its target is stored:

- clear: a word slot (a local, a Grail record field, a map value), read and written as 8 bytes, as
  every reference was before;
- set: narrow storage (a 4-byte element, a byte, a narrow C field), at the pointer with the bit
  cleared, read and written with the type's width and encoding.

User-space addresses have bit 63 clear on every supported target (Linux, Windows and macOS on
x86-64, AArch64 and RISC-V 64), whatever their alignment (a byte's address may be odd, so the low
bit is not free), and Grail never exposes a reference's address, so the bit is free. Only the three narrow places produce tagged references; every other reference is
untagged, exactly as before. Reading or writing through a sub-word reference tests the bit (a shift,
a `test` and a branch, which LLVM removes wherever the origin is visible). References to word types
are never tagged and their accesses are unchanged.

In the LLVM lowering a narrow load is `load float` + `fpext`, and a store is `fptrunc` + `store float`.
LLVM then narrows `fptrunc(fmul(fpext a, fpext b))` to `fmul float` and vectorises 4-byte lanes.

Measured (x86-64, `--backend=llvm`, loaded machine): matmul (256x256 `f32`) 0.605 s -> 0.239 s, 3.2x
-> 1.3x of C `-O2`; the `f64` benchmarks are unchanged. Until the bootstrap seed knows
`raw_load32`/`raw_store32`, the runtime's narrow routines (push, fill, copy, ...) compose 32-bit
accesses from bytes; compiled element reads and writes use one `movl` already.

Verification: the native suite on all three Linux targets and Windows, the package suites (meshopt and
clod are `f32[]`-heavy and bit-exact against C), the Abundance suite, and the benchmarks; output is
byte-identical before and after, because only storage changes.

Stage 3, only if measurements still demand it: a typed SSA IR emitted directly by the front end.

### Stage 2b: where the remaining gap is (measured)

After stage 2a the benchmarks stand at 1.0--1.2x of C except the two that mutate sequences in their
hot loop (`tools/bench.mjs`, x86-64, best of three). The gap there is not arithmetic, not loads and
not conversions: it is the per-element validation the front end emits for every checked access.

Two of the three checks are not bounds checks at all: they are the front end's *overflow* checks on
the address arithmetic (`s + 8` for the length field, `data + idx * 8` for the element), folded to a
constant compare where the addend is known. Addresses cannot wrap for an allocation the runtime
handed out -- user-space addresses have bit 63 clear on every supported target, the same axiom the
tagged references of stage 2a rest on -- so a front end that keeps pointer arithmetic apart from
integer arithmetic would emit both unchecked, leaving one compare and one branch per access. That
is a language and front-end decision, not something a lowering of the untyped stream can take: from the stream the
compare against `-8` and the `jb` after `addq` are indistinguishable from arithmetic on integers the
program is allowed to overflow-check, so eliding them here would silently weaken the checks the
front end asked for.

An element access is a fixed instruction sequence in the stream, and the lowering emits it as it
stands:

| stream | IR | purpose |
| --- | --- | --- |
| `movq <slot>,%rax; cmpq $-8,%rax; jae abort` | `load desc` / `icmp ult %desc, -8` / `br` | the descriptor is a real object pointer |
| `cmpq 8(%rax),%idx; jae abort` | `load len` / `icmp ult %idx, %len` / `br` | index in bounds |
| `movq (%rax),%rsi; addq %rsi,%off; jb abort` | `load data` / `add` / `icmp ult %addr, %data` / `br` | the element address does not wrap |

That is eight to nine machine operations per access, each with a dependent load (`slot -> header ->
element`) and three compare/branch pairs, against C's one addressing mode. `nbody` performs eight
such accesses per inner iteration and `sort` three to four per element moved.

To size the cost, the emitted IR was compiled with every branch to a check-failure block removed (a
measurement only: the outputs stay identical because no check fires on these programs):

| benchmark | `--backend=llvm` | checks removed | share of run time | floor vs C |
| --- | --- | --- | --- | --- |
| nbody | 0.256 s | 0.142 s | 44% | 1.34x |
| sort | 1.477 s | 1.172 s | 21% | 1.16x |
| fnv | 0.623 s | 0.601 s | 4% | ~1.0x |
| sieve | 0.660 s | 0.663 s | 0% | memory bound |
| matmul | 0.264 s | 0.425 s | none -- removal is *slower* | latency bound on the `addss` chain |

So `fnv`, `sieve` and `matmul` are already at their floor. `fnv`'s hash chain is a serial
`xor`/`imul` dependent chain, `sieve` stores with stride `i` and is memory bound, and `matmul`'s
inner loop is the serial single-precision `s += a * b` chain; deleting the check branches changes
nothing for the first two and actively mis-schedules the third (0.425 s), which is what a loop that
is latency bound and not issue bound looks like. Everything left is `nbody`
and `sort`, and it is all validation.

#### Why the lowering cannot remove the checks

The checks become cheap only if LLVM hoists them out of the loop, which needs the `len` and `data`
loads loop-invariant. Two things stand in the way, and both are properties of the stream, not of the
IR the lowering writes:

1. *Aliasing*: a store to an element could, as far as LLVM knows, write the descriptor it came from,
   so the header loads cannot be merged across a store. Element and descriptor storage are separate
   allocations by construction, but the word stream carries no type, so the lowering cannot say so.
   Tagging the accesses to model it was tried and does not work (below).
2. *Speculation*: even with perfect alias information LICM will not hoist a `load` from an
   `inttoptr` pointer, because it cannot prove the pointer dereferenceable, and without a hoisted
   `len` the bounds test is not loop-invariant, so no loop unswitching happens either.

Both are exactly the "type information carried into the stream" item that stage 2 introduced and
that stage 3 (a typed SSA IR emitted by the front end) is meant to supply. Loop versioning --
`if len >= 15` in front of the loop, the form a typed backend would use -- needs the same
information: with `i*3+k` derived from `for i in 5 { for k in 3 }`, the front end knows the largest
index, but it does not know the length at that point.

#### Measured and rejected

Each of these was applied to the emitted IR (or the driver) and measured on the five benchmarks;
none moved the numbers, so none is in the tree:

- `!tbaa` nodes separating element from descriptor accesses, and `!alias.scope`/`!noalias` on the
  same pair: no effect, for reason 2 above -- the loads are never hoisted even when they provably do
  not alias, and a `mem2reg` failure is not involved (`sort`'s descriptors already live in
  registers).
- `align 8`/`align 4` on word and narrow accesses instead of `align 1`: no effect anywhere
  (`-O2` already folds the address arithmetic into the operand; nothing vectorises differently).
- `nounwind` on every lifted function definition: no effect.
- `!prof` branch weights marking the check branches as cold: no effect.
- `llvm.loop.unroll.full` and `llvm.loop.unroll.count(N)` on the loop latches: ignored. The lowering
  emits a stream loop as a header with the exit test and an unconditional branch back, and this
  LLVM (23.x) drops the pragma from an unconditional latch.
- `-O3` instead of `-O2` for the `.ll`: 2--5% slower on `nbody` and `sort` (more inlining and
  unrolling of check-heavy code), so the level stays `-O2`.

What does move them is the unroller, which is both a cost and a size question and therefore a
policy decision rather than a lowering fix: `-mllvm -unroll-threshold=200000` fully unrolls the
`for i in 5 { while j < 5 { for k in 3 } }` nest of `nbody` (ten copies of the pair body, three of
the inner one), which lets LLVM CSE the `p[i*3+k] - p[j*3+k]` the source computes twice, merge the
redundant header loads and checks, and schedule the remaining dependent loads together: nbody
0.263 s -> 0.209 s (21% faster) and sort 1.549 s -> 1.448 s (6%), with `fnv` and `sieve` unchanged.
It is not adopted: `nbody`'s main function grows fivefold (513 -> 2493 instructions) and `clang`
takes several times longer on the module (the `matmul` module did not finish inside a ten-minute
budget), for a 21% win on one benchmark.

The lowering's own share of the loop is small. With the checks removed the only overhead left
against C is the representation: a sequence value is a pointer to a `{data, len, cap}` header, so an
access costs a slot load, a header load and the element access where C has one addressing mode
(that is the 1.34x floor of `nbody`); `sort`'s floor is 1.16x. A one-guard-per-straight-line-region
form (all the conditions of a run of accesses ANDed into one branch, the element loads after it)
would cut the block count per iteration without removing the compares, but it needs the same
"an element store cannot write the descriptor" fact to move a later access's check in front of an
earlier store, so it is blocked by the same missing type information.

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
