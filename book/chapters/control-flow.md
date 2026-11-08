# Branches and loops

Use `if`/`else` for branches. Braces delimit blocks; parentheses around a condition are not
required. Both returns in `classify` make that function total: falling through without a result is rejected.

{{example:branches}}

`for i in n` visits `0` through `n-1`; it is a counted loop, not an iterator protocol. `while`
repeats a numeric condition. `break` and `continue` apply to the innermost loop.

{{example:loops}}

The counted loop adds 0, 1, 3, 4 and 5. The while loop reaches 3, producing a total of 16.
Owned loop-local values are cleaned up even on `break` or `continue`. An ownership state that
would consume the same outer value on repeated iterations is rejected.

In the approved model a loop consumes its iterable, `for value in values`, while
`for value in borrow(values)` reads its elements. This preview copies scalar elements, still requires
`borrow(...)` for a vector of non-scalar elements, and does not accept direct temporary iteration
such as `for part in name.split(' ')`.

**Try it:** remove the `continue` and predict the new total.
