# Branches and loops

Use `if`/`else` for branches. Braces delimit blocks; parentheses around a condition are not
required. Both returns in `classify` make that function total: falling through without a result is rejected.

{{example:branches}}

A condition must be a `bool`. Comparisons produce `bool`, `&&`, `||` and `!` combine them, and
an integer is never a truth value on its own: write `if count != 0`, not `if count`.

{{example:strict-condition}}

`for i in n` visits `0` through `n-1`; `for i in a..b` visits `a` up to but not including `b`.
Both are counted loops, not an iterator protocol. `while` repeats while its condition is `bool`.
`break` and `continue` apply to the innermost loop.

{{example:loops}}

The counted loop adds 0, 1, 3, 4 and 5. The while loop reaches 3, producing a total of 16.
Owned loop-local values are cleaned up even on `break` or `continue`. An ownership state that
would consume the same outer value on repeated iterations is rejected.

## Looping over a vector

`for value in values` moves owned elements out of the vector, one at a time; after the loop the
vector has been consumed. A temporary works too: `for part in name.split(' ')`. `break`, `continue`
and `return` drop any unconsumed elements and loop-local owners exactly once. Use `for value in
&values` to borrow elements and keep the vector, or `for value in &mut values` to edit them.
Numbers, bytes and other plain values are copied, so a numeric vector stays usable either way.

{{example:consume-owned}}

The first loop consumes `words` through the callee's parameter; the second borrows `kept`, so its
`len` is still available afterwards.

**Try it:** remove the `continue` and predict the new total.
