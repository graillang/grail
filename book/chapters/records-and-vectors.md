# Records, fields and vectors

Records have named, explicitly typed fields. A record literal can use field punning: when a variable
already has the field's name, write `Message { body, label }` instead of repeating
`body: body, label: label`. Moving one owned field does not move its siblings; the remaining fields
are still released when the record ends.

{{example:records}}

A record is held as its words wherever it is held: in the function's frame, inline in the record
that contains it, and back to back in a vector (`Person[]` stores each `Person`'s words in its
buffer). Only what a record owns - its strings, vectors and other heap data - is on the heap, never
the record itself, whether or not it owns anything or implements `Drop`. When a record ends, its
fields are dropped in place, in declaration order, after its own `drop` if it has one; a vector
drops its elements in index order. Moving a field out leaves that field empty, so only the rest is
dropped. A record held in an enum, a closure, a `Mutex`, a `dyn` value or a task result is boxed
there, and freed with it.

`[10, 20, 30]` is a vector: the first element fixes the element type, and every other element is
checked against it. Where the context already names a vector type - a typed binding, a parameter, a
field, a return type, an enclosing literal - the literal takes that type instead, so
`b: u8[] = [104, 105]` is bytes and `rows: u64[][] = [[1], []]` needs no type inside. The type can
also lead the literal: `T[]` creates an empty vector, `u64[10, 20, 30]` initializes one, and
`f32[0.0; n]` (or `[0.0; n]`) makes `n` copies of a plain value in one allocation. A bare `[]` names
no element, so it is accepted only where a vector type is expected. A `[` that follows an expression
is still indexing: `v[0]`, `f()[0]`. Owned elements (strings, vectors, records
that own data) cannot be repeated, since each copy would share one owner; build those with `push`.
`values.push(value)` consumes an element, and `values.pop()` takes the last one off as an option:
`Some(element)`, or `None` when the vector is empty, so `while let Some(x) = values.pop() { ... }`
empties it and `if let Some(x) = values.pop()` handles both cases. `values.pop()!` insists there
is one, and stops the program with `pop from an empty vector` when there is not. A vector's buffer
of 512 bytes or more starts on a 64-byte boundary (a cache line, and enough for any SIMD load); a
smaller one starts on a 16-byte boundary.

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

Popping an empty collection or indexing out of bounds stops the program with a message that
says what went wrong and where, as Rust's panics do:

```
error: index 7 out of bounds for length 3
 --> src/main.grl:2:12
 = called from src/main.grl:9:5
 = called from src/main.grl:14:5
```

Each `= called from` line is the next frame up, named by the statement that called it: a backtrace,
up to 32 frames. The locations come from a table of statement positions the compiler emits for native
Linux builds of every target (x86-64, AArch64 and RISC-V). Windows, macOS, `--debug`, `--split`,
`--no-error-sites` and the LLVM backend carry no table, so what they print for a failed check names
no place.

The same goes for division by zero, `unwrap` of `None`, and overflow under `--overflow=checked`. Vectors of owners drop their
remaining elements; callers own popped elements. `==` compares vectors of numbers element by element.
`for value in values` moves owned elements out of the vector and consumes it; plain values such as numbers are copied, so a numeric vector stays usable. `for value in &values` borrows the elements either way (see [Branches and loops](control-flow.html)).
Any vector can be sliced (see [Views and slices](views.html)).

**Try it:** use `u8[][]`, push `u8[]`, and inspect the popped buffer's length.

## Fixed-size arrays

`[T; N]` is `N` values of `T` back to back, with no heap allocation and no length word: the
length is part of the type. A local array lives in the function's frame, which is what a vector
in an engine's hot loop - a position, a matrix row, a small scratch buffer - wants. The layout is
C's: `[f32; 4]` is 16 bytes, `[[f32; 4]; 4]` is 64, and `size_of`/`align_of` answer for arrays of
numbers.

{{example:arrays}}

- **Literals.** Where an array type is expected, a bracket literal is that array: `[1.0, 2.0, 3.0]`
  gives every element, `[0.0; 16]` repeats one. The count is checked while compiling. With no
  expected type, `[1, 2, 3]` is still a vector. An array starts full, so `mut a: [f32; 4];` without
  a value is refused, and `N` is a positive constant.
- **Indexing.** `a[i]`, `a[i] = x`, `a[i] += x`, `&a[i]`, `&mut a[i]` and `m[i][j]` work as on a
  vector. An index the compiler can prove is below `N` - a `for i in N` loop, `for i in a.len()`, a
  refined `i: u64 where i < N`, a literal - has no check; a literal past the end is a compile
  error. Any other index is one compare against the constant `N`, and a failure stops the program
  with `index 7 out of bounds for length 4` and where.
