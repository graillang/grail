# Collections

`hashmap::Map` stores key/value pairs and remembers the order keys were first inserted, so a loop
over `0..len` visits them in that order. `key_at(map, i)` and `value_at(map, i)` borrow the i-th
entry. `vecs::sort` sorts any vector whose element type implements the `order::Ord` interface;
numbers and text already do, and here `Score` sorts by points, highest first.

{{example:collections}}

Looking a key up returns a borrow tied to the map, so the map cannot change while you hold it.
That is why the loop checks `contains` first and only then takes `get_mut` to update the count.
Vectors of numbers print directly, like Rust's `{:?}`.

**Try it:** sort `scores` from lowest to highest by flipping the comparison in `less`.
