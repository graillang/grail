# Range values: a range carries the slice it indexes

A range in Grail is two bare words today. `same(view(stored), 0, name.len(), name)` in
`compiler/optimize.grl` passed the end of one slice as the end of a range over another, and the
compiler aborted on the LSP server's sources (`index 4 out of bounds for length 4`); a defensive
`e > s.len()` guard in the callee stopped the abort without touching the hole. The runtime's
`rt_sites` handshake has the same shape: a word plus fixed offsets into a buffer, with nothing that
ties the offsets to the buffer. This note decides what a range value is so that a range which does
not belong to its slice is refused where it is written.

## What a range value is

Three candidates:

**(a) `Range { start, end }` - two words, Rust's `Range<usize>`.** Free to pass, and exactly the
hole: any caller can hand a helper the width of another slice's tail. Rust is deliberate about this
(`Range<usize>` is not slice-bound; `slice[i]` re-checks the range against the slice on every use)
and its answer works because the check happens at the use. Grail's failures happen *across* a
boundary - a helper's argument list, a runtime handshake - where the pair has already lost every
clue about its origin, and where re-checking is what the deleted guard was doing.

**(b) `Range { start, end, bound }` - three words, `bound` = the length of the slice the range was
made from.** This catches a changed slice (`bound != s.len()`), but not a *different* slice of the
same length, and every use still has to compare `bound` with the slice it is applied to - a second
guard, one field away from the first.

**(c) `Span { base: &[u8], start, end }` - the range holds the slice it was made from.** Chosen.
The span's base carries the pointer and the length, so:

- a range from another slice cannot reach this one: nothing in the language takes a slice and a
  span and splices them together, and the only bytes a span can name come out of `span.bytes()`,
  which slices *its own* base (and is bounds-checked by the language like any other slice);
- a range its slice does not have is refused where the span is made (`span_of`), not where it is
  used, so the abort lands on the line that wrote the wrong end.

We improve on Rust here rather than follow it. Rust's unbound `Range<usize>` is right for an
expression that is checked at its use; it is wrong for a value that travels, which is the shape
that broke this compiler. The cost of carrying the base is two words the caller already holds - the
view's pointer and length - and no allocation: `Span` is a four-word local (view + two ends) built
by a compare and a copy, and the comparison loop is byte-identical to the one it replaces.

## How `s[a..e]` produces a range

`..` is the half-open range spelling in a `for` header today; inside brackets slices are spelled
with `:` (`book/chapters/views.md` calls the colon Grail's spelling of Rust's `..`). This round
makes the two agree: `s[a..e]`, `s[a..]`, `s[..e]` and `s[..]` are accepted in brackets exactly
where `s[a: b]` is, on sequences and on byte views, and lower to the same `rt_slice`/`rt_vslice`
calls - one spelling for a half-open range wherever a reader meets it, and no codegen change.

The bracket form yields the *elements*, not a `Span`: `s[a..e]` is the derivation form, and its
range is inside `s` by construction because `s` supplies the length the bounds are checked against.
A range that has to be *carried* - to a helper, into a comparison, across a runtime handshake - is
made with `span_of(&s, a, e)`:

```grl
r := span_of(&stored, 0, name.len())   // refused here if `stored` is shorter than `name`
if r.same_as(&name) { ... }            // no guard: the span cannot name bytes stored lacks
```

## What `s[r]` requires

`s[r]` with a `Span` is a compile error, not a checked slice: the span already names its slice, so
there is nothing left for `s` to say. The diagnostic points at the two spellings that have a
meaning - `r.bytes()` for the span's own bytes, `s[a: b]` for the slice's - and names the element
type of the sequence being indexed. Accepting `s[r]` with a runtime check would reintroduce the
guard this design deletes, and would let a foreign range compile.

## Composition with `for i in 0..n`

`..` in a loop header stays a **count-only** range: no slice, no bound, no span, and it is not a
value (it cannot be assigned, passed or stored). `for i in 0..v.len()` keeps the bounds-check
elimination it has today (`len_bound_ahead` and `--range-facts` rewrite `v[i]` in such a body to
the unchecked forms), which is why the count form is not folded into `Span`: a count has no slice
to be bound to, and giving every `for` a slice would break those proofs. The shared spelling is
deliberate: `..` means half-open everywhere; what it produces depends on where it is written - a
count in a loop header, elements in brackets, a value in `span_of`.

## Cost

| form | words | allocation |
| --- | --- | --- |
| range as two arguments today | 2 in registers | none |
| `Span` in a helper | 4 in a local (2 of them the view the caller already has) | none |
| `s[a..e]` slice | unchanged (`rt_slice`/`rt_vslice`) | one descriptor, as today |

`s[a..e]` emits the same code as `s[a: b]`; the compiler's own `same` keeps the same loop over the
same bytes. The comparison `r.end - r.start != w.len()` that used to sit behind a guard is now the
first thing `same_as` asks.

## A range in a loop that grows or shrinks the slice

Refused, by the rules that already exist: a `Span` holds a view, so while it is live its vector
cannot grow, be written, or end - the same checks that reject `v.push(4)` while `s := &v[0: 2]`
lives. Nothing new is needed and nothing is re-checked at run time, because the span keeps the
slice's length inside it. The one case that escapes the borrow checker is a span that names no
bytes: `span_of` yields `1..0` for a range its slice does not have, `same_as` answers false, and
`bytes()` stops the program on the language's own slice check rather than reading a neighbour.

## Staged, not in this round

- **Typed slices.** `&[u8]` (a byte view) and `&[T]` (a typed slice) are different types in this
  compiler, so one generic `Span` cannot cover both: a byte-view span covers the comparisons and
  the runtime handshakes this round targets, and a `SpanOf<a, T>` for `&[T]` is the next step.
- **A span that outlives its borrow.** Not needed while the borrow checker pins the slice; if a
  span must cross a boundary where the slice may change, it needs the third word of candidate (b)
  and a re-check at use.
- **The compiler's own copy.** The compiler is built without the standard prelude
  (`tools/native.mjs` lists its sources), so it now lists `lib/core.grl` and says `core::Span`;
  user programs get `Span` from the always-compiled prelude, unqualified.
