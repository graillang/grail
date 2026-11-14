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
- a refinement that contradicts the fact the path started from;
- **shared-reference calls keep escaped slots**: a call the analysis does not know clears every frame
  slot whose address the function took, since the callee may write through the address. The front
  end now records which parameters of each function are shared references (`fact_shared_param`,
  dumped as `; fact F param N shared`), and `rg_mut_escape` follows each `leaq` of a slot through
  register and frame-temporary copies to the next call. A slot whose every address reaches only
  shared-reference parameters, or is only read through (`movq (%rax),...`), keeps its facts across
  the call; any store through it, jump, label or other use before the call counts as an escape. In
  nbody, `energy(&p, &v, &m)` no longer erases the vectors' identities, so `main` proves 12 of its 17
  bounds-checked accesses (it proved none), and nbody goes from about 1.8x to about 1.5x of C
  (llvm, range facts). The remaining checks are in `main`'s update loop.
- **counted fill loops** (`rg_fill_loops`, the summary the section below asked for): a loop in the
  front end's `for i in N { ... }` shape - counter start `K` (`movq $K,I` or through `%rax`), guard
  `movq E,%rcx; movq I,%rax; cmpq %rcx,%rax; jae .LX`, latch `incq I; jmp .LH` - whose body is
  straight-line (its only branches skip a single `call rt_abort`), calls only functions that cannot
  shrink or rebind a vector, never writes `I`, `E` or a pushed vector's slot, and whose exit label
  is reached from the guard alone, ran at least `E - K` times and pushed each vector held in a
  non-escaped frame slot the number of times its body names it. At `.LX` the vector's length is
  then at least `(lower bound of E - K) * pushes`. In matmul the three 65,536-element fills now give
  the kernel's `a[i*n+k]`, `b[k*n+j]` and `c[i*n+j]` their lengths: about 1.4x to 1.0x of C
  (llvm, range facts, busy host). `range-fill-loop` pins the rule, and
  `range-fill-loop-skip-not-summarised` pins that a loop that can skip its push is not summarised.
- **element stores, decided drop flags, loads through a slot address, drop glue**: four transfer
  rules that keep a vector's facts alive through the code `p[i] = x` and its temporaries lower to.
  `rt_slot` returns the address of one heap element (kind 6), and a store through it changes that
  element only. A `cmpq $C, X; jcc` whose X this same block set with `movq $K, X` (a drop flag cleared
  just before its guarded drop) carries state down the edge it takes only, so the dead drop call
  is never analysed - decided from the block's own straight-line code, never from its entry state.
  `movq (%rax)` through the address of a frame slot reads that slot's word (it used to be read as
  the header's first field, losing the identity). And drop glue (`.D<hash>`) is given the dropped
  value, never a frame address, so it clobbers caller-saved registers but leaves escaped slots'
  facts. Measured (llvm, median of 7, quiet machine): nbody 1.7x and matmul 1.2x of C -O2, with or
  without `--range-facts`: the accesses inside nbody's update loop still lose the escaped vector
  after the first iteration's back edge (traced: header and length known in round 1, gone in round
  2), which is the next cause to find; matmul still needs the counted fill-loop summary.
- **widening at loop heads, and no verdicts without a fixpoint**: from the fourth round, a join on a
  back edge (into a block at or before the one the edge leaves) widens instead of creeping: an
  upper bound that grew jumps to the smallest immediate in the function that covers it - the guard's
  own bound, so `while i < 300` holds `i` at [0, 300] at the head and the guard narrows it to
  [0, 299] in the body - or to the maximum; a lower bound that fell goes to 0; a length generation
  the paths disagree on becomes a fixed value per (block, identity) that no bound was stated
  against. Forward joins never widen (widening the guard's edge into the body threw away the very
  bound it proved). Every loop now converges in a few rounds: `compiler/tests/range_long_proof.grl`
  (300 trips) and `range_push_loop.grl` (a loop that pushes) are proved. The 24-round cap stays as
  a backstop: a function still changing there gets *no* verdicts and keeps every check. Before
  widening that rule was what kept the pass sound - `while i < 100` over `u8[0; 30]` was judged
  with `i` in about [0, 23] and read 70 bytes past the end (`range_long_trip.grl`, still pinned:
  it converges now and keeps its check, since 100 does not prove an index into 30).

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

