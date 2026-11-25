# Collections

`[K: V]` is the map type. A literal is `[key: value, ...]`, and `[:]` is the empty literal when the
context already fixes the key and value types. `[string: u64]()` creates a randomly seeded map, and
`[string: u64]::with_seed(seed0, seed1)` fixes its seeds. The map keeps the order keys were first
inserted, and its operations are methods: `len`, `contains`, `get`, `get_mut`, `insert`, `remove`
and `entry`. The colon is what makes it a map: `["a": 1]` is a map and `[1, 2]` is a vector.

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

`for key, value in &map` visits every stored pair in insertion order, and `for key, value in
&mut map` visits the same pairs with writable values. Both hold one reference to the map for the
length of the loop: the body cannot insert or remove (that needs the map exclusively), and only the
`&mut` form can write, so a shared loop cannot change a value. `key` is a `&K` either way; `value` is
a `&V` or a `&mut V`. Iterating an owned map (`for key, value in map`) is refused, because the loop
only ever borrows the map: write `&map`. The loop counts positions, which is what `len`, `key_at`,
`value_at` and `entry_at` expose, so
`for i in map.len() { key := map.key_at(i); value := map.value_at(i); ... }` is the same loop written
out.

{{example:map-iteration}}

`v.sort()` sorts any vector whose element type implements the `Ord` interface, imported here with
`use order::Ord;`; numbers and text already do, and here `Score` sorts by points, highest first.

A vector's operations are its own methods, with no `use` line: `vecs`, where the generic ones live,
is linked by a program file that calls one (text's `split`, `trim`, `lines` and `join` come from
`strings` the same way). A file that declares `module name;` writes `use vecs;` itself. They are `map`,
`filter`, `filter_map`, `flat_map`, `fold`, `reduce`, `for_each`, `any`, `all`, `count`, `find`,
`position`, `get`, `first`, `last`, `into_iter`, `sort`, `sort_by`, `sort_by_key`,
`is_sorted`, `min`, `max`, `min_by_key`, `max_by_key`, `binary_search`, `insert_sorted`, `dedup`
and, on a `u64[]`, `sum` - plus the built-in `push`, `pop`, `len`, `insert`, `remove`, `swap`,
`reverse`, `truncate`, `clear`, `contains` and `is_empty`. Nothing aborts where `None` can answer:
`get`, `first`, `last`, `min`, `max`, `min_by_key`, `max_by_key`, `find`, `position`, `reduce` and
`binary_search` all answer `None` on an empty vector or a miss. `iter` is the vector's own too, like
`len`, and needs no `use` line: `v.iter()` borrows `v` and yields `&T` (see Iteration).

Three asymmetries are deliberate rather than gaps, because the language's element rules are what
they are:

- `u8[]` is byte text, a type of its own, and *not* a `T[]`: `words.map(...)` works on a vector of
  numbers or records, `bytes.map(...)` is not a method at all. `bytes` has the byte operations
  instead (`push_char`, `chunks`, `windows`, the text methods, `copy`).
- `windows` and `chunks` are therefore byte-vector methods; a vector of records cannot hand out
  borrowed runs, because a `&[T]` of them would be a second borrow of the vector per window.
- there is no generic `clone`: duplicating a vector needs a way to duplicate an element, and this
  language has no `Copy`/`Clone` bound to ask for. Copy the elements yourself into a new vector.

Vectors of numbers print directly, like Rust's `{:?}`.

**Try it:** sort `scores` from lowest to highest by flipping the comparison in `less`.

## Ordered maps

`btree::BTreeMap<K, V>` is the map whose order is its keys': a B-tree keyed by the `order::Ord`
interface, so any key with an implementation (the numbers, `string`, `u8[]`, or a record of yours)
works, and nothing needs a hash. `btree::new()` makes an empty one.

```grl
use btree;
use order;

fn main() {
    mut pages = btree::new<string, u64>();
    pages.insert("beta".text(), 2);
    pages.insert("alpha".text(), 1);
    pages.insert("gamma".text(), 3);
    for pair in pages.iter() { // key order: alpha, beta, gamma
        println("{} {}", pair.0, pair.1);
    }
    lo := "b".text();
    hi := "g".text();
    for pair in pages.range(&lo, &hi) { // b <= key < g
        println(pair.0);
    }
    if let Some(first) = pages.first() { // the smallest key
        println(first.0);
    }
    if let Some(last) = pages.last() { // the largest
        println(last.0);
    }
}
```

`iter()` walks every pair smallest key first, and `range(lo, hi)` walks the pairs with `lo <= key <
hi`; both hand out `(&K, &V)`, so a pair is read through references (`pair.0`, `pair.1`) exactly as
a `&map` loop hands them out. A walk borrows the map for as long as it lives, so the body cannot
insert or remove. `len`, `is_empty`, `contains_key`, `get` and `get_mut` are `[K: V]`'s, and `insert`
is the upsert: it replaces the value for an equal key and returns the old one, while `get_or_insert`
places a value only when the key is absent and answers the stored one either way. `remove` answers
`V?`, `first` and `last` answer `((&K, &V))?`, and `clear` empties the map.

Every operation is O(log n) in node visits (each a binary search over at most seven keys), a walk is
O(1) a pair, and `range` costs O(log n) to start. Deletion keeps the tree balanced by lending a key
from a sibling or merging two nodes, and a merged node goes on a free list that the next split reuses,
so growing and shrinking a map repeatedly does not keep allocating: `nodes_used()` reports the node
slots the tree holds, and `shrink()` rebuilds it when a burst of removals has left the arena larger
than the pairs need. Memory is a vector of nodes, `(max 7 keys + 8 children)` each; a lookup allocates
nothing.

**Try it:** insert the pages in the opposite order and check that the walk prints the same lines.

## Slices

`v[a..b]` borrows elements `a` up to (not including) `b` of a vector as a slice, `&[T]`; `&mut v[a..b]`
borrows them exclusively as `&mut [T]`. Either bound may be left out (`v[2..]`, `v[..n]`, `v[..]`), and
both are checked. A slice has `len()`, indexing (`s[i]`, and `s[i] = x` through `&mut [T]`), `for x in s`
loops, sub-slicing, `copy()` into a new vector and `{}`
formatting; it cannot change length. `for x in s` borrows each element, as `for x in &v`
does over a vector: `x` is a `&T` from a `&[T]` and a `&mut T` from a `&mut [T]`, so arithmetic
reads `*x` and `*x += 1` writes the element. While a slice lives, its vector cannot grow or be written
elsewhere, and a slice cannot outlive its vector. Functions take slices to work on any part of a
vector: `fn total(s: &[f32]) -> f32` sums all of `v` with `total(&v[:])` or part of it with
`total(&v[1:4])`. `&[u8]` is the byte view (see Views).

