# Typed references and exchange

`&value` refers to storage and `&mut value` grants mutable access. Mutable access is always written
explicitly: a read-only borrow never silently becomes writable. Every elided input reference gets a
fresh lifetime; an elided output follows the receiver or the sole input, and otherwise names its
groups with `&a`/`&b` (see [Lifetimes](lifetimes.html)). Local references infer their lifetime.
Numeric references do not require a heap allocation for the referent.

{{example:references}}

`*r` reads through a reference and `*r = v` (or `*r += v`) writes through a `&mut` one. Reading
copies, so it works for numbers, bools, floats and other plain values; copying an owner out of a
reference is rejected ("use exchange"), and an exclusive view cannot be copied either. Read-only
view descriptor copying retains checked provenance. `*r = v` drops the old value.

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