## What the checks cost, by kind (measured 2026-11-11)

Status: **measurement**. `compiler/` is untouched: the experiment is `tools/checks-budget.mjs`,
which classifies the abort arms in the emitted `.ll`, then times variants of that same `.ll` with
one kind of arm deleted. No temporary counter was added to the front end -- the kind of an arm is
decided by two facts that need no instrumentation: the accessor functions are the only place a
bounds check lives (`compiler/runtime.grl`), and an arm that `--overflow=wrap` does not emit is an
arithmetic check.

Four readings, all x86-64, `--backend=llvm`, `clang -O2` for the `.ll` and `-O2 -ffp-contract=off`
for C, `--rounds 9` (median of nine interleaved rounds, the method of `tools/bench.mjs`). The host
is 24 cores under a load average of 11; `llvm-backend.md` stage 2c already records that a difference
under 5-7% is not a result on this machine, and that is the resolution to read every table below at.

### The arms, by kind

`bun tools/checks-budget.mjs count`. "Reachable" follows direct calls from `f_main*`; the module
also carries the whole runtime and core library, most of which a benchmark never runs.

| benchmark | arms in the `.ll` | reachable | bounds | overflow | other | in `f_main*` | index accesses per inner iteration |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fnv | 1154 | 144 | 6 | 3 | 135 | 3 | 1 |
| sieve | 1156 | 131 | 9 | 5 | 117 | 5 | 2 |
| sort | 1164 | 140 | 6 | 12 | 122 | 13 | 3 |
| nbody | 1197 | 238 | 10 | 46 | 182 | 46 | 6 |
| matmul | 1161 | 228 | 16 | 8 | 204 | 10 | 2 |

*bounds* is an arm inside a sequence accessor (`rt_slot*`, `rt_at*`, `rt_write`, the slices, the
pushes, `vec_*`); *overflow* is an arm the checked build has and `--overflow=wrap` does not, by
function; *other* is everything else reachable -- allocation, formatting, UTF-8, division and
conversion, all of which run O(1) times per program except matmul's `f32` round trip, which is once
per accumulate.

The first structural fact this table shows: **a bounds check is not an arm at the call site**. Every
`v[i]` is a `call rt_slot` (`rt_slot4` for `f32`, `rt_atb` for `u8`), and the bounds test is the one
arm inside the accessor. So the static bounds count is 6-16 for every program while the number of
bounds checks *executed* is one per element access: 1 per inner iteration for `fnv`, 2 for `sieve`
and `matmul`, 3 for `sort`, 6 for `nbody`. A static count can size the arithmetic checks (which the
program's own functions carry: 46 in `nbody`, 12 in `sort`, 8 in `matmul`, 5 in `sieve`, 3 in
`fnv`) but not the bounds check. That is why everything below is timed.

### The time, by kind

`bun tools/checks-budget.mjs time --rounds 9`. Seconds, and the ratio to C in the same round.

| benchmark | C `-O2` | checked | `--overflow=wrap` | every arm deleted | wrap, bounds arms deleted | wrap, every arm deleted | checked, overflow arms deleted |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fnv | 0.569 | 0.577 1.01x | 0.577 1.01x | 0.578 1.01x | 0.577 1.01x | 0.582 1.02x | 0.576 1.01x |
| sieve | 0.507 | 0.597 1.18x | 0.620 1.22x | 0.551 1.09x | 0.599 1.18x | 0.582 1.15x | 0.567 1.12x |
| sort | 0.919 | 1.235 1.34x | 1.235 1.34x | 1.091 1.19x | 1.118 1.22x | 1.081 1.18x | 1.242 1.35x |
| matmul | 0.221 | 0.255 1.15x | 0.248 1.12x | 0.238 1.07x | 0.240 1.09x | 0.233 1.05x | 0.254 1.15x |
| nbody | 0.108 | 0.185 1.71x | 0.191 1.77x | 0.137 1.27x | 0.142 1.31x | 0.145 1.34x | 0.188 1.74x |

