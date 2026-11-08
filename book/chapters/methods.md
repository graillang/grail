# Methods

`impl Type { ... }` attaches functions to a struct or enum. A function whose first parameter is the
type itself (or a reference to it) is a method and is called with `value.name(...)`; others are
called through the type, like `Counter::new(...)`. Record literals can use field punning:
`Counter { name, count: 0 }` names the `name` field once and takes its value from the variable in
scope.

{{example:methods}}

The receiver parameter says how the method uses the value: `&Counter` reads it,
`&mut Counter` changes it (so `visits` must be declared `mut`), and `Counter` takes
ownership. Both languages borrow the receiver automatically at the call site, and mutable access
stays explicit in the signature. An elided result reference follows the receiver's lifetime. `format`
builds a `string` with `{}` placeholders, `for day in 1..4` counts 1, 2, 3, and `else if` chains
conditions.

Methods also work on generic types: `impl<T> Stack<T> { ... }`.

**Try it:** remove `mut` from `visits` and read the compiler's message.
