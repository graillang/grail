# SIMD, memory layout and checked parallel loops

Status: design proposal, nothing implemented. Branch `gaps12-simd-design` from `gaps10-all` 78c8c6e.
Measured on an AMD Ryzen 9 7900X (24 threads), clang 23.1.4, Linux x86-64. A test gate was running on
the same machine (load average 20-35), so timings are best-of-5 and good to about +-15%; ratios of
3x and more are safe, smaller ones are not.

Every claim is marked **[V]** verified (file:line in this tree, or a probe whose output is quoted) or
**[A]** assumed. Probe sources are in the appendix.

## 0. Decisions for the owner

| # | Decision | Recommendation |
|---|---|---|
| D1 | Fix native-backend `f32` arithmetic before anything else? It is 370x slower than the LLVM backend today. | Yes, stage 0. It is the largest number in this note and needs no new language. |
| D2 | SIMD surface: fixed-width types, a portable-width type, or auto-vectorisation only? | Fixed-width value types (`f32x4`, `f32x8`, `f64x2`, `f64x4`, `i32x4`, `i32x8`, `u32x4`, `u32x8`) plus masks. No width-agnostic type in v1. |
| D3 | Which backend gets real vector code first? | LLVM first. Native gets a correct scalar-lane lowering in the same stage, real SSE2/NEON later, riscv64 stays scalar. |
| D4 | Are SIMD results bit-identical across backends and targets? | Yes: no fast-math, reductions have a specified lane order, no implicit FMA. This is what makes a scalar fallback legal. |
| D5 | Per-CPU specialisation? | One build-wide `--cpu=` level plus `target.features` in `@if`. No runtime dispatch in v1. |
| D6 | Alignment and packing: where is it allowed? | `align(N)` on `extern "C"` records, on flat records and on fields; `packed` on `extern "C"` records only. Plain Grail records keep "no promised layout". |
| D7 | Should vector buffers be cache-line aligned by default? | Yes: the allocator guarantees 64-byte alignment for payloads of 64 bytes or more. |
| D8 | SoA: language feature or library? | Library pattern (a record of columns). No `soa` keyword. |
| D9 | Parallel loops: teach the borrow checker index ranges, or construct disjointness in builtins? | Construct it: one N-ary builtin `parallel_for_zip` and `split_at_mut`. Range-aware loans only if those prove too narrow (stage 6, optional). |
| D10 | Dynamic ECS (component sets chosen at run time)? | Runtime borrow flags per column, in a library. Static columns (record fields) are checked at compile time. |

### Decided by the director, 2026-11-16

- **D1** yes, and wider: stage 0 (hardware `f32` rounding) plus stage 0b - a float operation on the
  native backend must not be a call at all. Both are being built on branch `gaps12-float`.
- **D2, D3, D4, D5, D6, D8, D10**: as recommended.
- **D7 / Q6**: 64-byte alignment is guaranteed for payloads of 512 bytes or more, not for every
  buffer of 64. It lands after the allocator fast-path rewrite on `gaps12-alloc`.
- **D9**: construct disjointness (`parallel_for_zip`, `split_at_mut` with the sibling-loan flag);
  range-aware loans stay deferred. The split is given as a **grain** (elements per piece), not a chunk
  count, matching `docs/design/concurrency-model.md` (branch `gaps12-concurrency-design`): recursive
  halving down to the grain, results combined in index order, a function of `(n, grain)` only.
  Stage 1 here waits for that design's stage 1 (jobs on the one scheduler).
- **Q1**: NaN payload bits are unspecified. A float result that is a NaN is a quiet NaN and nothing
  more is promised; tests compare bit patterns of non-NaN results and NaN-ness of the rest.
- **Q2**: multi-word values, SIMD included, go by hidden pointer in the first version; the
  unboxed-values note owns the rule.
- **Q3**: `mul_add` is absent in v1. **Q4**: no runtime CPU dispatch in v1. **Q5**: integer lanes
  always wrap, documented.

## 1. What exists

### 1.1 Float arithmetic, native backend

- **[V]** Every float value is one 64-bit word holding binary64 bits; an `f32` is held widened to
  binary64. A binary float operation is `call rt_f64_op` (`compiler/native.grl:13409-13416`), whose
  body dispatches on the opcode to `raw_fadd/fsub/fmul/fdiv` (`compiler/runtime.grl:4761`).
- **[V]** An `f32` result is then rounded by `call rt_f32_round`, which is *software*: integer shifts,
  a `rt_div` call and a bit-scan loop (`compiler/runtime.grl:5252-5287`). Disassembly of the probe's
  loop body on the native backend:
  `call rt_slot4; cvtss2sd; call rt_f64_op; call rt_f32_round; call rt_slot4; cvtss2sd; call rt_f64_op; call rt_f32_round; call rt_slot4; cvtsd2ss`.
- **[V]** `grail profile` of the 1M-element transform: `rt_f32_round` 53.2%, `rt_div` 42.5%,
  `rt_slot4` 2.2%, `rt_f64_op` 0.9%.
- **[V]** The SSE text that exists is scalar and x86-only: `movq %rax,%xmm0 ... addsd ... movq %xmm0,%rax`
  inside the `raw_f*` intrinsics (`compiler/native.grl:24958-24990`) and `cvtsd2ss`/`cvtss2sd` at
  narrow loads and stores (`native.grl:20537-20559`). For other targets the front end emits pseudo-ops
  (`fop add`, `cf32bits`; `native.grl:24995-24998`, `20544-20546`) that `machine.grl` expands
  (`fadd d0,d0,d1` at `machine.grl:1213`, `fadd.d ft0,ft0,ft1` at `:1251`). `rg -c xmm` gives 0 for
  `machine.grl`: it does **not** translate SSE text, so there is nothing to build vector translation on.
- **[V]** No packed/vector instruction is emitted anywhere (`rg 'addps|mulps|movups|paddd'` over
  `compiler/` finds nothing).

