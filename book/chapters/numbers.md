# Numbers

`u64` is Grail's everyday integer: an unsigned 64-bit value that counts sizes, indices and bytes.
Arithmetic is checked in every build mode: `+`, `-`, `*` and `**` stop the program on overflow or
underflow, and `/` and `%` stop it on a zero divisor, instead of continuing with a wrong number.
Comparisons produce `bool` values, which combine with `&&`, `||` and `!`.

{{example:numbers}}

When you want arithmetic modulo 2⁶⁴, such as a rolling hash, say so: `wrapping_add`,
`wrapping_sub`, `wrapping_mul` and `wrapping_pow` take two `u64` values, evaluated left to right.

## Updates, division and powers

{{example:operators}}

`+=`, `-=`, `*=`, `/=`, `%=` and `**=` update a number in place with the same checks; the right-hand
side runs once. `/` truncates. `**` binds more tightly than `*` and groups right to left, and
`0 ** 0 == 1`. `^` is bitwise XOR, not a power.

## Sized and signed integers

For a particular width or for negative numbers, use `u8`, `u16`, `u32`, `i8`, `i16`, `i32` or
`i64`. There is no `usize` or `isize`.

{{example:integers}}

A suffix such as `200u8` or `-12i32` fixes a literal's type, and an unsuffixed literal next to a sized
value takes that value's type, checked to fit. Nothing converts implicitly: `u16(small)` converts and
stops the program if the value does not fit, `wrapping_u8(300)` deliberately keeps the low bits, and
`bits(x)` gives the raw 64-bit pattern. `&`, `|`, `^`, `<<` and `>>` work on integers; `>>` keeps a
signed value's sign.

## Floating point

`f64` literals need a decimal point or an exponent (`2.0`, `1e9`), and mixing `f64` with integers takes
a conversion such as `f64(values.len())`. Results print with the fewest digits that read back as the
same value, which is why `0.1 + 0.2` shows its rounding error.

{{example:floats}}

Floats have `sqrt`, `abs`, `floor`, `ceil`, `trunc`, `round` (halves away from zero), `min`, `max`
(a NaN operand yields the other), `is_nan`, `is_finite`, `is_infinite`, `next_up` and `next_down`,
all bit-identical to the C library.

## f32 and characters

`f32` is the single-precision float: write `0.5f32`, or let an `f32` context adopt a plain literal
(`ratio: f32 := 0.1`). Every result is rounded to `f32`, and an `f32[]` stores 4 bytes per element.
`char` is a Unicode scalar value: `'ï'` is a `char`, while an ASCII literal such as `'g'` is a byte
unless a `char` context adopts it. Characters compare with `<` and `==`, convert with `u32(c)` and the
checked `char(n)`, and offer `is_alphabetic`, `is_whitespace`, `to_uppercase` and similar methods.

{{example:chars-f32}}

**Try it:** in the sized-integer example, change `small + 55` to `small + 56` and run it again.
