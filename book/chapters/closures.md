# Closures

A closure is a function written inline that can use values from where it was created.
`|x: u64| -> u64 x + offset` takes a `u64`, returns a `u64`, and captures `offset`.

{{example:closures}}

Closures have the type `Fn(params) -> result`, so they can be passed to and returned from
functions. Numbers and other plain values are copied into the closure; owned values such as the
text in `words` are moved into it, and the original name can no longer be used. Inside the body,
captured values are read-only. A closure is called like a function and can be called many times;
when it goes out of scope, the values it captured are cleaned up with it.

Mutating captured state is rejected: captures are read-only inside the body. Closures work inside
generic functions; the checker keeps their captures affine like other values.

## Capturing a borrowed value

A closure may also capture a reference or view — `&T`, `&[T]`, `&[u8]`, `&mut T` — and that is how
a closure reads something that lives outside the value it is given. The reference moves into the
closure, pointer and loan together, so the name it moved from cannot be used afterwards, and the
closure may not outlive what it borrows: returning it, or storing it somewhere the borrow does not
reach, is rejected.

```grl
groups := &b.groups;
vecs::sort_by(&mut order, |x: &u64, y: &u64| -> bool {
    gx := &groups[*x];
    gy := &groups[*y];
    return gx.depth > gy.depth;
});
```

A struct or enum that merely holds a borrow is not captured (its layout and cleanup are its own):
bind the reference itself, or reach the value through one.

## Sorting with a closure

A closure's parameters may be references, borrowed afresh on each call, so a closure works as a
comparator. `vecs::sort_by` sorts stably: elements that compare equal keep their order.

{{example:sorting}}

Any function with a matching signature can be passed where an `Fn` is expected, so
`vecs::sort_by(&mut tasks, by_priority)` works too. `vecs::sort_by_key` sorts by a computed `u64`
key, and `vecs::insert_sorted` / `vecs::binary_search` keep a vector as a sorted set.

**Try it:** use `words` again after creating `length` and read the compiler's message.
