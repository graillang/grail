# Views and slices

`&owner` creates a readonly view over a byte sequence, and `&[u8]` is the parameter type for such a
view; `&[T]` is the same for any element type. The view has a descriptor but does not own the underlying byte buffer; it retains a checked
relationship to its owner. `view[start:end]` uses a half-open range: start is included and end is
excluded.

`owner[index]` reads a byte directly; indexing borrows its source readonly for the access.
`owner[start:end]` creates a readonly borrowed view. Omitted bounds default to zero and the source
length: `owner[:end]`, `owner[start:]`, and `owner[:]`. The colon is Grail's spelling of Rust's
half-open `..` range. Bounds and operands are evaluated once, left to right.

{{example:views}}

The slice contains only the middle byte. Bounds are checked at runtime. Slices and views do not make
their source immortal: their existence constrains when the owner may move, grow or end.

Readonly view derivation can copy a descriptor while retaining its provenance. That is different
from copying an owning buffer, and different from duplicating an exclusive view. An owned `string` or
`u8[]` argument is adjusted to a `&[u8]` parameter when the expected type is already known; every
other position writes `&` explicitly.

**Try it:** slice `[0:3]` instead, then return the first byte. Do not read index 3 from that view.

## Ranges that carry their slice

`..` is the half-open range spelling in a loop header, and brackets accept it exactly where the colon
is: `s[a..e]`, `s[a..]`, `s[..e]` and `s[..]` are the same slice as `s[a: e]`, `s[a: ]`, `s[: e]` and
`s[:]`, on vectors, views and strings. One spelling for one idea, and no extra cost: both forms
compile to the same slice.

A range that travels - to a helper, into a comparison, across a boundary - is a `span`:

```grl
use span;
fn opens_with<b, c>(r: span::Span<c>, w: &b [u8]) -> bool {
    r.same_as(w)
}
fn main() {
    stored := u8[1, 2, 3, 4];
    name := u8[2, 3];
    r := span::span_of(&stored, 1, 3); // the range, and the slice it was made from
    assert(r.len() == 2);
    assert(r.same_as(&name));
    assert(opens_with(&r, &name));
    over := span::span_of(&stored, 2, 9); // refused here: `stored` has no index 9
    assert(over.len() == 0);
}
```

The span holds the view it was made from, so its bytes come out of that view and nowhere else: a
range its slice does not have is refused where the span is written (`1..0`, which names no bytes and
slices nothing), and a range from another sequence cannot index this one - `s[r]` is a compile error,
because the span already knows its slice. That is the difference from a bare pair of indices: a pair
can be assembled from two different slices, and a span cannot.

## Slices of any vector

`v[a: b]` works on every vector, not just bytes. A function that takes `&[f32]` reads part of a vector
without copying it, and one that takes `&mut [f32]` changes exactly the elements it was given:

{{example:slices}}

A slice cannot change length, cannot outlive its vector, and while it lives the vector cannot grow or
be written elsewhere; an exclusive slice excludes every other access. These checks happen at compile
time, so passing `&mut samples[2:]` cannot alias a live reader the way a raw pointer and length could.
A slice compares with `==` against any vector or slice of the same element type.

## Exclusive views and reborrowing

`&mut data` grants exclusive access. `writer[index] = byte` writes through it. A readonly child can temporarily suspend its exclusive parent; the parent's
access resumes after the child's last use.

{{example:mutable-views}}

This is a reborrow, not an independent second exclusive permission. You cannot write through
`writer` while its readonly child is still used later. Nor can you create unrelated mutable views of
the same live storage and treat them as disjoint.

Mutable access is never implicit. A function that changes bytes takes `&mut [u8]`, and every caller
writes `&mut`:

```grl
fn fill(data: &mut [u8], value: u8) {
    for i in data.len() {
        data[i] = value;
    }
}
fill(&mut data, 9);
```

**Try it:** move the assertion using `reader` below the write. The compiler should reject it.