### 1.2 Float arithmetic, LLVM backend

- **[V]** `llvm.grl` lifts the same x86 word stream to IR. Typed facts carried beside the stream
  (`native.grl:436-449`, `docs/design/typed-ir.md` F1/F2) let it rewrite an `rt_f64_op` on two `f32`
  operands into `fmul float`/`fadd float` (`llvm.grl:1885-1955`) and keep `f32` slots as
  `alloca float`. The probe's inner loop after `clang -O2` is `movss; mulss; movss; addss; movss`.
- **[V]** `f64` code on this backend is worse than `f32` code: the same loop over `f64[]` keeps
  `rt_fail` calls and stack spills in the body (disassembly, appendix probe `xd`).

### 1.3 Does `clang -O2` vectorise a Grail loop today? No.

Probe `xform.grl`: `x[i] = x[i] * a + y[i]` and `s = s + x[i] * y[i]` over `&mut [f32]`/`&[f32]`,
n = 1 000 000, time per pass:

| build | transform | dot | note |
|---|---:|---:|---|
| Grail native, checked | 259 437 us | 237 658 us | software `rt_f32_round` |
| Grail native, `f64[]` instead | ~6 500-8 000 us | ~7 000-9 700 us | `call rt_f64_op` per op |
| Grail `--backend=llvm`, checked | 700 us | 604 us | scalar `mulss/addss` |
| Grail `--backend=llvm --overflow=wrap` | 693 us | 612 us | overflow checks are not the cost here |
| Grail `--backend=llvm --range-facts` | 680-800 us | 685-1012 us | no change beyond noise |
| C `clang -O2 -fno-vectorize` | 230 us | 610 us | scalar bar |
| C `clang -O2` | 77 us | 611 us | transform vectorised (SSE2); dot is a strict-FP serial chain |
| C `clang -O2 -march=native` | 78 us | 795 us | wider vectors buy nothing at this size |
| C `clang -O2 -ffast-math` | 86 us | 84 us | dot vectorised only with reassociation |
| C `clang -O2 -ffast-math -march=native` | 75 us | 61 us | |

All **[V]**, all programs print the same sums (`149999920` / `1.5e+08` for 200 dot passes).

What blocks vectorisation, read from the optimised IR of `f_main_scale_add` **[V]**:

1. **Bounds checks are early exits that reload the length.** Each iteration does
   `load len(x); icmp; br abort` and `load len(y); icmp; br abort`. clang's remark:
   `loop not vectorized: Cannot vectorize early exit loop with complex writes to memory`.
2. **No provenance.** Descriptor and element addresses are `inttoptr` of `i64` words, so the store to
   `x[i]` may alias the descriptor of `x` or `y`; `len` and `data` are reloaded every iteration and
   cannot be hoisted. `docs/design/llvm-backend.md:238-256` reached the same conclusion.
3. **No `noalias` between `x` and `y`**, although the borrow checker has proved it (`&mut` against `&`).
4. **Not** the cause here: overflow checks (`wrap` changes nothing), boxed elements (`f32[]` is flat,
   below), or float width (the lifter keeps `float`).
5. For reductions, strict IEEE order: C at `-O2` does not vectorise the dot product either. The LLVM
   backend already matches C here (604 vs 611 us). Only an explicit SIMD type or reassociation
   permission moves this number.

The transform is 9x off vectorised C and 3x off scalar C on the LLVM backend, and 3 400x off on native.

### 1.4 Storage

- **[V]** `f32[]`, `u32[]`, `i32[]` store 4-byte elements (`native.grl:20506-20534`; `rt_push4`,
  `rt_slot4`, `rt_at4` at `runtime.grl:6441-6492`). `u8[]` is bytes. Every other vector element is an
  8-byte word (`native.grl:1587`), so a `P[]` of a plain record is an array of words, not of inline
  records - the flat-array design has to change that.
- **[V]** A sequence header is `{data, len, cap}`, 24 bytes, element storage a separate allocation
  (`docs/design/llvm-backend.md:399`).
- **[V]** `rt_alloc_unlocked` (`runtime.grl`, after `:956`) uses power-of-two size classes from 32
  bytes, bump-allocated from a 1 MiB mapping at offset 16, with a 16-byte block header. Payload
  addresses are therefore `map + 32 + k*size`: 32-byte aligned by accident, never 64-byte aligned, and
  nothing promises either.
- **[V]** `extern "C" record` uses C layout: natural alignment, padding, tail padding
  (`native.grl:14123-14261`). Probe `p4`: `V3 {x,y,z: f32}` has `size_of` 12, `align_of` 4;
  `M {tag: u8, v: V3, d: f64}` has 24 and 8. `byval R` passes it by the target's C ABI
  (`docs/ffi.md:348-387`, `native.grl:9382`, `machine.grl:814`).
- **[V]** A plain Grail record has no promised layout: `size_of(P)` is the compile error
  `a Grail record or vector has no layout the language promises` (probe `p4b`, `native.grl:17249`).
- **[V]** There is no alignment or packing control. `align(64) struct ...` is a parse error (probe
  `p5`); `rg -i 'packed|@align'` over `native.grl` finds nothing relevant. `f32x4` is
  `unknown type` (probe `p6`).

### 1.5 `chunks_mut` and the loan model

- **[V]** `pool::chunks_mut` (`lib/pool.grl:105`) wraps the builtin `parallel_for_chunks`
  (`native.grl:26985-27060`). The compiler checks: the argument is an exclusive slice; the element is
  transferable; no `Task`/job handles; the callback is `Fn((&mut [T])) -> unit`; its captures are
  shareable (`require_parallel_closure`). Disjointness is **constructed**, not proved: the runtime
  cuts `[k*size, min(n, k*size+size))` with `size = ceil(n/chunks)` and asserts the lengths sum to `n`
  (`runtime.grl:2992-3027`). Element width is passed as 1, 4 or 8.
