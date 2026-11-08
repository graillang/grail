# Collections

`[K: V]` is the map type. The preview compiler constructs one with
`hashmap::with_seed<Key, Value>(seed0, seed1)`. The map stores key/value pairs, keeps the order keys
were first inserted, and exposes its operations as methods: `len`, `contains`, `get`, `get_mut`,
`insert`, `remove` and `entry`.

{{example:collections}}

Lookups borrow the key: `contains`, `get`, `get_mut`, `remove` and `entry` take a shared key, while
`insert` takes ownership of both the key and the value. The preview spells that key borrow
`borrow("the")` because a value-level `&` is still a byte view in this mode; the approved model
writes `&key`.

`get` and `entry` return optional values, so absence is visible: `counts.get(borrow("the"))!` aborts
when the key is missing, while `match counts.entry(borrow("hat"))` handles both cases. There is no
hidden `Entry` requirement: `entry` is an ordinary optional result, and code that never needs it
never sees an `Entry`. An `Entry` gives a shared `key` and a mutable `value`, so an existing value can
be changed in place; there is no insertion through a failed lookup.

`vecs::sort` sorts any vector whose element type implements the `Ord` interface, imported here with
`use order::Ord;`; numbers and text already do, and here `Score` sorts by points, highest first.
Vectors keep their built-in methods (`push`, `pop`, `len`, `insert`, `remove`, `swap`, `reverse`,
`truncate`, `clear`, `contains`), so `vecs` adds only the generic helpers that cannot be methods.
Vectors of numbers print directly, like Rust's `{:?}`.

## The approved map surface

The final model adds construction and access syntax that this preview compiler does not accept yet:

```grl
mut counts: [string: u64] = ["the": 2, "cat": 1]; // literal
empty: [string: u64] := [:];                       // empty literal
seeded := [string: u64]::with_seed(1, 2);          // type-first constructor
println(counts["the"]);                            // required-key indexing
counts["hat"] = 1;                                 // update an existing key only
counts.entry("and").or_insert(1);                  // explicit insert when absent
```

`counts["missing"]` aborts; indexing never inserts and there is no insertion through indexing.
`entry` stays optional, never a hidden insert, and `or_insert(value)` is the explicit way to add a
missing value and return access to the stored one. No tuples are involved: `for key, value in map` is
loop-header sugar for the map's entries, not a tuple protocol, and keys are never mutable through
iteration.

Until those land, write `hashmap::with_seed`, `get`, `get_mut`, `entry` and `insert`, and borrow the
key explicitly.

**Try it:** sort `scores` from lowest to highest by flipping the comparison in `less`.
