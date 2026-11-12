# Refinement types: checked invariants on values

Status: implemented (gaps round, G24): the syntax (`a483462`), the runtime checks that keep the
feature sound (`031fd33`), the prover with its second entry point (`a6fe6b0`, `3fee023`),
bounds-check elimination from a refined parameter (`a0d2dda`), strict mode (`5001170`) and the
`--verify-facts` cross-check on the native backend (`4ef15d8`).

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

As built, the prover reads one more source of facts than the list above: a refined parameter of the
function being compiled holds at its body's start, because the entry checked it or the caller proved
it. Two constructs reset what the walk knows rather than being followed: a `match` may bind any name,
so it drops every fact (and a body with one gets no bounds-check elimination), and a `let` pattern
drops the names it binds. Both keep a shadowed name from inheriting a fact about the outer one. Comparisons go through a difference graph of at most twenty terms with literals as exact
vertices; only facts whose offset is zero or negative take part, since `b + k` with a positive `k`
can wrap in a `--overflow=wrap` build and then the integer reading would be the wrong one.

A function with refined parameters has two entries. The checked one runs the parameter checks in the
prologue; the second, `<symbol>.proved`, is an out-of-line copy of the prologue's bytes followed by a
jump to the body, so a proved call needs no jump in the function itself. A call site takes it only
when every refined parameter's predicate is proved there; a method call, an interface method resolved
to an implementation, a function value and a foreign call keep the checked entry.

Strict mode is `--strict-refinements` for the program, `@strict;` for the rest of a module (kept by
module name, so a replayed generic body keeps it) and `@strict` before a declaration. The error names
the predicate, the declaration that requires it, why the proof failed, and the facts the prover had.

## Verification

`--verify-facts` already checks every range fact the LLVM lifter is told, and the LLVM lifter still
needs it for that. On the native backend the flag now means this instead: each refinement obligation
the prover discharged emits its runtime check anyway and the call enters the checked entry, so the
corpus asserts no such check ever fires and a prover bug shows up as a failing test, not as a silent
hole.

The tests are in `tests/native-cases.json` (every `refinement-` case): proved and unproved for the
parameter, field and result positions; the three motivating cases; the guards that drop a proof; the
bounds-check elimination on the emitted assembly; strict mode accepting a proved program and
refusing an unproved one; a function value still checking; and a cross-module proof through an
interface.

## Not in this version

Refinements on generic `T`, on vector elements (`u64[] where all < 10`), quantifiers, and
user-defined predicate functions. Each fits the design later.