- **[V]** The whole-vector loan does the rest. Probe `p3`, a callback capturing `&x[0: 8]` while
  `&mut x[0: 8]` is chunked: `error[E0008]: borrow conflicts with active access`.
- **[V]** A callback may capture a shared slice of *another* vector (probe `p2` compiles and runs).
  But the callback gets no chunk offset, so `s[i] + ys[i]` reads `ys[0..len/chunks]` in every chunk.
  **There is no correct in-place way to zip two arrays in parallel today.**
- **[V]** Baseline for that API, 1M `f32`, LLVM backend, `s[i] = s[i]*0.999 + 1.0`: 493 us with 1
  chunk, 115 us with 4, 144 us with 12, 120 us with 24 (loaded machine; scaling beyond 4 not shown).
- **[V]** `ownership.grl` (745 lines): a `Place` is a node in a storage tree (`parent/child/next`,
  `:14-25`), a `Loan` is `{source place, parent loan, mode, live}` (`:26-31`). Two places overlap iff
  one is an ancestor of the other (`overlaps`, `:95`), and a borrow conflicts with any live loan on an
  overlapping place unless both are shared (`conflict`, `:190`). Disjoint *fields* are disjoint places.
- **[V]** It knows nothing about indices: `rg 'range|index'` over `ownership.grl` finds nothing, and a
  slice borrows the whole vector. Probes `p1`/`p7`: `&mut x[0: 4]` together with `&mut x[4: 8]` is
  `error[E0008]: borrow conflicts with active access`. There is no `split_at_mut` in `lib/`.
- **[V]** A separate, small prover exists for refinements (`book/chapters/refinements.md`): facts are
  comparisons between names, `v.len()` and literals, taken from `where`, loop bounds, `if` and
  `assert`. It is not connected to the borrow checker.

## 2. SIMD

### 2.1 Surface

Fixed-width value types, named by element and lane count:

```grl
f32x4  f32x8  f64x2  f64x4      // floats
i32x4  i32x8  u32x4  u32x8      // integers; u8x16, i16x8, i64x2 follow the same rules later
m32x4  m32x8  m64x2  m64x4      // masks: what a comparison returns
```

They are plain data (copyable, transferable, shareable), with `size_of` = lanes x element size and
`align_of` = element alignment as a field (so a `[f32x4]` overlays an `[f32]` buffer). 256-bit types
exist on every target; where the CPU has only 128-bit registers the backend uses two halves. That is
the whole portability story: pick `f32x8`, and it is never slower than `f32x4` written twice.

```grl
a := f32x8::splat(0.999);
v := f32x8::load(xs, i);            // one check: i + 8 <= xs.len(); unaligned load
w := v * a + f32x8::load(ys, i);    // + - * / lane-wise; integers also & | ^ << >>
w.store(xs, i);                     // one check, unaligned store
m := v < w;                         // m32x8
r := m.select(v, w);                // lane-wise choice; m.any(), m.all(), m.bits() -> u64
x := v[3];                          // lane read; constant index checked at compile time
v2 := v.with(3, 1.5);               // lane write returns a new value
s := v.sum();                       // reductions: sum, min, max - fixed order, see below
z := v.shuffle<@7, @6, @5, @4, @3, @2, @1, @0>();   // constant lane indices (value generics)
i := v.to_i32();  f := i.to_f32();  b := v.bits();   // convert, reinterpret
q := v.sqrt();  n := v.abs();  lo := v.min(w);
```

Rules:

- **Bit-identical everywhere (D4).** Lane operations are IEEE operations on each lane, no fast-math
  flags. `sum()` on 8 lanes is defined as `((l0+l4)+(l2+l6)) + ((l1+l5)+(l3+l7))`, which is what a
  halving horizontal add computes; `min/max` follow the scalar `min/max` rule per pair. There is no
  implicit FMA; a later explicit `mul_add` is an open question (Q3). This is what makes the dot product
  fast without fast-math: the programmer writes the reassociation (eight running sums), the compiler
  does not invent it.
- **Loads and stores are unaligned and bounds-checked once per vector.** There is no aligned-load
  form: on every x86 since 2011 and on NEON an unaligned load of aligned data costs nothing **[A]**,
  and an alignment precondition would be a new kind of undefined behaviour. Alignment control (section
  3) exists for cache lines, not for SIMD.
- **Integer lanes wrap.** Overflow checking per lane has no cheap encoding; `--overflow=checked`
  does not apply to vector types and the book says so.
- **Tails are the programmer's**: the library gives the split, not the language.

```grl
// lib/simd.grl - written in Grail, no new builtin
pub fn zip_apply8(xs: (&mut [f32]), ys: (&[f32]) where ys.len() == xs.len(),
                  wide: Fn(f32x8, f32x8) -> f32x8, narrow: Fn(f32, f32) -> f32) -> unit {
    n := xs.len();
    mut i = 0;
    while i + 8 <= n {
        wide(f32x8::load(xs, i), f32x8::load(ys, i)).store(xs, i);
        i += 8;
    }
    while i < n { xs[i] = narrow(xs[i], ys[i]); i += 1; }
}
pub fn dot(xs: (&[f32]), ys: (&[f32]) where ys.len() == xs.len()) -> f32 {
    n := xs.len();
    mut acc = f32x8::splat(0.0);
    mut i = 0;
    while i + 8 <= n { acc = acc + f32x8::load(xs, i) * f32x8::load(ys, i); i += 8; }
    mut s = acc.sum();
    while i < n { s = s + xs[i] * ys[i]; i += 1; }
    return s;
}
```

No width-agnostic type (`f32xN`): its size would differ per CPU, which breaks record layout, FFI and
the bit-identical rule in one move. Rejected in section 5.

### 2.2 Implementation, per backend

