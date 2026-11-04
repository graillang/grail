# Numbers and booleans

`num` is Grail's everyday 64-bit unsigned integer. When you need a particular width or negative
numbers, use the sized types `u8`, `u16`, `u32`, `i8`, `i16`, `i32` and `i64` (`u64` and `usize`
are `num`; `isize` is `i64`).

{{example:integers}}

A suffix such as `200u8` or `-12i32` fixes a literal's type; an unsuffixed literal next to a
sized value takes that value's type, and the compiler checks that it fits. There are no implicit
conversions between integer types: `u16(small)` converts and stops the program if the value does
not fit, while `wrapping_u8(300)` deliberately keeps only the low bits. Arithmetic overflow stops
the program unless you compile with `--overflow=wrap`.

Comparisons produce `bool` values (`true`/`false`) that combine with `&&`, `||` and `!`; `&&` and
`||` only evaluate their right side when needed. `&`, `|`, `^`, `<<` and `>>` work on integers, and
`>>` on a signed value keeps its sign.

For fractions, use `f64`. Literals need a decimal point (`2.0`), and mixing `f64` with integers
requires a conversion such as `f64(values.len())`. Results print with the fewest digits that
identify the value exactly, which is why `0.1 + 0.2` shows its rounding error.

{{example:floats}}

**Try it:** change `small + 55` to `small + 56` and run it again.
