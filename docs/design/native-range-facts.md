# Range facts on the native backend

Status: implemented, 2026-11-13. Companion to [typed-ir.md](typed-ir.md), whose *range fact* (F3) is
the same question asked over the emitted word stream by the LLVM lifter. This note covers the native
backend, which reads the facts from the **source** at each access instead.

## The lever

The only place a bounds check lives is the sequence accessors in `compiler/runtime.grl`. Each begins

    fn rt_slot(s: u64, i: u64) -> u64 {
        if (i < raw_load(wrapping_add(s, 8))) == 0 { rt_fail(1, i, raw_load(wrapping_add(s, 8))); }
        return wrapping_add(raw_load(s), wrapping_mul(i, 8));
    }

and the front end already substitutes the *unchecked* sibling (`rt_slotu`, `rt_slot4u`, `rt_atbu`)
only where it has a proof. Before this change that proof was syntactic: `len_bound_ahead`, which
accepts `for i in 0..v.len() { .. v[i] .. }` only when the body names `v` nowhere except `v[x]` and
`v.len()`. Everything a real loop does - any other statement about `v`, an inner loop, a guard
written as an `if` or a `while`, an index expression - lost the proof and kept the check.

`pv_in_bounds_at` (`compiler/native.grl`) asks the prover's own question instead: *do the facts at
this program point imply `index < base.len()`?* The facts are the ones the refinement prover already
collects for its obligations (`pv_scope`), so a fact is established by

- a **dominating guard**: `while i < n`, `if i < v.len()`, `assert i < v.len()`, and the negation a
  failed `else` gives;
- the **loop's own bounds**: `for i in 0..v.len()` states `i < v.len`, `for i in n` states `i < n`;
- a **refined parameter**: `where i < v.len()` holds at entry, by the entry check or the caller's
  proof;
- an **allocation**: `v = u8[0; n]` states `len(v) == n`, `v = f64[1.0, 2.0]` states
  `len(v) == 2`, `w = v.copy()` states `len(w) == len(v)`;
- a **counted fill loop**: `for i in n { .. v.push(x) .. }` runs n times and pushes once per trip, so
  it leaves `len(v) >= n` behind. Read only when the body has no control flow (nothing can skip a
  push), no loan, and no other mention of `v` (nothing else can move the length).

and a fact is **dropped** on a write, a binding of the name, a loan, a method call on it, a call that
can reach it - so anything that can move a length between the guard and the access takes the proof
with it. Two cases stay conservative on purpose: a call whose *argument list* holds the access has
not run yet where the access is, `&NAME` is a shared loan that forbids a write, and `NAME[i]` in an
argument hands over one element or its address, never the header - so none of those three kills a
fact.

## Answering `index < base.len`

Two readings, both conservative:

1. **the difference graph** (`pv_implies`, the one the refinement prover uses): the index is one
   term plus a non-negative literal (`i`, `j + 1`), and the graph closes the facts over the terms to
   show `index - len <= -1`. This is what proves a guard stated against a length.
2. **a literal interval**: the largest value the index expression can take, from the literal bounds
   the facts state on each name in it and exact integer arithmetic over `+ - * /` (a non-negative
   result, every intermediate value below 2^32, and `-` / `/` only by a literal), against the
   smallest value the length is known to have. This is what proves `p[i * 3 + 1]` against a
   15-element allocation, and `a[i * n + k]` against a 65536-element one.

An expression shape the reader does not know is not evaluated, a term the facts do not bound has no
interval, and a length with no stated floor is not compared: in each case the check stays. The pass
never assumes anything the source did not state, so it cannot remove a check that would have fired.

## Verification

`--verify-facts` keeps **every** check on the native backend: `index_proved` and the syntactic proof
both return false, so the accessors called are the checked ones. A `--verify-facts` build is
therefore the same program with all its checks, and a corpus that prints the same numbers under it is
a corpus the proofs did not change. On the native backend the flag also keeps the runtime check of
every refinement obligation the prover discharged (it already did).

`--no-range-facts` turns the pass off entirely (the pre-change behaviour), which is how the "before"
column below was measured.

## Measured

`bench/` on Linux x86-64, native backend, one compiler built from this branch; "before" is the same
compiler built with `--no-range-facts`, so the two sides differ only in the checks. Checks are
counted in the program's own functions: a call to a checking accessor (`rt_slot`, `rt_slot4`,
`rt_slotb`, `rt_at`, `rt_at4`, `rt_atb`, `rt_write`) or the arm the optimizer inlined out of one.

| benchmark | checks before | checks after | time before | time after | ratio before | ratio after |
| --- | --- | --- | --- | --- | --- | --- |
| fnv     | 1 | 0 | TIMING | TIMING | RATIO | RATIO |
| sieve   | 2 | 1 | TIMING | TIMING | RATIO | RATIO |
| sort    | 8 | 8 | TIMING | TIMING | RATIO | RATIO |
| nbody   | 32 | 15 | TIMING | TIMING | RATIO | RATIO |
| matmul  | 4 | 1 | TIMING | TIMING | RATIO | RATIO |

`nbody` keeps 15 checks inside `energy`, whose three parameters are shared views: their lengths are
not known there, which is the fact that function does not have. `sort` keeps all 8: its merge loop
bounds `i` by `mid` and `j` by `hi`, and both are clamped into `[0, n]` by `if mid > n { mid = n; }`,
a fact that only holds at the *join* of the two paths. The prover reads a block's own edge facts, not
a join, so the clamp states nothing and the checks stay (the access is still correct - it is just
checked). `sieve` keeps one byte store: `rt_write` checks the value as well as the index, and there is
no unchecked byte-store accessor.

## What is missing

- **join facts from clamps** (`if X > n { X = n }`) and short-circuit reasoning inside `a && (b || c)`:
  both are needed by `sort`'s merge loop and by nothing else on this corpus.
- **a length floor that survives a push**: `while i < 5 { v[i]; v.push(0) }` keeps its check because
  the push drops the exact length. A `len >= L` floor that a push does not drop is the native
  counterpart of the lifter's own lower bound.
- **byte stores**: an unchecked `rt_write` (index only, value still checked) would remove sieve's
  last arm. It is deliberately not added yet: the LLVM lifter would have to learn the new accessor,
  and the native win is a compare per composite number.