A SIMD value is 2 or 4 words of frame storage; it never lives in a general register. The front end
emits one new line shape into the stream, operating slot-to-slot:

```
vop <type> <op> <dst-slot>,<src-slot>[,<src-slot>]     e.g.  vop f32x8 mul -96(%rbp),-64(%rbp),-32(%rbp)
vload/vstore <type> <slot>,<address-register>
```

- **LLVM backend (first).** `llvm.grl` turns each line into `load <8 x float>` / `fmul <8 x float>` /
  `store`, on slots it declares as `alloca <8 x float>`. SROA/mem2reg make them SSA values and clang
  picks instructions for the target: SSE2 pairs, AVX with `--cpu`, NEON, RVV if enabled. Reductions are
  emitted as explicit `shufflevector` + `fadd` in the specified order, not as
  `llvm.vector.reduce.fadd` with `reassoc`. Cost: one new line family in the lifter's parser, and the
  same typed-slot machinery F2 already uses for `alloca float` (`llvm.grl:269`). The slice bounds
  check stays one early exit per 8 lanes, and vectors are already explicit, so the three blockers of
  1.3 stop mattering for this code.
- **Native backend, same stage: scalar lanes.** `machine.grl` (and the x86 pass-through) expands a
  `vop` into one scalar operation per lane over the slot's memory, using the scalar float instructions
  each target already has. Correct by construction, bit-identical by D4, and still several times
  faster than today because no `rt_f32_round` call is involved. Cost: one expansion routine per
  target, no register allocation, no new encodings.
- **Native backend, later: real vectors.** x86-64 baseline is SSE2, so `vop f32x4 mul` becomes
  `movups a,%xmm0; movups b,%xmm1; mulps %xmm1,%xmm0; movups %xmm0,dst` and 256-bit types are two
  such halves. aarch64 gets the NEON equivalent (`ldr q0; ldr q1; fmul v0.4s,v0.4s,v1.4s; str q0`).
  riscv64 keeps scalar lanes: the V extension is not in the baseline and its vector-length model does
  not match fixed-width types. This is memory-form SIMD (every operation loads and stores), about half
  the speed of register-allocated code **[A]**; getting further needs vector registers in
  `optimize.grl`/`ir.grl`, which know `xmm` only as scalar scratch today (`rg -c xmm`: 1 and 4).
- **What "the native backend emits x86 text that machine.grl translates" costs.** Less than feared and
  more than nothing: floats already cross to aarch64/riscv64 as pseudo-ops, not as SSE text, so `vop`
  follows an existing pattern. The real costs are (a) three expansions to keep in step, (b) the text
  optimiser must pass `vop` lines through and treat their slots as read and written, and (c) the
  bootstrap seed: SIMD types must not be used inside `compiler/*.grl` or the runtime.

### 2.3 CPU feature levels

- Baseline: x86-64 = SSE2, aarch64 = NEON, riscv64 = scalar. A baseline build runs everywhere.
- `grail build --cpu=x86-64-v3` (or `native`) is build-wide: passed to clang as `-march`, and exposed
  as `target.features` for `@if` (`@if target.features.avx2 { ... } else { ... }`), next to the
  existing `target.os`/`target.arch` (`book/chapters/compile-time.md`). The native backend ignores
  levels above baseline.
- No per-function attribute and no runtime dispatch in v1. Evidence that it can wait: `-march=native`
  changed the transform from 77 to 78 us and the fast-math dot from 84 to 61 us (1.3). A game ships a
  v2 and a v3 binary, or picks a code path with `@if`. Runtime dispatch is a library over function
  values once `--cpu` per module exists (Q4).

## 3. Layout

### 3.1 What to add

```grl
extern "C" record Vertex align(16) { pos: f32x4, color: u32 } // alignment raised to 16, size 32
extern "C" record Header packed { tag: u8, len: u32 }         // size 5, alignment 1
extern "C" record Counters { hits: u64, align(64) misses: u64 } // field starts on its own cache line
struct Slot align(64) { n: Atomic }                           // flat record (other design), one per line
```

- `align(N)` on a record raises its alignment (never lowers); N is a power of two up to 4096;
  `size_of` rounds up to it. On a field it raises that field's alignment inside the record. Both are
  compile-time constants visible to `align_of`.
- `packed` is accepted on `extern "C"` records only and exists for wire and file formats. A packed
  field cannot be borrowed (`&r.len` is refused; read and assign copy), because the narrow-field
  reference path (`native.grl:484`, `20462-20500`) assumes natural alignment **[A]**.
- **Field order.** `extern "C"`: declaration order, C padding, as today **[V]**. Flat records
  (other design): this note needs declaration order *or* a documented reorder; either is fine as long
  as `size_of`, `align_of` and `offset_of` are compile-time constants. Plain boxed records: keep "no
  layout promised".
- **Allocations (D7).** The allocator guarantees: payload aligned to 16 bytes always, and to 64 bytes
  when the payload is 64 bytes or larger. Today it is 32 by accident (1.4), so this is a change of two
  constants in `rt_alloc_unlocked` (start the bump at `map + 48`) plus a rule for the 32-byte class.
  Larger alignments come from the element type: storage for `T[]` is aligned to
  `max(align_of(T), the rule above)`.
- **False sharing.** Three tools, in order of use: (1) `parallel_for_zip` rounds chunk sizes up to a
  whole number of cache lines when the element size divides 64, so two workers never write one line
  except at a buffer's unaligned ends - free once D7 holds; (2) `align(64)` on a per-worker record;
  (3) `align(64)` on a field to separate a hot atomic from its neighbours.

### 3.2 Interaction with FFI and flat arrays

- An `align(N)`/`packed` `extern "C"` record must match what `grail bindgen` reads from
  `__attribute__((aligned))`/`packed`/`alignas` (`compiler/bindgen.grl`); bindgen should emit them
  instead of refusing or silently mislaying such a struct **[A: current behaviour not probed]**.
