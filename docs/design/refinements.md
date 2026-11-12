# Refinement types: checked invariants on values

Status: design, approved for implementation (gaps round, G24).

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

A front-end fact set per program point, flow-sensitive and deliberately small - not an SMT solver:

- facts come from constants, refined parameters and fields, `ensures`, `assert(P)`, the condition
  of an enclosing `if`/`while` (and its negation in `else`), `for i in a..b` (`a <= i < b`),
  `for i in v.len()` (`i < v.len()`), and `x := e` for simple `e`;
- a fact is a linear comparison between two terms (`x < y + k`, `x == k`, `x % k == 0`) or a float
  class (`finite(x)`); terms are locals, parameters, `v.len()` of an unmodified vector and integer
  constants;
- assignment to a variable kills the facts that mention it, a `&mut` loan of a vector kills its
  `len()` facts, and loop heads keep only facts the loop body preserves (one pass: drop any fact
  whose terms the body assigns);
- an obligation is proved when it follows from the facts by transitivity of `<`/`<=` over a small
  difference graph (Bellman-Ford over at most a few dozen terms), by `%` facts with a divisor that
  divides, or by a matching float-class fact.

The prover is sound and incomplete by design: when it cannot see a proof the check stays. An SMT
backend (Z3 via `--prover=z3`) can be added later behind the same interface without changing
programs; the default build stays solver-free.

## Verification

`--verify-facts` already checks every range fact the LLVM lifter is told. The same mode re-checks
each refinement obligation the prover discharged by emitting the runtime check anyway and asserting
it never fires on the corpus, so a prover bug shows up as a failing test, not as a silent hole.

## Not in this version

Refinements on generic `T`, on vector elements (`u64[] where all < 10`), quantifiers, and
user-defined predicate functions. Each fits the design later.
