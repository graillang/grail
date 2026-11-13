# Bindings and reassignment

`name := value` declares an immutable binding. `mut name = value` declares a mutable one.
`=` after an existing name updates a mutable binding; with a type in front of it
(`name: T = value`) it declares instead. Types are inferred for the untyped declarations.
Statements end with semicolons.

{{example:bindings}}

`answer += 2` is shorthand for adding to its current value. The next chapter covers the arithmetic
and compound operators. `assert` aborts when its condition is zero; it accepts a `bool` or an integer.

## Typed bindings

Add a type before the initializer. The immutable form uses `=` and the mutable form does too; `:=`
is accepted as well, so an older `limit: u8 := 200;` keeps working:

```grl
limit: u8 = 200;
mut total: i32 = 0;
legacy: u8 := 200;
```

Either spelling fixes the type of the binding, and the initializer is checked against it, so
`small: u8 = 256;` and `x: u64 = true;` are errors rather than bindings whose type a later use has to
discover.

## Literal bindings take their type from use

A binding initialized with a bare number takes its type from how it is used later. `full := 200`
passed to a `u8` parameter is a `u8` there; the compiler checks that the literal fits at each such
use. A `mut` binding gets the type of its first sized use anywhere in the function: `sum += x` with
an `i32` `x` makes `sum` an `i32`, and `mut count = 0; count += 1; show(count)` with
`show(level: u8)` makes `count` a `u8` from the start, so `count += 1` is checked against 255.
Using one binding as two different sized types is an error. Without any sized use, integer
literals are `u64` and float literals are `f64`.

{{example:literal-inference}}

The compiler works in one pass, so when it meets such a use after it has already generated code
for the binding, it compiles that one function again with the type it learned.

## Owned data needs a mutable binding to change

An immutable owner may be read, borrowed readonly, or moved to a new binding. Mutating its owned
storage—growing a buffer, updating a vector, changing a field, or taking mutable access—requires
`mut`. An immutable declaration does not quietly acquire write permission:

{{example:immutable-owner}}

Repair this by writing `mut data = u8[];`. A `mut` binding permits mutation but does not override
the borrow checker: an outstanding reader can still prevent a write or growth.

## A fixed binding may carry exclusive access

`writer := &mut data` keeps the capability binding fixed: the binding is not reassigned, but the
bytes it reaches can still change. Declaring the capability needs no `mut`; replacing the capability
itself would. Mutable access is always explicit, so a read-only borrow never quietly becomes
writable. Use `&mut owner` uniformly for records, vectors, maps, scalars and byte buffers.

Bindings are lexically scoped. A new declaration - `:=`, or a typed `name: T = value` - may shadow
a name; `=` on an existing name means reassignment. Function parameters are fixed bindings too: to
mutate a by-value owner, move it into a `mut` local, or accept an explicit mutable reference from the
caller.

**Try it:** change `mut answer = base` into `answer := base`. The compound assignment should fail.