- `byval` of an over-aligned record follows the target ABI (on x86-64 SysV a 32-byte-aligned
  aggregate goes in memory with an aligned stack slot). Stage 2 refuses `byval` on records with
  `align` above 16 until that is implemented and tested per target.
- SIMD types as `extern "C"` fields map to `__m128`/`float32x4_t`. Passing them `byval` in vector
  registers is a later item; until then they cross FFI by pointer.

### 3.3 SoA or AoS

AoS is what flat arrays give: `Particle[]` with inline elements. SoA is a record of columns:

```grl
pub struct Particles {
    x: f32[], y: f32[], z: f32[],
    vx: f32[] where vx.len() == x.len(),
    life: u32[],
}
```

No language feature (D8). Reasons: columns are already disjoint *places* to the borrow checker
(fields of one record, 1.5), which is exactly what section 4 needs; SIMD loads want contiguous
same-typed lanes, which a column is; and the boilerplate (`push` that pushes to every column,
`swap_remove`, equal lengths) is a generated library type once compile-time reflection can iterate
fields (`book/chapters/compile-time.md`, Reflection). A `soa` keyword would bake one container shape
into the language and still not cover hot/cold splitting, which is the usual real layout.

Whether the prover carries `vx.len() == x.len()` from a field refinement into a loop is **[A]**;
if it does not, `parallel_for_zip` checks lengths once at run time, which is enough.

## 4. Checked parallel loops

### 4.1 Principle

Keep what `chunks_mut` does: the compiler does not *prove* an index partition, it *constructs* one
and uses ordinary loans to make everything else unreachable. The existing loan model already
supplies three of the four things an ECS-style loop needs:

| Need | Mechanism | State |
|---|---|---|
| nobody else touches the written data during the loop | whole-vector exclusive loan held by the call | exists **[V]** probe `p3` |
| two columns are different memory | sibling field places / distinct roots | exists **[V]** `ownership.grl:95` |
| read-shared columns | shared loans; shareable captures | exists **[V]** probe `p2` |
| each worker's part of *several* arrays lines up | **missing** - no offset, no multi-slice split | this design |

### 4.2 `parallel_for_zip`: one split, many columns

```grl
// builtin; lib/pool.grl wraps it as pool::zip2, zip3, zip4 with ordinary generic signatures
parallel_for_zip(grain, f, &mut pos[0: n], &vel[0: n], &mut life[0: n]);

pool::zip2(&mut pos[0: n], &vel[0: n], 4096,
    |p: &mut [f32], v: &[f32]| -> unit {
        for i in p.len() { p[i] = p[i] + v[i] * DT; }
    });
```

- Any number of slice arguments, each `&mut [T]` or `&[T]`, element types independent. The callback
  takes the same list; every piece covers the same index range of every slice. `grain` is elements
  per piece: the range is halved recursively until a piece is no longer than the grain, so the split
  is a function of `(n, grain)` only (the job model's rule, `docs/design/concurrency-model.md`).
- **Compile-time, existing checks reused:** each argument takes its loan at the call, so the same
  vector twice with one `&mut` is today's `E0008`; exclusive elements must be transferable, shared
  elements shareable; the callback is `Fn` with shareable captures and cannot capture any argument's
  vector (`p3`).
- **Compile-time, new:** argument count and modes against the callback's signature.
- **Run-time, once per call:** all lengths equal, else abort with a message naming the argument
  (skipped where the prover has `a.len() == b.len()`); and the existing `covered == n` assertion.
- **Run-time, per access:** each chunk is a slice with its own length, so an out-of-chunk index is the
  ordinary bounds abort, never a write into a neighbour. Inside a chunk, `i < p.len()` proves `p[i]`
  but not `v[i]`; the builtin states the fact `v.len() == p.len()` at callback entry so the prover can
  drop the second check **[A: needs the prover to accept a builtin-stated fact]**.
- Runtime: `rt_parallel_for_chunks` (`runtime.grl:2992`) already takes a width; it becomes an array
  of `{data, width}` pairs. A grain is rounded up to whole cache lines where the element size divides 64 (3.1).

*As built (2026-11-17, /root/fixed_arrays).* `parallel_zip_builtin` (native.grl, builtin id 67)
takes the grain, the callback and one to four slices, checks each slice's mode and element
(`require_capability_named`: transferable for `&mut`, shareable for `&`), the callback's arity and
that each parameter is the argument's slice (kind, mode, element; lifetimes not compared - a callable
bound is higher-ranked in them), and looks through a generic callable (`param_callable`). The frame
holds the `{view, width}` pairs; `rt_parallel_zip` checks the lengths (failure kind 19 names the
argument) and splits as `rt_parallel_split` does, from (n, grain) alone (`rt_job_split` kind 2,
`rt_job_zip_leaf`). The runtime cannot call with more than three arguments (it is compiled by the
seed too), so the leaf calls a compiler-emitted adapter `grail_zip_adapter_<closure>_<n>` with one
block {callback, environment, views}, which loads the views into argument registers. The
`v.len == p.len` entry fact (as /root/prover_wrap advised): `parallel_zip_builtin` marks the
`Closure` record of a literal written as its argument (`entry_eq`), and `emit_closures` queues
`pk.len == p0.len` as pending facts for the body's first block. Closure bodies were not proved at all
before; `emit_closures` now runs `pv_begin`/`pv_end` around the body (no refined parameters, so no
seeded facts). A closure value passed through a variable gets no fact. Cases: `parallel-for-zip-*`, `pool-zip-*`,
`reject-parallel-for-zip-*`.

Two smaller additions with the same construction:

```grl
// the chunk's first index, for reading captured tables or writing an owned per-chunk result
pool::chunks_mut_at(&mut xs[0: n], 4096, |base: u64, s: &mut [f32]| -> unit { ... });
// read-only reduction, combined in index order, so the answer depends on (n, grain) and nothing else
total := pool::reduce_chunks(&xs[0: n], 4096, 0.0, |s: &[f32]| -> f32 simd::sum(s), |a: f32, b: f32| -> f32 a + b);
```

