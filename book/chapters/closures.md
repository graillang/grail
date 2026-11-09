# Closures

A closure is a function written inline that can use values from where it was created.
`|x: u64| -> u64 x + offset` takes a `u64`, returns a `u64`, and captures `offset`.

{{example:closures}}

Closures have the type `Fn(params) -> result`, so they can be passed to and returned from
functions. Numbers and other plain values are copied into the closure; owned values such as the
text in `words` are moved into it, and the original name can no longer be used. Inside the body,
captured values are read-only. A closure is called like a function and can be called many times;
when it goes out of scope, the values it captured are cleaned up with it.

Grail closures always own their captures, like Rust's `move` closures. Capturing a borrowed reference and mutating captured state are rejected. Closures work inside generic functions; the checker keeps their captures affine like other values.

## Sorting with a closure

A closure's parameters may be references, borrowed afresh on each call, so a closure works as a
comparator. `vecs::sort_by` sorts stably: elements that compare equal keep their order.

{{example:sorting}}

Any function with a matching signature can be passed where an `Fn` is expected, so
`vecs::sort_by(&mut tasks, by_priority)` works too. `vecs::sort_by_key` sorts by a computed `u64`
key, and `vecs::insert_sorted` / `vecs::binary_search` keep a vector as a sorted set.

**Try it:** use `words` again after creating `length` and read the compiler's message.
