# Refinements: invariants the compiler checks

A refinement is a predicate a value must satisfy, written where the value enters. On a parameter and
on a record field it is `where`; on a result it is `ensures`, with `result` naming the value on its
way out:

```grl
fn sample(v: &f32[], i: u64 where i < v.len()) -> f32 { ... }      // i is in bounds
fn upload(buf: &u8[], align: u64 where align % 16 == 0) { ... }     // GPU alignment
struct Ray { t_max: f32 where t_max.is_finite() && t_max > 0.0 }    // no unbounded rays
fn normalize(x: f32 where x.is_finite()) -> f32 ensures result.is_finite() { ... }
```

Each one is an obligation. A call owes every parameter's predicate, with the arguments substituted; a
record literal and `r.field = v` owe the field's; a `return` owes the `ensures`. The compiler proves
an obligation where it can and checks it at run time where it cannot, so a refinement is never weaker
than the `assert` with the same predicate, and usually costs nothing.

{{example:refinements}}

`take(16)` is proved by arithmetic on a constant, and `take(n)` by the binding `n := 48` with `48 %
16 == 0`; neither call runs a check. The ray's predicate is only half proved: the literal `2.5` is
finite, but `2.5 > 0.0` is not something the prover settles between two float literals, so the
literal keeps its check - which passes. Nothing about a program changes when a proof succeeds: the
check that stays is exactly the one the compiler could not discharge.

## What the prover reads

The prover is deliberately small: a fact set per program point, read off the tokens of the function
being compiled, never inferred from the optimiser. A term is a name, a length (`v.len()`) or a
literal; a fact is a comparison between two terms (`i < n + 1`, `i <= j`, `x == 16`), a `%`
divisibility (`align % 16 == 0`) or a float class (`t.is_finite()`).

Facts come from a refined parameter (it holds at entry), the condition of an enclosing `if`/`while`
(and, in an `else`, the negation of a single comparison), an `assert`, a `for` loop's bounds
(`for i in v.len()` states `i < v.len()`), and a binding of one term. A fact dies when it could stop
being true: assigning to a name or binding it again, a method call or a `&mut` on a vector (its
length), and a call, which may write through any name it is given.

```grl
fn get(v: &u64[], i: u64 where i < v.len()) -> u64 {
    return v[i];                      // no bounds check: the entry said i < v.len()
}

fn second(v: &u64[], j: u64 where j < v.len()) -> u64 {
    k := j;                           // k == j
    return get(v, k);                 // and j < v.len(), so k < v.len()
}

fn total(v: &u64[]) -> u64 {
    mut sum = 0;
    for i in v.len() {                // the loop states i < v.len()
        sum += get(v, i);             // so this call is proved too
    }
    return sum;
}
```

A `%` fact carries through divisibility (`align % 32 == 0` proves `align % 16 == 0`), a float class
matches exactly (`t.is_finite()` proves `t.is_finite()`), and comparisons go through a small
difference graph, so transitivity works: `i <= j` and `j < v.len()` prove `i < v.len()`.

Anything else - a `||`, arithmetic the prover does not model, an argument that is not a name or a
constant, a function called through a value - is simply not proved, and its check stays. That is the
whole safety argument: the prover can only remove a check it has a proof for.

A refined parameter also feeds the bounds-check elimination. `i < v.len()` on `v: &u64[]` is exactly
what `v[i]` needs, so the body indexes without a check - unless the body binds either name again, or
the base is not a shared reference, in which case the bound could go stale and the check stays.

## Proved calls cost nothing

A function with refined parameters has two entries. The checked one runs the parameter checks in the
prologue; the second, `<symbol>.proved`, is the same frame and the same body with the checks skipped.
A call site that proved every parameter's predicate calls the second; everything else - a function
value, a `dyn` vtable entry, an interface method, a foreign call - calls the checked one, because
nothing was proved about the code it reaches.

Predicates travel in interface files, along with the parameters' names, so a caller in another module
owes - and may prove - exactly what a caller in the same module does.

## Strict mode

`--strict-refinements`, `@strict;` at the top of a module, or `@strict` before a declaration turn
every unproved obligation into a compile error at the call, the literal or the `return`. The program
then carries a proof that the invariants hold everywhere:

```
error: cannot prove the refinement `align % 16 == 0`
 = required by take at src/render.grl:1:1
 = the facts at the call do not settle it
 = the facts in scope were:
   n == 17
 --> src/render.grl:6:17
```

The diagnostic names the predicate, the declaration that requires it, why the proof failed and the
facts the prover had, which is usually enough to see what is missing. Strict mode still leaves the
checked entry in place: an indirect call proved nothing, and its check is what keeps the program
sound.

## Checking the prover itself

`--verify-facts` re-emits the check of every obligation the prover discharged and calls the checked
entry, so a proof that is wrong aborts instead of passing unnoticed. The corpus runs this way, and no
check has ever fired: the prover's power is an optimisation, and every step of it is covered by a
check whose absence is tested.
