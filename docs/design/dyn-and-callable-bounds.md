# `dyn` bounds and callable bounds on generics (proposals)

Status: proposals for the director (gaps12-closures, after ca78eba). Nothing here is built. Probes are
in `docs/design/dyn-callable-probes/`; **[P dN]** is a probe there, **[V]** read in the code, **[A]**
assumed.

## 1. `dyn` bounds

**Cases first - what crosses or outlives today** (all on this branch):

| Program | Today | Verdict |
|---|---|---|
| `dyn Peek` (over plain data) as a `parallel_map` item [P d2] | refused: "no capability proof for the type parameter" | sound, but the message is wrong and there is no way to say it is fine |
| `dyn Peek` as a task item [P d6], into `T: Send` [P d4] | refused, same text | same |
| `dyn Peek` into `T: Owned` [P d3] | accepted | sound: boxing refuses borrowed data [V `dyn_box`] |
| `dyn` over a record holding a borrow [closure-bounds P26] | refused at boxing | sound |
| `dyn` over a record whose `Fn` field holds a borrow [P27] | refused at boxing since stage 3 | sound (was a hole) |
| `&dyn Peek` stored in a `Hold<a>`, then the referent moved [P d5] | refused: the loan is kept | sound |
| `dyn` over a thread-affine handle, used locally [P d7] | accepted | sound (it cannot cross: default-deny) |

So there is **no `dyn` hole** today: `transfer_capability` denies kind 33 for both questions
[V native.grl, "nor does an interface object"] and `dyn_box` refuses borrowed data. What is missing
is expressiveness: no `dyn` value can ever cross a thread, and none can hold a borrow.

**Proposal** (mirrors `Fn<..>`):

