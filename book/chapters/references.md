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
dropping it: use it to move an owned value out of a reference.

A reference always points at a whole word. The elements of `f32[]`, `u32[]` and `i32[]` are stored in
4 bytes each, as are the `f32`/`i32`/`u32` fields of an `extern "C" record`, so they cannot be
borrowed: `&mut v[i]`, `&mut rec.x` and `for x in &mut v` are rejected. Read and assign them in
place instead (`v[i] += 1.0`, `rec.x = 2.0`) or iterate by value or by index. Bytes (`u8[]`) follow
the same rule.

Use a reference when the caller should keep the storage while a function reads or changes it. Use a
by-value parameter when ownership should move to the callee.

The examples use typed `&value` and `&mut value` references for scalars, records and collections.
Use `view(data)` or `view_mut(data)` when an explicit byte view is needed instead of a reference
to the owner itself.

**Try it:** print `before` and observe that exchange returns the old value, not the replacement.
