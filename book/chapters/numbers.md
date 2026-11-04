# Numbers and conditions

`num` is an unsigned 64-bit integer. Ordinary `+`, `-`, `*` and `**` abort on
overflow or underflow in every build mode; it is not a mathematical integer or a signed integer.
Comparisons produce `bool` values (`true`/`false`). A `num` condition is also accepted: zero is
false.

{{example:numbers}}

The example uses addition, subtraction, multiplication, remainder, xor and bitwise and. Parentheses
make evaluation and comparison grouping obvious. Operands are evaluated from left to right.

Division/remainder by zero and out-of-bounds accesses abort instead of continuing with an invalid result.
`num` itself is unsigned: signed and sized integers, `f64`/`f32` and `char` are separate types
covered in [Numbers and booleans](integers.html).

Use `wrapping_add(a,b)`, `wrapping_sub(a,b)`, `wrapping_mul(a,b)` and `wrapping_pow(a,b)`
when you intentionally want arithmetic modulo 2⁶⁴, such as a rolling hash. Both arguments must be
`num` and are evaluated once, left to right.

**Try it:** print `wrapping_sub(0,1)` with `println`: it produces the largest unsigned 64-bit
number. Ordinary `0-1` instead aborts.

## Updates, division and powers

{{example:operators}}

`+=`, `-=`, `*=`, `/=`, `%=` and `**=` update writable numeric storage. The target is kept valid
through right-hand-side evaluation; a conflicting write to that same target is rejected. The
right-hand side runs once. Ordinary `/` truncates unsigned integer division; both `/` and `%`
abort on zero divisors.

`**` binds more tightly than multiplication and groups right to left. Overflow aborts, just as
for multiplication; `0 ** 0 == 1`. Compound assignments use the same checked arithmetic. `^` remains
bitwise XOR. Parenthesize whenever
explicit grouping makes a calculation easier to read.
