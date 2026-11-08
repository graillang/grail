# Container ergonomics in Grail: what the Abundance port actually hit

Status: evidence from the completed port increments on `feature/abundance-cpu`
(`abundance/src/{math,hash,world_hash,landscape_digest,world_cache,checkpoint,entity_table,job_policy}.grl`).
Every point below is a rule the compiler enforced, with the shape that satisfied it. This is a
porting note, not a language proposal; each item says what it cost and what to do next time.

## 1. Owned aggregates are affine inside loops

A loop that reads an owned aggregate's fields consumes the aggregate at the loop backedge:

```grl
// rejected: "loop backedge consumes entry storage" at the line after the loop
fn insert(table: EntityTable, ...) -> ... {
    for i in table.rows.len() { rebuilt.push(copy_entity(&table.rows[i])); }
    size := table.size_out + 1;        // table is already consumed here
}
```

Loops over a **borrow** are fine; loops over an **owned value** are not. Two patterns survived:

- **copy first, then loop locally** — `rows := copy_page(&table.pages[p]);` and loop over `rows`;
- **consuming mutators** — `insert(table: &EntityTable, ...) -> UpdateResult { ok, table }`, with the
  caller doing `table = result.table`. `entity_table.grl` uses this; it reads naturally in a port and
  keeps row owners unambiguous.

## 2. Nested vectors cannot be indexed by reference

`&table.pages[p]` is rejected ("reference has no access authority near '['"), and
`out.queued[i].cancelled = 1` is rejected ("expected ; near '='"). Nested `T[][]` therefore supports
neither element references nor in-place field writes.

Workarounds used: pass `(table, page_index)` and copy the page into a local, and rebuild a vector
instead of writing through an index:

```grl
mut rebuilt = Job[];
for i in out.queued.len() {
    mut job = copy_job(&out.queued[i]);
    if job.id == id { job.cancelled = 1; }
    rebuilt.push(job);
}
out.queued = rebuilt;
```

`entity_table.grl` consequently stores parallel scalar arrays (`ids: u64[]`, `types: u64[]`, …,
`payloads: u8[][]`) instead of `Entity[]`. That is the shape to reach for when a container must be
mutated in place.

## 3. Rebinding a reference consumes it

For a reference parameter or local, a call that takes it by reference consumes the binding: pass
`&table` again at each use (`lower_bound(&rows, key)`, `far_limit(&model)`), and declare `mut` on the
local before mutation. `&mut` parameters need `&mut x` at every call site, including inside the same
function (`put_u32(&mut target, at, v)` in `cache_test.grl`).

## 4. Small syntax facts that cost iterations

| Shape | Rule |
| --- | --- |
| `x := …` then `x = …` | declaration is `:=`; reassignment needs `mut x = …` at the declaration, and `mut` binds with `=`, never `:=` |
| `if c { a } else { b }` as an expression | not supported; use a mutable local |
| `f64(x)` where `x: f32` | rejected inside non-entry modules (works in the entry file); `f64_from_bits(bits(x))` is the identity widening. Recorded in `abundance/README.md` |
| `u8[]` element push | `push` takes a `u64` word, not a `u8` value |
| empty vector of a qualified type | `module::Type[]` does not parse; take an empty one from a module helper (`empty_checkpoint().sections`) or a `new_*()` constructor |
| 7+ parameter function | rejected ("exceeds six parameters"), including helpers — pass a struct or a reference |
| `Type(...)` where the name is also a method | method names that shadow type names (`fn u64`) fail; use `word64`-style names |
| `1..n` ranges | not used in the port; loops are `for i in n { if i == 0 { continue; } … }` |

## 5. What this means for the next container increment

- A shared `Vec<T>`/arena must be **affine-friendly**: consuming updates returning a result struct, or
  index-based reads into a local, rather than `&mut` element access.
- Sparse/dense sets should be **parallel scalar arrays** with a separate free list, not
  `Row[]` with in-place mutation.
- Byte-oriented buffers are the comfortable case: everything in the port that only reads and rebuilds
  (`world_cache`, `checkpoint`, `entity_table`) needed no cleverness once it followed rules 1-3.
- The remaining friction is concentrated in **in-place mutation of records**, which is exactly what an
  ECS wants. That is the case to design deliberately rather than port ad hoc.
