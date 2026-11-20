# Lifetimes describe relationships

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