Shares of the checked-over-C gap, in the same run:

| benchmark | gap | overflow (`--overflow=wrap`) | overflow (branch only) | bounds (wrap base) | other (wrap base) | all checks | interaction | floor |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fnv | 8 ms | 1% | 13% | 0% | -59% | -8% | 50% | 108% |
| sieve | 90 ms | -26% | 33% | 24% | 18% | 51% | 34% | 49% |
| sort | 316 ms | 0% | -2% | 37% | 12% | 46% | -3% | 54% |
| matmul | 34 ms | 21% | 3% | 23% | 22% | 52% | -14% | 48% |
| nbody | 77 ms | -8% | -4% | 64% | -4% | 62% | 9% | 39% |

*interaction* is `all checks - (the three deltas)`: the individual deletions do not sum, because
removing a check changes what LLVM unrolls and schedules. *floor* is the residual `no arms / C - 1`
as a share of the gap -- the representation and whatever else is not a check. Two readings to be
careful with: the *bounds* and *other* columns are measured on the wrap base (the only build where
the accessor arms can be deleted without also deleting the arithmetic ones), which understates
`matmul` by 50 points -- the checked-base measurement under *Which proof would remove the most
checks* is the one to use for bounds -- and `fnv`'s row is entirely noise, a floor above 100% of the
gap meaning the check-free build is slower than the checked one.

### `--overflow=wrap` does not measure the overflow check

The variant was asked for and it is honest about one thing: what a program that *declares* its
arithmetic unchecked pays. It is not a clean isolate of the branch, because the front end also stops
emitting the flag materialization (`store i1 %f.C`/`%f.Z` and the compare that feeds it) that the
same machine's *comparisons* then read, so the emitted arithmetic differs in more than the branch.
The table above shows the consequence: `nbody` 1.71x -> 1.77x and `sieve` 1.18x -> 1.22x are
**slower** with fewer checks, `sort` and `fnv` do not move, and only `matmul` gains (1.15x -> 1.12x).
The right isolate is the third column of the shares table, which deletes exactly the arms
`--overflow=wrap` does not emit and leaves the rest of the checked build as the front end wrote it:

- `sieve` 0.597 s -> 0.567 s, the one real arithmetic-check win in the corpus (**5%**, a third of its
  gap; `i * i` and the stride adds in the `while` loops);
- `fnv`, `matmul`, `sort` unchanged, `nbody` 1.6% *slower* (0.185 s -> 0.188 s).

So the arithmetic checks cost nothing measurable on four of the five programs, and 5% on `sieve`.
Declared against measured: the two variants disagree by up to 8 points of the gap, and the
disagreement is the variant, not the check.

### The ceiling, re-measured

`checked` against "every abort arm deleted", against the numbers this design and
`llvm-backend.md` stage 2c quote:

| benchmark | quoted ceiling | measured, checked base | measured, wrap base | checked ratio in that run |
| --- | --- | --- | --- | --- |
| fnv | 1.001 | **1.002** | 1.009 | 1.01x |
| sieve | 0.955 | **0.923** | 0.975 | 1.18x |
| sort | 0.921 | **0.883** | 0.875 | 1.34x |
| matmul | 0.883 | **0.933** | 0.914 | 1.15x |
| nbody | 0.746 | **0.741** | 0.784 | 1.71x |

`fnv` and `nbody` reproduce to 0.005. `sieve`, `sort` and `matmul` are 3-5 points off and two of the
three order differently, while the *other* base moves the same three rows by 2-9 points in the
opposite direction. The same variant measured twice is the measure of that: "every abort arm
deleted" is 1.073x of C for `matmul` in the run above and 1.042x in the `floor` run below, 3 points
apart on the same binaries in the same hour, which is the size of the discrepancy -- so the ceiling
reproduces to this host's resolution and not tighter, and the quoted values are themselves one
day's reading of it. The floors
land where the design says they are, which is the more useful check: `1.002 / 1.042 / 1.120 / 1.121 /
1.256` here (see the next section) against the design's ~1.00 / 1.05 / 1.16 (sort) / 1.34 (nbody).

