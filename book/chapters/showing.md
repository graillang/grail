# Printing your own types

A record prints without any help: `println(p)` writes its name and fields in declaration order,
`Point { x: 3, name: "a" }`, with text in quotes and nested records and vectors inside; a tuple
prints as `(3, "a")`. That form is for looking at a value. To choose the text - or to print an enum,
which has no default form - give the type a `show` method that returns a `string`, and `println`,
`print` and `format` use it wherever the value appears.

{{example:showing}}

`show` takes `self` by shared reference and builds text with `format`. Rust gets the same effect by
implementing the `Display` trait. Module-level `const` values (`ORIGIN_NAME`, `LIMIT`) are fixed at
compile time and can be integers, `bool` or text. `'G'` is a byte character literal: it is the
number 71, like Rust's `b'G'`.

**Try it:** make `show` print `Point(3, -4)` instead of `(3, -4)`.
