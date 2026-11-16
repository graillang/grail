# Unboxed values

2026-11-16. Design note for stage 3 of `docs/design/compile-speed.md`. Nothing here is implemented.
Every factual claim is marked **[V]** (verified: read at the cited `file:line` of `78c8c6e`, or
measured here) or **[A]** (assumed: inferred, not checked). Measurements were taken on a shared
24-core host under load (another gate was running), best of three; treat them as ±10 %.

## Decided by the director, 2026-11-16

The owner has made run-time parity with C and Rust in release builds a pillar (Abundance is a
demanding game), so this work is ordered by what the engine needs; compile speed comes second.

1. **The model: yes.** A `Val` stays one slot. An aggregate (record, tuple, enum, view, later a
   vector header) is denoted by the address of its words; the words live inline in the frame, the
   enclosing record or the vector buffer, not in a heap block of their own.
2. **Order: 0, 1, 3, packed layout, 2, 4, 5, 6** (stage numbers as in section 6). Vector maths
   before views: the engine needs records in frames more than the compiler needs the 6-13 %.
3. **Floats on the native backend** are fixed elsewhere (branch `gaps12-float`). Release builds ship
   on the LLVM backend; the native backend is the development build, with a bar of 3x scalar C.
4. **Sub-word loads and stores are never calls, from stage 1 on.** After stage 1 an engine keeps
   its hot data in `extern "C" record[]`; a runtime call per `f32` field would undo the stage.
   Packed layout for plain Grail records stays late; inline sized access does not.
5. **Recursive types:** the compiler boxes the field that closes a cycle. No new syntax.
6. **View ABI:** a `{pointer, length}` pair that is never on the heap, returned in two registers.
7. **Vector and string headers inline** as stage 6.
8. **No opt-in attribute.** "Plain data" is computed.
9. **Bootstrap by fixed point, no reseed per stage.** Each stage's commit message names the
   compiler that built it.

**Decided by the owner, 2026-11-16: small plain records copy.** A plain record - no owned fields,
no drop - of at most 4 words copies implicitly on assignment, argument passing and element read
(`a := b`, `p := positions[i]`), as numbers do. A larger plain record stays move-only and needs an
explicit `.copy()`. It is automatic; the type does not declare it. This takes effect **at stage 3
and not before**: through stages 0 and 1 `q := v[i]` borrows and `b := a` moves, exactly as today,
and those stages do not change what the checker accepts (section 4 says what guards that).

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

**Data-oriented micro-benchmark** (sources in `bench/unboxed/`; 1M records, built by `push`, 20 passes of
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

**What the checker would do by itself, and why it must not.** A place is `copy` when its type needs
no drop: `copy := !needs_drop(ty) & (kind != 7)` (`member_place`, N:4147-4148), and `own` gives a
value an owner record only when it needs a drop (N:3948-3952). Today `needs_drop` is true for every
record because the box must be freed (N:3873), and that one fact is what makes records move-only.
- *Stage 1:* nothing changes, provided `needs_drop` keeps answering true for every record, plain
  or not - and it must, because a plain record in a local is still a box to free. The programs
  that would change meaning if stage 1b instead taught `needs_drop` that a plain record "owns
  nothing" (tempting, since a flat element has nothing to free) are exactly these, for a plain `P`:
  `b := a; use(a)` (E0006 today, would compile); `q := v[i]; v.push(..)` and `q := v[i]; v[i] = ..`
  (E0008 today: `q` is a `&P` borrowing `v`; would compile, with `q` a dangling interior address);
  `take(a); use(a)` (E0006 today); and `a := r.f; use(r.f)`, where `a := r.f` is a *move* of the
  field today (the field is then a hole that `r.f = ..` may refill, which is accepted and stays
  accepted) and would become a silent copy. Stage 1b therefore adds `plain(ty)` as a *layout*
  predicate only, never consulted by `member_place`, `own`, `move_out` or the alias paths, and its
  corpus keeps a refusing case for each (`unboxed-plain-stays-affine-*`).
- *Stage 3:* a plain record in a frame owns nothing. If `needs_drop` simply became false for it,
  *every* plain record would silently become `copy`, whatever its size. So stage 3 splits the
  question in two: `needs_drop(ty)` (is there anything to free: false for a plain record in a
  frame) and a new `affine(ty)` (is it moved rather than copied). `member_place`, `own` and the
  alias paths ask `affine`; only the drop emitters ask `needs_drop`. The owner's decision is then
  one line: `affine(ty)` is false for a plain record of at most 4 words and true for every other
  record and enum. That is a deliberate language change with its own cases, not a side effect.

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
these stages adds any; `Box<T>` would). `tools/test-selfhost.mjs` is exactly this fixed point
(stage 2 against stage 3), so it stays the acceptance test of every stage; stage 0 additionally
keeps stage 2 identical to the one built before it.
Interface files gain a layout line beside the `dyn` ABI line (N:39162), bumped per stage, so
objects of two layouts never link.

