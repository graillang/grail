# Typed IR facts for the LLVM backend

Status: design, 2026-11-10. **F2 implemented** (2026-11-10, see *Implemented: F2* below). **F1
implemented and gated off by its measurement** (2026-11-10, see *Implemented: F1* below): the fact,
its invalidation rules and its `--verify-facts` checks are in the tree, the lowering consumes it only
where the hoist it performs is provably usable, which on this corpus is nowhere, and F1 is therefore
neutral in `tools/bench.mjs`. `compiler/llvm.grl` and `compiler/native.grl` carry the fact table and
both consumers; the word stream, `optimize.grl` and `machine.grl` are unchanged.
Companion to [llvm-backend.md](llvm-backend.md), stage 2c, which records that no lever inside the
lifter reaches 1.0x C and names the two missing facts.

## Recommendation, in short

Carry two facts from the front end to the lifter in a **side table**, passed to `llvm.lower` beside
the word stream, that names (function, frame slot) and (function, call target, ordinal, argument) as
being *a sequence-header pointer of element width W* (**F1**) or *an `f32`-valued word* (**F2**); the
lifter consumes it in a small typed layer over the values it already tracks, and anything the table
does not name stays the untyped word it is today.
F2 is the cheap one: it rewrites the front end's own call sites (`rt_f64_op` with a constant opcode,
then `rt_f32_round`) into `fadd/fsub/fmul/fdiv float` plus one `fpext`, keeps the `f32` local as an
`alloca float`, and is bit-identical by the `p2 >= 2p1 + 2` argument (53 >= 2*24+2) that stage 2a
already uses for `fmul`.
F1 is the expensive one: it needs the header pointer typed and `dereferenceable`, *and* the header
and element loads in disjoint alias scopes, *and* (because stage 2c measured that LLVM will not
speculate a load from such a pointer) a lifter-emitted hoist of `data`/`len` to the point where the
fact is established -- which is why it changes the sequence access lowering rather than annotating it.

## What the lifter has, and why it cannot derive these facts

`compiler/llvm.grl` reads the x86-64-spelled word stream one line at a time (`split` groups lines
into functions, `lower_function` walks a function's instructions, `instruction` dispatches on the
mnemonic). Every machine value is an `i64` SSA name: registers and `xmm` registers are `alloca i64`
slots that `mem2reg` promotes, frame slots are `alloca i64` in split mode (`%s.N`) or one `%frame`
blob otherwise, and **every memory access is `inttoptr` from a word**. `address()` is the only place
that builds one; `value()` and `store()` are the only places that read and write.

That is the whole type problem. For

    movq -24(%rbp),%rax
    movq 8(%rax),%rcx

the lifter emits exactly

    %t8  = load i64, ptr %r.rax
    %t9  = inttoptr i64 %t8 to ptr
    %t10 = load i64, ptr %t9, align 1

