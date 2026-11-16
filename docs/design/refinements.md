# Refinement types: checked invariants on values

Status: implemented (gaps round, G24): the syntax (`a483462`), the runtime checks that keep the
feature sound (`031fd33`), the prover with its second entry point (`a6fe6b0`, `3fee023`),
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
| `while` / `loop` | the guard states its atoms in the body, and only there |
| `for` | `for i in a..b` states `a <= i < b`, `for i in n` and `for i in v.len()` state `i < n` / `i < v.len()`, in the body, and the body's `}` ends them |
| `match` | an arm's pattern (`16` states `n == 16`, `0..16` states both bounds) and its `if` guard state atoms for that arm's body; a guarded arm's facts never reach a sibling arm or the code after the match |
| `assert` | what it tested holds for the rest of the block |
| binding | `x := 16` states `x == 16` |
| assignment | `x = e` forgets what the facts said about `x`; `x.f = e` does not, since it writes a field of what `x` owns |
| statement | a statement that calls may write through the names it mentions, so those are forgotten after it - a compound statement is exempt because its condition and its own statements report themselves |
| call site | the callee's parameter predicates are discharged with the facts at the call, and the argument names are forgotten after it (a method call also forgets its receiver) |
| body | a refined parameter holds at the body's entry - the entry checked it or the caller proved it, which is what the `.proved` entry means - and nothing is carried into the next body the compile emits (a closure body starts empty) |

A term is a parameter's or local's name, a length spelled `v.len` (for `v.len()`), or a literal; an
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
literals as exact vertices; only facts and obligations whose offset is zero or negative take part,
since `b + k` with a positive `k` can wrap in a `--overflow=wrap` build and then the integer reading
would be the wrong one.

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

### What does not change

Sized and signed integers keep whatever the prover does for them today (the conditions above are
stated for `u64` terms; another width gets them only where the same argument is made for its range).
The `--verify-facts` mode keeps every check and must still find no fired proof.

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
and ending with it. Each proving case asserts the call reaches the `.proved` entry and the refusing
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
