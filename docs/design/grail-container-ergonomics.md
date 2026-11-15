# Container ergonomics in Grail: what still holds

Status: measured on `gaps3-diagx`, the tree that follows `gaps-int3` (e5b8f6d). The Abundance port
note that stood here listed nine container shapes that cost iterations. Six of them are fixed; this
records which still hold and names the case in `tests/native-cases.json` that pins each. Every
statement below was re-measured on this tree, none is carried over. Evidence, not a proposal.

## Still open

### 1. An owned aggregate is consumed at a loop backedge

```grl
s := "abc";
mut i = 0;
while i < 2 { take(s); i = i + 1; }   // refused
```

```text
error: loop backedge consumes entry storage: `s` is moved out of it, so a second iteration would
       use a moved value
 = help: copy it (`s.copy()`), borrow it (`view(s)`), or move it before the loop
```

The refusal is correct and the message is the finding: it names the binding, the state it is in and
the three ways out. Rust refuses the same program for the same reason (second iteration: use of
moved value), so this is not a Grail gap. Pinned by `for-in-move-collection-rejected`,
`diagx-backedge-names-the-value`, `diagx-backedge-names-the-field`, and
`diagx-backedge-continue-names-the-value` (the `continue` edge).

The refusal is about **moving** the value, not about touching it. Reading an owned aggregate's
fields inside a loop does not consume it, so this compiles even though the aggregate is owned:

```grl
fn total(table: T) -> u64 {
    mut n = 0;
    for i in table.rows.len() { n = n + table.rows[i]; }
    return n + table.size_out;          // fine: `table` was never moved
}
```

It is passing the value itself to a call inside the loop body that refuses; borrow it (`view(t)`)
or copy it (`t.copy()`) and the same loop compiles.

### 2. `if` and `match` in expression position (fixed since this note was written)

When the port ran, `n := if c { 1 } else { 2 };` was refused as `undefined name 'if'`, and the advice
was a mutable local. That workaround is no longer needed: `if` and `match` are both expressions.

```grl
n := if c { 1 } else { 2 };
x := match e { Good(v) => v, Bad(_) => 0 };
```

Two rules still shape a port. An `if` used as a value needs an `else`, because an `if` with no
`else` has no value - the refusal says to add one. And an arm whose value *borrows* is refused
(`match n { 0 => &a, _ => &b }`): one result word cannot name both arms' loans, so use the
reference inside each arm. A diverging arm (`return`, `break`) needs no value. Reasoning in
`docs/design/if-expression.md` and `docs/design/match-expression-arms.md`; corpus: the sixteen
`exprif-` cases and the ten `exprif-match-` cases.

### 3. `u8[]` push of a word

`b.push(300)` on a `u8[]` used to compile and then abort at run time with no message at all. A
literal that does not fit is now refused at compile time, exactly as `u8[300]` and `b[0] = 300`
already were:

```text
error[E0015]: integer 300 is out of range for u8 (0..=255)
 = help: write a value that fits, or truncate on purpose: `wrapping_u8(x)` says the narrowing is
   intended, where `u8(x)` checks the value at run time
```

A *value* wider than a byte is still accepted and range-checked at run time, which is what a byte
store does; only the literal is now a compile error. Pinned by
`diagx-byte-push-literal-out-of-range` (refused) and `diagx-byte-push-wider-value` (accepted).

## Fixed

Each row was a refusal or a parse failure in the port; each now compiles, and the case named in the
last column runs it.

| Shape | Now | Pinned by |
| --- | --- | --- |
| a function with 7 or more parameters | `fn nine(a, b, c, d, e, f, g, h, i)` and `fn seven<x>(...)` compile and run | `more-than-six-parameters` |
| `a[i].f = x` on a vector of records or vectors | `v[0][1] = 9`, `w.items[0].x += 1` | `nested-place-assignment` |
| `&v[i]` into a nested vector | `&rows[0][1]` | `diagx-nested-index-reference` |
| a mutating call through an index | `v[0].push(4)`, `&mut z.comps[0].data` | `nested-mutating-calls`, `borrow-through-index-and-field` |
| rebinding a reference | `mut r = &a; r = &b;` | `diagx-rebind-reference` |
| `module::Type[]` | `mut v = qvec::P[];`, `v: geom::Point[]` | `qualified-vec-literal` |
| `f64(f32)` outside the entry module | `pub fn wide(x: f32) -> f64 { return f64(x); }` | `diagx-f64-of-f32-outside-entry` |
| `1..n` ranges | `for i in 2..5`, `for i in n-3..n` | `for-range-loops` |

Two syntax facts from the port that are not container items and did not change: a declaration is
`:=` while a re-assignment needs `mut x = ...` at the declaration (a bare `x = 2` on a `:=` binding
is E0005, "assignment requires mut"), and a mutable declaration binds with `=`, never `:=`.
