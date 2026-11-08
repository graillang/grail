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

> **Preview status.** In the book's `--default-u64` mode a value-level `&expression` still means a
> byte view, so this example reaches scalar storage with `borrow(value)` and `borrow_mut(value)`.
> Byte buffers already use the approved spelling (`&data`, `&mut data`); the approved model writes
> every one of these as `&value` and `&mut value`.

**Try it:** print `before` and observe that exchange returns the old value, not the replacement.