The grain is always an argument, never derived from the number of cores, because float reductions
depend on the split and D4 wants the same answer on every machine. The names follow the job model's
`chunks_mut(data, grain, f)`, `range` and `reduce`.

### 4.3 `split_at_mut`: disjoint ranges without teaching the checker ranges

```grl
// builtin: one exclusive slice in, two out; run-time check mid <= s.len()
left, right := split_at_mut(&mut xs[0: n], mid);
```

The two results are loans whose parent is the argument's loan (`reborrow` in `ownership.grl:381`
already has a parent link), with a new flag meaning *sibling halves do not conflict with each other*.
That is the only change to `ownership.grl`: about 20 lines in `conflict`/`access_loan`, no index
arithmetic. It covers divide-and-conquer (parallel sort, tree builds) and hand-written chunkers.

*As built (2026-11-17, /root/fixed_arrays).* `Loan.group`; `open_group`/`close_group` around the two
reborrows the statement `left, right := split_at_mut(s, mid)` makes (`split_at_mut_statement`, both
halves `rt_vslice` views of `s` through `view_bonds`). `split_apart(other, through, extra)` - some
ancestor-or-self of each is a distinct loan of one group, and `other` is not below `through` - exempts
a loan in `reborrow`, `access_loan` and (for the second half) `use_loan`'s live-child test. A
temporary argument (`&mut xs[0: n]`) is bound under a hidden name so its loan lives as long as the
halves. Cases: `split-at-mut-*`, `reject-split-at-mut-*` (vector used, parent slice used, overlapping
re-split, overlap inside one half, shared argument), `mid` past the end aborts.

### 4.4 ECS-style systems

*Static columns* (components are fields of a world record) need nothing more than 4.2 plus one thing
from the job design: a structured `join` whose branches may capture borrows.

```grl
pub struct World { pos: f32[], vel: f32[], health: u32[], names: string[] }

fn integrate(pos: (&mut [f32]), vel: (&[f32])) -> unit { pool::zip2(pos, vel, 4096, step); }
fn regen(health: (&mut [u32])) -> unit { pool::chunks_mut(health, 4096, heal); }

fn frame(w: (&mut World)) -> unit {
    n := w.pos.len();
    // two systems at once: write sets {pos} and {health} are different fields, vel is read-shared
    pool::scope2(|| -> unit integrate(&mut w.pos[0: n], &w.vel[0: n]),
                 || -> unit regen(&mut w.health[0: n]));
}
```

The loans in this sketch are checked today. Probe `p10` **[V]**: one call taking `&mut w.pos[0: n]`,
`&w.vel[0: n]` and `&mut w.health[0: n]` through a `&mut World` compiles and runs (`1.5 7`); probe
`p11`, with `&w.pos[0: n]` in place of the `vel` slice, is `error[E0008]: borrow conflicts with active
access`. What is missing is only the join whose branches may hold those loans. Read-shared/write-exclusive is exactly shared/exclusive loans.

*Dynamic columns* (component types registered at run time, queries built from data) cannot be proved
at compile time by any of the compared languages. They stay a library: each column carries a borrow
flag, a query acquires read or write flags before its loop and an overlap is an error value (not UB),
and inside the query the work is `parallel_for_zip` again. That is Bevy's model; nothing in the
compiler changes for it (D10).

### 4.5 What the checker learns, what stays at run time, what is refused

| | |
|---|---|
| **Checker learns** | N-ary slice arguments of `parallel_for_zip` and their modes; the "sibling halves" loan flag for `split_at_mut`; (job design) borrows captured by branches of a structured join; one prover fact `len == len` at callback entry. |
| **Run-time checks** | equal lengths per `parallel_for_zip` call; `mid <= len`; per-chunk bounds; chunk coverage assertion; dynamic-ECS borrow flags. |
| **Refused** | scatter writes from a parallel body (`out[idx[i]] = ...`: uniqueness of `idx` is not provable - use per-chunk owned output, or `Atomic`); `FnMut` callbacks; capturing an exclusive borrow or anything reaching a zipped vector; overlapping or strided ranges of one vector (`&mut x[0: n]` with `&mut x[1: n]`); AoS field projection as a column (`&mut ps[..].x`) - use SoA; handles and unclassified foreign pointers as elements, as today. |

### 4.6 Optional later step: range-aware loans

If `split_at_mut` and zip prove too narrow, places can carry an index interval: `&mut x[a: b]` makes a
*range child* of `x`'s element storage holding two prover terms, and `overlaps` asks the refinement
prover whether `b1 <= a2 || b2 <= a1` before declaring a conflict; unknown means conflict. This
connects two components that are separate today (1.5), and invalidation is the hard part (a term
dies when its name is assigned, so the loan must capture the value, not the name). Not recommended
before there is a program that needs it.

### 4.7 What this note needs from the other two designs

From **unboxed records / flat arrays**:

1. `T[]` of a flat record stores elements inline at stride `size_of(T)`; `size_of`, `align_of`,
   `offset_of` are compile-time constants for flat records.
2. `&mut [T]`/`&[T]` over such a vector, and an element width that is not limited to 1, 4, 8
   (`parallel_for_chunks` passes exactly those today, `native.grl:27005-27017`).
3. SIMD types are legal flat fields and elements; `align(N)` on a flat record raises its stride.
4. A way to view `[f32]` storage as `[f32x8]` is **not** required (loads take an index).
5. Field-projection slices over AoS are **not** required.

From the **thread / job model**:

1. A structured two-way or N-way join whose branches may capture borrows: exclusive borrows of
   transferable data, shared borrows of shareable data, both ended at the join. Today `pool::join`
   takes `Fn` closures and exclusive-borrow captures are refused (`lib/pool.grl:18-22`).
