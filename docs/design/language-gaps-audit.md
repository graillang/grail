# Language gaps: the work list from the 2026-11-15 audit

Everything here was found by running the compiler, not by reading it. Each entry carries the exact
program or command that shows the gap, what Rust does instead, and how often a person coming from
Rust would hit it. Ranked by (frequency x annoyance) / effort, which is the only ranking that has
survived contact with this codebase.

Status of this round's three long-standing absences: **inherent impls on builtin types**, **`&self`
receivers** and the **postfix stdlib** are in flight on `gaps6-postfix`; they are listed here anyway
so the audit is complete and so the next reader knows where they are.

## 1. Wasteful ceremony, hit many times an hour

### 1.1 `unsafe` is a statement, not an expression
```grl
count := unsafe { c_alloc_buffers(&mut buffers) };   // refused
```
`error: unsafe is a statement, not an expression: it has no value`

Every foreign call therefore costs a `mut` declaration plus an assignment block; Rust writes
`let count = unsafe { f(..) }`. This is the whole of `ffi-handle-array`'s +14 lines against its Rust
twin, and FFI is where a systems language is judged.

### 1.2 No tuple destructuring in a `for` header
```grl
for (at, c) in pairs { ... }        // error: expected a name here, found `(`
(at, c) := pairs[0];                // works - a binding destructures
```
So `char_indices()` and every `zip`/`enumerate` chain ends in `pair.0` / `pair.1`, which is exactly
the noise the adapters exist to remove.

### 1.3 Missing collection methods (measured, all on `u64[]`)
```
u64[] has no method `iter`        v.iter()      <- blocks every adapter chain
u64[] has no method `get`         v.get(0)!
u64[] has no method `clone`       v.clone()
u64[] has no method `first`       v.first()!    (and `last`)
string[] has no method `join`     v.join("-")
string has no method `bytes`      s.bytes()
```
`s.split(",")` exists but a plain call is a type mismatch (E0004), so even the present ones are not
smooth. `s.trim()`, `s.len()`, `s.contains(x)`, `s.chars()` do work.

### 1.4 The `_num` family splits the API by element type
`vecs::any_num`, `all_num`, `count_num`, `position_num`, `min_num`, `max_num`, `filter_nums`,
`sort_nums`, `sum`. A generic method on the element type replaces all of them; they should be folded
and deleted, not kept as aliases.

## 2. Functional surface missing outright

Of Rust's common iterator surface Grail has `map`, `filter`, `fold`, `collect`, `count`,
`enumerate`, `zip`, `take`. Missing: `reduce` (in particular - `fold` without an initial value is the
shape people reach for), `filter_map`, `any`, `all`, `find`, `position`, `take_while`, `skip`,
`skip_while`, `chain`, `rev`, `flat_map`, `min`, `max`, `min_by_key`, `max_by_key`, `last`, `nth`,
`for_each`, `partition`, `dedup`, `windows`, `chunks`, `step_by`, `flatten`.

`reduce` must return `T?` with `None` on empty; a zero default silently changes the meaning of the
program, and a panic is not a language feature.

### 2.1 What we are doing, and what we are deliberately not

The goal is not to reimplement Rust's iterator surface. It is to close the gap where a competent
Rust programmer's hand goes without thinking. The split:

**Tier 1 - do now, because they appear in ordinary code constantly**
`iter` / `iter_mut` / `into_iter`; `chars` / `bytes` / `lines` / `split` / `split_whitespace` / `trim`
on text; `map` / `filter` / `filter_map` / `fold` / `reduce` / `collect` / `count` / `sum` / `any` /
`all` / `find` / `position` / `take` / `skip` / `chain` / `rev` / `zip` / `enumerate` / `flat_map` /
`for_each`; `get` / `first` / `last` / `clone` / `join` / `contains` / `push` / `pop` / `sort` /
`sort_by_key` / `dedup` / `windows` / `chunks` / `min` / `max` / `min_by_key` / `max_by_key`.

**Tier 2 - cheap, so take it if it falls out of the same code**
`take_while`, `skip_while`, `step_by`, `nth`, `partition`, `flatten`, `sort_by`.

**Not doing. This is a decision, not an oversight.**
`peekable`, `cycle`, `inspect`, `scan`, `unzip`, `try_fold`, `fold_while`, `rposition`, `chunks_exact`,
`windows_exact`, `array_chunks`, `split_at`, `split_at_mut`, `binary_search_by_*` beyond what exists,
`drain`, `splice`, `retain`, `dedup_by`, `sort_unstable*` as separate names, and the whole
itertools-style layer (`combinations`, `permutations`, `group_by`, `tuple_windows`, `cartesian_product`,
`batching`, `tee`). Each of these is real, and none of them is worth the surface area: a caller who
needs one can write six lines, and every method we add is one we test, document, keep working across
three targets, and teach in the book.

The test for moving something from "not doing" to "doing" is evidence, not argument: three or more
places in the compiler, the standard library or a ported application that want it badly enough to have
worked around it.

## 2.2 Second pass: what already works, and the two gaps it found

Probed the same way, because a list of gaps that omits what works reads as if the language were
worse than it is. **Verified working** (do not "fix" these): or-patterns (`1 | 2 => ...`), struct
destructuring in a `match` arm (`P { x, y } => ...`), slice and string ranges (`v[1..3]`,
`s[1..3]`), `format` with width and alignment (`"{:>6}|{:<4}|{:^5}"`), a hashmap literal indexed
directly (`m["b"] = 2`, with `use hashmap;`), `Option` combinators (`is_some`, `unwrap_or`),
closures capturing their environment, range patterns (`0..5 => ...`), `if let Some(v) = x`, tuples
returned and read as `t.0`/`t.1`, and `vecs::sort(&mut v)` with `use vecs;`.

Two gaps the pass found, neither in Tier 1 and both worth having:

**A. A struct cannot be destructured in a binding.** **Done** (`56179cf`, gated): `{ x, y } := p` is a
lookahead plus one lowering, with partial bindings allowed, an unknown field refused by name, the
same field twice refused, non-records and `Drop` types refused, and an owned `u8[]` field moving out
(`destr-record-*` cases). The original finding, kept because it explains the shape:
```grl
P { x, y } := p;      // error[E0001]: undefined name `x`
{ x, y } := p;        // same
match p { P { x, y } => ... }   // fine
```
Rust writes `let P { x, y } = p;` and reaches for it constantly when a function returns a small
record. This is the same family as the missing tuple destructuring in a `for` header (1.2): the
*pattern* machinery exists, it is the binding and loop forms that do not accept it.

Because it changes what `:=` means for a type with named fields, the case that proves it must prove
the **refusals** too, or it is a feature without a boundary and the next reader cannot tell a typo
from a compile error:

- a binding that names a field the type does not have (`P { x, zed } := p`);
- a binding that names the same field twice (`P { x, x } := p`);
- a binding that omits a field, if the rule is to require all of them - state which rule and pin it,
  since "partial bindings are allowed and the rest are dropped" and "partial bindings are refused"
  are both defensible and only one of them can be true.

**B. A map has no iteration surface.** **Done** (`8d0ac36`, on `main`): `keys()`, `values()` and
`iter()`, yielding references in storage order and borrowing the map like `iter::refs(&v)` borrows a
vector, plus `iter::from_step` as the seam for building an iterator outside `iter`. The original
finding: `hashmap` exposes `get`, `get_mut`, `insert`, `remove`,
`contains`, `entry`, `len`, `key_at`, `value_at`, `value_at_mut`, `entry_at` - and nothing else.
There is no `keys()`, no `values()`, no `iter()`, and `for k, v in &m` does not exist. Iterating a
map today is:
```grl
for i in m.len() { t += *m.value_at(i); }     // note the deref: value_at returns &V
```
Iterating a map is one of the most common things anyone does with one. A `keys()`/`values()`/`iter()`
trio (or a single `entries()` yielding a pair) belongs in Tier 1 alongside the other collection
methods, and it is cheap because the storage already has `key_at`/`value_at` to build on.

## 3. Crashes and silent failures (a compiler must never)

### 3.1 Main-thread stack exhaustion is a bare SIGSEGV
```grl
fn f(n: u64) -> u64 { if n == 0 { return 0; } return 1 + f(n - 1); }
fn main() -> u64 { println(f(100000000)); return 0; }
```
Status 139, no message. Task stacks have a guard page and `rt_stack_overflow`; the main thread has
neither. A recursion bug in a user program should say `error: stack overflow`, as it does on a task.

*Fixed this round, recorded so the audit is complete:* a truncated file (`fn f(a: u64` and nothing
else) aborted the compiler with `index 24 out of bounds`; a narrowing conversion that does not fit
aborted with empty stderr; `return;` in a unit function was refused with `expected a name`, and no
spelling for an early return from a unit function existed at all; a record that contains itself by
value was accepted with no diagnostic.

## 4. Driver and diagnostics

- `grail build` silently dropped several switches (`--module-root`, `--emit-interface`, `--no-entry`
  reached the compiler only in the raw form). Fixed on `gaps6-modroot`; **the audit item is the
  family check**: does `--emit-ir`, `--verify-facts`, `--speculative`, `--overflow=wrap`,
  `--strict-refinements`, `--diagnostics-json`, `--deny-ambient-host` or `--target` get dropped the
  same way? A table of "flag -> reaches the compiler?" closes it.
- The missing-argument refusal (`call to f leaves b without an argument, and it has no default`)
  carries no code, so `grail explain` has no page for it. E0018 is the honest code - it is the same
  complaint from the other side as "wrong number of arguments".
- The too-many-arguments message (`f takes 2, this call passes 1`) has no case pinning it, so it can
  regress silently.

### 4.1 The flag work, in the order it has to be done

An attempt at the unknown-flag refusal on 2026-11-15 was abandoned rather than shipped: inserting a
branch into `options()` means editing a deeply nested `else { if .. } else { .. }` chain, and a
half-applied edit left the compiler unable to parse its own source (`expected 'fn', found 'if'`). The
lesson is not "be careful", it is "change the shape first":

1. **Flatten `options()` into a table** (word -> kind -> field), as its own commit with no behaviour
   change, gated by "every existing flag still parses". This is the step that removes the brace
   hazard for every later flag.
2. **Then the refusal.** An unknown `--word` sets `bad` and the build reports
   ``grail: unknown option `--x`; `grail build --help` lists the options this command takes``. The
   pass-through allowlist (`--separate`, `--print-inputs`, `--skip-body`, `--reported`, `--interface`,
   `--verify-interface`, the analysis switches) lives in one place labelled as the driver-to-compiler
   contract, not as a user surface. `--` as a terminator and a `.grl` path are unaffected.
3. **Then `--emit-ir FILE`** as an `Options` field forwarded through `Home`, with a case asserting the
   file exists *and* is non-empty — an empty `.tir` would satisfy a naive existence check.
4. **Then `driverNoModules`** in `tools/test-native.mjs`. **Done** (`bef132e`, on `main`):
   `drv-module-root-bare-file` builds one file plus `--module-root` with the module outside `src/`,
   which is the shape that actually failed. Checked load-bearing by hand: the same project without
   the flag reports `cannot resolve module arithmetic ... no module root holds arithmetic.grl`, with
   it prints 42. `projectExtra` is used by that case; `printInputs` is used by the existing one.

## 5. Long-standing, known, and deliberately not "quick"

- The word optimizer still runs over spliced text in the per-function cache, so a cache hit saves the
  front end and the emitter but not the optimizer: 34% of bodies, 3-5% of wall time. The note says
  what would have to enter the key for that to change.
- `pool-chunks-mut-timing` measures in-place mutation at ~2x owned; the old 1.33x assertion was
  failing on loaded hosts because one round served both claims. Fixed this round.
- Windows ARM64 PE unwind records: **done**. They always did carry a frame-constant table - one
  `.set .F<unit>_<n>,<size>` per function - but the suite's pattern expected a bare `.F<n>`, so the
  comparison matched nothing and the absence looked like a property of the target (`672e1da`). The
  suite now matches the real spelling and requires one entry per function, equal to the record's
  `sub sp, #n`.

## How to re-run this audit

The probes are cheap and the method is repeatable: write the Rust idiom, run it against the current
compiler, record the diagnostic. The three that produced most of the list above:

```sh
C=$(ls -d .work/native/*/grail | head -1)
printf 'fn main() -> u64 {\n  v := u64[1, 2]\n  println(v.iter().count())\n  return 0\n}\n' > /tmp/p.grl
$C run /tmp/p.grl
```
Do this for: the iterator adapters, the collection methods, the string methods, the FFI shapes, and
the error-handling shapes. Then compare the book's Grail/Rust example pairs for verbosity - after
normalising both sides with `rustfmt` and `grail fmt`, because a line count from non-canonical sources
measures the author, not the language.
