# Typed references and exchange

`&value` refers to storage and `&mut value` grants mutable access. Mutable access is always written
explicitly: a read-only borrow never silently becomes writable. Every elided input reference gets a
fresh lifetime; an elided output follows the receiver or the sole input, and otherwise names its
groups with `&a`/`&b` (see [Lifetimes](lifetimes.html)). Local references infer their lifetime.
Numeric references do not require a heap allocation for the referent.

{{example:references}}

`exchange(reference,new_value)` replaces the stored value and returns the old one. It does not
silently drop an old owned result: that result becomes another value with its own cleanup path.
`load` can copy a scalar through a reference. It cannot generally copy an arbitrary owner or an
exclusive view. Read-only view descriptor copying retains checked provenance.

Use a reference when the caller should keep the storage while a function reads or changes it. Use a
by-value parameter when ownership should move to the callee.

The examples use typed `&value` and `&mut value` references for scalars, records and collections.
Use `view(data)` or `view_mut(data)` when an explicit byte view is needed instead of a reference
to the owner itself.

**Try it:** print `before` and observe that exchange returns the old value, not the replacement.
