# Ownership and moves

Owned buffers, strings, records, enums and vectors have one cleanup responsibility. Assigning
an owned value to a new binding or passing it by value moves that responsibility. There is no
implicit deep copy of a byte buffer.

{{example:moves}}

The caller gives `moved` to `consume`; the callee releases it on exit. The original name cannot
be used after its move, even though the underlying object still exists under a new owner.

{{example:moved-value}}

This is an intentional compile error. To keep data usable in two places, take a shared borrow
(`&data` for a byte buffer, or `borrow(owner)` for the owners this preview does not borrow with `&`),
or request an explicit copy such as `data.copy()` when a separate buffer is really wanted.

**Try it:** repair the rejected example by printing `moved.len()` instead.
