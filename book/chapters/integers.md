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

For fractions, use `f64`. Literals need a decimal point or an exponent (`2.0`, `1e9`), and mixing `f64` with integers
requires a conversion such as `f64(values.len())`. Results print with the fewest digits that
identify the value exactly, which is why `0.1 + 0.2` shows its rounding error.

{{example:floats}}

`f32` is the single-precision float: write `0.5f32`, or let an `f32` context adopt a plain literal
(`ratio: f32 := 0.1`). Every result is rounded to `f32`, and printing shows the shortest digits
that read back as the same `f32`. `f32(x)` converts from integers or `f64`; `f64(r)` widens exactly.

`char` is a Unicode scalar value. `'ï'` is a `char`; an ASCII literal such as `'g'` is a byte value
(like Rust's `b'g'`) unless a `char` context adopts it. Text's `chars()` decodes UTF-8 into a
`vec<char>`, `push_char` appends one, and characters compare with `<`/`==`, convert with `u32(c)`
and the checked `char(n)`, and offer `is_alphabetic`, `is_whitespace`, `to_uppercase` and similar
methods. Case mapping covers Latin-1, Latin Extended-A, Greek and Cyrillic.

{{example:chars-f32}}

**Try it:** change `small + 55` to `small + 56` and run it again.
