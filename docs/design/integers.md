# Sized integers

`num` remains the default 64-bit unsigned integer. Sized types are now available:

| Unsigned | Signed |
| --- | --- |
| `u8`, `u16`, `u32`, `u64` (= `num`), `usize` (= `num`) | `i8`, `i16`, `i32`, `i64`, `isize` (= `i64`) |

```grl
fn main() {
    a := 200u8;          // suffix fixes the type
    b := a + 55;         // an unsuffixed literal takes the other operand's type (range-checked)
    x := -7i32;
    assert(x / 2 == -3); // signed division truncates toward zero
    assert(x < 0);
}
```

Literals: decimal `255`, hexadecimal `0xFF`, binary `0b1111_0000`, octal `0o17`; `_` separates
digits (`1_000_000`). A suffix such as `0xFFu8` fixes the type.

Rules:

- Operands of `+ - * / % ** & ^` and comparisons must have the same integer type; there are no
  implicit widening conversions. An unsuffixed literal adopts the other operand's type if it
  fits (checked at compile time). A bare negative literal defaults to `i64`.
- Overflow, division by zero and `MIN / -1` stop the program in the default checked mode;
  `--overflow=wrap` wraps sized integers to their width (two's complement).
- Compound assignment (`+=`, `-=`, `*=`, `/=`, `%=`) works on every integer type and on `f64`
  (no `%=`), with the same checks as the operator.
- Unary minus applies only to signed integers and literals; `-1u8` and `-n` for `num` are errors.
- Comparisons `< > <= >= == !=` respect signedness and produce `bool`.
- `&`, `|`, `^` are bitwise; `<<` / `>>` shift (`>>` is arithmetic for signed types). Shift counts
  of the type width or more stop the program in checked mode.
- Conversions: `u8(x)`, `i32(x)`, `num(x)` … are checked (out-of-range values stop the program);
  `wrapping_u8(x)` … truncate; `bits(x)` returns the raw 64-bit word as `num`.
- `print`/`println` print signed values with a minus sign. Sized integers implement
  `hash::Hash`/`hash::Equal`, so they can be `HashMap` keys, and they are Send + Share.

Representation: every integer occupies one 64-bit word; unsigned values are zero-extended and
signed values sign-extended. Arithmetic on sized types goes through a checked runtime routine
(`rt_int`), so it is correct on every target but slower than `num` arithmetic; collection
elements are still one word each (packed `u8` storage and floating point are future work).

## bool

`true`, `false`, comparisons, `!`, `&&` and `||` produce `bool`. `&&`/`||` short-circuit. `&`, `|`
and `^` on two bools are non-short-circuit logic, as in Rust. Conditions accept `bool` (and, for
compatibility, `num`: nonzero is true). A `bool` widens implicitly to `num` (0/1), so older code
that adds comparison results keeps compiling; `num(b)` converts explicitly. The reverse is not
implicit: a `num` cannot be passed where a `bool` is expected.

## Iterating collections

`for x in v` copies each element of a vector of scalars (`num`, sized integers, `bool`) or each
byte of `bytes`/`string`/a byte view. Moving the collection inside the loop is rejected; other
mutations are memory-safe (every element read is bounds-checked). Vectors of other values are iterated
by reference: `for p in borrow(people) { ... }` (or `borrow_mut` to change elements) binds each
element as a reference for one iteration; the vector cannot be changed during the loop, and an
element reference cannot be kept past its iteration.

## Byte character literals

`'a'`, `'\n'`, `'\t'`, `'\r'`, `'\0'`, `'\\'` and `'\''` are integer literals with the byte's value
(like Rust's `b'a'`): `num` by default, adopting a sized type from context (`u + '0'` with `u: u8`).
They are bytes, not Unicode scalar values; a `char` type is future work.

## f64

`f64` is an IEEE 754 binary64 value. Literals need a decimal point (`1.0`, `2.5e-3`); the compiler
converts them to the nearest double (ties to even) with exact arithmetic, independent of the
assembler. `+ - * /` and comparisons follow IEEE 754 (NaN is unequal to everything, so `x != x` is
true for NaN); `%` and bitwise operators are not defined. There are no implicit conversions:
`f64(n)` converts an integer (rounding to nearest), and `i64(x)`, `num(x)`, `u8(x)` ... truncate
toward zero and stop the program for NaN or out-of-range values. `bits(x)` gives the raw bit
pattern and `f64_from_bits(n)` the reverse. Methods: `sqrt()`, `abs()`, `floor()`, `is_nan()`.
`print`, `println` and `format` produce the shortest digits that read back exactly, laid out like
Rust's `{}` (`0.30000000000000004`, `1000000000000000000000`, `-0`, `inf`, `NaN`). `{:.N}` prints
exactly N decimals, rounding the exact binary value half to even (`{:.1}` of 0.25 is `0.2`), as Rust does.

Arithmetic uses hardware instructions on every target (SSE2, AArch64 FP, RISC-V D; RISC-V code is
now assembled for `rv64imafd`). Not yet: `f32`, exponent-only literals (`1e5`),
an `f32` type and transcendental functions as methods (they live in `lib/math.grl`).

## Math library (`lib/math.grl`)

`math::exp`, `ln`, `log2`, `log10`, `sin`, `cos`, `tan`, `atan`, `atan2`, `pow`, `powi`, `sqrt`,
`abs`, `floor`, `ceil`, `round` (half away from zero) and the constants `PI`, `TAU`, `E`, `LN2`,
`LN10`, `SQRT2`, written in Grail after fdlibm. Against Rust's std on 1,150 random inputs, every
function except `pow` is within 1 ulp and `pow` within 12 ulp; trigonometric functions use
Cody-Waite reduction and are accurate for |x| < 1e6 (larger arguments lose precision).
`f64` constants (`const PI: f64 = 3.14...;`) are allowed.