Every stage: benchmark = `bun tools/compile-bench.mjs` (self-compile; plus `--release`) and the
micro-benchmark, on both backends; allocation count from callgrind on `check syn1000`.

**Stage 0 - plumbing, no behaviour change.** One layout question, `field_word(ty, k)` (the word a
field starts at; `k` today), asked by every site that reads, writes, compares, destructures,
prints or drops a record field, so that stage 1b changes one function and not twenty sites; and
the inventory in the appendix. The N-word frame fact (the `DynPair` fact generalised) belongs to
stage 3, its first user, and `plain(ty)` to stage 1b: neither is added before something reads it.
Files: native.grl. Acceptance: self-compile byte-identical (`tools/test-selfhost.mjs`,
`tools/ssair-bytes.mjs`). Risk: low. Bench: unchanged within noise.

**Stage 1a as built** (2026-11-16).
- *The invariant.* For a struct, a tuple and an `extern "C"` record, `&T`/`&mut T` is the word a
  `T` value is: the address of the record's storage. Enums, vectors, strings, scalars, closures and
  `dyn` keep the address of their word. One predicate decides (`direct`), and three helpers make
  every reference: `slot_reference` (from a frame slot), `word_reference` (from the address of a
  word: a field, an element, an enum payload, a mutex cell, a raw pointer) and `ref_load` (through
  a reference: a word copy for a record).
- *`extern "C"` records.* Before: the address of a slot holding the address of the bytes - the
  binding's own slot, or for a record embedded in another a *proxy slot* made for the purpose
  (`c.embedded`). After: the address of the bytes. The proxy survives only for the target of an
  assignment (below).
- *Places are not references.* `x.f = v`, `v[i].f = w` and a capture's field assignment write the
  *word* of the field: the old record is dropped and the new record's word stored, as before. This
  is `field_path(.., 3)`. It has to stay a word store because a place may hold nothing - a field
  that was moved out is refilled this way - and a reference never may.
- *Uninitialised and moved-out places.* `&x`/`&mut x` needs `ownership::borrow_place`, which
  refuses a place that is not `complete` - present and every sub-place live (ownership.grl:111-120,
  327-333). The only live-but-unfilled place is an `extern "C"` record declared without a value,
  whose storage is allocated at the declaration (`zero_record_binding`), so its address exists.
  Ten corpus cases pin the refusals (`unboxed-ref-reject-*`) and one the refills.
- *Through a reference.* `exchange(r, v)` and `*r = v` swap the storage of the referent and of the
  new value, by the record's byte size (`swap_records`): up to four whole words in line, otherwise
  `rt_swap(a, b, bytes)` - the one function for both kinds, exact for a 12-byte C record embedded
  between other fields. The new value's storage, now holding the old contents, is what `exchange`
  returns and what assignment drops. Measured on a self-compile with every swap forced through
  the runtime: 29 swap sites in the compiler's own code (22 of 4 words, 4 of 3, 1 of 2, 2 of 17
  words), 20,003 swaps executed out of 261 G instructions. Nothing swaps a large record in a loop.
- *Owned `dyn` of a record.* The cell stays `{value, vtable}`. A dispatch site has only the data
  word and cannot know the concrete type, and for a record `&T` is the cell's first word, not the
  cell's address; so a record boxed as `dyn` carries a second table (`.C...` beside `.V...`) whose
  entries are adapters - `pushq %rbp; movq %rsp,%rbp; movq (%rdi),%rdi; call method; leave; ret`,
  the shape `grail_fn_thunk` already has. A `&dyn` made from a `&T` keeps the plain table.
- *Closures.* An environment is a record type internally, and is deliberately not `direct`: its
  code is called with the address of the word holding the object, which is the closure ABI.
- *Reference identity.* Nothing in safe code or `lib/` compares or hashes a reference: `==` on two
  references is a type error, `hash::Hash` has no implementation for a reference, and `.addr()`
  exists only on raw pointers. `cptr(&r)` of an `extern "C"` record was and is the address of its
  bytes. `Rc<T>` holds a `*mut T` to a word it allocated; `as_ref`/`as_mut` turn it into a
  reference with `word_reference`, so for a record they now load that word.
