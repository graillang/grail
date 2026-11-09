# Methods, ranges, `else if` and formatted printing

## Inherent methods

```grl
struct Point { x: i32, y: i32 }
impl Point {
    fn new(x: i32, y: i32) -> Point { return Point { x: x, y: y }; }
    fn sum<a>(self: (&a Point)) -> i32 { return self.x + self.y; }
    fn shift<a>(self: (&mut a Point), dx: i32) { self.x = self.x + dx; }
}
fn main() {
    mut p = Point::new(3, 4);
    p.shift(1);
    println("{}", p.sum());
}
```

`impl Type { ... }` adds functions to a struct or enum declared in the same module. A function
whose first parameter is `(&a Type)`, `(&mut a Type)` or `Type` can be called with
`value.name(args)`: the receiver is borrowed, mutably borrowed (the binding must be `mut`) or moved
accordingly; a reference receiver is passed through, field receivers (`shape.origin.shift(1)`)
are borrowed in place, and temporaries (`Point::new(1, 2).sum()`) live until the end of the
statement. Other functions are called as `Type::name(args)`. Methods are checked exactly like
functions (ownership, lifetimes).

Generic types work too: `impl<T> Stack<T> { fn push<a>(self: (&mut a Stack<T>), v: T) ... }`.
The impl's parameters are added to each method's; the type arguments after the type name must be
exactly those parameters, in order. Associated functions take explicit type arguments when they
cannot be inferred: `Stack::new<num>()`.

## Matching integers, byte values and bools

