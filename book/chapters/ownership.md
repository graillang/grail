# Ownership and moves

Owned buffers, strings, records, enums and vectors have one cleanup responsibility. Assigning
an owned value to a new binding or passing it by value moves that responsibility. There is no
implicit deep copy of a byte buffer.

{{example:moves}}

The caller gives `moved` to `consume`; the callee releases it on exit. The original name cannot
be used after its move, even though the underlying object still exists under a new owner.

{{example:moved-value}}

This is an intentional compile error. To keep data usable in two places, borrow it, or request an
explicit copy such as `copy_bytes(read(data))` when a separate buffer is really wanted.

**Try it:** repair the rejected example by printing `len(moved)` instead.
