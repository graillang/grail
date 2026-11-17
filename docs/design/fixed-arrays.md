# Fixed-size arrays

2026-11-16. Approved by the director (answers and conditions below); A1 built. Line numbers are of `5dc07da`
(branch `gaps12-arrays`, cut from `gaps13-int-b`). `N` = `compiler/native.grl`, `O` =
`compiler/optimize.grl`, `I` = `compiler/ir.grl`, `L` = `compiler/llvm.grl`, `W` =
`compiler/ownership.grl`.

## 0. What exists

- `[T; N]` already parses as a type anywhere `parse_type` runs: store kind 32, element in `arg`,
  `N` in `mode`, `N` a positive compile-time constant (`ct_expr`) (N:13235-13247).
- It is only usable as a field of an `extern "C" record`: C layout (`ffi_field_align` /
  `ffi_field_size`, N:15550-15592), and Grail code sees it as a *vector* copied out and in whole
  (`carray_surface` N:24544, `cfield_load` N:22650-22670 via `rt_carray_load`, the store via
  `rt_carray_store` N:22833-22848, `carray_assign` N:40864). There is deliberately no reference
  into it ("a C array field has no reference", N:22660).
- Probed today: `a: [f32; 4] = [1.0, 2.0, 3.0, 4.0]; a[1]` is E0004 "a value of store kind 32
  (this compiler cannot spell it)"; `&[f64; 3]` does not parse (`slice_ahead` N:13404 only knows the
  map's `:`); and `grail run` of a program with an extern record holding an array fails in the
  interface writer ("cannot write a type of that kind", N:42709) - kind 32 has no interface spelling.
- `[1, 2, 3]` and `[0; 4]` are already **untyped vector literals** (corpus `literal-untyped-vector`);
  `T[x; n]` is the vector repeat literal (`collection_body` N:34430; owned elements refused N:34480).
- Value generics exist: `fn f<@n: u64>`, `struct Ring<T, @N: u64>`, a value is a type-level
  constant (kind 31) or, in a template, a parameter placeholder (kind 9), inferred from argument
  types (N:11261, `type_level_value` N:11399, `value_param_value` N:18892, inference N:25468).
- The prover is difference logic (`a < b + k`, `pv_holds` N:8619); `for i in n` states `i < n`
  (`pv_ir_range` N:9163). It cannot prove `i * 3 + k < 15`.

## 1. Syntax and semantics

**Spelling: `[T; N]`.** Grail writes vectors postfix (`T[]`), slices `&[T]`, maps `[K: V]`. The
postfix `T[N]` would be the closest visual relative of `T[]`, but `u64[3]` already *is* an
expression (a one-element vector literal), so in a type it would read as a value. `[T; N]` is
already the language's spelling for C arrays, is Rust's, and sits beside `[K: V]` (a bracket with
a separator). One spelling for both Grail and C arrays.

- `N`: an integer literal, a module constant (`N := 4;`), an integer static, `size_of(..)`-style
  constant expressions, or (stage A4) a value parameter `@n`. `N >= 1` in v1 (`[T; 0]` refused, as
  today; it can be allowed later without breaking anything).
- **Literals are chosen by the expected type.** Where the expected type is `[T; N]` (annotation,
  parameter, field, return, element of an outer array), a bracket literal builds an array:
  `a: [f32; 4] = [1.0, 2.0, 3.0, 4.0]`, `z: [f64; 15] = [0.0; 15]`, `m: [[f32; 4]; 4] = [[0.0; 4]; 4]`.
  The element count is checked **at compile time** (wrong count: an error naming both). The typed
  vector forms `T[a, b]` / `T[x; n]` are accepted there too when their count is a constant, so
  existing code like `PhysicalDevice[seed; 8]` for a C-array field (abundance/src/rhi_vulkan.grl:211,
  261-264) keeps compiling. With no expected type, `[1, 2, 3]` stays a vector: no existing program
  changes meaning.
- **Indexing** `a[i]`, `a[i] = x`, `&a[i]`, `&mut a[i]`, `a[i].f`, `a[i][j]`: as for vectors.
- **`a.len()`** is the constant `N`: emitted as an immediate, and to the prover a literal.
- **Iteration**: `for i in a.len()` (the bound is a constant); `for x in &a` / `for x in &mut a`
  through the slice view below. Consuming `for x in a` only for plain elements in v1.