### The floor: representation against everything else

`bun tools/checks-budget.mjs floor --rounds 9`, check-free build, then the same build with every
sequence accessor marked `alwaysinline` (which removes the call and the return and nothing else --
LLVM still may not merge the header load across an element store, which is the F1 argument):

| benchmark | C `-O2` | no checks | accessors inlined | what inlining buys |
| --- | --- | --- | --- | --- |
| fnv | 0.531 | 1.012x | 1.009x | 0.3% |
| matmul | 0.192 | 1.042x | 1.048x | -0.6% |
| sieve | 0.506 | 1.120x | 1.097x | 2.3% |
| sort | 0.914 | 1.121x | 1.129x | -0.8% |
| nbody | 0.101 | 1.256x | 1.269x | -1.3% |

So **call overhead is at most ~2% of the floor on one benchmark and nothing on the other four**:
the accessor call is not what the residual is made of. What is left is the two-dependent-load chain
per access (slot -> header -> element) and the word machine's own shape (every scalar is a
sign-extended word in a frame slot, every f64 operation a `call rt_f64_op` -- 19 of those in
`nbody`'s inner nest). The one experiment that separates the header load from the rest is F1's
typed sibling, which passes `data`/`len` as arguments: measured in *Implemented: F1*, it made
`nbody` 1.72x -> 1.89x (0.165 s -> 0.182 s), i.e. two loads at the call site plus two more arguments
cost more than the two loads in the callee they replaced. **The header's share of the floor is therefore not attributable by any experiment in
this tree, and the two facts this document is about do not remove the floor** -- F2's own stand-alone
effect on `matmul` at `-O2` is also nil (1.000/1.014 over two 41-round A/B runs).

### Which proof would remove the most checks

