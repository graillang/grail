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

`for value in values` copies scalar elements; `for value in &values` borrows each element, which a
vector of owners needs, and `for value in &mut values` lets the body change them in place. A
temporary works the same way: `for part in &name.split(' ')`.

**Try it:** remove the `continue` and predict the new total.
