# Borrowing and last use

A shared borrow allows reads while excluding conflicting mutation, growth and movement of its
source. Use `&owner` for a shared reference, or `owner[a: b]` for a view of part of it.
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

`&expression` keeps a temporary alive until the end of the enclosing block, like a hidden
binding, so the reference can outlive its statement but never its block:

{{example:borrow-temporary}}

References work uniformly for records, vectors, scalars and byte buffers.

**Try it:** reorder the last two operations in the rejected example without changing the owner.
