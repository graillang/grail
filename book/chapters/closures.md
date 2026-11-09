# Closures

A closure is a function written inline that can use values from where it was created.
`|x: u64| -> u64 x + offset` takes a `u64`, returns a `u64`, and captures `offset`.

{{example:closures}}

Closures have the type `Fn(params) -> result`, so they can be passed to and returned from
functions. Numbers and other plain values are copied into the closure; owned values such as the
text in `words` are moved into it, and the original name can no longer be used. Inside the body,
captured values are read-only. A closure is called like a function and can be called many times;
when it goes out of scope, the values it captured are cleaned up with it.

Grail closures always own their captures, like Rust's `move` closures. Capturing a borrowed reference and mutating captured state are rejected. Closures work inside generic functions; the checker keeps their captures affine like other values. A closure's parameters may be references (`|a: &Group, b: &Group| -> bool a.depth > b.depth`), borrowed afresh on each call, so a closure can be a comparator for `vecs::sort_by`. Any function with a matching signature can also be passed where an `Fn` is expected.

**Try it:** use `words` again after creating `length` and read the compiler's message.
