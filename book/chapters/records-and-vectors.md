# Records, fields and vectors

Records have named, explicitly typed fields. A record literal can use field punning: when a variable
already has the field's name, write `Message { body, label }` instead of repeating
`body: body, label: label`. The same shorthand is intended for record patterns in the approved model,
but this preview compiler matches enums, unions, integers and bools rather than records. Moving one owned field does not move its siblings. The remaining fields
are still released when the record ends.

{{example:records}}

`T[]` creates an empty vector; `u64[10, 20, 30]` initializes one directly.
`values.push(value)` consumes an element, and `values.pop()` removes and returns the last element.

{{example:vectors}}

`values[i]` copies a numeric element. `&values[i]` borrows an element slot readonly;
`&mut values[i]` borrows it exclusively when mutable access is available. Non-numeric indexed
values remain borrowed rather than moving owned elements out of the vector. `load(slot)` copies
a numeric referent. After the reference's last use, growth may reallocate the vector.

`values[i] = value` replaces an element (the old one is dropped) and `values[i] += 1` updates a
numeric one; both work through field paths such as `grid.cells[i] = 0`. The right-hand side is
evaluated first, so `values[i] = values[i - 1] * 2` is fine. On byte buffers, `buf[i] = b` stores a
byte and stops the program if the value does not fit.

Popping an empty collection or indexing out of bounds aborts. Vectors of owners recursively drop
their remaining elements; callers own popped elements. Byte buffers use the same `.push`, `.pop`,
`.len` and indexing syntax. Generic vector slicing is not implemented yet; byte slicing is.
In the approved model a loop consumes its iterable, `for value in values`; this preview copies
scalar elements and still needs `for value in borrow(values)` for a vector of owners.

**Try it:** use `u8[][]`, push `u8[]`, and inspect the popped buffer's length.