- **Slices**: `&a` / `&mut a` is `&[T; N]` / `&mut [T; N]`; where the expected type is `&[T]` /
  `&mut [T]` (or a slice method is called) it converts to a slice of length `N`, so every slice API
  works on an array. `a[lo: hi]` is a sub-slice. Copying from a vector:
  `(&mut a).copy_from(&v)` (run-time length check), replacing today's vector-assign of C fields.
- **Equality**: `==` / `!=` element-wise when `T` has `==` (floats compare as IEEE, as for
  scalars; padding is never read, as `structural_eq` N:24350 already does field by field).
- **Printing**: `println(a)` prints as a vector does.
- **Copying**: section 2.
- **`size_of` / `align_of`**: answered for arrays of scalars, extern records and arrays of those
  (C layout is promised); refused for arrays of plain Grail records, whose layout is not promised
  (N:18939).

## 2. Ownership

- **Plain array** (element plain: scalar, `&T`, plain record, extern record, plain array): owns
  nothing, needs no drop. The owner's copy rule applies to arrays from the first stage, since no
  existing program can depend on arrays: **copies implicitly when at most 4 words (32 bytes) and no
  `&mut` anywhere inside; otherwise move-only, with `.copy()`.** `[f32; 4]`, `[f64; 4]`, `[u8; 32]`
  copy; `[f64; 15]` and a `[f32; 16]` mat4 move. This is a kind-32 case in the place predicate
  (`copy := !needs_drop(..) & ..`, `member_place` N:4344) and does not touch records; stage 3d's
  `affine(ty)` later absorbs it unchanged.
- **Owned array** (element needs drop: `string`, vectors, boxed records, `dyn`): owned, move-only,
  dropped by dropping each element in index order. Stage A3.
- **Moving out of an element** `x := a[i]` of an owned element is refused (E0006 with a hint):
  an array has no holes. `exchange(&mut a[i], v)` and `a.swap(i, j)` are the ways out; full
  destructuring can come later. For plain elements `x := a[i]` is a copy (scalars) or follows the
  record rule (until 3d: a borrow, exactly as `v[i]` today).
