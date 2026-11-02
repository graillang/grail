# Bindings and reassignment

`let` binds a value; `var` allows the binding to be reassigned. Local types are normally inferred.
Parameters and non-unit function results have explicit types. Statements end with semicolons.

{{example:bindings}}

`assert` aborts if its numeric condition is zero. Use it to make examples executable explanations.
Bindings are lexically scoped, and an inner binding can shadow an outer name.

There are two kinds of mutation to distinguish. `answer=...` changes the binding and requires
`var`. Operations such as `push(data,...)` change an owned object's contents; they work with
`let data=bytes()` when the checker can grant exclusive access. `let` is not deep immutability.

**Try it:** make `answer` a `let` binding. The reassignment should fail rather than silently mutate it.
