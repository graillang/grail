# Borrowing and last use

A shared borrow allows reads while excluding conflicting mutation, growth and movement of its
source. Borrow a byte buffer with `&data`; other owners still use `borrow(owner)` in this preview.
The compiler can end a borrow at its last use, not only at the closing brace.

{{example:borrows}}

The reader has ended before `push`. Now compare a program where the reader is used afterward:

{{example:borrow-conflict}}

Reallocation could invalidate a live view, so the compiler rejects this ordering. Move the read
before the mutation, end the view, or create a fresh view after the mutation.

Last-use analysis respects shadows and loop backedges, but remains conservative. In particular,
opaque returned references may keep whole possible input frames borrowed rather than identifying
one exact field.

## Borrowing a temporary

`borrow(expression)` keeps a temporary alive until the end of the enclosing block, like a hidden
binding, so the reference can outlive its statement but never its block:

{{example:borrow-temporary}}

The approved model spells this `&expression`. For records, vectors and scalars the preview compiler
still requires `borrow`; the byte-buffer form `&data` is already accepted.

**Try it:** reorder the last two operations in the rejected example without changing the owner.
