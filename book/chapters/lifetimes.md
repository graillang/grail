# Lifetimes describe relationships

Lifetimes are inferred relationships, not a list you declare on a function. `&T` and `&mut T`
elide the lifetime; all elided references in one function signature share one inferred lifetime.
`read<a>` names a view lifetime derived from the inputs. `&a T` and `&a mut T` explicitly name
separate lifetime groups when one shared lifetime is not the contract you want:

```grl
fn choose(left: &a num, right: &b num) -> &a num
```

`a` and `b` are implicitly bound by the signature; no `<a, b>` declaration is needed. A lifetime
name is not a heap allocation, a target identity, or a request to extend a value's life.

Stored references are part of a nominal type, so struct and enum declarations still name the
lifetimes they store: `struct Cursor<a> { source: &a T }`. Function and method signatures do not.

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
