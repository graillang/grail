# Ownership, borrowing and lifetimes

Owned buffers, strings, records, enums and vectors have one cleanup responsibility. Assigning
an owned value to a new binding or passing it by value moves that responsibility. There is no
implicit deep copy of a byte buffer.

{{example:moves}}

The caller gives `moved` to `consume`; the callee releases it on exit. The original name cannot
be used after its move, even though the underlying object still exists under a new owner.

{{example:moved-value}}

This is an intentional compile error. To keep data usable in two places, take a shared borrow
with `&owner` (or `owner[a..b]` for part of it),
or request an explicit copy such as `data.copy()` when a separate buffer is really wanted.

**Try it:** repair the rejected example by printing `moved.len()` instead.

## Borrowing and last use

A shared borrow allows reads while excluding conflicting mutation, growth and movement of its
source. Use `&owner` for a shared reference, or `owner[a..b]` for a view of part of it.
The compiler can end a borrow at its last use, not only at the closing brace.

{{example:borrows}}

The reader has ended before `push`. Now compare a program where the reader is used afterward:

{{example:borrow-conflict}}

Reallocation could invalidate a live view, so the compiler rejects this ordering. Move the read
before the mutation, end the view, or create a fresh view after the mutation.

Last-use analysis respects shadows and loop backedges, but remains conservative. In particular,
opaque returned references may keep whole possible input frames borrowed rather than identifying
one exact field.

### Arguments that read what another argument borrows

A call's `&mut x` argument is borrowed after the call's other arguments are evaluated (Rust's
two-phase borrows), so those arguments may still read `x`:

```grl
bump(&mut c, c.pos);
c.bump(c.pos);
v.push(v.len());
```

The value read is copied before the borrow starts. Any plain path works there, including one that
computes (`bump(&mut c, c.pos + 1)`) or a call that only reads (`bump(&mut c, peek(&mut c))`). A
borrow that lives through the call is still a conflict: `take(&mut c, &c.pos)` is refused.

`exchange(&mut place, value)` is two-phase the same way, so its value argument may read the place:
`x := exchange(&mut p, p + 1)` stores the old `p` plus one, returns the old `p`, and needs no
temporary. The place itself as the value is refused, because the write would discard what the
argument named: `exchange(&mut a, a)` and `exchange(&mut a, &mut a)` are errors.

One shape is not covered, and there the value must reach the call in a local: a read through a
borrowed vector element (`c.rows[i].field`, where `Row` is a record) is a loan of that element
rather than a copy.

### Borrowing a temporary

`&expression` keeps a temporary alive until the end of the enclosing block, like a hidden
binding, so the reference can outlive its statement but never its block:

{{example:borrow-temporary}}

References work uniformly for records, vectors, scalars and byte buffers.

**Try it:** reorder the last two operations in the rejected example without changing the owner.

## Typed references and exchange

`&value` refers to storage and `&mut value` grants mutable access. Mutable access is always written
explicitly: a read-only borrow never silently becomes writable. The other direction is free: a
`&mut T` passes where a function takes `&T`, as a shared reborrow for the call. Every elided input reference gets a
fresh lifetime; an elided output follows the receiver or the sole input, and otherwise names its
groups with `&a`/`&b` (see *Lifetimes describe relationships* below). Local references infer their lifetime.
Numeric references do not require a heap allocation for the referent.

{{example:references}}

`*r` reads through a reference and `*r = v` (or `*r += v`) writes through a `&mut` one. Reading
copies, so it works for numbers, bools, floats and other plain values; copying an owner out of a
reference is rejected ("use exchange"), and an exclusive view cannot be copied either. Read-only
view descriptor copying retains checked provenance. `*r = v` drops the old value.

