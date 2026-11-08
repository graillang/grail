# Records and patterns

A function can return several values in a named record. `Stats` gives each result a clear name, and
callers access its fields with `.`. Field punning shortens the literal: `Stats { low, high,
mean: ... }` takes `low` and `high` from the variables in scope. Tuples are not part of the language,
so a named record is how a function returns more than one value.

{{example:records-patterns}}

Record patterns are not part of the preview surface yet, so the shorthand appears in the returned
literal rather than in a `match`. `match` works on integers too: a name with a guard (`t if t < 0`) catches values that pass the test,
`0..15` matches 0 up to but not including 15, and `_` handles everything else. `{:>4}` right-aligns a
number in four columns and `{:.1}` prints one decimal. `mut total: i32 = 0` declares the type
explicitly; without it the literal `0` would be a `u64`.

**Try it:** add an arm `25..35 => { ... }` that returns "warm".
