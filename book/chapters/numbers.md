# Numbers

`u64` is Grail's everyday integer: an unsigned 64-bit value that counts sizes, indices and bytes.
Arithmetic is checked in every build mode: `+`, `-`, `*` and `**` stop the program on overflow or
underflow, and `/` and `%` stop it on a zero divisor, instead of continuing with a wrong number.
Comparisons produce `bool` values, which combine with `&&`, `||` and `!`.

{{example:numbers}}

When you want arithmetic modulo 2⁶⁴, such as a rolling hash, say so: `a.wrapping_add(b)`,
`wrapping_sub` and `wrapping_mul` (also written `wrapping_add(a, b)`, with `wrapping_pow`, on `u64`).

## Integer methods

Every integer type has Rust's everyday methods, with no `use` line: `min`, `max`, `clamp`, `pow`,
`abs` and `signum` (signed types), `checked_add`, `checked_sub`, `checked_mul` and `checked_div`
(`None` on overflow or a zero divisor), `saturating_add` and `saturating_sub`, `wrapping_add`,
`wrapping_sub` and `wrapping_mul` (modulo the type's own width), `count_ones`, `leading_zeros` and
`trailing_zeros` (a `u32`, counted in the type's width) and `to_string`.

```grl
fn main() {
    small: u8 = 250;
    println(small.checked_add(10).is_none()); // true: 260 does not fit
    println(small.saturating_add(10)); // 255
    println(small.wrapping_add(10)); // 4
    delta: i32 = -7;
    println(delta.abs().pow(2)); // 49
    flags: u64 = 40;
    println(flags.count_ones()); // 2
    println(flags.trailing_zeros()); // 3
    println(flags.to_string().len()); // 2
}
```

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
`bits(x)` gives the raw 64-bit pattern (`x.to_bits()` on a float, and `f64::from_bits(b)` back). `&`, `|`, `^`, `<<` and `>>` work on integers; `>>` keeps a
signed value's sign.

## Floating point

`f64` literals need a decimal point or an exponent (`2.0`, `1e9`), and mixing `f64` with integers takes
a conversion such as `f64(values.len())`. Results print with the fewest digits that read back as the
same value, which is why `0.1 + 0.2` shows its rounding error.

{{example:floats}}

Floats have `sqrt`, `abs`, `floor`, `ceil`, `trunc`, `round` (halves away from zero), `min`, `max`
(a NaN operand yields the other), `is_nan`, `is_finite`, `is_infinite`, `next_up` and `next_down`,
all bit-identical to the C library, and `to_bits` (with `f64::from_bits(b)` and `f32::from_bits(b)`
for the way back). `use math;` adds the elementary functions as methods of `f64` and `f32`: `sin`,
`cos`, `tan`, `asin`, `acos`, `atan`, `y.atan2(x)`, `exp`, `exp2`, `ln`, `log2`, `log10`, `pow`,
`powi`, `hypot` and `fmod`, with the constants `math::PI`, `math::TAU` and `math::E`.

```grl
use math;

fn main() {
    angle := math::PI / 6.0;
    println(angle.sin()); // 0.49999999999999994
    println(3.0.hypot(4.0)); // 5
    println(2.0.powi(10)); // 1024
    println(1.0.atan2(1.0) * 4.0); // 3.141592653589793
}
```

## f32 and characters

`f32` is the single-precision float: write `0.5f32`, or let an `f32` context adopt a plain literal
(`ratio: f32 := 0.1`). Every result is rounded to `f32`, and an `f32[]` stores 4 bytes per element.
`char` is a Unicode scalar value: `'ï'` is a `char`, while an ASCII literal such as `'g'` is a byte
unless a `char` context adopts it. Characters compare with `<` and `==`, convert with `u32(c)` and the
checked `char(n)`, and offer `is_alphabetic`, `is_whitespace`, `to_uppercase`, `to_digit(radix)`,
`is_digit(radix)`, `is_ascii_punctuation`, `to_ascii_lowercase`, `eq_ignore_ascii_case`, `to_string`
and Rust's other everyday character methods.

{{example:chars-f32}}

**Try it:** in the sized-integer example, change `small + 55` to `small + 56` and run it again.

## SIMD vectors

`f32x4`, `f32x8`, `f64x2`, `f64x4`, `i32x4` and `i32x8` hold four or eight lanes of one number type,
and `+`, `-`, `*`, `/` (on floats), `&`, `|`, `^` (on integers) work lane by lane. A vector is an
ordinary value: it is copied like a number and needs no cleanup. It comes from `splat` (every lane
the same), `new` (each lane given), or `load` from a slice or array at an index, and goes back with
`store`:

```grail
fn dot<a>(x: (&a [f32]), y: (&a [f32])) -> f32 {
    mut n = x.len();
    if y.len() < n {
        n = y.len();
    }
    mut acc = f32x4::splat(0.0);
    mut i = 0;
    while i + 4 <= n {
        acc = acc + f32x4::load(x, i) * f32x4::load(y, i);
        i += 4;
    }
    acc.sum()
}
```

A `load` or `store` is checked once per vector, like an index: `f32x4::load(s, i)` needs
`i + 3 < s.len()`. `v.sum()` adds the lanes in a fixed order (pairs of halves, down to one lane),
so the result is the same on every machine; `v.lane(2)` reads one lane; `v.min(w)` and `v.max(w)`
follow the scalar rule (a NaN gives the other operand, and a tie gives the first).

Comparisons are lane-wise too, so they are methods that give a mask (`m32x4` for an `f32x4`), not
a `bool`: `a.lt(b)`, `a.eq(b)` and so on. A mask chooses lanes with `m.select(a, b)` (lane from `a`
where the mask is set, else from `b`), and `m.any()`, `m.all()` and `m.not()` read or flip it;
`m32x4::splat(true)` makes one directly. `a < b` on vectors is an error that says to use the method.

`u8x16`, `u8x32`, `u32x4` and `i64x2` hold bytes, unsigned words and 64-bit integers; unsigned lanes
compare and order as unsigned. `v.shuffle(3, 2, 1, 0)` rearranges lanes, and `v.shuffle2(w, 0, 4, 1,
5)` picks from `v` followed by `w` (which is how a 4x4 transpose is written); the indices are
literals. `to_f32()` and `to_i32()` convert lanes (`to_i32` truncates, saturates and turns NaN into
0), and `bits()`/`T::from_bits` reinterpret them. `load_aligned` and `store_aligned` promise an
address aligned to the vector's size, and a program that breaks the promise stops with the address
rather than reading the wrong bytes.

With `--release` (the LLVM backend) the vectors are SSE2 or NEON registers and a loop like the one
above runs as fast as the same loop written in C with intrinsics. The development backend computes
the same results one lane at a time for now. Every target and both backends give bit-identical
results (docs/design/simd.md).