- Spelling: `dyn<Send> I`, `dyn<Share> I`, `dyn<Send, Share> I`, `dyn<s> I`; with associated types
  `dyn<Send> Iterator<Item = u64>`. The list is parsed by `closure_bounds_list` (one spelling).
  `Owned` is the default and is not written: a bare `dyn I` holds no borrow (today's rule); `dyn<s> I`
  may hold borrows from `s` (the record's regions must all be `s`).
- Coercion (boxing a concrete `T`, or `&T` to `&dyn<..> I`): `T: I`, and `T` meets every stated bound
  (`transfer_capability(T, 0/1)`, or every region of `T` is `s`). `dyn<B> I` converts to `dyn<B'> I`
  when `B'` drops bounds (same cell and vtable); never the reverse.
- Classification: `dyn<Send> I` is `Send`, `dyn<Share> I` is `Share`; a bare `dyn I` stays neither,
  with the message "an interface object whose type does not say it is Send (write `dyn<Send> I`)"
  instead of today's type-parameter text.
- Representation: bits 2/4 of kind 33's `mode`, the region in `regions`, compared by `same_type`,
  written in the interface row (format 7). `fmt` already keeps the angle list on one line.
- **Breakage: zero.** `lib/`, `abundance/` and `borg/` have no `dyn` at all; 33 corpus cases use it
  and every bare `dyn I` keeps its meaning. The only visible change is the better message.
- Cases to add: accepted - `dyn<Send> Peek` as a `parallel_map` item, a task item, a `T: Send`
  argument, `dyn<Send, Share> Peek` behind `&` shared by workers, `dyn<s> Peek` over `View<s>` kept in
  a `Hold<s>`; refused - boxing a handle-holding record as `dyn<Send>`, a borrowed record as bare
  `dyn`, `dyn<s>` returned past `s`, `dyn I` to `dyn<Send> I`.

## 2. Callable bounds on generics

**Measured first** (`iter_chain.grl` / `.rs`, 10M `u64`, map `x*2` -> filter `%3 == 0` -> sum, best
of five, machine loaded by the gate):

| | Grail (native) | Rust `-O` |
|---|---|---|
| iterator chain | **1832 ms** | 7.2 ms |
| hand-written loop | 16 ms | 7.1 ms |
| the same loop calling two `Fn` callbacks | 34 ms | 5.4 ms (`&dyn Fn`, not inlined) |

`split.grl` takes the chain apart: copying the vector 33 ms; `iter::of(v).fold(..)` alone **998 ms**;
adding `map` 1638 ms; adding `filter` 1254 ms. So the indirect call costs about 2x (34 vs 16), but the
chain costs 114x because of the *shape of `Iter<T>`*: every element is a call through the boxed
`step` closure returning `T?`, and `of` first reverses the vector by popping and pushing. Callable
bounds alone fix the 2x; the 114x needs the adapters to be types. Both are proposed together.

**Proposal.**

- Bound: `F: FnMut(T) -> U` (also `Fn`, and with bounds `F: FnMut<Send>(T) -> U`) in a generic list,
  parsed by the closure-type grammar. In the body, a value of type `F` is callable with that signature
  and call mode (`f(x)`; today `unknown function f` [closure-bounds P07]); `F: Send`/`Share`/`Owned`
  are the existing structural bounds on its environment.
- Naming and specialisation: a closure expression's type is already unique (its environment record
  `.closure::ClosureN` is part of the interned type [V Ty.env]), and generic functions already
  specialise per type, so `F` bound to it is one specialisation per closure literal and the call
  `f(x)` is emitted as a **direct call to that closure's body symbol**, with the environment pointer
  as its hidden argument. The optimiser can then inline it like any small direct call. A named `fn`
  passed for `F` gets a zero-capture closure type of its own (one per function), so it is direct too.
- Adapters as types: `struct Map<I, F> { it: I, f: F }`, `Filter<I, F>`, `VecIter<T>` (index-based,
  no reversal) implementing the existing `Iterator` interface (`type Item`) [V lib/iter.grl:13], with
  `fn map<U, F: FnMut(Self::Item) -> U>(self, f: F) -> Map<Self, F>`. A chain is then one nested type,
  fully specialised; `fold`/`sum` are generic over `I: Iterator`. `iter::Iter<T>` stays as the erased
  form (`from_fn`, `dyn Iterator`, storing an iterator in a field), with today's `FnMut<Owned>`
  signatures.
- Bounds and borrows: `F` is a type parameter holding whatever the closure captured; `Map<I, F>` with
  a borrowing `F` is not `Owned` (`owned_walk` already walks into the environment), so the Q8 rule
  holds unchanged: hidden borrows travel by loan flow and cannot cross a lifetime boundary.
- S6 (`/root/call_abi`, `{code, env}` closures with frame environments, boxed on escape): compatible
  and complementary. S6 makes the *erased* call cheap (+458 -> ~+20 per call); callable bounds remove
  the call. A closure bound to `F` and stored in `Map<I, F>` is an inline field, so it needs records
  embedded by value (unboxed stage 3a) to avoid one box per adapter; until then each adapter is one
  allocation per chain, not per element.
- Compile cost: one specialisation per (generic function, closure literal) pair, as in Rust. Proxy
  for the size: callback call sites are 2 in `lib/`, 2 in `abundance/`, 2 in `borg/`, 12 in
  `compiler/` and 41 across the corpus [counted with `rg`], so the specialisations added are in the
  tens, not thousands. Measure compile time on the compiler itself once `vecs` moves.
- First to move (call-scoped, no storage, so no adapter types needed): the `vecs` methods `map`,
  `filter`, `filter_map`, `fold`, `reduce`, `any`, `all`, `count`, `find`, `position`, `sort_by`,
  `sort_by_key`, `min_by_key`, `max_by_key`; then `strings` callbacks (`split`, `join` with a
  function); then the `iter` adapters as types with `VecIter`. Target for the benchmark: the chain
  within 1.2x of the hand loop, and the hand loop itself is the backend's distance to Rust (16 vs 7 ms,
  a separate item).
- Cases first: `F: FnMut(u64) -> u64` called in a generic body (accepted); a closure for `F` whose
  type does not match the bound (refused); `F: Send` with a handle capture (refused, as P06);
  `Map<I, F>` over `refs(&v)` moved into a job (refused, Q8 rule); an `asm` check that `vecs::map` with
  a literal closure has no indirect call.

## 3. Step 2a, built: no per-element waste outside the `T?`

`parts.grl`, 10M `u64`, load average about 45 (numbers are noisy; ratios hold):

| | before | after |
|---|---|---|
| `iter::of(mk(n))` (building the vector included) | 633 ms (2142 ms with the first in-place reverse) | 114 ms |
| `.fold(..)` alone | 709 ms | 973 ms (noise: the pop loop itself went 543 -> 601) |
| plain `while let Some(x) = v.pop()` | 543 ms | 601 ms |

- `of` reversed the vector by popping and pushing every element: one `T?` allocated per element on
  top of the one `next` returns. It now reverses in place. The `vecs` methods had the same loop twice
  over (two options per element); they now reverse in place and take with `pop()!`, which builds no
  option.
- `v.reverse()` was a call to the bounds-checked `rt_vec_swap` and an `rt_div` per pair; it is a
  two-pointer loop.