- **Full initialisation by construction**: an array value only ever comes from a literal with
  exactly `N` elements (compile-time count), a repeat `[x; N]` of a plain `x` (an owned repeat is
  refused, as N:34480 does for vectors), a copy or move of another array, a call result, or a
  field/element read. `mut a: [f32; 4];` without a value is refused ("an array starts full: write
  `[0.0; 4]`"). There is therefore no partially initialised state for the checker to track, and the
  existing definite-initialisation of the binding covers the array as a whole.
- **Borrows**: element places are one child of the array place, index-insensitive, as for vectors
  (`&mut a[0]` and `&a[1]` together are refused, as in Rust). `W` needs nothing new
  (`borrow_place` W:327).

## 3. Layout

- **C layout everywhere**: `size = size_of(T) * N`, `align = align_of(T)` (`ffi_field_*`
  N:15550-15592 already compute this). An element is stored at its own size: `[f32; 4]` is 16
  bytes, `[u8; 16]` 16, `[[f32; 4]; 4]` 64. A plain-record element uses the record's current inline
  layout (8 bytes per field until unboxed stage 7).
- **In frames**: the array's bytes, rounded up to whole slots, in adjacent frame slots; its value is
  the address of the first byte. Declared to both backends by the frame-aggregate fact (section 7).
- **In records**: inline at an offset (`field_layout` N:22392), occupying `ceil(size / 8)` words of
  a plain Grail record, or its exact C bytes in an extern record. Narrow elements read and write
  through `sized_load` / `sized_store` (N:22742, N:22783), never calls. A record holding a plain
  array is plain (`plain` / `layout_bits` N:22424, N:22473 gain kind 32).
- **In vectors**: `[f32; 4][]` is flat - the stage 1b width runtime (`rt_pushw`, `rt_slotw`,
  pseudo-op 52, I:895) with width 16. A vector of `[f32; 4]` is a C `float[n][4]`.
- **Statics**: `static TABLE: [u32; 256] = @crc_table();` is read-only data; `TABLE[i]` is
  `leaq TABLE(%rip)` plus the scaled index, which LLVM sees as a constant global. Needs the statics
  work (`gaps12-statics-impl`, not yet in this base).
- **C interop**: an `extern "C" record` field `[T; N]` *becomes this type* (stage A2): `d.ids[3]` and
  `&d.name` in place instead of a whole copy, `d.ids = [1, 2, 3, 4]` with a compile-time count. The
  vector surface (`carray_surface`, `rt_carray_load` / `rt_carray_store`, `carray_assign`, the
  "no reference" refusal) is then deleted. `&[T; N]` / `&mut [T; N]` passed to an `extern "C"`
  parameter is the element pointer (C's `T*` / `T[N]` parameter), one word. A C array is never
  passed by value (C cannot), only inside a record by `byval`, which `ffi_byval_plan` already lays
  out from the C size.
- **Large arrays in frames: they live in the frame, as in C and Rust, and that is made safe.**
  (1) A frame larger than one page gets a stack probe in the prologue (touch each page downwards;
  on LLVM `"probe-stack"="inline-asm"`), so a large frame can never step over the guard page that
  task stacks and the main thread have (docs/design/main-stack-overflow.md): an overflow is always
  reported, never silent corruption. (2) A function whose frame exceeds the default task stack
  (1 MiB) is a compile error naming the array, suggesting a vector or a static. (3) Plain array
  storage is not covered by the prologue's zero fill (`rep stosq` N:17290, small-frame stores
  O:2679), since construction fills it; a 4 KiB scratch buffer costs nothing per call.

## 4. Checks

- **No check** when the prover has `i < N`: `for i in N` / `for i in a.len()`, a refined index
  `i: u64 where i < N`, a constant index (checked against `N` at compile time; an out-of-range
  constant is a compile error), a dominating `if i < N` / `assert`.
- **Otherwise one compare against the constant, no length load**: a new leaf pseudo-op beside
  rt_slot4/rt_slotw (O:1126-1160, I:893-935), `rt_aslot` (checked) / `rt_aslotu` (proved), arguments
  base, index, and the constants N and element size as immediates. The native expansion is
  `cmpq $N,%rsi; jb .Lk; call rt_abort; .Lk: leaq (%rdi,%rsi,S),%rax` (`imulq` for a size that is
  not 1/2/4/8, as op 52 does); the failure message and location are the vector's, through the same
  site table. Being a pseudo-op, not a runtime call, it costs nothing on any target and the three
  targets need no new instruction (scales 1/2/4/8 and `imulq` are already lowered).
- **LLVM lifter**: `rt_aslot` lifts to `icmp ult i64 %i, N` + `br` to the cold stub, and the address
  to `getelementptr inbounds i8, ptr %base, i64 %i*S` where `%base` keeps provenance: a frame array
  is its own `[bytes x i8]` alloca (the aggregate fact), a field of a record is a GEP from the
  record pointer, a `&[T; N]` parameter is the incoming pointer. Because the bound is a constant,
  LLVM's own range analysis removes the checks the difference-logic prover cannot (nbody's
  `p[i * 3 + k]` with `i < 5`, `k < 3`), and SROA can promote a small non-escaping frame array to
  registers - which is what C and Rust get. `--verify-facts` re-emits the compare under a proved
  access, as it does for vectors (L:2075-2090).
- **Native optimiser**: frame-aggregate slots are never promoted, forwarded or reused while live
  (the `DynPair` rules, O:17-23, generalised to a width); a later step (A5) turns constant-index
  accesses of a non-escaping frame array into plain slot operands so the existing promotion puts
  vec3/vec4 maths in registers on the development build.

## 5. Generics

First step (A1-A3): concrete `N` only - literal, constant, static, or a value parameter already
bound in a specialisation (inside `fn f<@n: u64>` the body is compiled per value, so `[f32; n]` in
the *body* is concrete). Step A4: `N` as a generic parameter in signatures, inferred from the
argument type: `fn sum<@n: u64>(a: &[f32; n]) -> f32`, `struct Mat<@R: u64, @C: u64> { m: [[f32; C]; R] }`.
To make A4 small, A1 already stores the length as a type-level value (kind 31, or kind 9 in a
template) in kind 32's `args` rather than in `mode`, so substitution, the type key and inference
(N:25468) are the existing machinery for value parameters of records. No new generic syntax.

## 6. SIMD

