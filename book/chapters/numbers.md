# Numbers and conditions

`num` is an unsigned 64-bit integer. Arithmetic wraps modulo 2⁶⁴; it is not a mathematical
integer or a signed integer. Comparisons produce numeric zero or one. Zero is false in a condition.

{{example:numbers}}

The example uses addition, subtraction, multiplication, remainder, xor and bitwise and. Parentheses
make evaluation and comparison grouping obvious. Operands are evaluated from left to right.

Remainder by zero and out-of-bounds accesses abort instead of continuing with an invalid result.
Do not assume signed arithmetic, floating-point values, a separate `bool` type, or a full operator
set just because another language has them.

**Try it:** print `0-1` with `println`. The printed value is the largest unsigned 64-bit number.

## Updates, division and powers

{{example:operators}}

`+=`, `-=`, `*=`, `/=`, `%=` and `**=` update writable numeric storage. The target is kept valid
through right-hand-side evaluation; a conflicting write to that same target is rejected. The
right-hand side runs once. Ordinary `/` truncates unsigned integer division; both `/` and `%`
abort on zero divisors.

`**` binds more tightly than multiplication and groups right to left. Its result wraps like the
other `num` arithmetic, including `0 ** 0 == 1`. `^` remains bitwise XOR. Parenthesize whenever
explicit grouping makes a calculation easier to read.
