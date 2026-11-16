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

The prover is deliberately small: a fact set per program point, kept as the body is compiled and
attached to the structure the compiler already knows - a block, a binding, a condition, a loop's
guard, a `match` arm - never inferred from the optimiser. A term is a name, a length (`v.len()`) or a
literal; a fact is a comparison between two terms (`i < n + 1`, `i <= j`, `x == 16`), a `%`
divisibility (`align % 16 == 0`) or a float class (`t.is_finite()`).

Facts come from a refined parameter (it holds at entry), the condition of an enclosing `if`/`while`
(and, in an `else`, the negation of a single comparison), an `assert`, a `for` loop's bounds
(`for i in v.len()` states `i < v.len()`), a `match` arm's pattern and guard, and a binding of one
term. A fact dies when it could stop being true: assigning to a name, a method call or a `&mut` on a
vector (its length), and a call, which may write through any name it is given. A loop is where that
rule has to look ahead: the body's first statement runs again after its last one, so every name the
body assigns, lends out with `&mut` or calls a method on loses its facts *before* the body starts.
`mut i = 0; while i < 3 { take0(i); i += 1; }` does not prove `i == 0` at the call - the loop's own
guard `i < 3` is the only fact about `i` in the body - while a name the body never writes keeps
what was known about it.

A term is a name, a length (`v.len()`), a literal, or a field reached through a binding nothing can
write - `c.at` and `c.items.len()` where `c` is a record that is not `mut` or a shared reference to
one. A field behind `&mut` or a `mut` binding is not a term: something between the test and the
call could write it. A comparison may carry a constant on either side (`i + 1 < v.len()`), and so
may an argument: `get(&v, i + 1)`, `get(&v, i - 1)` and `get(&v, v.len() - 1)` are proved from the
facts about `i` and `v.len()`. That arithmetic is the program's own, so it is read only in a checked
build, where a wrap stops the program before the callee is entered; under `--overflow=wrap` an
offset states nothing. A subtraction whose operands the facts order (`hi - lo` with `lo <= hi`,
`v.len() - 1` with `v.len() > 0`) keeps no underflow check, which is what lets a function that
computes a width be `@no_panic`.

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

Because a fact belongs to the block that stated it, a `match` arm's pattern is where its fact lives
and nowhere else:

```grl
fn pick(n: u64) -> u64 {
    match n {
        16 => take(n),            // proved: this arm is the one about 16
        _ => take(n),             // checked: the 16-arm's fact is not this arm's
    }
}
```

A guard counts the same way - `_ if n % 16 == 0 => take(n)` states it in that arm's body - and
binding a name again hides the facts about the outer value only while the new binding is in scope:
`{ i := 9; ... }` proves nothing about `i` inside the block and proves `i < v.len()` again after it.

A `%` fact carries through divisibility (`align % 32 == 0` proves `align % 16 == 0`), a float class
matches exactly (`t.is_finite()` proves `t.is_finite()`), and comparisons go through a small
difference graph, so transitivity works: `i <= j` and `j < v.len()` prove `i < v.len()`.

### Arithmetic in a condition

Integer arithmetic traps on overflow in a development build and wraps in a release build, and a
proof must not depend on which. So a constant added to a name is read in one of two ways, and the
same way in both builds:

```grl
fn walk(v: &u64[]) -> u64 {
    mut sum = 0;
    for i in v.len() {
        if i > 0 {
            sum += get(v, i - 1);     // 0 < i: `i - 1` cannot wrap, and i - 1 < v.len() follows
        }
    }
    mut j = 0;
    while j + 1 < v.len() {
        sum += get(v, j + 1);         // the guard and the argument name the same value, `j + 1`
        j += 1;
    }
    return sum;
}
```

Where the facts show the arithmetic cannot wrap, the constant is ordinary integer arithmetic:
`i - 1` needs a lower bound (`i > 0`, `i >= 3`), and `i + 1` needs something above `i` (`i < n`,
or a literal bound such as `i < 10`). Where they do not, the whole expression is one opaque value:
a fact about `j + 1` proves an obligation about `j + 1` and nothing about `j`, and it ends when `j`
is written. That is why `get(v, i - 1)` under `i < v.len()` alone is not proved - `i` may be `0`,
and in a release build the argument would be 2^64-1 - and why `i + 1 < n + 1` does not prove
`i < n`. The rule covers `u64`; a sized integer's sum is always the opaque kind.

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
entry, so a proof that is wrong aborts instead of passing unnoticed. The corpus runs this way. The
prover has been wrong once: a fact stated before a loop was still believed inside it after the body
had written the name, and that was found by review rather than by this flag, because no case then
wrote a refined name in a loop and the driver did not pass the flag on to the compiler. Both are
fixed and pinned (`refinement-loop-write-*`). A second one of the same family was found the same
way: a call in a `while` guard was proved from facts the loop's body ends, although the guard runs
again after every iteration (`refinement-wrap-loop-guard-call-*`). That is the honest form of the claim: the prover's
power is an optimisation, and each rule that removes a check has a case in which the check must
still fire.

## Checked effects

A refinement states what is true of a value. An effect attribute states what a function never
does, and the compiler proves it over everything the function can reach:

```grl
@no_alloc
fn sum(v: &u64[]) -> u64 { ... }        // no heap allocation, in it or in anything it calls

@no_panic
fn get(v: &u64[], i: u64 where i < v.len()) -> u64 {
    return v[i];                          // no runtime check is left that could fail
}

fn drain() {
    @bounded(64)
    while i < 64 { i += 1; }               // at most 64 iterations, proved from the counter
}
```

The proof walks the call graph, the runtime's own included: a function allocates exactly when a
chain of calls reaches the allocator, and it can fail exactly when a chain reaches a runtime check
that the prover did not remove. The refusal names that chain:

```
error: `@no_alloc` function `grow` performs a heap allocation: it calls grow -> rt_push -> rt_grow
```

A refined parameter's check belongs to the caller. A `@no_panic` function that calls `get` with an
index it has proved in bounds reaches `get`'s proved entry and passes; one that has not is refused,
because the call goes through the check. Overflow is a failure too, and in every build: a release
build wraps where a development build traps, but the claim is about the program, so `@no_panic` is
judged as if the arithmetic could trap and both builds accept exactly the same functions.
`@no_panic` arithmetic either cannot overflow from the facts the prover has - `hi - lo` with
`lo <= hi`, `i + 1` with `i < n` - or is written with the wrapping operations (`wrapping_add`,
`wrapping_sub`, `wrapping_mul`), which never fail.

An effect claim crosses a module boundary through the interface file: each claimed function has an
`effects` row, so a caller is checked against the row and not against the body. The facts are
recorded as each statement is emitted, not read back out of the assembly, so a check the prover
removed is not in the graph at all - that is what makes `@no_panic` exactly as strong as the prover.

Indirect calls in user code (a function value, a `dyn` method) are unknown and refused under both
attributes. The compiler's own dispatch is followed instead: a record's or a vector's drop helper
calls the field's or the element's helper directly, and a `dyn` value's drop is resolved through the
vtable to the drop helper of every concrete type that vtable can hold, because the compiler built
that vtable itself.

One record per emitted body means a generic is judged per instantiation. A `@no_alloc` function that
only reaches a quiet instance of a generic is accepted even when another instance of the same generic
allocates, and a claim on the generic itself is checked for every instance that is emitted - the
refusal names it:

```
error: `@no_alloc` function `fill<main::File>` performs a heap allocation: it calls fill<main::File> -> rt_push -> rt_grow
```