`bun tools/checks-budget.mjs proofs --rounds 9` deletes exactly the arms one candidate proof would
remove, from the checked build, and nothing else. Bytes are the `.text` delta of the `.ll` object
(`objdump -h`) -- for a single accessor that is the check's own code across all the sites clang
inlined it into; for a multi-function deletion the number is not interpretable (deleting eight
accessors makes `matmul`'s text 5.4 KB *larger*, because the smaller functions inline more).

Each row is measured inside its own paired run, so the *after* column and the share are comparable
within the table and not against the table above (the C baseline moves 3-15% between runs on this
host, which is why the same program shows `checked 1.15x` here and `1.17x` there).

| benchmark | proof | arms | bytes | after | share of the gap |
| --- | --- | --- | --- | --- | --- |
| matmul | bounds: `i*n+k`, `k*n+j` < `n*n == len(a)`, from `for i in n { for k in n }` (`rt_slot4`) | 1 | 144 B | 1.049x (was 1.170x) | **72%** |
| nbody | bounds: `i*3+k < 15 == len(p)`, from `for i in 5 { for k in 3 }` (`rt_slot`) | 1 | 368 B | 1.287x (was 1.731x) | **61%** |
| sieve | bounds: `len(composite) == n + 1`, `i`, `j <= n` (`rt_atb` + `rt_write`) | 3 | 352 B | 1.036x (was 1.059x) | 41% |
| sort | bounds: `i < mid <= hi <= n == len(v)`, `k < hi` (`rt_slot`) | 1 | 256 B | 1.217x (was 1.342x) | 37% |
| fnv | bounds: `len(data) == n` from the fill loop (`rt_atb`) | 1 | 336 B | 1.018x (was 1.012x) | none |
| matmul | overflow: `i*n+k`, `k*n+j` do not overflow (`n = 256`) | 8 | 0 B | 1.178x | 0% |
| nbody | overflow: `i*3`, `i*3+k` do not overflow (both < 15) | 46 | 0 B | 1.726x | 0% |
| sort | overflow: `lo + width`, `2 * width` do not overflow | 12 | 0 B | 1.359x | 0% |
| sieve | overflow: `i * i` does not overflow | 5 | 16 B | 1.040x | none |

Ordered by measured nanoseconds saved, the bounds proofs are `sort` 106 ms > `nbody` 44 ms >
`matmul` 23 ms > `sieve` 13 ms > `fnv` 0; ordered by bytes of code they are `nbody` 368 B >
`sieve` 352 B > `fnv` 336 B > `sort` 256 B > `matmul` 144 B; every arithmetic proof is 0-16 B and
0 ms (the front end's arithmetic check is a compare on values already in registers, and LLVM hoists
or predicates it). The two orderings disagree because the bytes are a per-inlined-site cost and the
seconds are a per-execution cost: `matmul` runs 3.4·10^8 inner iterations with two loads each and
has the smallest check, `sort` moves 4.2·10^6 elements through 22 merge passes with three accesses
per move -- ~3·10^8 accesses -- and has code for a wider element.

Read the two orderings together and the answer is the same rule three times, not three rules:

1. **A length fact plus a loop guard on the index: `len` of a sequence is a literal, or the bound of
   the loop that filled it, and the index is `c*i + k` with `i`, `k` bounded by literal loop
   bounds.** In `nbody` that is `i*3+k < 15` with `p`, `v` literal `f64[15]` arrays; in `matmul`
   `i*n+k < n*n` with `n = 256`; in `sieve` `i, j <= n < n+1 = len(composite)`; in `sort` the merge
   indices against `n == len(v)`; in `fnv` `i < n == len(data)` after the fill loop. It is 1 arm in
   the source and 144-368 bytes across the inlined sites, and it is worth 61% of `nbody`'s gap, 37%
   of `sort`'s, 72% of `matmul`'s, 41% of `sieve`'s and nothing on `fnv`.
2. **The arithmetic checks are worth nothing except on `sieve`** (5%, `i*i`), so the "both operands
   are bounded by the integration step" proof for `nbody` -- true and easy -- would move 0 ms.
   Building it first would be building the proof that measures zero.
3. **`fnv` has no gap** (6-8 ms, and every deletion makes it slower): no proof is worth building
   for it, which is what its 1.001 ceiling already said.

**Build first: the range fact (F3) restricted to the loop-guard form of item 1, and start with
`nbody`.** It is the largest single check in the corpus (61% of a 1.71x gap, 44 ms), its shape is the
simplest instance of the rule (a literal `f64[15]` indexed by `i*3+k` from two literal `for`
bounds -- no fill-loop reasoning, no alias question), and the fallback is free: an absent fact keeps
today's `rt_slot`. `matmul` is the same rule one step further (the payload is `i*n+k` over `n*n`,
and it is the largest *fraction*, 72%) and is the second thing to build; `sort` needs the same fact
plus the `mid`/`hi` clamping to follow, and `sieve`/`fnv` are the last 13 ms and 0 ms.

### What this measurement could not attribute

- **The floor's split between the 24-byte header and the word-shaped scalars.** Inlining the
  accessors removes the call and measures ~0 (table above), and F1's typed sibling -- the one
  experiment that removes the header load itself -- was slower than the code it replaced. Both say
  the floor is not "the call" and neither says how much of it is the header, so the honest statement
  is that the floor is 1.01-1.26x of C and this document's two facts do not remove it.
- **`sieve`.** Its gap moved between 0.5x and 0.9x of the same story across runs, the wrap base and
  the checked base disagree in sign (+21 ms vs -13 ms for the bounds arms), and the C baseline moved
  0.474-0.547 s across runs. Only "the arithmetic branches are worth ~5%" reproduced; sieve's bounds
  share is somewhere in 24-40% and I would not put a tighter number on it.
