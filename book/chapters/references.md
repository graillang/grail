# Typed references and exchange

`borrow(value)` refers to storage as `ref<a,T>`; `borrow_mut(value)` grants mutable storage
access as `ref_mut<a,T>`. Local references infer their lifetime. Numeric references do not require
a heap allocation for the referent.

{{example:references}}

`exchange(reference,new_value)` replaces the stored value and returns the old one. It does not
silently drop an old owned result: that result becomes another value with its own cleanup path.
`load` can copy a scalar through a reference. It cannot generally copy an arbitrary owner or an
exclusive view. Readonly view descriptor copying retains checked provenance.

Use a reference when the caller should keep the storage while a function reads or changes it.
Use a by-value parameter when ownership should move to the callee.

**Try it:** print `before` and observe that exchange returns the old value, not the replacement.
