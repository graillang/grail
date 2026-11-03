# Bindings and reassignment

`name := value` declares an immutable binding. `mut name = value` declares a mutable one.
Plain `=` updates an existing mutable binding; it never declares a name. Types are inferred for
these local declarations. Statements end with semicolons.

{{example:bindings}}

`answer += 2` is shorthand for adding to its current value. The next chapter covers the arithmetic
and compound operators. `assert` aborts when its numeric condition is zero.

## Owned data needs a mutable binding to change

An immutable owner may be read, borrowed readonly, or moved to a new binding. Mutating its owned
storage—growing a buffer, updating a vector, changing a field, or taking mutable access—requires
`mut`. An immutable declaration does not quietly acquire write permission:

{{example:immutable-owner}}

Repair this by writing `mut data = bytes[];`. A `mut` binding permits mutation but does not override
the borrow checker: an outstanding reader can still prevent a write or growth.

## A fixed binding may carry a mutable capability

`writer := &mut data` and `reference := borrow_mut(value)` keep the capability binding fixed.
They may still write through the explicit mutable capability. Replacing that capability itself
requires a mutable binding. This is not deep immutability of everything reachable through a value.

Bindings are lexically scoped. A new `:=` declaration may shadow a name; `=` always means
reassignment. Function parameters are fixed bindings too: to mutate a by-value owner, move it
into a `mut` local, or accept an explicit mutable reference from the caller.

**Try it:** change `mut answer = base` into `answer := base`. The compound assignment should fail.
