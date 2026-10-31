# Loop exits and scope cleanup

`break;` and `continue;` are implemented for counted and while loops, including nested blocks,
conditionals and consuming enum matches. Both target the **innermost enclosing loop body**. They
are checked IR operations, not fake function returns, parser-only sentinels or runtime exceptions.

- Counted `continue` runs the counter increment and then checks the bound; while `continue`
  re-evaluates its condition. A counted bound is still evaluated only once.
- `break` leaves the loop without another condition evaluation.
- Before either transfer, local loans close and remaining local owners drop in reverse binding
  order, with the existing recursive field/active-variant cleanup and partial-move flags.
- Outer owners/views survive. Function return remains different: it closes the function's owners
  and checks actual return origins rather than preserving a loop-entry frame.
- Unreachable statements diagnose; outside-body exits reject, including jumps from raw while
  condition IR to a surrounding loop. A loop nested **within** a condition may have its own exits.

## Independent checker boundary

Each loop body has an immutable entry snapshot of live values and scalar-definedness bits. Branch
states share that snapshot, not a mutable ownership state or whole-state recursive clone. After
source cleanup, every exit independently checks closure and exact entry resource/value identity.
It cannot hide a moved outer owner, a leftover local heap value, an unclosed loan, changed partial
moves/capture state, or a lost entry numeric definition—even when all branch paths terminate.

Source synthesis and the final raw-IR checker both validate the exit. Scalar entry facts stay live
through synthesis, matching final loop-body checking. The monotonic type ledger remains separate
from definite initialization; a loop's zero-iteration path still establishes no body-only bindings.
Nested frames do not escape into function checking or the native layer.

While-condition checking temporarily suspends outer jump targets; conditional **function returns**
from `?` still work. Loop body frames are restored for ordinary checking. Continuing backedges retain
the prior closure check, and joins ignore paths that have independently validated a transfer.

This deliberately preserves the existing **conservative entry-state invariant** for exits. Rust can
accept moving/dropping an outer owner immediately before a break when it is not used afterward;
Grail currently rejects it. Numeric values may change, but remaining resource state must agree with
entry. General conditional ownership/drop joins are still required work, not solved or silently
removed from the v0 goal. This slice adds practical loop control without claiming full Rust precision.

## Native targets

C uses function-local unique loop labels. It does not emit an ambiguous `break` inside a `switch`
for a source match. Continue labels are at the counted latch / while-body end; break labels are
outside the loop. Nested/reused IR counter registers cannot collide in the label namespace.
Only needed labels are emitted, so programs without exits retain their prior C.

LLVM uses actual branch destinations, with a counted latch when a continue needs one. The numeric/
byte-view subset executes through both C and LLVM at `-O0`/`-O2`; the independent LLVM backend
continues to reject heap/nominal layouts explicitly rather than pretending to support their cleanup.
No interface schema, foreign ABI or additional exception runtime is introduced.

## Evidence

Run `python research/experiments/loops38/check.py`. The retained gate covers stable and private
nightly full suites, clang development/release and TinyCC execution, immutable hidden-source calls,
nested/match destinations, numeric results, shared reborrow release followed by unique access, and
complete ownership traces. Selected development objects are audited, alongside independent optimized
ASan/UBSan C with allocation observation preserved. Production optimizer settings remain unchanged.

The allocating-condition/partial-record case releases `[2,3,4,5,6,7,1]`: no third condition allocation
occurs after the break. Owned match payloads release `[3,2,5,4,1]`. Independent Rust scopes/Drop
controls produce those same sequences; a separate accepted Rust outer-move control records the
conservative Grail mismatch honestly.

A frozen prechange compiler checks the same 1,600-case compile/lower-only regression corpus and
sequential-loop cost programs. Generated invalid or potentially nonterminating IR is **never run**.
Checking/emission costs and unchanged acceptance/C/API output are recorded in
[retained evidence](../../research/evidence/loops38-20261031/README.md). This is validation evidence,
not a soundness proof, generic mutable-reference solution or self-hosting demonstration.