and for `raw_load(wrapping_add(s,8))` inside `rt_slot` (which clang inlines into the caller's loop)
the same shape again, through the callee's `%a0` parameter:

    %t13117 = load i64, ptr %r.rax
    %t13118 = inttoptr i64 %t13117 to ptr
    %t13119 = load i64, ptr %t13118, align 1

Three consequences, all measured in stage 2b/2c:

- `%t13119` is not provably dereferenceable, so LICM may not hoist it out of the loop even though it
  is loop-invariant;
- nothing says the store `*(data + i*8) = x` cannot write `header+8`, so the `len` load cannot be
  merged across it. Stage 2c tried `!tbaa` and three-region `!alias.scope` and nothing moved: the
  metadata is not the missing piece on its own;
- every element access is an `inttoptr`, so the element load is `align 1` and carries no type.

The type is destroyed *before* the lifter sees it, in the front end: `Local.ty` (a `Ty` id, kinds at
`compiler/native.grl:16`) and the element type at every access site are known when the line is
emitted, and by the time `llvm.grl` reads that line they are one word. `rt_f32_round` is the one
place a type survives into the stream by accident -- the front end emits it once per `f32` arithmetic
result (`compiler/native.grl:17178`), so it already marks an `f32`-valued word -- and even there the
value then crosses a frame slot and the marking is lost.

## The three ways to carry the facts, compared

| | side table (recommended) | annotations in the stream | typed value model in the lifter | pattern-match the stream |
| --- | --- | --- | --- | --- |
| where the type comes from | `C` fields the front end already computes (`Local.ty`, element type at each `invoke`) | same, formatted as extra lines/directives | nowhere -- it would have to be inferred or supplied anyway | inferred from instruction shapes |
| cost in `native.grl` | fill a `Fact[]` (~60 lines, no new analysis: types are in hand at the emission point) | same + escape-safe text encoding | none | none |
| cost in `llvm.grl` | typed value layer + fact lookup (~400-480 lines, itemised below) | a parser for the new lines (~40 lines) *plus* the same typed layer | the typed layer only, but every value becomes a pair (type, name) and the ~1 900-line lifter is rewritten around it | large, and unsound |
| effect on `optimize.grl` / `machine.grl` | none: `--backend=llvm` already skips `optimize.grl` (`native.grl:20937`) and the fact table is not part of `c.out` | a comment line makes the function "unrecognized" and `optimize.grl` copies it unoptimised, so the native backend loses register promotion wherever a fact is emitted | none | none |
| effect on the native backend | none | possible (above) | none | none |
| failure mode when a fact is missing or stale | falls back to today's correct lowering, per value | same, but a mis-parsed line can also fail the function (`l.fail`) and drop it to native assembly | same | unsound: a wrong structural match elides a check it should keep |
| who else can read the facts | `machine.grl` later, on the same footing | any consumer of the text | nobody | nobody |

Two structural points decide it.

First, **the anchor can be anything**, because the table and the stream are produced by the same
compile and consumed in the same compile: a line index, a byte offset or a call ordinal cannot
disagree with the text it describes. The risk a text format would buy (a directive shifting, a
function being rejected by a pass) does not exist for a table that never enters the text.

Second, **the fallback is free**. `llvm.grl` has `l.fail` for "this line is not understood" and it
already drops such functions back to native assembly; a typed layer that degrades to the word
lowering on any doubt is the same safety at a finer grain. A typed *value model* (option 3) has no
such fallback: it is a rewrite, and the 1 916-line lifter plus 209 executable cases would have to be
re-verified at once. That is the wrong first step for two facts.

Rejected: deriving the facts from the stream. Stage 2c already argues it needs per-value provenance,
and stage 2b removed the one idiom that came closest -- `cmpq $-8` on the descriptor -- from
`compiler/runtime.grl`, so `rt_slot`'s descriptor check is no longer even in the text.

## The recommended shape

`C` gains one field, appended to the per-compile state next to `backend` and `debug_funcs`:

```
// Typed facts for the LLVM lifter (docs/design/typed-ir.md). Emitted where the front end knows
// a type and the lifter cannot: a word is a sequence header of element width W, or an f32.
struct Fact {
    // 0 slot, 1 call argument.
    kind: u64,
    // Function body symbol (f_main_main), as emitted.
    fn: u8[],
    // kind 0: the frame slot index, `b` unused (slot k covers [-8(k+1), -8k) below rbp).
    // kind 1: `a` is the ordinal of the call to `callee` inside `fn` (0-based, in emission
    // order) and `b` the argument index.
    a: u64,
    b: u64,
    callee: u8[],
    // 0 word, 1 f32, 2 header of width 8 (vector), 3 header of width 4 (narrow vector),
    // 4 header of width 1 (bytes), 5 descriptor {data, len} of a view or slice, 6 element
    // pointer (the result of rt_slot), 7 float arithmetic on two f32 operands (kind 1 only).
    what: u64,
    width: u64
}
```

Three entry kinds are enough for both facts:

- `slot(k) = f32` -- every read of slot `k` in the function is an `f32` value. Emitted by `bind()`
  for a local of type `f32` (kind 21, arg 32), which it already tests with `is_f32`.
- `slot(k) = header(W)` / `descriptor` -- slot `k` holds a header pointer for the whole function.
  Emitted by `bind()` for a local of kind 6 (`T[]`) or 27 (`&[T]`), with `W` from `narrow_code`.
- `call(fn, rt_slot, ordinal i, arg 0) = header(W)` and `call(fn, rt_f64_op, i, arg 0) = f32-arith`
  -- the argument word at that call is a header of width `W`, or the call is an `f32` operation.
  Emitted inside `invoke()` (`native.grl:1837`), which is the single chokepoint through which every
  runtime call in the program is emitted, and which already has both the callee name and the
  argument values in hand.

Conservatism rules, each of which turns a fact off rather than risking it:

- a slot gets a fact only if **one** type ever occupies it in the function. `fresh()` reuses frame
  slots across scopes, so a slot that is `f32` in one block and `u64` in another gets no fact;
- a call argument gets a fact only when the argument value's static type is exactly the header or
  `f32` type at that site -- no inference through a temporary;
- taking the address of a slot (`leaq -N(%rbp)` into a call, a byval copy, `rep movs`) drops the
  slot's fact, because an untyped write can then change it;
- any slot write the lifter cannot type (a call result, a raw load, an unknown instruction) clears
  the type of that slot's value for the rest of the block, and clears the slot fact itself.

`llvm.lower` gains a `facts: &a [Fact]` parameter (`lower`, `lower_for`, `lower_target` each forward
it; the two callers in `native.grl:20984` and `21003` pass `c.facts`). Inside the lifter:

- `L` gains `facts: Fact[]` (sorted by `(fn, kind, a, b)`, binary searched once per function into two
  small maps: slot facts by slot index, call facts by `(callee, ordinal, argument)`);
- `L` gains `typed: u64[]` -- the value-type map, keyed by the register slot name and the frame slot
  name, holding `what`/`width`; `set_reg`/`store` to a typed location preserve the type when the
  value carries it and clear it otherwise; `get_reg`/`value` return the type with the name;
- `valtype(l, name)`, `set_valtype(l, name, what, width)`, `clear_valtype(l, name)` -- three small
  functions; every existing call site keeps its current signature and a `valtype` of 0 by default;
- `instruction` consults `valtype` in the three places that matter: the memory operand helper
  `address` (typed base -> `getelementptr` on a typed pointer instead of `inttoptr`), the `movq` /
  `movsd` / slot copy path (propagate), and `lower_call` (F2's rewrite, below).

Estimated cost: about 400-480 lines in `llvm.grl` (a `Fact` consumer, the value-type map, typed
`address`/`value`/`store` variants, the `rt_f64_op`/`rt_f32_round` rewrite, the F1 consumers and the
`--verify-facts` checks; itemised under *Cost*), about 60-80 in `native.grl` (the `Fact` struct,
`emit_fact` at three sites, the call-ordinal counter in `invoke`, the conservative-emission rules),
plus the two call sites of `llvm.lower`. No new pass, no new IR type, no change to the stream, no change to `optimize.grl` or
`machine.grl`.

Lookup granularity in the lifter is the function, not the line: `lower_function` loads the facts for
`f.name` once, and a call fact is matched by counting `call TARGET` occurrences in emission order
(`instruction` already sees every line). That ordinal is exact because the front end counted the same
calls in the same order while emitting them, and a mismatch cannot corrupt anything -- it makes the
fact find nothing.

## F1: "this word is a pointer to a 24-byte sequence header"

### What has to be known

For the lifter to type an access it needs, at one point in the stream:

- the word is a pointer to a header, not an arbitrary address;
- the header is `{data: u64, len: u64}` for a view or slice (`rt_slice`/`rt_vslice`/
  `rt_view`, allocated 24 bytes by `rt_alloc(24)`), or `{data, len, cap}` for a vector (`rt_new`);
- **`cap` may only be read when the word is a vector header**, because a descriptor leaves `+16`
  uninitialised (`rt_slice` writes `+0` and `+8` only). The two are different facts, which is why
  `what` distinguishes 2/3/4 from 5;
- the element width (`8`, `4` or `1`) is the element type's, and `len` counts elements, so the
  element address is `data + i*W`;
- element storage is a different allocation from the header (`rt_alloc`/`rt_grow` return a slab;
  the header and `data` are two live slabs and cannot overlap).

Alignment follows from the allocator, not from the fact: `rt_alloc_unlocked` rounds the object to a
power of two (`>= 32`) with a 16-byte block prefix and returns `block + 16` from a page-aligned
arena, so headers and word/narrow element bases are 8-aligned (16 in practice). A slice at
`data + a*W` keeps that alignment for `W = 8` and `W = 4`. The lifter may therefore emit `align 8`
on the header loads and on word elements, `align 4` on narrow elements, instead of today's `align 1`.

### Where the knowledge exists today

- `rt_new()` (`runtime.grl:219`) creates the vector header; `rt_fill`/`rt_reserve`/`rt_grow` grow
  and rewrite it. Every call site of these in user code is emitted by `bind`/`push`/`repeat-literal`
  lowering, and every one of them is a `call rt_new`/`call rt_fill` line in the stream.
- `bind()` (`native.grl:5248`) records `Local.ty`, and the kind/element type is exactly the fact;
  the frame slot is `Local.id`.
- The access sites are `invoke(rt_slot/rt_slot4/rt_slotb/rt_at/rt_len ...)` emitted from
  `index_view` (`native.grl:16689`) and its neighbours, and the push sites from `native.grl:14605`.
  `index_view` holds `elem := ty_arg(&mut c, xty)` and `code := narrow_code(&mut c, elem)` right
  before the call, i.e. the element type and width are in local variables at the exact line that
  becomes `call rt_slot`.

Measured surface (`tools/tir-facts.mjs`, x86-64 raw stream, whole runtime included):

| stream | F1 call sites in program functions | F1 sites in the runtime | F2 sites (`rt_f32_round`) | float-op sites |
| --- | --- | --- | --- | --- |
| fnv | 16 | 245 | 0 | 0 |
| sieve | 18 | 245 | 0 | 0 |
| sort | 25 | 245 | 0 | 0 |
| matmul | 24 | 245 | 4 | 5 |
| nbody | 84 | 245 | 0 | 38 |

Per program, F1 is **16-84 call sites**: it is not a pervasive change to the stream. On the callee
side the fact is needed in the hand-written accessors only -- `rt_slot`, `rt_slotu`, `rt_slot4`,
`rt_slot4u`, `rt_slotb`, `rt_at`, `rt_at4`, `rt_atb`, `rt_len`, `rt_push`, `rt_push4`, `rt_pushb`,
`rt_write`, `rt_fill`, `rt_reserve`, `rt_slice`, `rt_vslice`, `rt_view` -- because those are the
bodies clang inlines into the hot loop, and their `%a0`/`%a1` parameters are where a typed parameter
attribute can be stated.

### The IR that would follow

At the point the fact is established (a `rt_new`/`rt_fill` result, or a borrowed `&[T]` parameter),
and inside a region where the header is not written (*F1b*, below), the lifter emits the header load
once, through a typed pointer:

```
; fact: %hdr is a vector header of element width 8, 24 bytes, 8-aligned
%hdr.p   = inttoptr i64 %word to ptr
%len.p   = getelementptr i8, ptr %hdr.p, i64 8
%cap.p   = getelementptr i8, ptr %hdr.p, i64 16
%len     = load i64, ptr %len.p, align 8
%data    = load i64, ptr %hdr.p, align 8
```

and every in-region access then reads those two SSA values instead of re-loading, with the element
address built from them:

```
%off  = mul i64 %i, 8
%addr = add i64 %data, %off          ; still a word: the ABI is unchanged
%elem = inttoptr i64 %addr to ptr
%s    = load double, ptr %elem, align 8   ; or store double
```

Because the store is to the element allocation and the `len` load is hoisted out of the loop, the
`idx < len` compare is against a loop-invariant value and the descriptor/header loads and the
address-overflow guard are gone from the loop body: that is the three-dependencies-to-one-address
change stage 2b's "checks removed" column bounds at 44% of `nbody` and 21% of `sort`.

The same typing must reach the *callee* when the accessor is not inlined at the call site: the fact on
`call(rt_slot, i, 0) = header(8)` makes the lifter define a typed sibling

```
define internal {i64, i64} @"rt_slot.hdr8"(ptr nocapture nofree dereferenceable(24) align 8 %s, i64 %i, ...)
```

emitted from the same stream body with `%a0` typed as `ptr`, and used by every fact-carrying call
site. That parameter is where `dereferenceable(24)` is stated, and after inlining it is the pointer
LLVM sees -- which is the "speculation" half of stage 2c's blocker, the half that `!tbaa` and
`!alias.scope` could not supply.

Two consumers are possible and they are not exclusive:

- **F1a, annotate**: typed parameter + `dereferenceable(24) align 8` + `!alias.scope`/`!noalias`
  (header vs element, the shape stage 2c already built) + `align 8`. Then LLVM's own LICM and
  loop-unswitching do the rest. Cheap, but *unmeasured in combination*: stage 2c measured the
  metadata alone (inert) and stage 2b measured the speculation blocker, never both together.
- **F1b, restructure**: the lifter hoists `data`/`len` itself at the point the fact is established
  and rewrites the in-region loads to the hoisted SSA values (the IR above). No speculation is
  needed -- the load is executed where the front end says the header exists -- and it does not
  depend on what LLVM decides to do. Costs a region: it needs the inner fact "no `push`/`pop`/
  `insert`/`remove`/`truncate`/`reserve`/`fill` of *this* sequence between the hoist point and the
  loop", which for a borrowed `&[T]` is implied by the language (`docs/design/typed-slices.md`:
  "a slice cannot outlive its vector, and the vector cannot grow ... while one exists") and for an
  owned vector must be checked by the emitter (`no fact across a call to one of those functions on
  that value`).

Recommendation: build F1a (it is the cheaper half and the IR metadata is written by code that already
exists in the lifter), measure, and add F1b only if the checkpoint below fails. The fact table is the
same either way; F1b changes only the consumer.

## F2: "this word holds an `f32`"

### What has to be known

That the word's binary64 value is the exact widening of some binary32 value, i.e.
`fptrunc(w) -> float` loses nothing, for the whole life of the fact. Where it matters in
`matmul` is the accumulator `s`: `s = s + a[i*n+k] * b[k*n+j]`.

Today the stream contains, for that expression, two calls the front end emits at
`native.grl:17174` and `17178`. The front end inline float arithmetic for neither type: user `f64`
and `f32` both go through `rt_f64_op`, and `f32` adds the `rt_f32_round` call after it (the inline
`addsd` path at `native.grl:10814` is only for the runtime's own `raw_f64_*` intrinsics):

```
movq <s slot>,%rsi ; movq <a..>,%rdx ; movq $43,%rdi ; call rt_f64_op ; call rt_f32_round
```

which `llvm.grl` lowers to a call plus the round trip the lifter already special-cases
(`lower_call`, `compiler/llvm.grl:858`):

```
%t279 = call {i64, i64} @"rt_f64_op"(...)
%t280 = bitcast i64 %t279 to double
%t281 = fptrunc double %t280 to float
%t282 = fpext float %t281 to double
%t283 = bitcast double %t282 to i64
```

After `clang -O2` inlines `rt_f64_op` that becomes `addsd` + `cvtss2sd` + `addsd` + `cvtsd2ss` on the
accumulator's dependency chain, and once the loop is unrolled the carried value is a `phi double`,
which is why the unrolled kernel (1.95x) is *slower* than the un-unrolled one (1.30x). Stage 2c shows
the instructions.

### Where the knowledge exists today

- `bind()` knows `Local.ty` and `is_f32` is a two-line test on it; the frame slot is `Local.id`.
- Every `f32` arithmetic site holds `ty` (and `is_f32(&mut c, ty)`) where it emits the `rt_f64_op`
  and `rt_f32_round` pair, so the *opcode* (43 `+`, 45 `-`, 42 `*`, 47 `/`) and the fact are both in
  local variables at the emitting line.
- `narrow_code(&mut c, elem)` (used at `index_view` and the narrow element store) already picks
  `rt_slot4`/`rt_at4`/`rt_push4` for `f32` elements, and `narrow_decode` emits the
  `cvtss2sd`-equivalent widening; those are the sites where a narrow load *produces* an `f32`-typed
  word.
- `rt_f32_round` call sites are already an exact marker: 4 in `matmul`'s own functions, 0 in every
  other benchmark, 1 in the whole runtime. F2's surface is *smaller* than F1's by an order of
  magnitude.

### The IR that would follow, and which operations become real float

With the operands typed, `lower_call` rewrites the pair at the call site instead of emitting it:

| stream | today | with F2 |
| --- | --- | --- |
| `call rt_f64_op` (op 42/43/45/47, both operands `f32`) | `call` -> inlined `mulsd`/`addsd` on doubles | `%f = fmul/fadd/fsub/fdiv float %a.f, %b.f` then `%w = fpext float %f to double` (only where the word is needed) |
| `call rt_f32_round` (argument `f32`) | `fptrunc double`, `fpext float`, `bitcast` | nothing: the word already is the widened float; the call is dropped |
| `movq`/`movsd` of an `f32` slot | `load/store i64` | `alloca float` for that slot; `load/store float`, widened at untyped uses |
| narrow element read (`rt_slot4` + `movl (%rax),%eax`) | `load i32` -> `zext` -> `narrow_decode` (`fptrunc`/`fpext` gymnastics) | `%f = load float, ptr %elem, align 4` |
| narrow element store (`cvtsd2ss` + `movl`) | `fptrunc` + `trunc` + `store i32` | `store float %f, ptr %elem, align 4` |
| `rt_f64_cmp` on two `f32` | `call` -> inlined `ucomisd` + `seta`/`sete`/`setnp` | `fcmp ogt`/`oeq` on floats, same predicate |
| `f64(some_f32)` conversion | `rt_f32_round` then arithmetic on doubles | already a `fpext`; the round becomes a no-op |
| `rt_f64_op` on `f64` operands | unchanged | unchanged (there is no fact) |
| everything else (`rt_f64_sqrt`, `min`/`max`, `head`/`floor`, `toi`, printing) | calls | calls, unchanged: their arguments are typed, so the `fpext` is free, but their bodies are not touched |

The only structural change is that an `f32` local becomes a real `alloca float` (split mode already
gives every frame slot its own alloca, so this is one word changed in `lower_function`), which is
what keeps the loop-carried value a `phi float` instead of a `phi double` and lets `-O2`'s unroller
narrow the whole chain. Zero-init is unaffected: a `float` 0.0 is all-zero bytes, so the `rep stosq`
frame clear and the `store i64 0` slot initialisation stay bit-identical.

### Bit-identical output

The language says an `f32` operation rounds its result to binary32. Today that is done as
"compute in binary64, then round to binary32" (`rt_f64_op` + `rt_f32_round`); the proposal computes in
binary32 directly. These agree for `+ - * /` and `sqrt` because the intermediate precision satisfies
the standard sufficient condition `p2 >= 2*p1 + 2` (`53 >= 2*24 + 2 = 50`): the binary64 result is
within 1/2 ulp(binary64) of the exact value, so rounding it to binary32 gives the same result as
rounding the exact value, provided no binary64 overflow (the `f32` range gives `|x| <= 3.4e38`, far
inside binary64) and no binary64 underflow (a `f32` subnormal is a normal binary64). This is the same
argument stage 2a already relies on for `fmul` narrowing, extended to the other three operations and
to `sqrt`. The operands satisfy "already binary32" by induction: `f32` literals, `f32` loads (a
4-byte load *is* the binary32 value), `f32(...)` conversions (which round), and every `f32` arithmetic
result (which rounds by construction).

Where it can differ, and what is done about it:

- **NaN payloads.** `addsd` on two widened `float` NaNs propagates the quiet bit and the sign
  through binary64, and `cvtsd2ss` back keeps them; `fadd float` propagates the payload directly. The
  printed form of a NaN is the same, but the low payload bits of an intermediate are not part of the
  language and no test compares them. Stated as an explicit exemption.
- **`-0.0` and infinities** are bit-identical: `+0 + -0` and the sign rules are the same under IEEE
  binary32 and binary64 followed by an exact rounding.
- **Widening at an untyped boundary.** Wherever a typed value leaves the typed region (a call into an
  unwritten helper, a `raw_store`, a field address taken, a printed value), the lifter emits
  `fpext` -- bit-exact because the fact says the value *is* the widening. This is the one place a
  wrong fact would corrupt a value silently, and it is where `--verify-facts` (below) checks it.
- **No fast-math, no FMA.** As today: no `fast`/`reassoc`/`contract` flags, `-ffp-contract=off`
  semantics. `fadd float` is a single correctly rounded operation, so the corpus's exact values are
  preserved, not just its 12-significant-digit comparison.

Testing: `tools/bench.mjs` compares printed numbers to 12 significant digits, which is *not* enough
to prove bit-identity (`llvm-backend.md` says so itself). The bit-identity test is the native suite
(`GRAIL_BACKEND=llvm bun tools/test-native.mjs x86_64`), whose executable cases compare `stdout`
exactly, plus new cases that make each bit visible: a binary32 value printed as `f64` is printed in
its shortest round-trip decimal, which is unique per bit pattern, so
`println(f64(f32(1.0) / f32(3.0)))` prints `0.3333333432674408` and a 1-ulp difference changes the
last digit. One such case per operation, plus a chain that feeds each result into the next (where a
narrowing that changes a rounding shows up), plus the `f32` min/max/abs/floor and `toi` conversions.

### Implemented: F2 (2026-11-10)

F2 landed on top of the shape this section describes, and it is the whole of the change: `optimize.grl`
and `machine.grl` are untouched, the word stream is byte-identical (checked on all five benchmarks:
same `.s` from the same source with the compiler before and after), and the native backend reads
exactly what it read before.

**The table.** `compiler/llvm.grl` defines `Fact` exactly as proposed above (`kind`, `fn`, `a`, `b`,
`callee`, `what`, `width`), plus a one-field `Facts { items: Fact[] }` wrapper: the compiler has no
cross-module view of a struct array, so `C` holds a `Facts` and every other module sees it as one
record. `C` gains `facts`, `facts_fn` (the body symbol of the function being emitted, which is what
keys the table) and `f64_ops`/`call_ord` (the ordinal of the next/last `call rt_f64_op` in that
function).

**Where the facts come from.** Two emission points, both places the front end already has the type:

- `bind()` (`compiler/native.grl`) records `slot(Local.id) = f32` for an `f32` binding, and
  `what = 0` for every other binding. Recording the negative case too is what makes a reused slot
  detectable: the lifter accepts a slot only when *every* fact naming it says `f32`.
- `float_op_call()` (the single wrapper the three `rt_f64_op` sites now call) records
  `call(rt_f64_op, ordinal, arg 0) = f32-arith` with the opcode in `width`, keyed by the ordinal
  `invoke()` just assigned. It emits the fact only when both operands' static type is `f32`, so the
  `f64` arithmetic that shares the same call -- `nbody`'s 38 sites, `matmul`'s final `sum` loop --
  keeps the word lowering. That distinction was the one bug the first cut had, and the f64 checksum
  loop printed a value 3e-5 off until the fact carried the operand type.

Facts are rolled back with the text they describe when a function attempt is retried for a literal
type hint, and nothing is recorded while `emit_specializations` validates an unused template.

**Which slots the lifter types.** A slot fact is accepted only when the body touches the slot
exclusively through `movq`/`cmpq` on the whole eight-byte slot, with an immediate write allowed only
of zero, and only when the slot is inside the frame. Anything else -- `leaq` of the slot (an
address taken, `&mut s`, a by-reference call), a `movl`/`movsd` alias, `incq`, an arithmetic
instruction with the slot as an operand -- leaves the slot an untyped word. Measured on the corpus:
only `matmul` has F2 facts at all (`f_main_main`, the accumulator `s`: 1 slot accepted, 4 call facts,
opcodes `*`, `*`, `*`, `+`), the four ops of the two `f32` fill loops and the pair in the kernel.
`fnv`, `sieve` and `sort` have no `f32` local and no `f32` arithmetic; `nbody` has 38 float
operations and every one of them is `f64`, so it gets no fact -- which is the answer to "why does
nbody not move": its gap is F1, exactly as the projection says. The borrowed-slot rule is exercised
by `compiler/tests/f32_borrowed.grl`, where the front end records the slot and the lifter drops it.

**The IR.** For an accepted slot: `alloca float, align 4` (and `store float 0.0` for the frame
zeroing, bit-identical because a float zero is all-zero bytes); every read is `load float` +
`fpext` + `bitcast` to the word the rest of the program expects; every write is `bitcast` +
`fptrunc` + `store float`. For a call with an `f32` fact: `fptrunc(bitcast rsi/rdx)` for each operand,
the `fadd`/`fsub`/`fmul`/`fdiv float` itself, and one `fpext` + `bitcast` for the word result. The
`rt_f32_round` call after it keeps its current lowering, which the round trip folds away; no value
ever crosses a register alloca as a non-f32, so `mem2reg` leaves the loop-carried accumulator a
`phi float`. `matmul`'s inner loop is now

    movss  (%r14,%r8,1),%xmm1
    mulss  0x0(%rbp,%r10,4),%xmm1
    addss  %xmm0,%xmm1

against `movss`/`mulss`/`cvtss2sd`/`addsd`/`cvtsd2ss`/`addss` before, and the f64 checksum loop after
the kernel is still `addsd`.

**`--verify-facts`** (off by default) makes the lifter emit, at every word a fact treats as an f32
(a slot store and each float-op operand), `fpext(fptrunc(d)) == d` compared on the bit pattern so a
NaN passes, with a cold branch to `rt_abort.cold`. The slot's declared-width half of the check is
the accept rule above, which is static: a slot only ever typed when every access is exactly one
eight-byte word and the slot index is inside the frame, so a narrow or partial access cannot be
silently reinterpreted. With the flag the table is also written into the module as `; fact ...`
comments, which is what `tools/test-facts.mjs` reads -- so both the check and the coverage are
visible in the artefact CI builds. The flag is inert with respect to results: the f32 fixture prints
the same 11 values with and without it.

**Bit-identity.** The argument in the next section is unchanged; what proves it is the native suite's
executable cases, which compare `stdout` exactly on both backends, plus `compiler/tests/f32_bits.grl`
(every operation, a chain that feeds each result into the next, a narrow `f32[]` load/store path,
`f32(i64)`, `-0.0`, and a sum that rounds to even at the boundary). Each value is printed as
`f64`, which is the shortest decimal of that bit pattern, so a one-ulp difference is a test failure
rather than a 12-significant-digit comparison.

**Measured.** `tools/bench.mjs --rounds 9` (paired medians), x86-64, `--backend=llvm`, same host,
same compiler sources except for this change; C `-O2 -ffp-contract=off`:

| benchmark | C `-O2` | before | ratio | after | ratio |
| --- | --- | --- | --- | --- | --- |
| fnv | 0.521 s | 0.523 s | 1.00x | 0.527 s | 1.01x |
| sieve | 0.560 s | 0.645 s | 1.15x | 0.664 s | 1.18x |
| sort | 0.897 s | 1.121 s | 1.25x | 1.119 s | 1.25x |
| nbody | 0.096 s | 0.165 s | 1.72x | 0.163 s | 1.72x |
| matmul | 0.184 s | 0.220 s | 1.20x | 0.214 s | 1.14x |

**matmul's number does not move on this host.** Two 41-round paired A/B runs of the two binaries
alone, which is the measurement that can resolve it:

| run | before | after | after/before |
| --- | --- | --- | --- |
| 1 | 0.2183 s | 0.2183 s | 1.000 |
| 2 | 0.2135 s | 0.2166 s | 1.014 |

The kernel did change -- `movss`/`mulss`/`addss` with no conversion, against
`movss`/`mulss`/`cvtss2sd`/`addsd`/`cvtsd2ss`/`addss` before -- but at `-O2` this LLVM unrolls the
pair anyway, and the second element's independent `addss` hides the widened chain's latency, so the
conversions cost throughput nothing here. Stage 2c's 1.30x baseline came from a host where they did.

What F2 is actually worth shows up in the design's own experiment: delete the branch of every check
in the `.ll` (measurement only -- no check fires on `matmul`, so the output is unchanged) and the
before/after split is unambiguous:

| matmul, checks removed | time | vs C |
| --- | --- | --- |
| before | 0.360 s | **1.95x** |
| after (F2) | 0.191 s | **1.05x** |

That is stage 2c's 1.95x pathology reproduced exactly: without F2 the unrolled, check-free kernel
carries the `f32` accumulator as a `phi double`, and removing the checks makes `matmul` 1.9x
*slower* than leaving them in. With F2 it is 1.05x -- C parity -- and that is what makes F1's lever
usable for `f32` code at all. So F2 on its own moves nothing on this machine, and F2 as the
prerequisite for the checks coming out moves `matmul` from 1.95x to 1.05x; the fact table is
committed on the second basis, with the first stated plainly.

### Implemented: F1 (2026-11-10)

F1 landed in the shape above, and then was **gated off by the measurement**: the fact table, the
invalidation rules and the `--verify-facts` checks are in the tree, but the lowering that consumes
them is only taken where the hoist it performs is provably usable, which on this corpus is nowhere.
`optimize.grl` and `machine.grl` are untouched and the word stream is unchanged throughout, so the
native backend emits exactly what it emitted before.

**The table.** `what` 2/3/4 means a *vector* header whose elements are 8, 4 or 1 bytes wide (`+16` is
`cap`). `what` 0 on a slot is the negative case F2 already needed, so a slot reused for another
binding is dropped. Facts are recorded at two points, both places the front end has the type:

- `emit_slot_fact` (`compiler/native.grl`), which already ran at every `bind`, records `what` and
  `width` from `header_what`/`header_width` (`ty_kind` 6 with a narrow element is a 4-byte vector,
  3/4 are byte sequences). `f32` and header facts are mutually exclusive, so one entry per slot
  still suffices.
- `fact_seq_arg` records `(function, callee, ordinal, argument 0) = header` at the access sites in
  `index_view` and at `.len()`. The ordinal is the call's index *among the calls to that callee in
  that function*: `invoke` bumps a per-callee counter and the lifter counts the same `call` lines
  back, both reset per function. A fact whose ordinal does not line up is simply not found, which
  falls back to the word lowering.

**Which slots the lifter types.** `accept_headers` keeps F2's rule that every fact naming a slot
must agree, and adds a body rule: every line that mentions the slot must be a whole-eight-byte
`movq`, a `cmpq`, or a `leaq` of it (`&v`). A constant written into the slot, a four-byte alias or
any integer operation leaves it an untyped word. Measured with `--verify-facts` on the corpus:
`nbody`'s `f_main_main` records three header slots (`p`, `v`, `m`, `what 2 width 8`) and 32 call
facts on `rt_slot`; `total(&v)` in `compiler/tests/f1_header.grl` records its two vectors the same
way. Every slot whose entry says `what 0` is dropped, as designed. A **borrowed `&[T]` parameter is
not typed**: its word is the *address* the front end passed, which for `&v` is the vector's own
header but not provably one to the lifter, so `header_what` records no fact for `ty_kind` 5/27. That
is the reason nothing in this implementation claims `!invariant.load` or `!alias.scope`: the only
place those are unconditionally true is a descriptor, and a descriptor is exactly the case the fact
table cannot speak about.

**The lowering.** A fact-carrying call targets an internal sibling of the accessor:

    define internal {i64, i64} @"rt_slot.h2w8"(ptr nocapture nofree dereferenceable(24) align 8 %a0,
                                               i64 %a1, i64 %a2, i64 %a3, i64 %a4, i64 %a5,
                                               i64 %d, i64 %l)

It is the callee's *own* word-machine body re-emitted from the same stream text, with argument 0
typed as a `ptr` and with the two header fields passed in: every load of `+0`/`+8` through a
header-derived value becomes `%d`/`%l` (`sibling_load`), the machine's word for the pointer is
`ptrtoint %a0`, and any other offset still loads through the pointer, so a body that read `+16`
would read exactly the bytes it reads today. The call site passes the words the lifter hoisted.

**The invalidation rules, enforced where the facts are consumed.** `L.eon[slot]` is 1 while the two
words are current and 2 once the header may have been rewritten; the pair is invalidated by

- any call that is given the header word and is not one of the read-only accessors (`rt_slot*`,
  `rt_at*`, `rt_len`, `rt_view`, `rt_slice`, `rt_vslice`, `rt_write`) -- which is where
  `rt_push*`/`rt_fill*`/`rt_reserve*`/`rt_pop`/`rt_vec_*`/`rt_append*`/`rt_drop_seq` land, so `data`
  dies on growth and `len` dies on push/pop/insert/remove/truncate/fill/clear under one rule;
- any `leaq` of the slot: the callee holds the header's address and may rebind or grow it;
- any untyped write to the slot, which clears it outright.

`cap` is never read from a fact: the only words an F1 fact supplies are `+0` and `+8`, so a
descriptor's uninitialised `+16` is unreachable from one. `--verify-facts` reads `+16` only to check
`cap >= len`, and only for a vector fact.

**Why the lowering is gated, and what the measurement said.** The design expected the typed
parameter to let LLVM's LICM hoist the header loads, with `!alias.scope` supplying the aliasing fact.
Measured directly with `opt -O2` on a hand-written module of the same shape, that is false, and the
reason is the caller rather than the callee: after inlining, the pointer LLVM sees is
`inttoptr i64 (load %s.N)` out of a frame slot, which is not dereferenceable at the loop preheader, so
the load may not be speculated there -- the callee's `dereferenceable(24)` is not re-derived for the
inlined argument. (`!invariant.load` *does* hoist such a load and fold the bounds compare into the
loop condition; a vector may still grow, so F1 may not claim it.)

So F1's hoist has to be the lifter's own: emit `data`/`len` where the fact is established and pass
them in. That is only correct where the establishing block *dominates* the call, and the lifter
cannot assume it -- the word machine spills every temporary to a frame slot, so `nbody`'s `main` is
143 blocks and the sites that carry a fact are in blocks that the establishing block does not
dominate. Rather than estimate dominance, the consumer requires the two words to be established in
the *same block* as the call, and otherwise keeps today's `call rt_slot`. That is the "an absent fact
is always safe" rule applied to the half of the fact that is a promise about liveness.

Measured the first time round with that rule relaxed -- the call site re-reading `data`/`len` when
they were not established, which is what a fact-gated lowering can always do safely -- `nbody` went
from 1.72x to 1.89x (0.165 s -> 0.182 s): the sibling call with eight arguments plus two loads at the
call site is strictly more work than the six-argument call whose body does the same two loads. So the
relaxed form is not a lowering worth having, and it is not in the tree.

**Measured, with the gate in place.** `tools/bench.mjs --rounds 9` (paired medians), x86-64,
`--backend=llvm`, same host, the same compiler sources except for this change; C `-O2
-ffp-contract=off`. "before" is `origin/main` measured the same way an hour earlier; note that *every*
row's C baseline drifted up ~4% between the two runs, which is this host, not this change:

| benchmark | C `-O2` before | Grail before | ratio | C `-O2` after | Grail after | ratio |
| --- | --- | --- | --- | --- | --- | --- |
| fnv | 0.527 s | 0.527 s | 1.00x | 0.551 s | 0.549 s | 1.00x |
| sieve | 0.557 s | 0.646 s | 1.16x | 0.566 s | 0.664 s | 1.17x |
| sort | 0.890 s | 1.135 s | 1.28x | 0.917 s | 1.133 s | 1.24x |
| nbody | 0.095 s | 0.164 s | 1.72x | 0.099 s | 0.173 s | 1.75x |
| matmul | 0.183 s | 0.214 s | 1.17x | 0.193 s | 0.228 s | 1.18x |

Stage 2c's baselines for the same five, from `llvm-backend.md`, are 1.05x / 1.07x / 1.46x / 2.42x /
1.30x; F2 moved `matmul` to 1.14-1.20x on this host and nothing else. F1 changes no ratio outside
the observed spread: it is **neutral**, which is the honest description of a fact the lowering
declines to use.

**Was it worth it?** No, not as a performance lever on this corpus, and the measurement is what says
so. What the fact buys is blocked by two things that are not type facts: LLVM will not speculate a
header load whose pointer is not dereferenceable at the preheader, and the lifter cannot place its
own hoist without knowing which block dominates which. Both are fixable and neither is F1's job:

- a **region fact** from the front end -- "no `rt_push*`-family call on this value inside this loop"
  -- turns the lifter's hoist into a real preheader hoist for an owned vector, and would let a
  *descriptor* fact carry `!invariant.load`, which is measured to hoist on its own;
- the remaining `sort`/`nbody` gap is the per-access bounds compare, which needs the **range fact**
  and a loop-guard proof (`llvm-backend.md` stage 3), not a type.

The two things F1 does leave behind are worth keeping: the fact table now carries a *pointer* type
with its element width, which is the half of the design that outlives this attempt, and
`--verify-facts` checks it -- including `cap >= len`, the check that makes a
vector-fact-on-a-descriptor abort rather than corrupt a length, exercised by
`tools/test-facts.mjs`'s `--f1-what=2` case.

### Implemented: the range fact (F3)

The lever is in `compiler/llvm.grl` and it is the lifter's own: the front end's stream is unchanged,
`optimize.grl` and `machine.grl` are untouched, the word stream of all five benchmarks is
byte-identical to the F1 branch's, and the native backend emits exactly what it emitted before. What
the range fact changes is the lowering of the six accessors that bounds-check -- `rt_slot`,
`rt_slot4`, `rt_slotb` and the `rt_at`/`rt_at4`/`rt_atb` loaders above them.

**What a fact is.** A *state* is one flat `u64[]` per block, and the lattice is a little richer than
"an integer in [lo, hi]" because the bounds check is not the only thing the word machine hides:

| kind | the word in the location is | join |
| --- | --- | --- |
| 0 | nothing this analysis can type | absorbing: a location two paths disagree about stays untyped |
| 1 | an integer in [lo, hi], and/or a value proven `< len(identity)` | hull, and the `< len` bound survives only when both paths state it against the same length generation |
| 2 | a sequence header of identity *k* (`rt_new`'s result, and every copy of it) | survives while both paths name the same identity |
| 3 | the address of frame slot *k* (the front end's `&v`, loaded back at the accessor) | same |
| 4 | the length word of identity *k* (a `+8` load, or `rt_len`'s result) | same |
| 5 | the 0/1 word a comparison was materialised into | same |

and per identity, alongside the locations: a lower bound on the length, whether it is known at all,
and a *generation* counter bumped by every event that may move it. A bound stated against a length
that has since moved proves nothing, so the generation is part of the fact.

**Where facts are established.** All of these are proofs:

- a literal (`movq $c,%rax`, `movabsq`), a masking (`andq`), and the truncation to a narrow type
  (`movl`, `movb`, `movzbq` -- the last two land on the register they zero-extend into);
- the arithmetic over them: `addq`/`subq` (with an underflow check), `incq`/`decq`, `imulq`/`mulq`
  (bounded so the product cannot wrap), `shlq`/`shrq`;
- a comparison already checked on the path: the taken and fall-through edges of `cmpq` + `jcc` are
  refined with the relation the branch tests, on both operands, and a proven comparison also *decides*
  the branch, which is what makes the front end's cold `rt_abort` arms unreachable;
- the loop guard as the front end actually emits it: every `while`/`for` condition is materialised as
  a 0/1 word (`cmpq`; `setcc`; `movzbq`; `xorq $1`; `testq`; `jcc`), so the analysis records which
  comparison a `setcc` came from and, at the `testq`, refines the comparison's own operands -- and
  follows the copies that carried them (`movq -120(%rbp),%rax` then `movq %rax,-128(%rbp)`), so the
  fact lands on the slot the loop counter lives in rather than on a register the block reuses;
- the length: `rt_new` gives a fresh identity of length 0, `rt_fill`/`rt_fill4`/`rt_fillb` of a
  constant count give that length, `rt_vec_copy` gives a copy of its source's, and a `rt_push` grows
  it by one.

**Where facts are dropped.** Each of these is a rule, not an accident of the code:

- a write to the location (`movq`/`movl`/`arithmetic`/`popq`), which ends whatever it held;
- an address that escapes: `leaq -N(%rbp)` marks the slot, and a *store through a register* then ends
  the facts of every escaped slot, because such a store can reach exactly those;
- a call this analysis does not model: it may hold a pointer into the frame and may take any of its
  six argument words by reference, so the escaped slots and the caller-saved registers are dropped and
  any identity whose header word it was handed loses its length. The six accessors, `rt_len`,
  `rt_view`, `rt_write`, `rt_slice`/`rt_vslice` and the float helpers are the ones that cannot: they
  are given the header *word*, never the slot's address;
- the callee-saved registers are *not* dropped: the stream spills them at entry and reloads them at
  exit, which is where the loop counters live;
- a narrowing that is not provably in range ends the fact instead of being reinterpreted;
- a join the lattice cannot express (two kinds, two identities, two length generations);
- a refinement that contradicts the fact the path started from.

**It is behind a flag.** `--range-facts` (off by default) turns the pass on; `--verify-facts` keeps
checking whatever facts exist, so the two together are what proves a removal. The flag exists because
the pass does not yet pay for itself: it removes no check on the corpus and costs compile time (see
*Measured* and *Was it worth it?*), and a default that is ~90% slower to compile for 0% of runtime is
not a default. The ticket that would let it be turned on is at the end of this section.

**The consumer.** At a call to one of the six accessors, when argument 0 is a header of identity *k*
and argument 1 is a word the facts put below `len(k)` -- either below a known lower bound on it, or
below a length word the same generation still bounds -- the accessor's body is emitted in place of the
call with the check removed: `data + i*width` through a typed load of `+0`, `align 8`/`align 4`/
`align 1` by element width, and the value loaded for the `rt_at` family. Nothing is assumed: the
address arithmetic is the accessor's own, and the six accessors' bodies are exactly
`if (i < len) == 0 { rt_abort(); }` followed by that address.

`--verify-facts` re-inserts the check it removes -- `icmp ult i64 %i, <len>` and a cold
`rt_abort.cold` -- at every site whose check was elided, so a wrong fact aborts on the spot instead of
reading or writing whatever is at the address. The flag also writes one `; range <line> <verdict>`
comment per verdict into the module, so a test (or a CI log) shows exactly which sites the proof
covered.

**Measured.** `tools/bench.mjs --rounds 9` (paired medians), x86-64, `--backend=llvm`, same host, one run per
side, C `-O2 -ffp-contract=off`. "before" is `origin/typed-ir-f1` built from the same tree:

| benchmark | C `-O2` before | Grail before | ratio | C `-O2` after | Grail after | ratio |
| --- | --- | --- | --- | --- | --- | --- |
| fnv | 0.513 s | 0.519 s | 1.00x | 0.511 s | 0.519 s | 1.00x |
| sieve | 0.479 s | 0.580 s | 1.21x | 0.448 s | 0.571 s | 1.28x |
| sort | 0.826 s | 1.101 s | 1.33x | 0.816 s | 1.076 s | 1.32x |
| nbody | 0.098 s | 0.168 s | 1.71x | 0.098 s | 0.169 s | 1.72x |
| matmul | 0.195 s | 0.224 s | 1.15x | 0.191 s | 0.224 s | 1.17x |

**Nothing moves, and the reason is that nothing fires.** The Grail column is the same to the
millisecond on four of the five (`fnv` 0.519 -> 0.519, `matmul` 0.224 -> 0.224, `nbody` 0.168 ->
0.169, `sort` 1.101 -> 1.076, `sieve` 0.580 -> 0.571 -- the spread of that one is 0.107 s, so it is
noise); the ratios differ only because the C baseline drifted 2-6% between the two runs, which every
measurement in this document has had to correct for. The removed-check count is the flat statement:
**0 of the front end's bounds checks on all five benchmarks**, and the run was made on a shared
machine, so the paired design is what keeps the comparison honest.

**What does fire.** Two fixtures, and only where the length is a literal the analysis can hold:

    fn main() {
        mut v = u8[0; 10];
        mut i: u64 = 2;
        while i < 5 { if v[i] == 0 { println(i); } i += 1; }
    }

proves `v[i]` at its one access (1 of 1 checks, `; range 44 3`), and prints `2 3 4` identically
through the native backend, through LLVM, and through LLVM with `--verify-facts` (which re-inserts
the compare and the cold abort). The same program with `n` a local instead of a literal (`u8[0;
n + 1]`, `while i <= n`) still proves it, but only while the fill's constant survives to the call;
the sieve-shaped version of it -- two nested loops over a 101-element vector -- proves nothing,
because the extra loop copies the counter through slots the decision machinery cannot follow. That
fixture is kept in the report rather than the tree for that reason.

**Why the benchmarks do not fire.** Each one needs a length the analysis cannot state:

- `sort`, `matmul` and `fnv` fill their vectors with `for i in N { v.push(x) }`. The length after
  such a loop is `N`, and the analysis never reads it, because it has no rule for a loop's *trip
  count*: the fixpoint's join at the loop header is a lower bound on the length, taken as a minimum,
  so it correctly keeps the pre-loop value (`0`) for the loop body and cannot express the exit value
  (`N`). `sieve` is different: its `u8[0; n + 1]` is a constant `rt_fill`, which the pass does read
  (`len >= 50000001`), and its `composite[i]` check is the one that *would* go -- what stops it is
  that its counter also reaches the accessor through an extra copy, and the pass loses the bound
  there.
- `nbody` hands its three vectors to `energy(&p, &v, &m)`, which takes their addresses. The rules
  drop every fact about a slot whose address escapes, correctly: an unknown callee may rebind it. It
  does not, but only a region/effect fact -- "this call does not grow or rebind what it borrows" --
  can say so, and that is not a range fact.

**Cost, and why the pass is off by default.** With the pass on, the lifter runs it for every function
that both creates a sequence and reads one: `sieve` 3.2 s -> 5.5 s and `nbody` 3.3 s -> 6.1 s end to
end (`--backend=llvm`, same host; measured with other work on the machine, so an upper bound). Two
thirds of the original cost came from what the `creates` gate and the worklist fixedpoint removed, and
the rest is one forward walk per function plus a second walk to record the verdicts. With the flag off
-- which is the default, and what every gate in the project compiles with -- the pass is skipped
entirely and the compiler is back to F1's numbers: **3.2 s / 3.3 s** on the same two programs.


**Was it worth it?** No -- not as a performance lever, and the flat number above is the whole of it: on this corpus the
range fact removes no check, so it moves no benchmark, and the pass therefore ships behind
`--range-facts` rather than on. What is in the tree is the *proof machinery*,
which is the part that had to exist before any loop summary could be believed:

- a fact lattice that is sound by construction (a join with two kinds, two identities or two length
  generations is `unknown`, every refinement narrows what is already held, and a contradictory
  refinement clears the fact rather than inventing an empty set);
- the establishment rules the front end's own stream supports, including the 0/1 word it
  materialises every `while` guard into, with the copies that carried a comparison's operands
  followed back to the slot the loop counter lives in;
- the drop rules, and `--verify-facts` re-inserting exactly the check a fact removed, at every site,
  so a wrong fact aborts on the first out-of-range index instead of on the last element;
- the consumer, which is the accessor body with the compare taken out.

The next ticket is one rule, and it is worth writing down while the analysis is fresh: **summarise a
counted fill loop**. Detect a loop (a header block and a single backedge) whose guard the analysis
already decodes; the counter's lower bound at the header is its initial value, so the trip count is
`bound - lo + 1`; count the `rt_push` calls to each identity in the body (the same pass already
counts one per iteration); then attach `len(k) = len_before + trip * pushes` to the loop's *exit
edge*, not to the header's join. That is the one place the lattice cannot express the answer on its
own -- the join must stay a minimum for the body -- so it has to be an edge annotation. With it,
`sort`, `matmul`, `fnv` and `sieve` all have both halves of their proof, and `nbody` still needs the
region fact for `energy(&p, ...)`.


## Staged plan and checkpoints

Each stage is independently shippable; each stage's checkpoint is a measurement, not an opinion.
Baselines are stage 2c's paired medians of nine, `tools/bench.mjs --rounds 9`, x86-64, and the
"expected" column is my estimate with its derivation; the ones marked *measured* are stage 2c's
numbers, not projections.

| stage | change | checkpoint (gate) |
| --- | --- | --- |
| 0 | `tools/tir-facts.mjs` in the tree; no compiler change | coverage table reproducible; `bun tools/ci.mjs lint` unchanged |
| 1 | `Fact[]` in `C`, `emit_fact` at `bind` + `invoke`, `llvm.lower(facts)`; **nothing consumed** (facts counted and dropped, one `--print-facts` count) | fact counts match `tools/tir-facts.mjs`; native suite unchanged on both backends; **all five benchmarks within noise** (no fact is consumed, so this stage *must* be a no-op) |
| 2 | F2 consume: `f32` slots as `alloca float`, `rt_f64_op` rewrite, the fact table and its `--verify-facts` mode (**landed**) | the `.s` half met: `matmul`'s unrolled kernel is `addss`/`mulss` on `xmm` with no `cvtss2sd`/`cvtsd2ss`, every other benchmark is unchanged, `nbody` correctly gets no fact, and the native stream is byte-identical. The ratio half is **not** met here: at default `-O2` on this host `matmul` is 1.20x -> 1.14x in the 9-round paired run and 1.000/1.014 after/before over two 41-round A/B runs, i.e. no change. With the checks removed (stage 2c's experiment) the same change is 1.95x -> 1.05x, which is the basis it is committed on. Stage 5's check rode along with it |
| 3 | F1a: typed `rt_slot`-family parameters (`dereferenceable(24) align 8`), `align 8` on header and word element accesses, `!alias.scope` on header vs element | **sort 1.46x -> <= 1.25x**, **nbody 2.42x -> <= 1.55x**; if either gate misses, go to stage 4 rather than tuning metadata |
| 4 | F1b only if stage 3 misses: lifter hoists `data`/`len` at the fact's point and rewrites in-region loads | **nbody <= 1.40x**, **sort <= 1.22x**; the loop body must contain no `load i64, ptr %hdr` (grep the `.ll`) |
| 5 | `--verify-facts` mode (below) on in every CI run of the native suite | **landed with stage 2**: the flag and `tools/test-facts.mjs`; the whole native suite is green on both backends with it available, and the f32 fixtures are in the suite with and without it |

Expected ratios if both facts land (start -> expected, with the basis):

| benchmark | now | expected | basis |
| --- | --- | --- | --- |
| fnv | 1.05x | **1.00-1.05x** | already at its floor: the hash loop is a serial `xor`/`imul` chain, so the header load F1 would remove (`rt_atb` per byte) is not on the critical path. 0 F2 sites |
| sieve | 1.07x | **1.00-1.07x** | memory bound, stores with stride `i`; F1 removes the header load from `composite[i]`/`composite[j]` but the loop is waiting on memory |
| matmul | 1.30x | **1.05-1.20x** | F2 removes two conversions and a binary64 add from the accumulator's dependency chain, and stops the widening from *penalising* an unroll (the 1.95x column). The unrolled, narrowed kernel has not been built, so the 1.05x end is an extrapolation (the C kernel is the same `addss` chain); the gap F2 does not close is the header load and bounds compare per access, which F1 addresses and which is why this row is bounded from below by ~1.05x rather than 1.00x |
| sort | 1.46x | **1.18-1.22x** | F1: the "checks removed" column is 1.21x *measured*, and 1.16x is the measured representation floor |
| nbody | 2.42x | **1.30-1.48x** | F1: the "checks removed" column is 1.48x *measured*; 1.34x is the representation floor, and hoisting the header load is exactly what the floor is made of; the 1.25x end needs `-unroll-threshold=2000` as well, which stays rejected |

So: **two facts take five benchmarks to 1.00-1.07x on three of them and to 1.18-1.48x on `sort` and
`nbody`.** Reaching 1.0x on those two needs a third fact that is not a type: a *range* fact (the
front end's `for i in 15` over a 15-element `f64[]`, or the `i*3 + k` bounds it already computes in
`proven_index`), which is what turns the remaining one compare-and-branch per access into a loop
guard. That is stage 3 proper in `llvm-backend.md`'s terms and is deliberately out of scope here: it
needs the range in the front end's representation, not a type in the lifter's.

## Tests that catch a wrong fact

The two failure modes are "the pointer was not a header" (or the wrong width) and "the word was not
an `f32`". Four independent nets, cheapest first:

1. **`--verify-facts`**, a compiler flag that makes the lifter emit a checked use of every fact it
   consumes, all cold:
   - `header(W)`: `and i64 %w, 7 == 0`, `%w != 0`, and for a vector `cap >= len` (a `header(24)`
     fact wrongly attached to a view would read uninitialised `+16` and fail this);
   - element pointer `data + i*W`: `%w >= %data` and `%w < %data + len*W` -- this is exactly the
     descriptor-validity check stage 2b deleted from `runtime.grl`, restored where the fact is
     claimed, so it costs nothing in a release build;
   - `f32`: at every widening, `fpext(fptrunc(d)) == d`. One `fcmp` + branch per typed boundary.

   `tools/test-facts.mjs` runs the `f32` fixtures with the flag (and without it, asserting the same
   output) and checks that the round-trip compare is in the module; any program whose fact is wrong
   aborts loudly instead of printing a plausible wrong number. The flag also writes the table into
   the module as `; fact` comments, so a CI log shows exactly what was claimed.
2. **Wrong element width** (a `header(8)` fact on a `u32[]`): a case that fills a `u32[]` with
   `u32(4294967295), 1, 2` and a `f32[]` with `1.0, 2.0`, reads them through every path (index,
   `for x in`,
   `for x in &mut`, `&mut v[i]`, a sub-slice, a generic function over `&[T]`) and prints the values.
   A width mixup either aborts (bounds) or prints the neighbouring element's bits.
3. **Stale header** (a fact that says `data`/`len` do not change while they do): a case that grows in
   the loop it reads in, e.g.

   ```
   fn main() {
       mut v = u64[];
       mut acc: u64 = 0;
       for i in 64 {
           v.push(i * 3);
           for j in v.len() { acc = acc + v[j]; }     // len and data both change under the loop
       }
       println(acc);
   }
   ```

   plus its `bytes`/`f32[]`/`i32[]`/slice-taking variants. The expected `stdout` (from the native
   backend, which is today's reference) is a single number; a hoisted `len` or `data` changes it or
   hangs, so both failure directions are caught without any instrumentation.
4. **Not-an-`f32`**: a case that computes with `f64` and then narrows, printing the exact decimal of
   the widened result (`f64(f32(1.0) / f32(3.0))`, `f64(f32(1e30) + f32(1.0))`, a `f32` field of a
   record whose address is taken, `&mut` to an `f32` local). Any wrongly-typed word shows up in the
   last digits.

The native suite is the right home for all of them: `tests/native-cases.json` cases assert exact
`stdout`/`status` and run on both backends, so a divergence between them is a test failure by
construction.

## Risks and invalidation rules

**F1, the header pointer.** The pointer-ness is static; the header's *contents* are not.

- *Kill on any untyped write to the slot.* If a slot's fact says `header` and the lifter then sees a
  write it cannot type (a call result, a `raw_load`, an unknown instruction, an address-taken slot),
  the slot stops being typed. This is the typed-value layer's job, not a fact-table rule.
- *Kill on reallocation.* `data` changes when the sequence grows: `rt_push`/`rt_push4`/`rt_pushb`
  call `rt_grow` (`runtime.grl:233`, `runtime.grl:161`), which may `mremap` in place or allocate a new block and store
  the new pointer at `+0`. A fact that permits hoisting `data` must therefore be scoped to a region
  containing no growth of *that* sequence. Emission rule: hoist-facts (`F1b`) are emitted only (a) for
  a borrowed `&[T]`/`&mut [T]`, where the language forbids growth for the loan's life
  (`docs/design/typed-slices.md`), and (b) for an owned vector only within a straight-line region
  with no call to `rt_push*`, `rt_fill*`, `rt_pop*`, `rt_reserve*`, `rt_vec_insert`,
  `rt_vec_remove`, `rt_vec_truncate`, `rt_append*`, `rt_vec_copy`, `rt_drop_seq` on that value. The
  emitter knows which call it emits, so this is a lookup, not an analysis.
- *`len` changes* on every `push`/`pop`/`remove`/`insert`/`truncate`/`fill`/`clear` as well, and
  `cap` only on growth. Same region rule; a hoisted `len` across a `push` is a wrong loop trip count
  (a hang or a truncated sum) -- test 3 above.
- *Element stores never write the header.* Unconditionally true: the header and `data` are two slabs
  returned by `rt_alloc`/`rt_grow` and both live while the sequence is. That is the fact that lets
  the bounds compare and the element store be reordered relative to each other, and it does not go
  stale -- it is a property of the allocator.
- *A view is not a vector.* `rt_slice`/`rt_vslice` write `+0` and `+8` only, so `+16` of a descriptor
  is uninitialised. A `header(24)` fact on a view is the one way a fact reads memory that the
  untyped lowering never reads (today nothing reads `+16` of a view because `rt_push` only runs on
  vectors). `what` distinguishes them and `--verify-facts`' `cap >= len` check catches a mixup.
- *Reference tagging.* Stage 2a's tagged (narrow) references set bit 63 of an element pointer. A
  *header* pointer is never tagged, so a fact on a slot holding a reference-to-element (`what = 6`)
  must not be confused with a header; element-pointer facts carry `what = 6` and the lifter must test
  the tag before typing a load through them (or decline the fact when the slot is a sub-word
  reference, which is the conservative option and covers `f32[]`).

**F2, the `f32` word.** The facts are static and per function, so they cannot go stale at runtime;
the failure mode is a *wrong emission*, not a stale one.

- A `f32` value is created by: an `f32` literal, a narrow (4-byte) `f32` element load, `f32(x)`
  conversion (which calls `rt_f32_round`), `rt_f32_from_int`, and any `f32` arithmetic (which the
  rewritten `lower_call` produces and then marks). A `f32` slot is created only by `bind` for a local
  whose type is `f32`.
- Killed by: a write to that slot from a non-`f32` source, or an address-taken slot.
- The dangerous boundary is widening: `fpext` of a value that is not `f32`-representable silently
  changes it. `--verify-facts` covers exactly this, and the emission rule (never infer through a
  temporary, never type a call result) keeps the boundary small.
- Field/reference interactions: an `f32` record field lives in a word slot with the *word* type (a
  reference to it is tagged per stage 2a), so `slot = f32` applies to *locals*, not to records; a
  record field's `f32`-ness is a `narrow_decode`-to-`cvtss2sd` fact that lives one block and needs no
  slot entry.

## Cost, in one table

| item | where | size |
| --- | --- | --- |
| `Fact` struct, `C.facts`, `emit_fact` at `bind`/`index_view`/`invoke`, call-ordinal counter, conservative rules | `compiler/native.grl` | ~60-80 lines |
| pass `c.facts` to `llvm.lower` | `compiler/native.grl` | 2 lines |
| `facts` parameter through `lower`/`lower_for`/`lower_target`; per-function fact maps | `compiler/llvm.grl` | ~60 lines |
| typed value layer: `valtype`/`set_valtype`/`clear_valtype`, typed `address`/`value`/`store` variants, propagate through copies | `compiler/llvm.grl` | ~150 lines |
| F2 consumer: `alloca float` slots, `rt_f64_op`/`rt_f32_round` rewrite, narrow load/store typing, `fcmp` for `rt_f64_cmp` | `compiler/llvm.grl` | ~80-100 lines |
| F1a consumer: typed accessor parameters, `dereferenceable`, `align 8`, `!alias.scope` | `compiler/llvm.grl` | ~60 lines |
| F1b consumer (only if F1a misses) | `compiler/llvm.grl` | ~70-100 lines |
| `--verify-facts` | `compiler/llvm.grl` | ~40 lines |
| fact coverage measurement | `tools/tir-facts.mjs` | 80 lines (in this change) |
| tests | `tests/native-cases.json` | ~10 cases |

Total: roughly 390-480 lines in `llvm.grl` (a fifth of the file's 1 916), 65-80 in `native.grl`,
none in `runtime.grl`, `optimize.grl` or `machine.grl`.

As built, F2 alone is **+337/-12 in `llvm.grl`** (the `Fact`/`Facts` table, the slot accept rules,
the typed slot load/store, the `rt_f64_op` rewrite, `--verify-facts` and the table dump) and
**+116/-23 in `native.grl`** (the table fields, `emit_slot_fact`/`float_op_call`, the label that keys
the table, the ordinal in `invoke`, the report and roll-back of a discarded attempt, the flag). No
typed-value layer was needed for F2: only the *slot* is typed (`alloca float`), and a register that
carries an f32 carries the word, whose `fptrunc`/`fpext` pairing folds away. F1 is what needs the
per-value layer. For comparison, stage 2a (4-byte elements)
touched the front end, the runtime and all three lowerings; option 3 touches the whole lifter.

## What this does not do

- It does not make the lifter's value model typed (option 3). It makes two facts visible to an
  otherwise untyped lifter; a real typed SSA IR from the front end would subsume both and is still
  the better long-term shape, but it is not the cheapest way to get these numbers.
- It does not remove the bounds compare. That is a range fact, and it is the remaining 0.2-0.35x on
  `sort` and `nbody`.
- It does not touch `f64` performance, the ABI, `optimize.grl`, `machine.grl`, or the native backend.

## Verification

- `bun tools/ci.mjs lint` (no new checks; the doc and the tool are not wired into it).
- `bun tools/native.mjs build` is untouched by this branch: no file under `compiler/` changed.
- `bun tools/tir-facts.mjs <stream>.s` reproduces the coverage table above:
  `grail --debug --target x86_64 --overflow=checked OUT.s bench/NAME.grl compiler/runtime.grl
  compiler/os-linux.grl` writes the raw stream (`--debug` skips `optimize.grl`, which is the same
  stream `--backend=llvm` lowers).
- F2's own checks: `bun tools/test-facts.mjs` (the f32 fixtures on both sides of `--verify-facts`,
  the `; fact` coverage, and the address-taken slot that must be dropped).
- `GRAIL_BACKEND=llvm bun tools/test-native.mjs x86_64` (exact `stdout` on both
  backends), `GRAIL_BACKEND=llvm bun tools/bench.mjs --rounds 9`, and the same for `aarch64`/`riscv64`
  under qemu, since the facts are target-independent and the lowering is shared.
