# Closures

A closure is a function written inline that can use values from where it was created.
`|x: num| -> num x + offset` takes a `num`, returns a `num`, and captures `offset`.

{{example:closures}}

Closures have the type `Fn(params) -> result`, so they can be passed to and returned from
functions. Numbers and other plain values are copied into the closure; owned values such as the
text in `words` are moved into it, and the original name can no longer be used. Inside the body,
captured values are read-only. A closure is called like a function and can be called many times;
when it goes out of scope, the values it captured are cleaned up with it.

Grail closures always own their captures, like Rust's `move` closures. Capturing a borrowed
reference, mutating captured state and closures inside generic functions are not supported yet.

**Try it:** use `words` again after creating `length` and read the compiler's message.