- **`a.len()`** is the constant `N`. `for x in &a` and `for x in &mut a` borrow each element, as for a
  vector, and compile to a counted loop with no iterator.
- **Copying.** An array of plain data of at most four words (32 bytes) copies on binding, as a
  number does; a larger one moves, and `a.copy()` copies it. Assigning an array, `a = b` or
  `*r = b`, copies the elements into `a`'s own storage.
- **`==`** compares element by element (floats as IEEE, so `-0.0 == 0.0`), and an array prints as
  a vector does: `[1, 2, 3]`.
- **References and slices.** A function takes an array as `&[T; N]` to read it and `&mut [T; N]`
  to change it; that is one word, the address of the elements, and the fastest way in. Where a
  slice is expected, `&a` is one: `&[T]`, `&mut [T]` (for `&mut a`), or `&[u8]` for a `[u8; N]`, and
  `a[lo:hi]` is a sub-slice. Every slice method works on an array, and `a.copy_from(&v)` copies a
  vector or slice of exactly `N` elements in (the length is checked as it runs). Until views are
  pairs in the frame, making a slice from an array allocates its `{pointer, length}` record, so a
  hot path takes `&[T; N]`.
- **Where arrays live.** In locals, as fields of structs, tuples and generic records (inline, as a
  plain record's fields are), and as the elements of a vector: `[f32; 4][]` stores its elements
  back to back, a C `float[n][4]`, with `push`, `insert`, `remove`, `pop()!`, indexing and
  iteration. Elements are numbers, C handles and pointers, records, owners or arrays.
- **C structs.** An `extern "C" record` field `[T; N]` is an array: `d.ids[3]` and `d.ids[3] = 7`
  work in place, `&d.name` is a `&[u8]`, `d.ids = [1, 2, 3, 4]` assigns it whole, and reading the
  whole field (`ids := d.ids`) copies it, as reading an embedded C struct does.
- **By value.** A function can take and return arrays: `fn add(a: [f32; 3], b: [f32; 3]) -> [f32; 3]`.
  An argument is a copy the callee owns (or the array itself, moved, when it is large or owns
  data). Until results travel in registers, a returned array comes back through one short-lived
  heap block, so a hot inner function fills a `&mut [T; N]` instead. `extern "C"` functions take
  and return arrays only as pointers, as C does.
- **Owned elements.** `[string; 3]`, `[u64[]; 4]`, `[T?; 2]` and arrays of records that own data
  hold one owner per element. Such an array always moves, drops its elements when it ends,
  replaces an element by dropping the old one, and reading `a[i]` borrows the element. A literal
  gives every element; a repeat `[x; N]` of an owner is refused, as for vectors.
- **Generic length.** A value parameter can be the length: `fn sum<@n: u64>(a: &[f32; n]) -> f32`
  is inferred from the argument (`sum(&v)` with `v: [f32; 3]` is `sum<3>`), given explicitly
  (`zeros<4>()`), or a record's own (`struct Mat<@R: u64, @C: u64> { m: [[f32; C]; R] }`). Each
  length is a specialisation of its own, so `n` is a constant inside the body.
- **Not yet.** An array cannot be an enum payload or an option (so `pop()` without `!` on a
  vector of arrays is refused) or a closure's capture, and an array whose elements own data cannot
  be a `dyn` value or a task's result (docs/design/fixed-arrays.md). It can be a struct field and a
  vector element like any array.
- **Large arrays** live in the frame, as in C. A frame larger than a page is touched a page at a
  time from the top as the function starts, so running out of stack is always reported as
  `stack overflow` and never steps over the guard page; a frame larger than the 1 MiB stack a task
  runs on is refused at the array that makes it so - keep such data in a vector or a static.

## Returning several values

A function can return several values in a named record. `Stats` gives each result a clear name, and
callers access its fields with `.`. Field punning shortens the literal: `Stats { low, high,
mean: ... }` takes `low` and `high` from the variables in scope.

When the values need no names, return a tuple: `fn divmod(a: u64, b: u64) -> (u64, u64)` returns
`(a / b, a % b)`, `(q, r) := divmod(17, 5);` takes it apart, and `t.0`, `t.1` read one element. A
tuple owns its elements like a record owns its fields; `enumerate` and `zip` yield tuples.

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