An array is **storage**: memory with the element's alignment and C layout. A SIMD type (`f32x4`,
`f32x8`, ... per simd-layout-parallel-loops.md D2) is a **value** in a register. The boundary is
explicit and free: `f32x4.load(&a)` / `f32x4.load(&a[4: 8])` and `v.store(&mut a)` /
`v.to_array() -> [f32; 4]` compile to one unaligned vector move; an array is never implicitly a
SIMD value and a SIMD value never silently spills to an array. Because `align_of(f32x4)` is the
element's (that note's own rule), `[f32x4; N]` and `[f32; 4 * N]` have the same layout and a
`[f32x4]` slice can overlay an array of `f32`. Arrays get no lane-wise operators: `a + b` on arrays
is not defined (it would make arrays a second, slower SIMD type). LLVM may still auto-vectorise
loops over arrays; that is a bonus, not the contract.

## 7. Dependency on unboxed stage 3

Arrays in frames need exactly 3a's fact - "an aggregate of W words at frame slot k" (the
`DynPair` fact, L:50-66, L:263-267, L:2883, generalised to a width; O's pair rules with a width).
Stage 3 is approved but only its doc exists (`gaps12-unboxed` c0bfca1). Proposal: **A0 builds that
fact alone, with no record using it**, as one commit pushed early, so /root/unboxed_design's 3a
rebases onto it and records become its second user. If 3a already has it in progress, A1 builds on
theirs instead; the director decides. Nothing else of stage 3 is needed for A1-A2:
`&[T; N]` parameters are one word; arrays by value as arguments and results follow 3b/3c (A3), and
the copy rule (section 2) is arrays-only until 3d.

## 8. Stages

Every stage: `bun tools/test-selfhost.mjs`; filtered corpus `GRAIL_TEST_FILTER=array|c-array|unboxed-|slice|ffi`
(counts reported); cases run on x86_64, aarch64, riscv64 and with `GRAIL_BACKEND=llvm`; book chapter
(`records-and-vectors.md` gains "Fixed-size arrays") and CHANGELOG in the same commit as the
user-visible change. Corpus names `array-*` / `reject-array-*`.

- **A0 - frame aggregates.** `fact_aggregate(fn, slot, words)` in L; O: never promote / forward /
  kill / split; L: one `[8W x i8]` alloca, `leaq` of it is the pointer. No user yet: test by a
  corpus case after A1. Fixed point byte-identical (no emitter uses it).
- **A1 - arrays in locals.** Type `[T; N]` for scalar, plain-record, extern-record and array
  elements; expected-type literals and repeats; indexing (`rt_aslot`/`rt_aslotu`), `a[i] = x`,
  `&a[i]`, `&mut a[i]`; `.len()` constant; `&[T; N]` / `&mut [T; N]` (parse fix in `slice_ahead`),
  as parameters; `for i in a.len()`; `==`; printing; the copy rule; interface spelling of kind 32
  (fixes the `grail run` failure); prover: `a.len()` is the literal N and constant indices are
  checked at compile time. *Accept*: literal/repeat/nested `[[f32; 4]; 4]`; `[f32; 4]` copied and
  both used; `[f64; 15]` passed as `&mut` and mutated; `for i in 4 { a[i] }` (asm pin: no compare);
  `a[k]` with unknown `k` (asm pin: `cmpq $N`, no length load) and its run-time abort at the right
  line; `==`; `size_of([f32; 4]) == 16`. *Refuse*: wrong literal count; `mut a: [f32; 4];`; non-constant
  `N`; `a[7]` on `[_; 4]`; implicit copy of `[f64; 5]` then use (hint `.copy()`); `&mut a[0]` with
  `&a[1]` live; owned element (until A3). LLVM: frame array is one alloca, accesses are GEPs.
  **Measured**: `bench/nbody_arr.grl` (nbody.grl with `[f64; 15]`/`[f64; 5]` and
  `energy(p: &[f64; 15], ..)`) against `bench/nbody.c` (already the fixed-array C twin) and
  `bench/rivals/nbody.rs` / `.zig` (origin/gaps12-rivals): **target parity with `clang -O2` on the
  LLVM backend** (within noise), native within 3x; read the optimised IR of the step loop if not.