2. `&mut [T]` classified as transferable *within* such a scope (it is refused as a capture now).
3. A waiting worker helps run jobs (nested `parallel_for_zip` inside a system must not deadlock);
   `tests/pool/chunks_mut.grl` shows this holds for `parallel_for_chunks` **[V]**.
4. No dependence on worker count in results: splits depend on `(n, grain)` only.
5. SIMD types classified as plain data.

## 5. Alternatives rejected

- **Rely on auto-vectorisation.** Needs the three blockers of 1.3 removed, which is the typed-IR
  programme (`docs/design/typed-ir.md`), is LLVM-only, is silent when it fails, and never vectorises a
  strict-FP reduction (C does not either: 611 us). Worth doing for scalar code, not a SIMD story.
- **A portable-width type** (`f32xN`, ISPC's `varying`, Rust's dropped `Simd<T, LANES>` inference).
  Size varies per CPU, so it cannot be a record field with a known layout, cannot cross FFI, and
  reductions give different sums on different machines. ISPC gets away with it because it is a
  separate language without layout promises to C.
- **Raw intrinsics per ISA** (C++ `_mm256_*`). Three vocabularies, no fallback, and useless on the
  native backend. They can be added later as `extern` functions for the LLVM backend without changing
  this design.
- **Zig's `@Vector(N, T)` for any N.** Attractive and close to this design; rejected only in the "any
  N" part, because the native scalar/SSE2 lowering and the mask types want a closed list. The named
  types can become aliases of a generic form later.
- **Fast-math flags or a `reassoc` block.** Breaks bit-identical output between backends, which the
  project uses as its backend test oracle (`docs/design/llvm-backend.md`, bit-identical requirement).
- **Aligned load/store forms.** No measurable gain on current CPUs **[A]** and a new way to fault.
- **Native-backend-first SIMD.** Three hand-written lowerings before the first user benefit, and the
  native backend is not where a release build of an engine comes from: it is 370x behind on `f32`
  today.
- **Rust-style `par_iter` over arbitrary iterators (rayon).** Needs `Send`/`Sync` bounds on generic
  iterator adaptors and unsafe splitting inside the library; Grail's version of the same guarantee is
  the builtin split plus classification, which already exists. Kept the part that matters: ordered
  results and explicit chunks.
- **Range loans first** (Rust has no such thing either; `split_at_mut` is `unsafe` inside). Section
  4.6: larger change, no program yet needs it.
- **A `parallel for` statement.** Syntax over the same builtin; decide after the library form has
  users.
- **A `soa` keyword.** Section 3.3.

## 6. Staged plan

Each stage ships alone. Benchmark: `xform`/`dot` from the appendix, 1M `f32`, us per pass, with
today's numbers from 1.3. To be added to `bench/` in stage 0.

| Stage | What | Files | Tests | Benchmark: today -> target | Risks |
|---|---|---|---|---|---|
| 0 | Native `f32` rounding in hardware: replace `call rt_f32_round` with `cvtsd2ss; cvtss2sd` on x86 and a `cf32round` pseudo-op elsewhere | `native.grl` (sites at 31209, 32894, 34703, 35065, 37989 and the float-op path), `machine.grl` (next to `cf32bits`, :964), keep `rt_f32_round` for the seed | differential test: 1M random and edge binary64 words, hardware against `rt_f32_round`; existing float corpus on three targets | native transform 259 437 -> under 10 000 (the `f64[]` figure) **[A]** | NaN payloads: the software path returns a NaN word unchanged, `cvtsd2ss` quiets and truncates it - decide which is the definition (Q1). Subnormal and tie cases are the differential test's job. |
| 0b | Native float operations inline, not `call rt_f64_op` (comparisons and conversions too) | decided on `gaps12-float` | bit-identical output against the call form on three targets | native `f32` and `f64` transform within 5x of scalar C (230 us) | must keep what the LLVM lifter keys on (`typed-ir.md` F1/F2) |
| 1 | `parallel_for_zip`, `pool::zip2/3/4`, `chunks_mut_at`, `reduce_chunks`, `split_at_mut`; waits for the job model's stage 1 | `native.grl` (beside `parallel_for_chunks_builtin`, :26985), `runtime.grl` (:2992), `ownership.grl` (sibling flag), `lib/pool.grl`, `book/chapters/concurrency.md` | content-comparing tests like `tests/pool/chunks_mut.grl`; reject cases: same vector twice, unequal lengths (abort text), captured argument, `FnMut` | parallel transform over two arrays: not expressible today; single array 493 us at 1 chunk, 115 us at 4 -> zip2 within 10% of that | Loan bookkeeping for N arguments; the sibling flag is the only soundness-relevant line and needs its own negative tests. |
| 2 | `align(N)` on `extern "C"` records and fields, `packed`, allocator alignment guarantee, `offset_of` | `native.grl` (:14123-14261, :17227), `runtime.grl` (`rt_alloc_unlocked`), `bindgen.grl`, `docs/ffi.md` | `@assert(size_of/align_of/offset_of)` against a C shim, as `tests/ffi/c_arrays.grl` does; address-modulo test for buffers | false-sharing benchmark (N workers incrementing adjacent against `align(64)` counters): **not measured, to be written in this stage** | Allocator change touches every program: run the whole corpus; the seed compiler's 8-aligned statics (`runtime.grl:977-981`). |
| 3 | SIMD types on the LLVM backend, scalar-lane lowering on native, `lib/simd.grl` | `native.grl` (types, operators, `vop` emission), `llvm.grl` (lift `vop`), `machine.grl` + x86 path (lane expansion), `optimize.grl`/`ir.grl` (pass-through), `lib/simd.grl`, book chapter | every operation against a scalar reference on random lanes; identical output native against LLVM on three targets (the bit-identical oracle); edge lanes NaN, +-0, subnormal | LLVM transform 700 -> 100 or less (C: 77); LLVM dot 604 -> 100 or less (C fast-math: 84; strict C: 611) | Multi-word values in a one-word-per-value front end: argument passing and returns of 16/32-byte values need an ABI decision (Q2). The text optimiser misreading a `vop` slot as dead. |
| 4 | Real SSE2 and NEON for `vop` on native; `--cpu=` and `target.features` | `machine.grl`, `native.grl`, `cli.grl`, `tools/native.mjs` | same tests as stage 3, now exercising the new encodings; qemu for aarch64 | native transform -> within 3x of C -O2 **[A]** | Assembler coverage on all supported hosts, Windows and macOS object paths. |
| 5 | Scalar loops clang can vectorise: hoisted bounds checks, `noalias` from the borrow checker | typed-IR work, owned by `docs/design/typed-ir.md` | - | LLVM transform without SIMD types 700 -> 230 (scalar C) or better | Outside this note; listed so nobody expects stage 3 to deliver it. |
| 6 | Optional: range-aware loans (4.6) | `ownership.grl`, prover in `native.grl` | - | - | Only with a motivating program. |