- What remains is **the `T?` itself**: `v.pop()` and every `Iter.next` build `Some(x)` with
  `rt_enum`, a 16-byte heap record allocated and freed per element. A plain pop loop costs about 55 ns
  per element, and `fold` over an `Iter` is that plus one closure call. No library change removes
  it; an unboxed `T?` for word-sized `T` (tag and payload in two registers, unboxed stage 3) does.
  Until then the erased `Iter` cannot get near the hand loop, which is the case for 2b/2c.

## 4. Step 2b, built: callable bounds and direct closure calls

- **Bound.** `F: FnMut(T) -> U` (or `Fn`, with closure bounds) in a generic list. It travels in the
  parameter's requirement set as a tagged entry (`CALLABLE_BOUND + type`), so templates, interfaces
  (an empty interface name followed by the type) and specialisation carry it with no new field. It is
  read when the whole parameter scope exists (`resolve_callable_bounds`), because a method's bound
  names its impl's `T`.
- **Body.** A parameter's type carries its bound among its proofs; a local of that type, or of the
  specialisation's alias of it, is called through `param_callable`: with the bound's signature in a
  template, and in a specialisation with the closure's own environment plus the bound's signature as
  the body sees it (`T`, `U` bindings), so the call is direct and the types line up.
- **Call site.** The bound's parameters and result are inferred from the closure (`infer_callable`)
  and hint an untyped closure's parameters; the closure must convert to the bound
  (`require_interfaces`), else "this argument does not meet the callable bound".
- **Direct calls.** `indirect_call` emits `call <closure body>` whenever the callee's type is a
  closure expression's own type (it has an environment) - for local closures too.
- **Specialisation key.** A closure's environment was keyed by its captures only, so two closures with
  one signature and no captures were one specialisation - harmless while the call went through the
  code word, a miscompile once it is direct (found by `vecs-fold-and-predicates`). The key now names
  the closure literal (file and position).
- **Loans.** A closure given for a callable-bound parameter without `Owned` is lent for the call: it
  neither makes the type arguments "borrowing" nor binds its loans to the result (`captured_bonds`).
- **Moved first.** The 16 `vecs` callback methods. Measured below once the before/after pair is run.

## 5. Step 2c, built: typed adapters - and where the 1.2x stands

`lib/iter.grl`: `VecIter<T>` (a vector reversed once in place, popped), `Map<I, U, F>` (the item type
`U` is a parameter so the next adapter's callback is typed by it - there is no projection syntax for
`<Map<..> as Iterator>::Item`), `Filter<I, F>` (item `I::Item`), each with `next`, `map`, `filter` and
`fold`, plus `fold_all<I: Iterator, A, F: FnMut(A, I::Item) -> A>`. Compiler fixes it needed: callable
bounds on impl parameters are read right after the impl's generic list (before its own type, so
`Self` and fields carry the bound); impl matching treats a callable entry as a bound to meet (and
infers parameters only it names, `U`); a callable parameter forwarded to another callable-bound
parameter is checked by its own bound, without specialisation aliases; interface records skip the
tag in dependency lists.

`lb.grl` (10M `u64`, map `x*2` -> filter `%3 == 0` -> sum, best of five, load about 30-50):

| | native | `--release` (LLVM -O2) | Rust -O |
|---|---|---|---|
| typed chain (`iter::over`) | 432-529 ms | 158 ms | 6.9 ms (chain) |
| hand loop | 20-28 ms | 21 ms | 6.6 ms |
| erased `Iter` chain | 711-779 ms | 1090 ms | - |

No allocation remains per element (inline `T?` from unboxed 5a covers the adapters' options; the
asm has no `rt_enum`). **What the 1.2x still needs is inlining:** per element the native build makes
about ten calls - three nested `next`s, two closure bodies, the out-of-line `core::some`, and empty
drop helpers - none inlined, because the native optimiser inlines leaves only; the LLVM build
inlines part of it (7.5x). The remaining work is in the optimiser (inline small non-leaf direct
calls, drop the empty drop helpers, make `Some` an intrinsic), not in the library or the type system.

### 5.1 The inherent hop removed

Each adapter's `next` was written once (`vec_next`, `map_next`, `filter_next`) and reached from both
the `Iterator` impl and the inherent `next` a `for` loop uses: one forwarding call per adapter per
element. The body now sits in both. Same benchmark: native 374 ms (was 432-529), `--release`
72 ms (was 158) against a 17 ms hand loop - 4.2x. Still to do: VecIter as an index walk (needs a
"move element i out" primitive and a remainder drop; `rt_pop` is a call per element today), and
S6(A) (the closure held inline).
