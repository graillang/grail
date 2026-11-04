# Tuples and patterns

A function can return several values as a tuple. `(low, high, mean) := stats(...)` takes the tuple
apart into three new names.

{{example:tuples}}

`match` works on integers too: a name with a guard (`t if t < 0`) catches values that pass the test,
`0..15` matches 0 up to but not including 15, and `_` handles everything else. `{:>4}` right-aligns a
number in four columns and `{:.1}` prints one decimal. `mut total: i32 = 0` declares the type
explicitly; without it the literal `0` would be a `num`.

**Try it:** add an arm `25..35 => { ... }` that returns "warm".