- *Measured* (instruction counts, which the loaded host does not disturb; wall times moved less
  than the noise). The compiler checking the 26k-line program: 9.991 G before, 9.907 G after
  (-0.8 %; the compiler measured is the one built by the new compiler - the first build from the
  bootstrap compiler still has the old code inside and shows no change). Micro-benchmark, native
  backend: `aosu` 2.345 G to 2.185 G (-6.8 %), `aosu_shuf` 2.540 G to 2.380 G (-6.3 %); LLVM
  backend: `aosu` unchanged (LLVM had already folded the second load), `aos` -1.4 %. Peak RSS
  unchanged at 68 MB, as expected: nothing was unboxed yet. The note's earlier guess that the saved
  load "applies to almost every line of the compiler" was too generous - it is under one percent.
  Binary size 27.26 MB to 27.27 MB; self-compile output 109.63 MB to 109.65 MB.
- *Keyed artefacts.* Interface files: the `abi` line gained `ref record = address`, so a file from
  an earlier compiler is refused. Build-store entries and per-function units are keyed by the
  compiler's own digest (cli.grl:2779, 1546) and need no bump.

**Stage 1b as built** (2026-11-16).
- *Plain.* A struct or tuple with no `Drop` whose fields are all scalars, references, function or C
  pointers, or plain records (`layout_bits`, memoised per type). A layout fact only: `needs_drop`,
  `member_place`, `own` and `move_out` never ask it, and six cases pin that the checker accepts
  exactly what it did (`unboxed-plain-stays-affine-*`).
- *Inline fields.* A plain record held by a Grail struct or tuple is its words at an offset
  (`field_layout`, a per-type table). Reading one gives its interior address; anything that would
  own or move that value first copies it to a box of its own (`materialise`, called from `own`,
  `move_value` and `move_out`). Assigning one copies the new words in through the embedded-place path
  C records already used. A record's construction now allocates after its fields are evaluated.
- *Flat vectors.* `T[]` of a plain record or of an `extern "C"` record holds the elements' bytes
  (8 per word, or the C size; so `Vertex[]` is a C array). The runtime family takes a width:
  `rt_pushw`, `rt_popw`, `rt_vec_insertw/removew/swapw/reversew`, `rt_slotw`, `rt_flat_box`. A
  checked `&v[i]` is optimiser pseudo-op 52 next to `rt_slot4`'s 49-51, expanded to the same bounds
  check and `imulq`/`addq`; a proven index skips the check, as for words. C arrays of extern records
  copy to and from flat vectors.
- *Padding.* `==` on `extern "C"` records was and is field by field (`structural_eq` reads each field
  with `cfield_load`), so padding is never read; vectors of records have no `==`, `contains` or hash.
- *Narrow fields.* Through the merged `gaps12-float` emitter (`sized_load`/`sized_store`), which
  already serves `cfield_*`/`caddr_*`; an element of a flat C-record vector reaches it through the
  same functions, so no second emitter exists.
- *Transitional cost (stage 3 removes it).* A record still starts in a box, so `push` of a fresh
  record allocates, copies and frees, and taking one out (pop, remove, a consuming loop, an owned
  field read) allocates a copy. Measured below.
- *Bug found on the way.* Layout first depended on `c.raw`; drop helpers are emitted after the last,
  raw, module, so a whole-program build walked a flat vector as pointers at exit. Layout is now a
  property of the type alone.
