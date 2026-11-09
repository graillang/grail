# Records, fields and vectors

Records have named, explicitly typed fields. A record literal can use field punning: when a variable
already has the field's name, write `Message { body, label }` instead of repeating
`body: body, label: label`. Moving one owned field does not move its siblings; the remaining fields
are still released when the record ends.

{{example:records}}

`T[]` creates an empty vector; `u64[10, 20, 30]` initializes one directly, and `f32[0.0; n]`
makes `n` copies of a plain value in one allocation. Owned elements (strings, vectors, records
that own data) cannot be repeated, since each copy would share one owner; build those with `push`.
`values.push(value)` consumes an element, and `values.pop()` removes and returns the last element.

{{example:vectors}}

`values[i]` copies a numeric element. `&values[i]` borrows any element readonly and `&mut values[i]`
exclusively, whatever its size (a byte of `u8[]` or a 4-byte `f32` included). Non-numeric indexed
values stay borrowed rather than moving owned elements out of the vector. `*slot` copies a numeric
referent. After the reference's last use, growth may reallocate the vector.

`values[i] = value` replaces an element (the old one is dropped) and `values[i] += 1` updates a
numeric one; both work through field paths such as `grid.cells[i] = 0`. The right-hand side is
evaluated first, so `values[i] = values[i - 1] * 2` is fine. Assignment works on any place built from
indexes and fields: `grid[y][x] = 0`, `world.items[i].hp -= 1` and `rows[i].cells[j] += 1` borrow
each step mutably for the statement, and a mutating method call such as `rows[i].push(x)` or
`world.items[i].tags.clear()` does the same. On byte buffers, `buf[i] = b` stores a
byte and stops the program if the value does not fit.

Popping an empty collection or indexing out of bounds aborts. Vectors of owners drop their
remaining elements; callers own popped elements. `==` compares vectors of numbers element by element.
`for value in values` copies scalar elements; a vector of owners is read with `for value in &values`.
Any vector can be sliced (see [Views and slices](views.html)).

**Try it:** use `u8[][]`, push `u8[]`, and inspect the popped buffer's length.

## Returning several values

A function can return several values in a named record. `Stats` gives each result a clear name, and
callers access its fields with `.`. Field punning shortens the literal: `Stats { low, high,
mean: ... }` takes `low` and `high` from the variables in scope. Tuples are not part of the language,
so a named record is how a function returns more than one value.

{{example:records-patterns}}

`match` works on enums, unions, bools, integers and records (the next section): a name with a guard (`t if t < 0`) catches values that pass the test,
`0..15` matches 0 up to but not including 15, and `_` handles everything else. `{:>4}` right-aligns a
number in four columns and `{:.1}` prints one decimal. `mut total: i32 = 0` declares the type
explicitly; without it the literal `0` would be a `u64`.

**Try it:** add an arm `25..35 => { ... }` that returns "warm".

## Record patterns

A record can also be taken apart by `match`: `Order { items, .. }` names the fields the arm uses
and `items: held` renames one. A record pattern matches every value of that record type, so it is
the only pattern in the `match`; an explicit `_` may follow and is never taken. A field the pattern
does not name is an error unless `..` covers the rest, and an unknown field is reported by name.

Matching through a reference leaves the record with its owner: `match &order` binds owned fields as
shared references and `match &mut order` as exclusive ones, so the arm reads or changes them in
place. Matching the record itself moves it instead, so owned fields are bound by move and the fields
`..` leaves out are dropped with the record. Plain scalars (numbers, `bool`, `char`, `f32`) are
always copied.

{{example:record-patterns}}

**Try it:** change the arm to `Order { id: number, .. }` and print `number`.
