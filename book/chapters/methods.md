# Methods

`impl Type { ... }` attaches functions to a struct or enum. A function whose first parameter is the
type itself (or a reference to it) is a method and is called with `value.name(...)`; others are
called through the type, like `Counter::new(...)`.

{{example:methods}}

The receiver parameter says how the method uses the value: `&Counter` reads it,
`&mut Counter` changes it (so `visits` must be declared `mut`), and `Counter` takes
ownership. Grail borrows the receiver automatically, just as Rust does for `&self` and
`&mut self`. `format` builds a `string` with `{}` placeholders, `for day in 1..4` counts 1, 2, 3,
and `else if` chains conditions.

Methods also work on generic types: `impl<T> Stack<T> { ... }`.

**Try it:** remove `mut` from `visits` and read the compiler's message.
