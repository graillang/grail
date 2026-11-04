# Printing your own types

Give a struct or enum a `show` method that returns a `string`, and `println`, `print` and
`format` use it wherever the value appears.

{{example:showing}}

`show` takes `self` by shared reference and builds text with `format`. Rust gets the same effect by
implementing the `Display` trait. Module-level `const` values (`ORIGIN_NAME`, `LIMIT`) are fixed at
compile time and can be integers, `bool` or text. `'G'` is a byte character literal: it is the
number 71, like Rust's `b'G'`.

**Try it:** make `show` print `Point(3, -4)` instead of `(3, -4)`.
