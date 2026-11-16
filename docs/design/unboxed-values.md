# Unboxed values

2026-11-16. Design note for stage 3 of `docs/design/compile-speed.md`. Nothing here is implemented.
Every factual claim is marked **[V]** (verified: read at the cited `file:line` of `78c8c6e`, or
measured here) or **[A]** (assumed: inferred, not checked). Measurements were taken on a shared
24-core host under load (another gate was running), best of three; treat them as ±10 %.

## Decisions for the owner

1. **The model.** Keep a `Val` one word. An aggregate (record, tuple, enum, view, later a vector
   header) is *denoted by the address of its words*; what changes is where the words live: inline in
   the frame, the enclosing record, the vector buffer - not in a heap block of their own.
   *Recommend: yes.* It is what a record `Val` already is (a pointer to its words), so the front
   end's 121 `save` sites and 195 runtime-call sites keep their shape.
2. **Order.** You expected "vectors of plain-data records inline" and "views as two words" first.
   *Recommend: confirm both as stages 1 and 2, with two corrections.* (a) Stage 1 must also change
   what `&T` to a record is (below), or flat elements cannot be borrowed. (b) For *compile speed*
   neither is the largest item: 68-74 % of the compiler's allocations are vector headers and
   buffers, 19-20 % records, 6-13 % view records (measured below), and in a full build allocation
   is 20 % of the work, not 40 %. Views still go second because they are cheap.
3. **Floats on the native backend are a separate blocker for the engine.** The 1M-`{x,y,z: f32}`
   benchmark runs 11.8 s natively against 0.14 s through LLVM and 0.05 s in C, because every `f32`
   operation is a call (`rt_f64_op` + `rt_f32_round`). No layout work moves that number.
   *Recommend: decide whether the engine ships on the LLVM backend only; if not, inline float
   arithmetic in the native stream is its own task, ahead of stage 1 in value.*
4. **Layout of a plain record.** *Recommend: word-granular first (each field 8 bytes, as today),
   C-like packing in declared order as a later stage (stage 7); `size_of` stays refused for non-extern
   records until then,* so the layout is not promised before it is final.
5. **Recursive types.** Inline options make `next: Node?` infinitely large. *Recommend: the compiler
   boxes the field that closes a cycle (it already finds those edges); no new syntax now.* An explicit
   `Box<T>` can come later and would need a two-step bootstrap.
6. **View ABI.** *Recommend: a view is a handle to a `{pointer, length}` pair that lives in a frame, a
   record, a vector buffer or a vector header - never the heap - returned in two registers. This is
   exactly the `DynPair` rule of `docs/design/fat-dyn.md`.* Passing views in two registers is a
   later optimisation, not a prerequisite.
7. **Vector and string headers inline (three words).** *Recommend: yes, as stage 6.* It is the
   largest allocation count in the compiler (40 %) but touches every runtime function that returns a
   vector, so it goes after frames can hold aggregates.
8. **No opt-in attribute.** *Recommend: every record that qualifies is unboxed; "plain data" is a
   property the compiler computes, not something the programmer writes.*