- *Interface line:* `record plain = inline`.

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
- Sized access (decision 4): a field of an `extern "C" record` narrower than a word is read and
  written with `movl`/`movzbq`/`movb`-class instructions in the stream instead of calls to
  `rt_load_sized`/`rt_store_sized` (N:20502); the three targets and the lifter learn the widths
  they do not yet spell (16-bit, sign-extending, `f32` to and from a register).
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
the deepest corpus program; fixed point.
*Language change shipped with this stage (owner's decision):* plain records of at most 4 words
copy. Corpus: accepted - `b := a` on a 3-word plain record then both used; `p := v[i]` then
`v.push(..)` and `v[i] = ..` with `p` still read (it is a copy now, not a borrow); a 4-word record
passed to a function and used after. Refused - `b := a; use(a)` on a 5-word plain record, E0006
with a message that names `.copy()`; the same for a record of any size with an owned field or an
`impl Drop`. Words are counted after inline nesting (a record of two 3-word records is 6 words).
Book: the ownership chapter's "what copies" list gains "a record of plain data no larger than four
words"; the records chapter says the size is what decides, shows `.copy()` for larger ones, and
notes that adding a fifth word or an owned field to a record turns its copies into moves - a
compile error at each use, never a silent change of meaning. Changelog entry in the same commit. Bench: all; expect the micro-benchmark build phase to drop.

**Stage 4 - records with drop and owned fields inline** (in records and vectors). Drop helpers
split into in-place and boxed. Risk: partial moves out of inline fields, drop of a half-built
vector on panic paths. Acceptance: allocator-balance corpus, `impl Drop` order cases.

**Stage 5 - enums and options inline**, with the one-word niche and automatic boxing of cycle
edges. Files: native.grl (constructors, `match`, `?`/`!`, retag in place), runtime.grl
(`rt_pop_option`, `rt_enum*` deleted), interface writer. Acceptance: recursive-type cases, `match`
corpus, fixed point.

**Stage 6 - vector and string headers inline.** Every runtime function that returns a vector takes
a destination instead. Removes the 40 %. Risk: breadth of runtime.grl; literals' static headers.

**Stage 7 - packed layout** (`f32` in 4 bytes, natural alignment, declared order) and `size_of`
for plain records; inline sized access is already there from stage 1. Ordered right after stage 3
(decision 2). This is the stage that makes `V3` 12 bytes; until then an engine uses `extern "C"
record` for GPU data, which stage 1 already stores flat.

Stages 2 and 3 are independent of each other after stage 1; the decided order runs 3 first.
Stage 6 needs stage 3 only.

## 7. Compile speed, both directions

- **Faster.** Allocator work is 38 % of a check and 20 % of a self-compile. By allocation count
  (check / self-compile) the stages remove 8 / 2 % (1), 13 / 6 % (2), 5 / 2 % or more (3 - more if
  `snapshot` and `ir::ty` records, 14 % of a self-compile's allocations, are short-lived locals
  **[A]**) and 40 / 37 % (6); each also removes the matching free and, for views, a
  call per hop. One load fewer per field access through a reference (1a) measured at 0.8 % of a
  check. **[A]** the time saved is proportional to the count; it is measured per
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

1. Owned `dyn I` over an N-word value: `{vtable, words...}` or a pointer to the words; fat-dyn.md
   pins `{value @0, vtable @8}` today. To be proposed at stage 3.
2. Given the release compiler self-compiles in 2.98 s and allocation is 20 % of that work, where
   stages 2 and 6 stand against direct object emission is a compile-speed.md question.

## Appendix: aggregates that cross a thread or live in library storage

Inventory for stage 0 (all **[V]** unless marked). None of these blocks stage 1; each names the
stage that must handle it.
- **`Mutex<T>`**: `rt_mutex_new(value)` takes one word (N:26688); the cell is `{lock, value}` and
  `lock` hands the body the address of the value word, `leaq 8(cell)` (N:29957-29958), which is a
  `&mut T` in today's meaning (the slot that holds the pointer). *Stage 1a:* for a record `T` the
  body's `&mut T` must be the record's words, so `lock` loads the word instead of taking its
  address. *Stage 3:* the cell holds the words inline.
- **Tasks**: `rt_task_spawn(scope, f, item, arity, dropper)` moves one item word in, and the result
  is one word with a dropper (N:27295-27315; R:3655). Boxed records keep working unchanged through
  stage 1; at stage 3 an aggregate item or result is boxed at the spawn (it crosses a thread and
  outlives the frame).
- **`parallel_map` / `parallel_for_chunks`**: over a vector of words; `rt_parallel_for_chunks`
  already takes an element width (R:2900, R:2992). *Stage 1b:* a flat `T[]` passes its element size
  there; `parallel_map` over a flat vector hands each call an element address.
- **`Atomic<u64>`**: scalar only (kind 11). Unaffected.
- **Channels**: there are none (grep of `lib/` and the compiler).
- **Hash maps**: `[K: V]` is `lib/hashmap.grl`'s `Map`, whose storage is `Slot<K, V>[]` plus
  `u64[][]` buckets (lib/hashmap.grl:20-26). Its entries become flat at stage 1b exactly when
  `Slot<K, V>` is plain for that `K` and `V`; no change to the library.
  `lib/concurrent_map.grl` is `Mutex<[K: V]>[]` (line 9) and follows `Mutex`.
- **`lib/arena.grl`**: `Slot<T>[]` (line 28) - the same rule as the map.
- **`lib/rc.grl`**: `Rc<T>` holds a `*mut T` (line 23). **[A]** a raw pointer to a record is the
  record's address already; to be read before 1a, since 1a changes what a *reference* to a record
  is and the two meet at `unsafe` conversions.