A comparison reads through a reference to a plain value by itself: with `n: &u64`, `n > 4`,
`4 < n` and `n == m` (where `m` is a `u64`, a `&u64` or a `&&u64`) compare the numbers, so a
predicate such as `filter(|n| n > 4)` needs no `*`. Arithmetic does the same, as in Rust: `n + 1`,
`map(|x| x * 2)` and `i + x` in `for (i, x) in xs.iter().enumerate()` read the number, and the result
is a plain value. This holds for integers, floats, bools and chars. Assignment through a reference
still names it: `*n += 1`. Text compares through a reference as well; records and vectors compare as
values only.

`exchange(reference, new_value)` replaces the stored value and returns the old one instead of
dropping it: use it to move an owned value out of a reference. Its value argument is read before
the swap, so `x := exchange(&mut p, p + 1)` leaves the old `p` in `x`; naming the place itself as
the value, `exchange(&mut a, a)`, is refused.

Any element or field can be borrowed, whatever its size: `&mut v[i]` for an `f32[]`, `u32[]`,
`i32[]` or byte vector, `for x in &mut v`, and `&mut rec.x` for a narrow field of an
`extern "C" record`. A reference to an 8-, 16- or 32-bit value works the same whether it points at a
local, a record field or packed vector storage.

Use a reference when the caller should keep the storage while a function reads or changes it. Use a
by-value parameter when ownership should move to the callee.

`&value` and `&mut value` work the same way for scalars, records, collections and individual
elements, including a single byte of a `u8[]` or one `f32` inside an `f32[]`.

**Try it:** print `before` and observe that exchange returns the old value, not the replacement.

## Lifetimes describe relationships

A lifetime is an inferred relationship between references, not a list you declare on a function.
Every elided input reference gets its own fresh lifetime. `&a T` and `&a mut T` name those
relationships when one shared name is not the contract you want; `a` is bound by the signature, so
there is no `<a>` parameter list. A read-only byte view is `&[u8]`; its mutable counterpart is
`&mut [u8]`.

An elided output reference uses the receiver's lifetime for a method, and otherwise the lifetime of
the sole input reference. When more than one input could flow to the result, write the relationship
out:

```grl
fn relay(value: &[u8]) -> &[u8] {
    value
} // sole input supplies the output
fn choose(left: &a [u8], right: &b [u8]) -> &a [u8] {
    left
} // two groups, one output
```

{{example:lifetimes}}

The relay can return its input view, and its caller still owns `data`. A signature cannot smuggle a
view of a local allocation out of a function:

{{example:escaping-local}}

Changing the lifetime name does not repair this error. Return the owned buffer instead, or borrow
storage supplied by the caller.

Stored references are part of a nominal type, so struct and enum declarations still name the
lifetimes they store: `struct Cursor<a> { source: &a [u8] }`. Function and method signatures do not.

A lifetime name is not a heap allocation, a target identity, or a request to extend a value's life.
Distinct mutable inputs remain distinct abstract targets even if they use one lifetime label.
Returned borrows conservatively retain compatible input origins; this is deliberately more
restrictive than guessing which projection an opaque function returned.

**Try it:** change `wrong` to return `u8[]` and move `local` out.

## Replacing values that contain borrows

References and views can live inside other values. Replacing such a value must update its
storage's retained origins, not just exchange a machine word.

{{example:writeback}}

The generic function replaces a stored shared reference and returns the previous one. `&mut current`
borrows the binding's own slot, so the callee may change which vector `current` names but never writes
through the old reference. The caller retains both underlying byte owners for as long as the
corresponding values require them.
Incoming borrows cannot be shorter-lived than the contract of external storage.

Assignments, exchange, and captured vector updates propagate guards across calls. Weak updates
can retain old guards longer than strictly necessary, and opaque local-frame writes require a
retained owner witness. Opaque external writes without a recoverable invariant contract are
rejected rather than accepted on the strength of an erased lifetime label.

The mutable argument is `&mut current`: a typed reference to the stored view. `first[..]` and
`second[..]` create the views that are exchanged through it.

**Try it:** add `second.push(3)` before reading `current`. The live stored view should prevent it.