9. **Bootstrap.** *Recommend: no transitional compiler per stage and no reseed per stage* (this
   corrects compile-speed.md's "a reseed per sub-stage"): a representation change alters emitted
   code, not the source the seed must read. Reseed at publication, as `docs/testing.md` already says.

## 1. Where the one-word assumption lives

All `[V]`. `N` = `compiler/native.grl`, `R` = `compiler/runtime.grl`.

**Front end: values and slots**
- `Val {t, ty}`: `t` is one frame slot (N:298). Every slot is 8 bytes at `-(id+1)*8(%rbp)`
  (`stack_slot`, N:2783-2789). `save` stores `%rax` into a fresh slot (N:3016); `get` loads one
  (N:3050). `save(&mut c)` is called at 121 sites, `invoke`/`apply` (runtime calls returning one
  word through `save`) at 195.
- The front end writes an x86-64-spelled *word stream* as text; it is not an IR with types.
  Types travel beside it as "facts" (`llvm::Fact`, `compiler/llvm.grl:19-41`).
- Records: a constructor calls `rt_rec(count)` and stores each field at `k*8` (N:22100-22105).
  The field offset `k*8` is computed in exactly two places, `rec_load` (N:20224-20233) and
  `rec_store` (N:20235-20241); 32 and 14 call sites. Nested records are nested boxes: `Q {a: P, b:
  P}` is three `rt_rec` calls (measured: `.work/ub/t_nest.s`).
- Tuples are records declared on demand as `.tuple::TupleN`, 2 to 12 elements (N:11481-11500).
- Enums and options: `rt_enum(tag, payload)`, a 16-byte block with a one-word payload (N:22305,
  R:1666). `T?` is the ordinary enum `result::Option` (N:28232-28239); `pop()` builds one in the
  runtime (N:32117-32128). Changing a variant frees and reallocates (`rt_enum_retag`, R:1672).
- Views (kind 5): one word, the address of `{pointer, length}`. A whole-vector view is the vector's
  header; a sub-slice is a heap record 8 past a 16-aligned block (R:1410-1456), freed by
  `rt_view_free` (R:1422).
- Vectors: a 24-byte heap header `{pointer, length, capacity}` (`rt_new`, R:1181) plus a separate
  buffer of 8-byte elements (`rt_push`, R:1184-1202; `rt_slot` scales by 8, R:1384-1389).
- Narrow vectors: `narrow_code` answers 1/2/3 for `f32`/`u32`/`i32` elements and nothing else
  (N:20507-20523); a second family of runtime functions handles width 4 (`rt_push4`, `rt_vec_*4`,
  R:6441-6617). Element width is therefore one of {8, 4, 1}, chosen by name, not a parameter.
- References: `&T` to a record is the address of the *slot that holds the record's pointer*, not of
  the record: `&mut v[i]` is `leaq (data,i,8)` and each field access through it loads twice
  (`movq (%rax),%rax; movq 8(%rax),%rax`; measured in `.work/ub/out/aosu-native/aosu.s`; N:37473).
  Sub-word referents use a tagged pointer (bit 63) and branch on it at every load (N:31885-31909).
- `exchange` on a word-sized referent is `rt_xchg`, one word swapped (N:25854, R:1677).
- Calls: at most six argument words in registers; a seventh makes the caller allocate a heap record
  for the overflow, which the callee frees (N:3765-3790). One result word in `%rax`; the single
  exception is a returned `&dyn`, two words in `%rax:%rdx` (N:3038-3046, N:37024-37029).
- Closures: the environment is `rt_rec(count)`, one word per capture (N:29455-29459); a function
  used as a closure is a three-word record `{code, drop, target}` (N:23815-23825).
- Owned `dyn I`: a two-word heap cell `{value, vtable}` whose value is one word (N:10468-10475).
- Extern C records are already C-laid-out (`ffi_field_size`/`ffi_field_align`/`ffi_offset`,
  N:14152-14261) but still live in a heap block (`rt_rec(words)`: N:20432, N:36890, and for a C
  result N:13658). `byval` (kind 28) is a parameter-passing class only (N:13424-13435,
  `ffi_byval_plan` N:20935). A view already crosses to C as two words (N:13425).
- `size_of`/`align_of` refuse a non-extern record: "a managed object whose layout the language does
  not promise" (N:17227-17230). That refusal is what leaves the layout free to change.

**Ownership and drops**
- `needs_drop` is true for *every* record and enum (kind 8), because the box itself must be freed
  (N:3856-3883). There is no "plain data" predicate yet.
- Drop helpers are emitted per type and read fields at `i*8(%r12)` / an enum payload at `8(%r12)`
  (N:38844-38870), then free the block.
- The checker is already field-granular and layout-independent: places form a storage tree with
  per-field children (`compiler/ownership.grl:14-25`). A by-value read of an element or field of
  an aggregate is already a *borrow* of the container: `q := v[0]` followed by `v.push(..)` or
  `v[0] = ..` is refused with E0008, and so is growth under `&v[0]` (measured:
  `.work/ub/t_alias.grl`, `t_alias2.grl`, `t_grow.grl`). Records are move-only (`b := a` then
  `a.x` is E0006), and `==` on records is structural (two separate allocations compare equal), so
  no program can observe a record's address through `==`.

**The text optimiser** (`compiler/optimize.grl`, `compiler/ir.grl`)
- Operands are classified as register / frame slot `-N(%rbp)` / other (ir.grl:24-25); passes forward,
  kill, promote to callee-saved registers and compact *single slots* (optimize.grl:7-12, 1782-1784).
- One two-word value exists: a `DynPair`, declared by a fact; its slots are never promoted or
  forwarded, never dead, kept adjacent, and a function that builds one is not inlined
  (ir.grl:27-36, optimize.grl:17-23, 1169-1177, 1841-1849).
- The runtime accessors are expanded inline by name with the scale 8 built in: `rt_slot`, `rt_at`,
  `rt_len`, `rt_xchg`, `rt_push` (ir.grl:749-760).

**The three native targets** (`compiler/machine.grl`)
- `lower` translates the x86-spelled stream line by line (machine.grl:1463, `instruction` :1031).
  It knows `movq`, `movl`, `movb`, `movzbq`, `movabsq` (machine.grl:1419-1423). It has no notion of
  a value's width beyond the instruction's: a multi-word value spelled as word moves needs nothing
  new here. **[A]** new addressing forms (a scaled index other than 8) would.

**The LLVM lifter** (`compiler/llvm.grl`)
- Lifts the same stream: registers and each 8-byte frame slot become allocas (llvm.grl:3-9,
  260-262, 2835-2860); calls pass six `i64` words and return the `rax:rdx` pair (llvm.grl:8). A
  `DynPair` is one `[2 x i64]` alloca (llvm.grl:263-267, 2619). Typed facts name f32 slots and
  vector headers of element width 8/4/1 only (llvm.grl:19-41).

**Generics.** Every generic is specialised per type; the symbol is a hash of the structural type
key (N:22362-22394, `type_key` N:5666-5700). Layout is therefore always known where code is
emitted. compile-speed.md's stage 6 (shared generic bodies) would end that and is rightly after this.

**Interface files.** An interface carries one ABI line, for `dyn`, and a reader refuses a file whose
line differs (N:39154-39164). Record layout has no such line because layout is uniform today.

**Caches.** A per-function unit stores text, labels and opaque facts (`compiler/fncache.grl:4-33`);
its key includes the declaration surface and typed signature (N:14806-14820). A module's store key
names the compiler's own digest (`compiler/cli.grl:1541-1546`). So a new compiler never reuses an
old-layout object; nothing to migrate. (`id.compiler` is the digest of the executable, cli.grl:2779.)

**Debug info.** A record is described as `8 * count` bytes, a view as 16 (N:1638, N:1684).

## 2. Measurements (today's baselines)

Compiler: `.work/native/256d304c54af594175cf5c2c/grail`, built from `78c8c6e` by `grail-c6`.

**Compile bench** (`bun tools/compile-bench.mjs`, natively built compiler) **[V]**

| | seconds |
| --- | --- |
| check syn250 / syn1000 / syn4000 | 0.515 / 1.335 / 5.007 |
| check hello | 0.250 |
| build hello: empty store / after edit / `--no-cache` | 1.051 / 0.207 / 0.568 |
| check generic (100x20) | 1.703 |
| **self-compile** | **11.267** |

The compiler as shipped (`--release`: the same sources through LLVM, 6.6 MB against 27 MB) **[V]**:
check syn1000 0.228 s, check hello 0.038 s, build hello `--no-cache` 0.186 s, check generic 0.277 s,
**self-compile 2.982 s**. compile-speed.md's target of "self-compile at or under 10 s" is already
met by the release build; stage 3 should be judged against 2.98 s, not against 41.6 s.

**Where the compiler's allocations come from** (`valgrind --tool=callgrind`, `GRAIL_JOBS=1`,
`grail check` of the 26k-line scaling program; 9.99 G instructions, 5.85 M allocations) **[V]**