Order: 0 and 1 are independent of everything and of each other. 2 should land before the flat-array
work fixes its layout rules. 3 depends on nothing here but shares the multi-word-value question with
flat records.

## 7. Open questions

Q1-Q6 are answered in section 0 (decided by the director); Q7 and Q8 remain.

- **Q1.** Is the result of an `f32` operation on a NaN defined bit-for-bit? Stage 0 changes NaN
  payload behaviour unless the hardware rounding is followed by a fix-up.
- **Q2.** How are 16- and 32-byte values passed and returned? Proposal: by hidden pointer, exactly as
  flat records will be - needs agreement with the flat-record design.
- **Q3.** `mul_add`: fused everywhere (slow software fallback where the CPU has no FMA) or absent
  until `--cpu` levels exist? Proposal: absent in v1.
- **Q4.** Is runtime CPU dispatch wanted at all, given a game can ship per-level binaries?
- **Q5.** Should `--overflow=checked` ever apply to integer lanes? Proposal: no, documented.
- **Q6.** Does D7 (64-byte aligned buffers) justify up to 48 wasted bytes per small-vector block, or
  should it apply only from 4096 bytes up?
- **Q7.** Why does `f64` code on the LLVM backend keep `rt_fail` calls and spills in the loop (2 100 us
  against 700 us for `f32`)? Not investigated here; it bounds what `f64x4` can gain.
- **Q8.** Does `grail bindgen` see `aligned`/`packed` attributes today? Not probed.

## Appendix: probes

All under `.work/simd/` (untracked). Compiler: `GRAIL_COMPILER=$PWD/.work/base/grail-c6 bun tools/native.mjs build`.
LLVM builds through `compileProgram(..., { backend: 'llvm' })` from `tools/native.mjs` (clang `-O2`).
Per-pass time = (wall time with REPS passes - wall time with 0 passes) / REPS; 200 passes, 4 for
native `f32`, 20 for `f64`.

```grl
// xform.grl
fn scale_add(x: (&mut [f32]), y: (&[f32]), a: f32) -> unit {
    n := x.len();
    mut i = 0;
    while i < n { x[i] = x[i] * a + y[i]; i += 1; }
}
fn dot(x: (&[f32]), y: (&[f32])) -> f32 {
    n := x.len();
    mut s: f32 = 0.0;
    mut i = 0;
    while i < n { s = s + x[i] * y[i]; i += 1; }
    return s;
}
fn main() -> unit {
    n := 1000000;
    mut x = f32[];
    mut y = f32[];
    for i in n { x.push(f32(i % 7) * 0.5); y.push(f32(i % 5) * 0.25); }
    a: f32 := 0.999;
    mut total: f32 = 0.0;
    for r in REPS { scale_add(&mut x[0: n], &y[0: n], a); }
    for r in DREPS { total = total + dot(&x[0: n], &y[0: n]); }
    print(total);
}
```

The C twin uses `float *restrict`, `noinline` kernels and an `asm volatile("":::"memory")` barrier
so the dot call is not hoisted. `xd` is `xform.grl` with `f32` replaced by `f64`.

```grl
// p1: two disjoint exclusive slices           -> error[E0008]: borrow conflicts with active access
fill(&mut x[0: 4], &mut x[4: 8]);
// p2: chunk callback capturing a shared slice of another vector -> compiles, prints 3
ys := &y[0: 8];
pool::chunks_mut(&mut x[0: 8], 2, |s: &mut [f32]| -> unit { for i in s.len() { s[i] = s[i] + ys[i]; } });
// p3: the same, capturing a slice of x itself -> error[E0008]: borrow conflicts with active access
// p4: extern "C" record V3 { x: f32, y: f32, z: f32 }; extern "C" record M { tag: u8, v: V3, d: f64 }
//     size_of/align_of -> 12 4 24 8
// p4b: size_of(P) for `struct P`              -> error: ... a Grail record or vector has no layout the language promises
// p5: align(64) struct Counter { n: u64 }     -> error: expected `fn`, found `align`
// p6: a: f32x4 := ...                         -> error[E0003]: unknown type `f32x4`
// p7: a := &mut x[0: 4]; b := &mut x[4: 8];   -> error[E0008]: borrow conflicts with active access
// p10: two(&mut w.pos[0: n], &w.vel[0: n], &mut w.health[0: n]) with w: (&mut World) -> runs, prints 1.5 7
// p11: two(&mut w.pos[0: n], &w.pos[0: n], ...)  -> error[E0008]: borrow conflicts with active access
// par: parallel_for_chunks(&mut x[0: n], CHUNKS, body), body: s[i] = s[i] * 0.999 + 1.0
//     LLVM backend: 493 us (1 chunk), 115 (4), 144 (12), 120 (24)
```