- **The interaction term, 9-34% on `nbody` and `sieve`.** Deleting a check changes unrolling, so the
  per-kind shares are a decomposition of measured deltas, not a partition of the cycles; the three
  deltas and the total differ by that term, and it is large on exactly the two benchmarks where the
  loop shape changes (`matmul`'s -14% is the F2 story: removing its checks once made it *slower*).
- **`fnv`.** 6-8 ms of a 1% gap, with deletions that make it slower: nothing is attributable, and no
  ordering of the deltas is meaningful.

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

# A typed IR with SSA values, and its serializer

Status: design, 2026-11-13 (gaps round, the `ssair` workstream). This section is the *second* half of
this note: the fact table above carries two types from the front end into the LLVM lifter as a side
table, and leaves the word stream, `optimize.grl` and `machine.grl` untouched. The IR below is the
structural change that makes the stream a *program* -- values with types, instructions that define
and use them, function bodies as units -- so the optimizer's passes can stop rediscovering value
identity from text, the effects prover can walk calls instead of counting `call` lines, and a
function body can be serialised and cached. It is staged so that stage 1 emits byte-identical
assembly; the fact table stays the mechanism the LLVM backend reads, because it costs nothing on the
native path and is consumed per value.

## What exists today

`compiler/native.grl` emits the program as *text*: `o(&mut c, view("movq %rax,%rcx\n"))` at several
thousand sites, appended to one buffer. There is no instruction object anywhere in the front end. The
first thing that looks at structure is `optimize.grl`, which scans that buffer line by line, splits a
line into a mnemonic key (`opcode_key`, 34 codes) and two operands (`classify`: register, frame slot
`-N(%rbp)`, immediate, label, or opaque text), and runs four passes over the parallel arrays it filled
-- constant folding and slot forwarding, dead stores, dead definitions, and frame compaction with
register promotion -- then prints each surviving line back, either from its original byte span or
from the rewrite a pass recorded. `machine.grl` then lowers the x86-64 spelling to another target, and
`llvm.grl` lifts the same spelling to LLVM IR.

So the streams' *operands* are classified, but there are no values: two instructions that both say
`-24(%rbp)` are related only by the passes re-deriving "did this slot change" from the text, and a
value's type is known only where a `.gpair` marker or an `f32` fact happens to say so. Three
consequences this section exists to remove:

- `live_pass`, `count_reads` and `dead_stores` each walk the instruction array again to answer "how
  many reads does this slot have from here", because nothing records a definition or a use;
- the effects prover cannot see a call in the IR, so `fx_end` counts the `call` lines a body emitted
  to check that no call site bypassed `call_out` -- a text scan that exists only because there is no
  call list;
- nothing in the tree can name a function body as a thing, so nothing can hash one, serialise one, or
  reuse one (`docs/design/incremental-compilation.md`, *Below the module*).

## What a value is

A **value** is one machine word that an instruction wrote and a later instruction may read. It is
identified by a number `v<i>`, and it names a location, not a register name: the location is the
*space* and *index*

- space 0, index `r` -- the 64-bit register `r` (the `reg_key` numbering: 0 rax, 1 rcx, ..., 13 r15),
- space 1, index `k` -- the frame slot `-8k(%rbp)`,
- space 2, index `r` -- the `xmm` register `r` (a float or a two-word move's second half).

A value id is minted when an instruction *defines* a location, and it is what a read of that location
resolves to. A two-word pair (`docs/design/typed-ir.md`'s `.gpair`, and the frame-slot pair the
borrowed-object ABI builds) is **one** value occupying two slots: the pair's identity is its first
word, and the second word is reachable only through the pair's address, exactly as `optimize.grl`'s
`pair[]` already encodes.

A value also carries a **type**, `Ty { kind, width }`, where kind is one of

| kind | meaning | where the front end knows it |
| --- | --- | --- |
| 0 | an untyped word | everywhere else |
| 1 | an `f32` (the low half of the word) | `Local.ty` is `f32`, `bind()` |
| 2 | a vector header pointer, `width` = element width | `Local.ty` is `T[]`, `bind()`; `rt_new` results |
| 3 | a view/slice descriptor `{data, len}`, `width` = element width | `&[T]` parameters and `rt_slice`/`rt_view` results |
| 4 | an element pointer (the result of `rt_slot`) | `index_view` |
| 5 | an immediate | `classify` already knows this |

The type of a *slot* comes from the front end's `Fact` table (the section above), keyed by `(fn,
slot)`. The type of a *register* is propagated from the instruction that wrote it: a `movq` copies its
source's type, `leaq -N(%rbp)` types the destination as a slot pointer, an `f32` arithmetic call
types its result, and anything the IR cannot type is kind 0. The propagation mirrors the one the
lifter's F2 work already needed (`valtype`/`set_valtype` in `llvm.grl`), with the difference that here
it happens once, in the emitter's own IR, instead of per backend.

## What an instruction is

An instruction is one line of the stream that has a mnemonic: an opcode (the 34 existing codes, plus
100 label, 101 directive, 102 two-word declaration), two operands `(kind, value, span, mask)`, the
`del`/`chg`/`tr`/`lab` flags the passes already keep, its byte span in the emitted text, and the SSA
annotations:

- `d` -- the value id it defines, or 0;
- `u0`, `u1` -- the value ids it reads, or 0 for "the location's content on entry to the block";
- `ty`, `w` -- the type and width of `d`.

**SSA, and how it relates to the frame slots.** Ids are assigned per basic block, where a block starts
at a label that something jumps to (or at the first instruction) and ends at a jump or at a label with
an incoming edge. Inside a block, each definition is a new id and each read binds to the last
definition of that location in the block. At a block entry nothing is known, so a read of a slot gets
id 0 and stays a *slot read*; a read of a caller-saved register at a block entry is likewise 0. There
are no phi nodes and none are needed: the pass that wants union-at-merge (frame compaction's
per-slot read counts, forwarding) treats id 0 as "the slot", which is exactly the answer the current
text-based passes compute, and the emitter needs the location either way.

Two gaps are deliberate and named rather than hidden: an `xmm` register operand is not numbered
(`classify` gives it kind 6, and an `xmm` value keeps its register, because no pass reasons about it
yet), and a call's argument registers are not uses of the call instruction -- they are the calling
convention's, so `u0`/`u1` are 0 for a call and its operands are the symbol it names.

This is the sense in which SSA values relate to frame slots rather than replace them: a value id is
*the name of one definition of one location*, the location is what the emitter prints, and the maps
`value -> (space, index)` and `(space, index) -> current value` are both in the IR. The native
backend emits from instructions whose operands are still locations, which is why this landing cannot
change a byte; the SSA ids are what the passes, the prover and the cache read.

## How ownership and drop information travels

The front end already computes ownership: `own`, `move_out`, `release_temporaries`, `drop_call_out`
and the drop-helper set decide, per expression, what is copied, moved and dropped, and the effects
prover follows those drops through the call graph. In the IR that information appears in the two forms
the native backend actually uses, and the IR does not invent a third:

- **an edge.** Dropping a value emits a call to the drop helper (or to `rt_drop_seq`, `rt_free`,
  `rt_release`), so the IR's call list carries the callee symbol and the instruction that made it.
  Ownership *transfer* is therefore a call fact plus the values that flow into it, which is what
  `docs/design/effects.md`'s fixpoint consumes and what stage 2 walks instead of counting text;
- **a type.** The type a value carries (kind 2/3/4 above) is what decides whether a drop is one
  release or element-by-element, so the drop information that the prover and the cache key need is the
  pair (callee symbol, receiver type).

What the IR deliberately does **not** carry is a borrow/loan encoding: loans are a front-end,
source-level discipline, resolved before the word stream exists, and re-deriving them from
instructions would be a second, weaker checker. A stage that needs it (an ownership-aware optimizer
pass) has to have the front end record it, which is the same lesson the fact table taught.

## What the optimizer's facts become

The passes keep their algorithms, and their *inputs* become first class instead of re-derived:

| today | in the IR |
| --- | --- |
| `reads`/`writes`/`slot_read`/`slot_written` scan an instruction twice per operand | `u0`/`u1`/`d` on the instruction, filled once by the SSA pass |
| `live_pass` counts reads of a slot from a point by walking forward | the same walk, over value ids, so a redefinition of the slot ends the search without comparing spans |
| `pair[]` (a slot array the two-word passes consult) | the pair is one value; `w` says two words |
| `f32`/header handled by special cases in the lifter only | `ty` on the value, for every consumer |
| the effects prover counting `call` lines in emitted bytes | `calls[]`, with the callee symbol and directness |

Nothing in the table changes a decision in stage 1: the values are computed and carried, the passes
read them where that reproduces today's answer, and `tools/ssair-bytes.mjs` compares every emitted
function against the pre-change compiler to prove it.

## The serializer

The IR serialises as **one function per unit**, versioned, textual, because the two things it is for
-- reviewing a body and keying a cache -- both want a diffable file, and because a body is what
`docs/design/incremental-compilation.md` caches. Version 1:

```
ssair 1
fn f_t_main unit t prefix t_11a4bd8d ins 12 labels 2 calls 1
v 3 reg 0 ty=0,1 def=4
v 4 slot 3 ty=1,1 def=7
i 0 movq o0=1:0 o1=3:0 d=0 u=0,0 ty=0,1 x=12:movq %rax,%rcx
i 1 leaq o0=2:24 o1=1:3 d=3 u=0,0 ty=0,1 x=18:leaq -24(%rbp),%rax
c 0 ins 9 direct rt_abort
end
```

- line 1 is the magic and the version; a reader refuses any version it does not implement and a unit
  whose byte count disagrees with its declared `ins`, which is the same "a damaged entry is a miss"
  rule the artifact store already uses;
- `fn` names the symbol, the emission unit and its label prefix (both from `.grail_part`), and counts
  the rest, so a truncated unit is detectable without parsing it;
- `v` lines are the value table: id, space (`reg`/`xmm`/`slot`), index, `ty=<kind>,<width>` and
  `def=<instruction>`;
- `i` lines are the instructions in emission order: the ordinal, the mnemonic, each operand as
  `=<kind>:<value>` (the kinds `classify` already assigns: 1 register, 2 frame slot, 3 immediate,
  4 text/label, 6 `xmm`), the defined value, the two used values, the type and width of the defined
  value, and the emitted line itself, length-prefixed as `x=<len>:<bytes>`; because `len` is stated,
  the only field whose body can contain spaces is the last one, so a unit round-trips exactly;
- `c` lines are the calls: ordinal, instruction, and either the callee symbol or, for an indirect
  call, the reason it cannot be named (stage 2's refinement makes that reason specific: the interface,
  the closure, the vtable slot's interface).

`optimize.grl` does not read the format in stage 1 -- it is written and compared, so the format is
fixed by something real before a cache depends on it. Stage 3 reads it, keys a unit by the hash of its
own text plus the interface surfaces it names, and replays the emitted bytes of a unit that matches.

Two properties of the writing are worth stating because they decide where the text comes from.

**The unit is the body as the optimizer parsed it, before the passes.** `optimize.grl` calls
`ir::build` and then `ir::write_body` at the same point, and only then runs the passes that delete
instructions, rewrite spans and compact the frame. Writing the body *after* a pass would describe a
stream whose `-N(%rbp)` numbering had already moved, and the frame slots are exactly what the type
facts are keyed by (`docs/design/incremental-compilation.md` keys a unit by its body, not by its
rewrite, so this is also the body a cache wants).

**The facts are recorded for the IR only when it is asked for.** Every producer of a type fact in
`native.grl` (`emit_slot_fact`, `fact_seq_arg`, `float_op_call`) tests one predicate, `wants_facts`:
the LLVM lifter always wants the table, the typed IR wants it under `--emit-ir`, and a plain native
build records nothing and pays nothing. When the table is wanted the optimizer indexes it once per
compile (`ir::index_facts`, a 4096-bucket table by body symbol) so a slot lookup is a scan of one
body's few facts rather than a scan of the whole table per slot the program writes.

## What this does not do

- It does not remove the front end's text emission. That is the *next* structural step (a builder API
  in `native.grl`), and it is not needed for any of the three stages here: the IR starts where the
  stream does.
- It does not type every value: a value whose type the front end did not record is kind 0, and the
  passes must treat that as "word", which is what they do today.
- It does not add a phi node, a rewriter, or a second optimizer. The four passes stay the passes.