| allocation | calls | share | removed by |
| --- | --- | --- | --- |
| vector/string headers (`rt_new`) | 2,364,725 | 40 % | stage 6 |
| vector buffers (`rt_grow`) | 1,630,905 | 28 % | not by this note |
| records (`rt_rec`) | 1,104,724 | 19 % | stages 1 and 3 |
| - of which `Val` | 308,284 | 5 % | stage 3 |
| - of which tokens (built twice: lexer.grl:411, N:9151) | 449,318 | 8 % | stage 1 |
| sub-slice view records (`rt_slice`) | 745,217 | 13 % | stage 2 |
| enums (`rt_enum`) | 0 | 0 % | - |

`rt_alloc_unlocked` + `rt_free_unlocked` + `rt_free` + `rt_alloc` + `rt_drop_seq` + `rt_view_free`
are 38.4 % of all instructions in that run, which agrees with compile-speed.md's "about 40 %".

**The same for a self-compile** (one process, 261 G instructions, 60.0 M allocations) **[V]**

| allocation | calls | share |
| --- | --- | --- |
| vector buffers (`rt_grow`) | 22,190,870 | 37 % |
| vector/string headers (`rt_new`) | 22,086,774 | 37 % |
| records (`rt_rec`) | 12,211,248 | 20 % |
| - `ownership::snapshot` | 5,498,647 | 9 % |
| - `ir::ty` (the optimiser's type record) | 2,833,631 | 5 % |
| - `Val` | 1,101,305 | 2 % |
| - tokens | 1,235,766 | 2 % |
| sub-slice view records | 3,542,555 | 6 % |
| enums | 0 | 0 % |

Here the allocator and view runtime are **20 %** of instructions, not 40 %: the optimiser and its
IR are 51 % (`optimize::*` 24 %, `ir::*` 27 %), the front end 14.5 %. So "40 % is allocation" holds
for a check and not for a full build, and unboxing can remove at most a fifth of a self-compile.

**Data-oriented micro-benchmark** (sources in section 5; 1M records, built by `push`, 20 passes of
transform-in-place then sum; `--overflow=wrap`) **[V]**

| program | native backend | LLVM backend | C `-O2` | peak RSS |
| --- | --- | --- | --- | --- |
| `V3 {x,y,z: f32}[]` (boxed today) | 11.79 s | 0.137 s | 0.049 s | 68 MB (C: 13) |
| three `f32[]` columns | 10.49 s | 0.071 s | - | 12 MB |
| `P3 {x,y,z: u64}[]` (boxed today) | 0.183 s | 0.125 s | 0.022 s | 68 MB (C: 25) |
| the same after shuffling the vector | 1.026 s | 0.404 s | - | 68 MB |
| three `u64[]` columns | 0.121 s | 0.086 s | - | 23 MB |

What it says: (1) boxing costs 3x to 5x memory and, once allocation order and vector order differ
(the shuffled row, which is what a running engine looks like), 3x to 6x time on top; (2) even the
hand-written columns are 3x to 4x off C, so flat storage alone will not reach C; (3) on the native
backend float arithmetic dwarfs everything (decision 3).

## 3. The representation

One rule: **an aggregate value is the address of its words, and its words are stored inline in
whatever owns it.** A `Val` stays one slot. Moving an aggregate copies its words into the
destination's storage; borrowing it is its address.

| value | today | recommended |
| --- | --- | --- |
| record in a local | pointer to `rt_rec` block | words in adjacent frame slots; the `Val` is their address. Field access to a frame aggregate whose address never escapes is emitted as plain slot access, so the existing promotion applies; one whose address is taken is declared by a fact (the `DynPair` fact generalised to N words) |
| record in a record | pointer to a second block | fields inline at an offset from a per-declaration layout table; `r.a` is `base + offset` (what `rec_load(.., address = 1)` already emits) |
| record in a vector | pointer per element | elements inline; element size = record size, alignment 8 (until packing: stage 7). `v[i]` is `data + i*size`; `&v[i]`/`&mut v[i]` are that address; `push` copies the words in; `swap`, `insert`, `remove` move `size` bytes. Growth moves every element and invalidates every element address - which the checker already forbids while any borrow of the vector or of an element is live [V, section 1] |
| record with drop / owned fields | same box | same inline storage; its drop helper splits in two: *drop in place* (drop the fields) and, where a box still exists, *free*. A vector of them drops element by element in place. Staged after plain records (stage 4) |
| record holding references | same box | inline; a reference field is one word. Lifetimes are the checker's business and do not depend on layout [V: ownership.grl:14-25] |
| `&T`, `&mut T` to an aggregate | address of the slot holding the pointer | the address of the words. One load fewer per field access; `&local` is the value's own word |
| tuple | record | as a record |
| enum, `T?` | `rt_enum` block, one-word payload | `{tag, payload words}` inline, size = 1 + the largest variant. Niche: `T?` where `T` is a reference, a handle or (until stage 6) a vector is one word with 0 for `None`; no other niche. A field that closes a type cycle stays a pointer (decision 5) |
| view, slice | pointer to a header or to a heap pair | handle to a `{pointer, length}` pair that is never on the heap: the vector's own header (as today), two frame slots, or two inline words of a record/element. Bound to a name or stored: the two words are copied. Returned: `%rax:%rdx` |
| vector, string, bytes | pointer to a heap header | (stage 6) the three header words inline; the `Val` is their address, so a whole-vector view stays "the header" |
| argument | one word | an aggregate argument is the address of the caller's words; the callee owns their contents. A move into a call therefore copies nothing |
| result | one word in `%rax` | up to two words in `%rax:%rdx` (the existing dyn-result rule); larger through a hidden destination pointer as the first argument |
| closure captures | one word each in a heap environment | the environment stays a heap record (a closure is type-erased); captured aggregates are inline fields of it |
| extern C | `byval` plans | unchanged at the boundary; an `extern "C" record` in a `T[]` becomes contiguous C-layout storage, which is what can be handed to C as `(pointer, count)` |

Why arguments are addresses and not split across registers: a call with more than six argument words
allocates a heap record today (N:3765-3790). Splitting aggregates into words would push many calls
over that line and add the allocation this note exists to remove.

Why register passing of results stops at two words: `%rax:%rdx` exists in both backends and all
three targets already (the dyn result). `Val` is two words, so the compiler's most frequent
aggregate result fits.

## 4. Semantics

**Must not change**
- Move-only records, definite initialisation, partial moves, drop order, drop exactly once.
- Every borrow rule. In particular nothing new is unsound: element and field reads already borrow
  the container [V], so an interior address is never live across a growth or an overwrite.
- Structural `==`; the C ABI at `extern "C"`; `&dyn` (fat-dyn.md) - its data word becomes the
  address of the words, which is what it already is for a boxed record.
- Self-compile fixed point: the compiler built by the new compiler emits itself byte for byte.

**Would change**
- **Moves copy N words** instead of one. A large record moved in a loop gets slower. The
  compiler's context is one record of about 450 fields (compile-speed.md); it is passed by `&mut`
  everywhere (built once, N:43508; no function takes or returns `C` by value, by grep) **[V]**,
  so it is not moved; a stage should still count words moved.
- **Identity.** A record no longer has a stable heap address; moving it changes its address. No safe
  code can see this [V: `==` is structural; A: there is no address-of-to-integer for a Grail record
  outside `unsafe`].
- **`exchange(&mut r, v)`** swaps the words of the referent instead of one pointer: same meaning,
  cost proportional to size.
- **`&T` to a field** is an interior address (`base + offset`). It was already the address of the
  field's slot; what is new is that the slot is the value, not a pointer to it.
- **Vector operations on record elements** (`swap`, `sort`, `insert`, `remove`) move whole
  elements. Sorting a vector of large records gets slower; that is the honest cost of flat storage.
- **Stack use grows.** Frames hold aggregates, and the prologue zeroes the frame (`rep stosq`,
  N:15709; small frames by direct stores, optimize.grl:1860). Deep recursion in the compiler's
  expression parser needs measuring (`docs/design/main-stack-overflow.md`).
- **Recursive types** need an indirection the compiler inserts (decision 5).

## 5. Alternatives considered

- **Escape analysis only** (keep the model, stack-allocate boxes that do not escape). Removes some
  allocations; leaves a vector of records a vector of pointers, leaves the double load, leaves the
  5x memory. Its result depends on inlining, so an engine cannot rely on it. Rejected as the plan;
  it falls out of stage 3 for free.
- **Opt-in value types** (`@value struct`). Lowest risk, but it makes two kinds of record, every
  generic and container must handle both forever, and the compiler's own sources would need the
  attribute on nearly every record to get the benefit. The same predicate ("plain data") is used
  internally to *stage* the work instead.
- **Arenas only.** Makes allocation cheap; does not remove indirection, memory overhead or cache
  misses (the shuffled row). Complementary: an engine wants frame arenas as well.
- **Wide values** (`Val` carries N slots; aggregates travel in N registers). The textbook answer and
  the best code for two-word values, but it rewrites every `save`/`invoke` site and collides with
  the six-word call limit. The address rule gets the allocation and layout wins without it, and
  two-register *results* are kept where they already exist.
- **Two-register views everywhere.** fat-dyn.md rejected this for `&dyn` for reasons that hold
  here (Win64 passes 16-byte aggregates by reference; it doubles every container of views; the
  optimiser's pair rule would apply to every view in the program).

## 6. Stages

Bootstrap, once, for all stages. A stage changes the code the compiler *emits* and the runtime it
compiles alongside (`runtime.grl` is compiled from source by the same compiler in every build
[V: `tools/native.mjs:488`]). The sources stay readable by the previous compiler, so:
old compiler builds C1 (old layout inside, emits new layout); C1 builds C2; C2 builds C3; the
acceptance is `C2.s == C3.s`. **Zero transitional compilers, three builds, no reseed.** A stage
needs a two-step bootstrap only if the compiler's own sources start using new *syntax* (none of
these stages adds any; `Box<T>` would). `tools/test-selfhost.mjs`'s "byte-identical before and
after" cannot hold across a stage and must be replaced by the fixed point for that commit.
Interface files gain a layout line beside the `dyn` ABI line (N:39162), bumped per stage, so
objects of two layouts never link.

Every stage: benchmark = `bun tools/compile-bench.mjs` (self-compile; plus `--release`) and the
micro-benchmark, on both backends; allocation count from callgrind on `check syn1000`.

**Stage 0 - plumbing, no behaviour change.** Generalise the `DynPair` fact to "aggregate of N words
at slot k" in `llvm.grl` facts, `ir.grl`/`optimize.grl` (`pair[n]` becomes a width), fncache fact
framing; add a layout table (size, per-field offset) beside `Decl`, with `rec_load`/`rec_store`
reading it (offsets stay `k*8`); add `plain(ty)`. Files: native.grl, ir.grl, optimize.grl, llvm.grl,
fncache.grl. Acceptance: self-compile byte-identical (`tools/test-selfhost.mjs`,
`tools/ssair-bytes.mjs`). Risk: low. Bench: unchanged within noise.

**Stage 1 - flat vectors of plain records** (engine first; removes the 8 % token allocations).
- 1a: `&T` to a record becomes the address of its words (all records, still boxed);
  assignment and `exchange` through such a reference copy words. Measurable alone: one load fewer
  on every `c.field` through `c: &mut C`. Risk: `mut r: R;` passed as `&mut r` before it holds a
  value needs its storage to exist at the declaration (as extern records already do, N:36886).
- 1b: plain records nest inline in plain records; `T[]` of a plain record (or of an `extern "C"
  record`) stores elements inline. Element size becomes a parameter of the vector runtime
  (`rt_push`, `rt_slot`, `rt_at`, insert/remove/swap/truncate/copy) and of the optimiser's inline
  expansions; the `*4` family folds into it.
- Files: native.grl (index, push, iteration, slices, `narrow_*`, drop helpers), runtime.grl,
  ir.grl/optimize.grl (accessor expansion with a size), llvm.grl (header facts with a width),
  machine.grl only if a new addressing form is spelled.
- Risks: every `rt_*` that assumes 8-byte elements reached with a flat vector (generic library
  code over `T[]` is specialised, so each instance knows its size [V]); `rt_take`/consuming
  iteration; slices of flat vectors (`rt_vslice` already takes a width, R:1438).
- Acceptance: new corpus cases for push/index/`&v[i]`/`&mut v[i]`/swap/insert/remove/slice/iterate
  over nested plain records; E0008 cases unchanged; an assembly assertion that `&v[i]` has no load of
  an element pointer; `extern "C" record[]` passed to a C function that sums it; fixed point.
- Bench: `aosu`, `aosu_shuf`, `aos`. Target on LLVM: shuffled = unshuffled, RSS <= 30 MB, time
  within 1.5x of the column version. `push` still builds a box and frees it until stage 3.

**Stage 2 - views are pairs, never allocations** (removes the 13 %).
A sub-slice writes two frame slots declared as a pair and yields their address; results come back
in `%rax:%rdx`; a view field or element is two inline words (layout table from stage 0, flat
elements from stage 1); `rt_view_record`, `rt_view_free` and the `& 8` address test in `rt_free`
(R:974-984) are deleted. Files: native.grl (the 10 `rt_view`/`rt_slice`/`rt_vslice` sites and view
drops), runtime.grl, llvm.grl (descriptor fact 5), optimize.grl. Risks: a handle to a frame pair
escaping its frame - bind, store and return must copy; a view inside an enum payload before stage 5
(keep one boxed pair there until then). Acceptance: zero `rt_alloc` from slicing in callgrind;
`@no_alloc` accepted on a function that slices; fixed point. Bench: self-compile, check syn1000.

**Stage 3 - records in frames, arguments by address, results in registers** (removes `Val`'s 5 %
and the box in every `push`; what vector maths in an engine needs).
Files: native.grl (constructors, binding, moves, call and return paths, drop flags), optimize.grl
(promotion of aggregate words whose address does not escape; inlining with aggregates), llvm.grl
(`[N x i64]` allocas, two-word results beyond dyn, hidden destination argument). Risks: the largest
stage; frame growth and prologue zeroing; a callee keeping an argument address past the call (it
must copy to store); drop flags per aggregate rather than per pointer. Acceptance: no `rt_rec` in
a function that builds, passes and returns plain records (assembly assertion); stack-depth test on
the deepest corpus program; fixed point. Bench: all; expect the micro-benchmark build phase to drop.

**Stage 4 - records with drop and owned fields inline** (in records and vectors). Drop helpers
split into in-place and boxed. Risk: partial moves out of inline fields, drop of a half-built
vector on panic paths. Acceptance: allocator-balance corpus, `impl Drop` order cases.

**Stage 5 - enums and options inline**, with the one-word niche and automatic boxing of cycle
edges. Files: native.grl (constructors, `match`, `?`/`!`, retag in place), runtime.grl
(`rt_pop_option`, `rt_enum*` deleted), interface writer. Acceptance: recursive-type cases, `match`
corpus, fixed point.

**Stage 6 - vector and string headers inline.** Every runtime function that returns a vector takes
a destination instead. Removes the 40 %. Risk: breadth of runtime.grl; literals' static headers.

**Stage 7 - packed layout** (`f32` in 4 bytes, natural alignment, declared order), `size_of` for
plain records, sub-word loads spelled inline instead of `rt_load_sized`/`rt_store_sized` calls
(N:20502). This is the stage that makes `V3` 12 bytes; until then an engine uses `extern "C"
record` for GPU data, which stage 1 already stores flat.

Stages 2 and 3 are independent of each other after stage 1 and can swap if vector maths matters
more than compile time. Stage 6 needs stage 3 only.

## 7. Compile speed, both directions

- **Faster.** Allocator work is 38 % of a check and 20 % of a self-compile. By allocation count
  (check / self-compile) the stages remove 8 / 2 % (1), 13 / 6 % (2), 5 / 2 % or more (3 - more if
  `snapshot` and `ir::ty` records, 14 % of a self-compile's allocations, are short-lived locals
  **[A]**) and 40 / 37 % (6); each also removes the matching free and, for views, a
  call per hop. One load fewer per field access through a reference (1a) applies to almost every
  line of the compiler. **[A]** the time saved is proportional to the count; it is measured per
  stage, not promised.
- **Slower.** (a) Moves of N words: more instructions and, because the pipeline is text, more lines
  for the optimiser to parse - the self-compile already writes 110 MB of assembly [V:
  `.work/cg/self.s`]. Copies above about four words should be a call (`rt_copy_words`), not inline
  moves. (b) Larger frames, zeroed in the prologue. (c) Specialised vector code per element size
  where one 8-byte routine served every record type: more emitted functions. (d) Two drop helpers
  per type during stages 4-5.
- **Code size** is expected to grow a few percent **[A]**; the bench must report the size of
  `self.s` and of the compiler binary per stage so the trade is visible.

## Open questions

1. Does the engine ship on the LLVM backend only (decision 3)?
2. Given the release compiler already self-compiles in 2.98 s and allocation is 20 % of that work,
   is stage 3 of compile-speed.md still ordered before direct object emission (its stage 4)? The
   optimiser's text pass is 51 %. The engine's needs justify stages 1-3 here on their own.
3. Should a by-value read of a plain element (`q := v[i]`) stay a borrow, or become a copy for
   small plain records? Staying a borrow changes nothing; a copy is friendlier for vector maths but
   is a language change (an implicit `Copy`).
4. Owned `dyn I` cell layout once the value is N words: `{vtable, words...}` or a pointer to the
   words; fat-dyn.md pins `{value @0, vtable @8}` today.
5. Tasks, `Mutex<T>` and channels carry one word across threads [A]; with inline aggregates they
   need the size too. Not inventoried here.
6. Hash maps (`[K: V]`) are library values [V: N:32130]; whether their storage becomes flat follows
   from stage 1 only if they are built on `T[]` [A].
