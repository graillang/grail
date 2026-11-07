# Lifetimes describe relationships

Lifetime parameters are bare names in angle brackets. In a signature, `read<a>` says the view
is tied to input lifetime `a`. A lifetime name is not a heap allocation, a target identity, or a
request to extend a value's life.

{{example:lifetimes}}

The relay can return its input view. Its caller still has to retain the concrete owner. This
cannot be used to smuggle a view of a local allocation out of a function:

{{example:escaping-local}}

Changing a lifetime name does not repair this error. Return the owned buffer instead, or borrow
storage supplied by the caller.

Distinct mutable inputs remain distinct abstract targets even if they use one lifetime label.
Returned borrows conservatively retain compatible input origins; this is deliberately more
restrictive than guessing which projection an opaque function returned.

**Try it:** change `wrong` to return `u8[]` and move `local` out.
