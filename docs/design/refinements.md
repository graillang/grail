# Refinement types: checked invariants on values

Status: implemented (gaps round, G24; arithmetic sound under wrapping in both overflow modes,
2026-11-16): the syntax (`a483462`), the runtime checks that keep the
feature sound (`031fd33`), the prover with its second entry point (`a6fe6b0`, `3fee023`; the second entry was removed on 2026-11-16 - a copy of the prologue taken before optimisation, it corrupted the caller's callee-saved registers),
bounds-check elimination from a refined parameter (`a0d2dda`), strict mode (`5001170`), the
`--verify-facts` cross-check on the native backend (`4ef15d8`) and the fact walker over the typed IR
that replaced the token re-walk (`dc5c73b`).

## What it is

A refinement is a predicate a value must satisfy, written where the value enters a function, a
record field or a result:

```grl
fn sample(v: &f32[], i: u64 where i < v.len()) -> f32 { ... }      // i is in bounds
fn upload(buf: &u8[], align: u64 where align % 16 == 0) { ... }     // GPU alignment
struct Ray { t_max: f32 where t_max.is_finite() && t_max > 0.0 }    // no unbounded rays
fn normalize(x: f32 where x.is_finite()) -> f32 ensures result.is_finite() { ... }
```

The compiler proves each predicate where it can and checks it at run time where it cannot, so a
refinement is never weaker than an assertion and usually costs nothing. With `--strict-refinements`
(or `@strict` on a function or module), an unproved predicate is a compile error instead: the
program then carries a proof that the invariant holds everywhere.

This is the everyday layer of "invariants checked, not just memory": the misaligned buffer, the
unbounded ray and the NaN spreading through a pipeline are all refinement violations.

## Semantics

- **Where predicates go.** After a parameter's type (`p: T where P`), after a field's type, and
  after a result type (`-> T ensures P`, with `result` naming the value). `P` is a boolean
  expression over the refined value, other parameters declared before it, `len()` of views and
  vectors, integer and float arithmetic and comparisons, `%`, `&&`, `||`, `!`, and the pure float
  tests `is_finite`, `is_nan`. No calls to user functions, no side effects (checked).
- **Obligations.** A call must establish each parameter predicate (with the arguments substituted);
  a record literal or field assignment must establish each field predicate; a `return` must
  establish the `ensures`.
- **Assumptions.** Inside the callee, parameter predicates hold; a field read of a refined field
  carries its predicate; a call's result carries the callee's `ensures`. Assumptions also feed the
  existing bounds-check elimination, so `i < v.len()` on a parameter removes `v[i]`'s check.
- **Fallback.** An obligation the prover cannot discharge compiles to a check that fails with a
  runtime error naming the predicate and both locations (`error: refinement violated: i < v.len()`,
  `--> caller`, `= required by sample at file:line`). Under strict mode it is a compile error with
  the same text and the facts the prover had.

## The prover

A front-end fact set per program point, flow-sensitive and deliberately small - not an SMT solver.

The facts are a property of the typed structure the front end is compiling, not of the token stream.
`compiler/native.grl` has no materialised tree - a body is parsed once and assembled as it is read -
so the facts are kept *as the body is compiled*, at the points where the parser already knows the
structure, and a check reads the live list instead of rebuilding it. Each hook is small and each one
is a place where a scope, a binding or a guard is opened or closed:

| where | what it does |
| --- | --- |
| `block` | one scope per `{}`: what a condition, a guard or an arm's pattern stated for it holds inside it, and the atoms a binding's shadowing removed come back when it closes |
| `bind` | every binding: the name stops meaning what the old one meant, for this block only |
| `if` / `else` | the condition states its atoms in the then-block; the negation of a single comparison states one in the `else`, and an `else if` carries it while the next condition is tested |
| `while` / `loop` | what the body writes is forgotten before the guard is compiled (the guard runs again after every iteration); the guard then states its atoms in the body, and only there |
| `for` | `for i in a..b` states `a <= i < b`, `for i in n` and `for i in v.len()` state `i < n` / `i < v.len()`, in the body, and the body's `}` ends them |
| `match` | an arm's pattern (`16` states `n == 16`, `0..16` states both bounds) and its `if` guard state atoms for that arm's body; a guarded arm's facts never reach a sibling arm or the code after the match |
| `assert` | what it tested holds for the rest of the block |
| binding | `x := 16` states `x == 16` |
| assignment | `x = e` forgets what the facts said about `x`; `x.f = e` does not, since it writes a field of what `x` owns |
| statement | a statement that calls may write through the names it mentions, so those are forgotten after it - a compound statement is exempt because its condition and its own statements report themselves |
| call site | the callee's parameter predicates are discharged with the facts at the call, and the argument names are forgotten after it (a method call also forgets its receiver) |
| body | a refined parameter holds at the body's entry - the entry checked it or the caller proved it, which is what a proved call means - and nothing is carried into the next body the compile emits (a closure body starts empty) |

A term is a parameter's or local's name, a length spelled `v.len` (for `v.len()`), a literal, or an
opaque term (`i+1`, `v.len-1`: an expression whose arithmetic may wrap, see below); an
atom is `a < b + k`, `a <= b + k`, `a == b + k`, `a % k == 0`, `finite(a)` or `nan(a)`. Terms are
compared by text, which is why the *scope* of a name is the whole question: two `i`s in one function
are the same variable unless a binding between them shadowed it, and that is what the trail in
`block` is for. Renaming across a call boundary is textual too: the callee's parameter names are
replaced by the caller's terms.

A kill comes in two kinds, and the difference is a scoping question, not a taste:

- **a binding** (`x := ...`, `let`-like patterns, a `for` variable, an arm's binder) removes the
  atoms about the name *and remembers them*: the block that made the binding restores them when it
  closes, because the outer binding was never written. This is what makes
  `{ i := 9; ... }` stop proving `i < v.len()` inside the block and start proving it again after it;
- **a write** (`x = e`, a call that may write through `x`, a `&mut` loan in a call's arguments)
  removes them for good: the write may have happened on a path that led here, so nothing restores it.

A fact that is only *added* is owned by the block that added it: an arm's `n == 16`, a loop guard's
`i < v.len()`, an `if`'s condition never outlive the braces that hold them. A condition whose span
calls or takes a mutable loan states nothing, since the call may write what the atoms would name -
the same reason a call forgets the names it is given.

What the prover cannot read it does not assume: a `||`, a `!`, arithmetic it does not model, more
than one alternative in a pattern, an argument that is not a name or a constant, a function called
through a value. The check then stays. That is the whole safety argument - the prover can only remove
a check it has a proof for - and it is also why the walk has to be complete: a construct whose write
is not reported would leave a fact standing after it stopped being true. Every write in the language
reaches one of the hooks above, `bind` and the statement wrapper most of all, because every binding
and every statement goes through them.

The switch was made behind a flag that kept the old re-walk (scan the tokens from the body's `{` to
the obligation) so the two could be compared on the corpus; the numbers are in the Verification
section, and the walk and its flag were removed once the facts over the IR were green.

An obligation is proved when it follows from the facts by transitivity of `<`/`<=` over a small
difference graph (Floyd-Warshall over at most twenty terms, literals as exact vertices), by `%` facts
with a divisor that divides, or by a matching float-class fact. Comparisons go through the graph with
literals as exact vertices and any offset: an offset reaches an atom only where its arithmetic was
shown not to wrap (the next section), so every atom is a statement over the integers.

The bounds-check elimination is still its own pass (`pv_bce`): a refined parameter `i < v.len()` is
the pattern `[i]` on a shared reference needs, and the body is scanned for anything that could make
the bound stale before it is used. Folding that into the fact set is the next step, and the fact
walker already refuses to reuse a shadowed name.

## Arithmetic in a predicate: sound under wrapping, in every build (design, 2026-11-16)

Decided: integer arithmetic is checked in development builds and wraps in release builds
(`docs/design/runtime-parity.md`). A proof must therefore not depend on which it is. Before this
design the prover read a constant offset (`i + 1 < n`) only in a checked build, where an overflow
has already stopped the program, and read nothing with an offset in a wrap build; so a `@strict`
program could compile in one mode and be refused in the other. **The rule now: what is accepted is
decided as if arithmetic could wrap (so a proof needs evidence that it does not) and as if it could
trap (so `@no_panic` needs evidence that it does not). Both builds accept exactly the same
programs; the trap is only an extra check in a development build.**

### What an atom means

An atom `a REL b + k` is a statement over the integers about the *values* of the terms `a` and `b`
(each in `[0, 2^64)`), with `k` an integer. That is unchanged. What changes is when a source
expression with an offset may be turned into one.

A source side `t + c` or `t - c` (`t` a term, `c` a literal) denotes, at run time, the wrapped value
`(t +- c) mod 2^64`. It equals the integer `t +- c` exactly when:

- `NW+(t, c)`: `t + c <= 2^64 - 1`. Established from the facts when some term `y` has
  `t <= y - c` (every term is at most `2^64 - 1`), in particular `t < y` for `c = 1`; or when `t` is
  itself a literal and the sum fits.
- `NW-(t, c)`: `t >= c`. Established when the facts give `c <= t` (a literal lower bound: `0 < t`,
  `t >= 3`, `t != 0` where that is a fact the graph has).

### Reading a comparison (a fact from a condition, or a callee's predicate)

For each side that carries an offset:

1. If the no-wrap condition for it follows from the facts in scope, the side is normalised: the
   term is `t` and the offset moves into `k`, as it does today.
2. Otherwise the side is an **opaque term**: the whole expression, spelled canonically (`i+1`,
   `v.len-1`), is the term, with offset 0. A fact about it is a fact about the value that expression
   has, wrapped or not, so it is always sound; it proves an obligation that names the same
   expression, and nothing else.

An opaque term mentions its base: a write to `i` kills every fact naming `i+1` (`pv_mentions`).

So `while i + 1 < v.len() { get(&v, i + 1); }` is proved in both builds without knowing that
`i + 1` does not wrap: fact and obligation name the same value. And
`for i in v.len() { if i > 0 { get(&v, i - 1); } }` is proved by normalising: `0 < i` gives
`NW-(i, 1)`, and `i - 1 < v.len()` follows from `i < v.len()`.

### An argument with an offset

The parameter stands for the wrapped value of the argument. If the argument's no-wrap condition
holds, it is the term with an integer offset (today's mechanism); otherwise it is the opaque term.
A predicate offset applied on top (`where p + 1 < n` called with `i - 1`) is the integer
`i - 1 + 1` only if each step is known not to wrap: the argument's own condition, then the
condition for the combined offset (`NW+` if the total is positive, `NW-` if negative, nothing if
zero).

### What a development build adds

Nothing to the prover. A development build traps on overflow, which only makes more executions
stop; it never makes an accepted program wrong. The one place the mode used to help - "the
arithmetic would have trapped, so the offset is exact" - is gone, and with it the difference
between the builds.

### `@no_panic` and the other effects

An arithmetic operation that could overflow is a possible failure of the function in *both* builds:
the claim is about the program, not about a build of it. So where a development build would emit an
overflow check, the effect analysis records "may fail" unless the facts prove the operation cannot
overflow (`hi - lo` with `lo <= hi`; an addition bounded by `NW+`), whether or not the check is
emitted. A release build emits no check and accepts no more `@no_panic` functions than a
development build does.

### As implemented (2026-11-16)

- `pv_atom` reads a comparison with each side's constant beside its term (`Atom.ao`, `Atom.bo`) and
  decides nothing. `pv_settle` turns that into a fact with the facts in scope (`pv_side` per side:
  `pv_nw` is `NW+`/`NW-`), left to right through a conjunction so `i > 0 && i - 1 < n` normalises.
  The function's own parameter predicates are settled the same way at the body's entry, with the
  predicates before them as the facts: `where p + 1 < n` is a fact about the opaque `p+1` inside
  the callee.
- A callee's predicate is read once, in its own names, constants still beside their terms. At the
  call each argument is settled first (`pv_side`), then each side of each atom adds the
  predicate's constant on top (`pv_oblige_side`): zero in total needs nothing more, an argument
  without an offset is settled like any side (so `where p + 1 < n` called with `i` is the opaque
  `i+1`), and an argument with a proved offset needs the no-wrap condition of the total.
- `NW+` also accepts a literal upper bound (`t <= L` for a literal `L` the facts name): the
  prover's literals and constants have at most fifteen digits, so the sum is far below `2^64`.
- Only `u64` terms are normalised (`pv_u64_term`: a literal, a length, a `u64` local, parameter or
  field). A sized or signed term with a constant is always opaque, in both modes - before this a
  checked build read its offset too.
- `pv_mentions` treats `i+1` and `v.len-1` as mentioning `i` and `v`, so every kill and shadow rule
  covers opaque terms with no rule of their own.
- A `while` guard is compiled after the loop's kill (`pv_loop_kill` moved above the guard). It has
  to be: the guard's constants are settled with facts that must hold at every evaluation. The move
  also closed a hole that predates this design - a refined call in a guard was proved from facts
  the body ends.
- Effects: `binary` and `int_binary` record a failure edge where a trapping build emits an overflow
  check and this build does not (`fx_would_trap`), so the graph is the same in both modes.
  `pv_arith_proof` proves `hi - lo` (`lo <= hi`) and `t + c` (`NW+`); a proved operation has no
  check and no edge in either mode, and `--verify-facts` emits its check in both.
- `@bounded` (`fx_bound_value`) and the bounds-check elimination (`pv_bce`) read a parameter
  predicate only when neither side has a constant.
- `tools/overflow-parity-test.mjs` (in the gate and in CI) checks every corpus case that states a
  refinement or an effect under both modes and requires the same outcome and the same diagnostics.

- **Offsets are summed exactly or not at all.** Every addition of a `k`, `ao` or `bo` - settling a
  side, the predicate's constant on top of an argument's, the `else` negation, an edge of the
  difference graph and every path Floyd-Warshall builds from them - goes through `pv_k_sum`. It
  refuses an operand or a result whose magnitude passes `2^60`, and the caller then abandons the
  atom, drops the edge or ignores the path: fewer proofs, never a wrong one. Within the limit a
  64-bit sum is exact (`2^60 + 2^60 < 2^63`), so every distance the graph holds is the exact sum
  of the offsets along its path, and `pv_inf` (`2^62`) cannot be reached by a sum. A source
  constant has at most fifteen digits (below `2^50`), so a few of them never come near the limit;
  the cases `refinement-wrap-large-offsets-*` push two maximal ones and the predicate's through a
  path, and show the boundary exactly (`a + K <= b` proves `a + K <= b` and not `a + K < b`).
- **What each branch of a condition gets.** A condition states atoms only when it is a conjunction
  (`&&`) of comparisons the prover reads; then the then-branch gets every conjunct, and the
  `else` gets the negation only when there is exactly one conjunct. Everything else states nothing
  in either branch:
  - `a || b`: nothing in the then-branch (either disjunct may be the true one); nothing in the
    `else` either today, although `!a` and `!b` both hold there - a proof that could be added,
    and when it is, `!a` may settle `b`'s sides, since both hold at every use in that branch.
  - `!(a && b)`, `!(a || b)`: a `!` is not read, so nothing in either branch.
  - `a & b`, `a | b` (non-short-circuit): not a conjunction the prover reads, nothing in either.
  Cases: `refinement-disjunction-*`, `refinement-negated-*`, `refinement-bitwise-*`.
  A side's no-wrap condition is settled only with atoms that hold wherever that side's value is
  used: the facts in scope at the condition (after the loop's kill, for a guard) and the
  conjuncts to its left, which a short-circuit `&&` has already found true.
- **Each loop form is pinned.** `while`, `loop` with a guarded `break`, `while let`, an iterator
  `for`, a counted `for` and a map `for` each have a case (`refinement-loop-form-*`, and
  `refinement-wrap-loop-guard-call-*` for `while`) where a call in the guard or the body's first
  statement would be proved from a fact the body ends; each is refused under `@strict` and fires
  at run time on the second iteration in both modes.

One observation not used: `(x + a) + b` wraps to the same value as `x + (a + b)` whatever the
intermediate does, so the argument's own no-wrap condition is not needed when the total is what
is settled. The rule above is the stricter one this design states.

### What does not change

Sized and signed integers keep whatever the prover does for them today (the conditions above are
stated for `u64` terms; another width gets them only where the same argument is made for its range).
The `--verify-facts` mode keeps every check and must still find no fired proof.

## Field predicates (2026-11-16)

A field predicate (`n: u64 where n > 5`) is a property of every record of its type, for as long as
the record exists. Before this section it was compiled in the scope of whoever built or wrote the
record: a predicate naming another field was an undefined name, or - when a local had that name -
a proof about the wrong value; and three writes skipped it (`&mut r.n` handed to a writer,
`r.n -= 8`, a closure's or a nested path's write). `--strict-refinements` accepted records that
violated their own predicates.

**What a field predicate may say.** Its own field, literals, `len()` and the pure tests, and
nothing else; the field is an integer of any width, a float, or an owned vector (through `len()`).
Anything else is refused at the struct (`ref_field_pred_rules`). Another field, a parameter or a
global would be read wherever the record is built, which is the bug.

**Where it is owed.** At every store into the field, with the stored value as the field's name:
the record literal, `r.f = v`, and `r.f op= v` for every compound operator Grail has (`+=`, `-=`,
`*=`, `/=`, `%=`, `**=`; it has no bitwise or shift compounds and no `++`). An assignment's path is
read by `assign_field_path`, so the predicate owed is the one of the field the path ends at, in the
record that declares it (`o.inner.n = v` owes `In.n`'s; it used to be looked up in the head's type
and found nothing). A closure's write of a captured record's field goes through the same path.
Strict mode refuses an unproved one; plain code checks it at run time.

**No `&mut` to a refined field exists.** Through one, a write would reach the field with nothing to
check it, and a loan can outlive any point where a check could run. Every way to get one is refused
(`ref_field_loan_fail`), each with a case (`refinement-field-loan-*`):

| route | where it is refused |
| --- | --- |
| `&mut r.f`, also as an argument, held in a binding, given to `exchange` | `field_path`, the last segment of a `&mut` path |
| a mutating method on the field (`r.items.push(x)`, `swap`, `pop`, ...) | `ref_refuse_field_receiver` in the vector methods, and the receiver autoref of a `&mut self` method |
| a record pattern through a `&mut` scrutinee binding a non-copy field | the record pattern (a copy field is bound by value) |
| `for x in &mut r.items` | the `&mut r.items` it is written with |
| a closure | closures capture by move; a write in the body is a field write and is checked |

`swap` as a free function does not exist in Grail. A user `&mut self` method on a refined field
cannot exist either: the field types that may carry a predicate have no user methods. `&mut r` of
the whole record stays allowed: every write through it is a field write (checked), a `&mut` of a
refined field (refused), or a store of a whole `R`, which satisfies the predicates by induction.

**What a reader may assume.** For a path the field-path rule already trusts (`pv_field_stable`: a
binding that is not `mut`, of a record or a shared reference to one, and an integer or vector
field), an obligation naming `r.f` or `r.f.len` gets the field's predicate with the field renamed
to the path (`pv_field_facts`). A `mut` or `&mut` root gets nothing.

**Cost.** Nothing when no field is refined: every hook stops at `pred.hi == 0`.

### Follow-up: predicates across fields (not built, refused until then)

`struct P { lo: u64, hi: u64 where lo <= hi }`. Sketch: every field name in the predicate is renamed
to the record's field values - at a literal all of them, after every field is stored; at a direct
write of any field the predicate mentions, the new value and the other fields read from the
record - the same renaming a call's arguments get. The no-`&mut` rule extends to every field a
predicate mentions; a trusted root's reader fact becomes `r.lo <= r.hi`; the interface carries the
text and the field list.

## Verification

A `--use DIR` build is the one place a proof is not available: the interface carries the predicate's
text but not the file it was written in, so `pv_read_pred` cannot read it for either side of a proof.
Every refinement obligation in such a build keeps its runtime check - sound, and the reason a
separately compiled caller never loses a check it should have kept.

`--verify-facts` already checks every range fact the LLVM lifter is told, and the LLVM lifter still
needs it for that. On the native backend the flag now means this instead: each refinement obligation
the prover discharged emits its runtime check anyway and the call enters the checked entry, so the
corpus asserts no such check ever fires and a prover bug shows up as a failing test, not as a silent
hole.

The tests are in `tests/native-cases.json` (every `refinement-` case): proved and unproved for the
parameter, field and result positions; the three motivating cases; the guards that drop a proof; the
bounds-check elimination on the emitted assembly; strict mode accepting a proved program and
refusing an unproved one; a function value still checking; and a cross-module proof through an
interface. The `pv-` cases are the typed-IR walk's own: a match pattern and a match guard proving a
call (and a sibling arm, which has no such fact, keeping its check), a shadowing binding killing its
block's facts and restoring the outer ones after it, and a `for` guard proving a call inside the body
and ending with it. Each proving case is accepted under `@strict` (the asm pins on a `.proved` entry went with that entry, 2026-11-16) and the refusing
case asserts the runtime check fires, so neither can pass by accident.

The switch was measured before the re-walk was deleted, with the same compiler built twice and the
26 refinement programs of the corpus compiled one at a time (`rt_refine` and `rt_trap` call sites in
the emitted assembly): **41 checks with the token walk, 41 with the typed-IR walk** - nothing
regressed - and the seven new cases add proofs the token walk could not get (it proved none of the
five that need a pattern, a guard, a shadowing scope or a loop guard).

Performance: the walk costs one pass over the names of a statement that calls, and nothing at all in
a body that never mentions a refinement. The compiler builds itself with it on, and the filtered
corpus runs at the same speed.

## Not in this version

Refinements on generic `T`, on vector elements (`u64[] where all < 10`), quantifiers, and
user-defined predicate functions. Each fits the design later.