`match n { 0 => {..}, 1 | 2 => {..}, 'a' => {..}, -1 => {..}, _ => {..} }` compares an integer, `u8`
or `bool` against literal patterns. Patterns are range-checked against the value's type, duplicates
are errors, and a `_` arm is required unless a `bool` match covers both `true` and `false`.
`lo..hi` matches `lo <= n < hi` (signed or unsigned, per the value's type). A name pattern binds the value
(`n => {..}` is a catch-all), and any pattern may take a guard: `x if x % 2 == 0 => {..}`. Guarded
arms never make a match exhaustive. Values the guard moves are unavailable in later arms.

## Default arms

An enum `match` may end with `_ => {..}` for the remaining variants (an owned value is dropped
there). It must be the last arm and is an error when every variant is already listed.

## Matching through references

`match value { ... }` consumes an owned enum. Matching a reference (`match self`, `match borrow(o)`,
`match borrow_mut(m)`) inspects it in place: scalar payloads are copied, others are bound as
references of the same mode (shared or mutable), so methods on enums can take `self` by reference
and the value remains usable afterwards. The owner cannot be moved or dropped while a payload
reference is live.

## Parenthesized types

`()` is the unit type and value. Parentheses group a type or expression, so `(A)` is just `A` and
`(T | E)[]` is a vector of union values. Tuple types, tuple values and tuple destructuring are
not part of the language.

## Typed bindings

`mut total: i32 = 0;` and `limit: u8 := 200;` give a binding an explicit type; the initializer is
checked (and an unsuffixed literal adopts the type). `mut x: T;` declares a binding initialized later.

## Struct literals

`Point { x, y }` is shorthand for `Point { x: x, y: y }` (each name must be a variable in scope).

## Control flow

- `if a { } else if b { } else { }`.
- `if let Some(x) = value { } else { }` runs the block when the enum value is that variant, with
  the payload bound; like `match` it consumes the value (the else branch drops it).
- `while let Some(x) = next() { }` repeats while the value matches (a non-matching value is dropped).
- `loop { }` repeats until `break` or `return`; code after a loop without `break` is unreachable.
- `for i in a..b` counts from `a` up to, not including, `b`; `for i in n` counts from 0.
- `for x in v` copies scalar elements of a vector, or the bytes of `u8[]`/`string`/a view.

## Formatted printing

`print` and `println` accept a format string: `println("x = {}, y = {}", x, y)`. Each `{}` prints
the next argument (`num`, sized integers, `bool`, text, byte views); `{{` and `}}` print braces.
Vectors of printable elements (numbers, `bool`, `f64`, text, nested vectors) print like Rust's
`{:?}`: `[1, 2, 3]`, `["a", "b"]`, `[0.5, 2.0]`. A struct or enum with an inherent `show(self: (&a Self)) -> string` method is printed
(and formatted) through it. The string is split at compile time, so printing allocates nothing extra; the number of `{}` must
match the arguments. `format("...", args)` builds a `string` the same way. Format specs follow Rust: `{:8}` pads to 8 characters (numbers right-aligned, text left-aligned),
`{:<8}`/`{:>8}`/`{:^8}` choose alignment, `{:*^8}` sets the fill character, `{:05}` zero-pads after
the sign, and `{:.2}` (alone or as `{:8.2}`) gives an `f64` exactly 2 decimals.

## Vector helpers (`lib/vecs.grl`)

`vecs::map(items, f)` (moves each item into a closure `Fn(T) -> U`), `vecs::filter_nums`,
`vecs::sum`, `vecs::max_num`, `vecs::sort_nums` (in place), `vecs::reverse` and `vecs::contains`
(for `hash::Equal` element types).

`vecs::sort(borrow_mut(v))` sorts any vector whose element type implements `order::Ord`
(`less(left, right) -> bool`; provided for integers, `f64` with NaN last, `u8[]` and `string`). It is
a stable merge sort that moves elements instead of copying them. `vecs::is_sorted`, `min_index` and
`max_index` use the same order. Implement `order::Ord` for your own types to sort them.
`vecs::sort_by(&mut v, less)` sorts stably by a comparator `Fn(&T, &T) -> bool` (any function with
that signature, or a closure); `vecs::sort_by_key(&mut v, key)` by a `u64` key computed once per
element. Sorted-vector sets: `vecs::insert_sorted(&mut v, x)` (keeps order, rejects duplicates) and
`vecs::binary_search(&v, &x) -> u64?`.

## Text helpers (`lib/strings.grl`)

`strings::starts_with`, `ends_with`, `find` (→ `num?`), `contains`, `split` (on a byte),
`trim`, `join_with`, ASCII `to_upper`/`to_lower`, and `parse_num` (→ `num?`, `None` for
non-digits or overflow), `replace` and `repeat`. Unicode: `chars` decodes UTF-8 into code points
(`u32[]`, invalid bytes become U+FFFD), `char_count` counts them and `push_char` appends a code
point's UTF-8 encoding. `strings::to_upper/to_lower` are ASCII-only; the built-in methods also map
Latin, Greek and Cyrillic letters.

## Constants

`const NAME: Type = literal;` at module level, for integers (any integer type, range-checked),
`bool` and `string`. `pub const` makes it usable as `module::NAME`. Each use inlines the value; a
text constant yields a new owned `string`. Computed constant expressions are future work.

## Optional values (`lib/core.grl`)

`T?` supports `is_some()`, `is_none()`, `unwrap_or(fallback)`, `map(f)` and `ok_or(error)`.
The `is_*` methods borrow; the others consume the value. Unions are matched by member type or
propagated with `?`, rather than using `Result` methods.

## Program environment (`lib/env.grl`, `lib/process.grl`)

`env::args()` returns the command-line arguments as `string[]` (index 0 is the program path),
`env::var(name)` returns `string?`, and `process::exit(code)` ends the program immediately
with that status (no cleanup runs). `fn main() -> num` also sets the exit status.

## Files and I/O errors (`lib/fs.grl`, `lib/io.grl`)

`fs::read`, `read_text`, `write`, `create_dir`, `remove_file`, `remove_dir` return
a union of the success type and `io::Error`; `fs::exists` and `fs::list_dir` (names, directories end with `/`) do not fail.
`io::Error` is `NotFound`, `PermissionDenied`, `AlreadyExists`, `NotADirectory`, `IsADirectory`,
`NotEmpty` or `Other(errno)`, prints readably (`not found`) and has `is_not_found()`. `?` propagates
it. The older `host::` functions remain for the compiler and runtime.

## Text operators

`==`, `!=`, `<`, `<=`, `>`, `>=` compare any two of `string`, `u8[]` and byte views by content
(byte-lexicographic, which is code point order for UTF-8): `name == "admin"`. `a + b` creates a new
value without consuming the operands: a `string` (checked UTF-8) when either side is a `string`,
otherwise `u8[]`.

## References to text as views

A reference to `u8[]` or `string` (`&v[0]`, `borrow(s)`) passed to a parameter of view type
`read<a>` becomes a view of the same storage, like Rust's `&String` to `&str`. The view keeps the
original borrow alive, so the owner cannot change or go away while it is used.

## Borrowing elements

`borrow(v[i])`, `borrow(s.items[i])` and `borrow_mut(...)` borrow one element of a vector. Note that a
`match` on such a borrow keeps it alive for the whole match, so calling a method that needs the owner
mutably inside an arm is rejected; finish the match first (copy what you need), then make the call.

## Built-in text methods

On `string`, `u8[]` and views: `is_empty()`, `contains(t)`, `starts_with(t)`, `ends_with(t)`,
`trim()`, `to_upper()`, `to_lower()` (ASCII, Latin-1, Latin Extended-A, Greek and Cyrillic; other
scripts unchanged), `replace(from, to)`, `repeat(n)` and `split(byte)`
(every field kept, like Rust's `split`). Transforming methods return a new `string` for `string`
input and `u8[]` otherwise. `lib/strings.grl` adds `find` (returning `num?`), Unicode `chars` and
`parse_num`.

## Built-in vector methods

`push(x)`, `pop()`, `len()`, `is_empty()`, `insert(i, x)`, `remove(i)` (returns the element),
`swap(i, j)`, `reverse()`, `truncate(n)`, `clear()` and, for integer or bool elements, `contains(x)` (dropping removed elements). Elements are
moved, never copied; indices out of range stop the program; changing methods need a `mut` binding.

## Structural equality

`==` and `!=` compare two structs or enums of the same type: numbers and `bool` by value,
`f64` by IEEE rules, text by content, vectors of integers/bools element by element, nested structs field by field, and enums by variant and then payload (`some(5) == some(5)`). Other field types
(vectors of non-scalars, closures, handles) are a compile-time error.
