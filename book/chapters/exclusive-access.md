# Exclusive views and reborrowing

`mut(data)` grants exclusive byte access. `write(view,index,byte)` writes through that access.
A readonly child can temporarily suspend its exclusive parent; the parent's access resumes after
the child's last use.

{{example:mutable-views}}

This is a reborrow, not an independent second exclusive permission. You cannot write through
`writer` while its readonly child is still used later. Nor can you create unrelated mutable
views of the same live storage and treat them as disjoint.

`mut(data)` produces a byte view. It is not the same operation as `borrow_mut(value)`, which
produces a typed reference to a value's storage. The next chapter shows that distinction.

**Try it:** move the assertion using `reader` below the `write`. The compiler should reject it.
