# Collections

`[K: V]` is the map type. A literal is `[key: value, ...]`, and `[:]` is the empty literal when the
context already fixes the key and value types. `[string: u64]()` creates a randomly seeded map, and
`[string: u64]::with_seed(seed0, seed1)` fixes its seeds. The map keeps the order keys were first
inserted, and its operations are methods: `len`, `contains`, `get`, `get_mut`, `insert`, `remove`
and `entry`.

{{example:collections}}

`map[key]` is a required-key place. Reading it aborts when the key is missing; `map[key] = value`
inserts or replaces (upsert); `map[key] += value` updates an existing key and aborts like any
missing read, so it is not an insert. The key expression is evaluated before the assigned value and
exactly once. Assignment needs a mutable map, and indexed assignment currently updates a named map
or a field path such as `holder.values["a"] = 1`; a temporary receiver or a nested target is
rejected. `&map[key]` and `&mut map[key]` refer to the stored slot.

Lookups that can miss use `contains` for presence and the optional forms `get`, `get_mut` and
`entry`. They borrow the key, while `insert` takes ownership and returns the previous value as `V?`.
`entry` returns an optional `Entry<a, K, V>` view with a shared `key` and a mutable `value`; it never
inserts, and there is no `or_insert`. Insert with `map[key] = value`, update an existing entry through
its `value` or `get_mut`, and move a non-copyable value out with `remove`, which returns `V?`.

Key borrows use `&key`; explicit mutable map arguments use `&mut map`.
Iterating a map with `for key, value in map` is approved loop-header sugar, but this preview
compiler does not accept it yet.

`vecs::sort` sorts any vector whose element type implements the `Ord` interface, imported here with
`use order::Ord;`; numbers and text already do, and here `Score` sorts by points, highest first.
Vectors keep their built-in methods (`push`, `pop`, `len`, `insert`, `remove`, `swap`, `reverse`,
`truncate`, `clear`, `contains`), so `vecs` adds only the generic helpers that cannot be methods.
Vectors of numbers print directly, like Rust's `{:?}`.

**Try it:** sort `scores` from lowest to highest by flipping the comparison in `less`.

## Slices

`v[a: b]` borrows elements `a` up to (not including) `b` of a vector as a slice, `&[T]`; `&mut v[a: b]`
borrows them exclusively as `&mut [T]`. Either bound may be left out (`v[2:]`, `v[: n]`, `v[:]`), and
both are checked. A slice has `len()`, indexing (`s[i]`, and `s[i] = x` through `&mut [T]`), `for` loops
by value or by reference (`for x in &mut s`), sub-slicing, `copy()` into a new vector and `{}`
formatting; it cannot change length. While a slice lives, its vector cannot grow or be written
elsewhere, and a slice cannot outlive its vector. Functions take slices to work on any part of a
vector: `fn total(s: &[f32]) -> f32` sums all of `v` with `total(&v[:])` or part of it with
`total(&v[1: 4])`. `&[u8]` is the byte view (see Views).