- **A2 - arrays everywhere plain data lives.** Inline in Grail records and in vectors (flat);
  slice conversion `&a -> &[T]` and slice methods, sub-slices `a[lo: hi]`, `copy_from`; statics
  (after `gaps12-statics-impl` lands); C interop: extern-record array fields become arrays, the
  vector surface deleted, `tests/ffi/c_arrays.grl`, the bindgen fixture and abundance's ten sites
  migrated; `&[T; N]` to C as a pointer (test-ffi: a C function summing a `float[4]` and one filling
  a `char[16]`). Until unboxed stage 2, the slice made from an array is the existing sub-slice view
  record (correct, one allocation); stage 2 removes it as it does for every sub-slice.
- **A3 - owned elements, by value.** Arrays of `string` / vectors / boxed records: element-wise
  drop, no move out by index, `exchange`/`swap`; arrays as by-value arguments and results (with
  3b/3c), consuming iteration. Allocator-balance cases.
- **A4 - generic length** `@n` in signatures and records, inferred from arguments.
- **A5 - native optimiser**: constant-index accesses of non-escaping frame arrays as slot
  operands (register promotion); optionally a prover rule for `i * k + j < N` from `i < a`, `j < k`,
  `a * k <= N` so the native build drops nbody's checks too.

## Questions for the director

1. A0 ahead of 3a (recommended; small, no user but arrays), or wait for /root/unboxed_design's 3a?
2. A2 unifies extern-C array fields with real arrays and deletes the copy-as-vector surface; the
   typed-literal acceptance keeps abundance's literals compiling, but `ids := d.ids` becomes an
   array (not a vector) and a vector assigned to a field becomes `copy_from`. Agreed?
3. `[T; 0]` refused in v1?
4. Untyped `[a, b]` stays a vector unless an array is expected (no existing program changes)?

## Director's answers and conditions (2026-11-16)

1. No A0: the frame-aggregate fact is unboxed stage 3a's (`llvm::fact_aggregate`, gaps12-unboxed
   72f29d3); arrays are its first user. 2. A2 unifies extern-C array fields with arrays and deletes the
   copy-as-vector surface, migrating abundance and the bindgen fixture; the CHANGELOG says
   `ids := d.ids` is now an array. 3. `[T; 0]` refused in v1, revisited with A4. 4. Untyped `[a, b]`
   stays a vector unless an array is expected.
Conditions: native nbody is judged against Zig Debug and Go; `for x in &a` is an index loop with no
call or allocation (asm-pinned); the slice made from an array allocates a view record until unboxed
stage 2, kept off hot paths (lib/ read APIs take `&[T; N]` or a pointer-and-length slice); probe,
frame-limit and 64 KiB-task cases; every case on three targets and LLVM.

## A1 as built

- *Representation.* An array value is the address of its bytes (`direct`, as a record). Its storage
  is a frame aggregate per making site (`array_storage`). A new binding adopts a literal's or a
  `.copy()`'s storage (`bind_value`); anything else bound gets a copy (`move_value`); assignment,
  `*r = v` and `exchange` copy bytes into the destination's own storage (`assignment_tail`,
  `record_bytes` → `swap_records`). So no two names share storage.
- *Checks.* `rt_aslot(base, i, N, w)` (checked) and `rt_aslotu(base, i, w)` (proved, literal
  offsets) are leaf ops 53/54, written in line by the optimiser (`cmpq %rdx,%rsi` against the
  constant, `rt_fail(1, i, N)` on the cold path) and lifted by `llvm::array_element` to `icmp` +
  `getelementptr inbounds` on `inttoptr(base)`, which folds to the alloca: provenance kept.
  Proofs: `array_index_proved` asks the prover for `i < N` or `i < a.len`; a literal index is
  checked while compiling.
- *Ownership.* `affine_nodrop` (an exclusive reference, or an array over 32 bytes) gives an owned
  place with no drop flag; smaller arrays are copyable roots in `bind`.
- *Stack.* `frame_limit` sets `probes` for a frame over a page and refuses one over 1 MiB;
  `optimize::probe_frames` writes the page walk before the frame's `subq` from the final `.set`
  sizes, on the optimised, debug and LLVM-remainder outputs; lifted functions carry
  `"probe-stack"="inline-asm"`. Windows (targets 3, 4) describes its prologue to the unwinder,
  so there the probe follows the frame line and touches the pages from the top down with `%rax`,
  `%r10`, `%r11` (Windows grows a stack only through its guard page - `__chkstk`'s job); the windows
  leg runs a 64 KiB frame on the main thread and in a task (fiber) under wine.
- *Refused in A1* (A2/A3): by-value parameters and results, struct fields, vector elements, type
  arguments, closure captures, non-numeric elements. No slice conversion yet, so no view record is
  allocated anywhere by arrays.
- *Measured* (bench/nbody.grl, now the fixed-array twin of bench/nbody.c; shared loaded host):
  LLVM 0.128 s vs C 0.145 s (paired median of 7, spread ±0.1 s; the optimised IR of the step loop
  has no bounds check, every access a GEP on its own alloca, `m[j]` loaded once). Native 0.59 s
  (vectors: 1.12 s); Zig Debug 0.90 s, Go 0.109 s, Rust -O2 0.100 s. The native gap to Go is A5's:
  the base is reloaded from a slot at each access, `i * 3 + k` keeps the dev build's overflow checks,
  and the constant compare costs two `movabsq`.
- *Verified.* Self-host fixed point (119.8 MB, stage 2 = stage 3); filter `array`: x86_64 31/0,
  aarch64 29/0, riscv64 29/0, LLVM 27/0; regression filter
  `c-array|literal|repeat|narrow|unboxed|slice|exchange|equal|stack|overflow|dyn|struct|record|tuple|closure|print|format|refine|deref|vector`
  x86_64 656/0; book tests 12/0.

## A2 as built

- *Records.* An array is plain data (`layout_bits` answers 1), so a struct or tuple holding one keeps
  it inline at a word offset (`field_layout`, `record_words` = whole words of its bytes); a field
  read is its interior address, which a binding copies (`move_value`); `copy_into` copies an
  array's bytes and frees nothing; `materialise` leaves arrays to the binding. Generic records take
  arrays as type arguments; enums and options do not (their payload is one word until stage 5).
- *Vectors.* `[T; N][]` is flat with element width `array_bytes` (`flat_bytes`); `rt_pushwk` and
  `rt_vec_insertwk` copy from frame storage without freeing it; `remove` and `pop()!` copy the boxed
  element into frame storage and free the box (`array_unbox`); `pop()`'s option is refused.
  `push`/`insert` arguments and the right side of `v[i] = ...` take the element type as their
  expected type (`index_target_array`), so a bracket literal there is an array.
- *Slices.* `array_to_slice` (from `coerce_view` for call arguments and from typed bindings) and
  `a[lo: hi]` (`array_subslice`) make a view record with `rt_aslice`; any method other than
  `len`/`copy`/`copy_from` views the array (exclusively for `&mut` or a `mut` binding) and continues
  as the slice's method. **This is where arrays still allocate: one 32-byte view record per slice
  made from an array, freed when the slice is dropped. Nothing in lib/ takes arrays yet; a read API
  that wants to avoid it takes `&[T; N]`.** `copy_from` copies bytes when the vector stores the
  element as the array does (bytes, 4-byte narrow, words, flat records) and checks the length at
  run time (`rt_array_copy_from`, failure kind 10, now "array length mismatch").
- *C structs.* `field_type` no longer surfaces `[T; N]` as `T[]`; `cfield_load` gives the interior
  address for a reference, an index, a method or an assignment, and a copy for a whole read;
  `cfield_store` and `caddr_store` copy bytes. Deleted: `carray_surface`, `surface_field_ty`,
  `carray_elem`, `carray_assign`, the vector branches of `cfield_load`/`cfield_store`, and
  `rt_carray_store`. `rt_carray_load` stays: it serves compile-time tables and `cslice`. A
  reference to an array is never a tagged narrow reference (`tag_narrow_borrow`). Migrated:
  abundance `rhi_vulkan.grl`, `tests/ffi/c_arrays.grl`, the bindgen fixture program and test.
- *Statics* wait for `gaps12-statics-impl` to land in this base.
- *Verified.* Self-host fixed point; filter `array`: x86_64 39/0; `array|c-array|cimp`: aarch64
  38/0, riscv64 38/0, LLVM 34/0; test-ffi 81 linked and executed; bindgen-test 68 checks;
  abundance tests all pass but `abgeo_test`, which fails identically with the base compiler
  (`5dc07da`: the geometry hashes differ from the reference on this host).
