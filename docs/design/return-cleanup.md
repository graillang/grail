# Terminating control flow and ownership cleanup

The checked IR has a real `Return(reg)` terminator. Source bodies no longer require a special tail
return. The low-level typed-IR builder still accepts an optional fallthrough result, used by parser-
independent checker/backend fixtures; it is not a dummy register or a source-language fallback.

On a source return, last-use loans end and remaining owners drop in reverse binding order, except
the returned register. Nested owned record fields drop in declaration order, testing per-field flags.
Moving `token.inner.name` out clears that leaf's flag. This is default recursive destruction, not a
custom `Drop` interface. Abort paths do not promise cleanup.

Each return checks its declared result and origins, independently of other paths. A local allocation
or the storage of an owned parameter cannot stand in for a captured input lifetime. Default record
destruction does not dereference captured view descriptors: a returned shared reborrow of a unique
span does not keep an unrelated owned name alive. Loans into the name itself still prevent freeing
it. Captured byte views remain descriptors, not general references into the record's frame.

Terminated arms do not join into the continuation. When both arms continue, resource bindings and
recursive field states must agree exactly; matching partial moves are supported. Numeric temporaries
are available after a join only when defined on both continuing paths. Loops may execute zero times;
only continuing paths must restore their back-edge ownership state. An early return inside a loop
cleans enclosing owners too. Unconditional blocks preserve actual effects. Missing returns and
unreachable statements diagnose rather than being filled with placeholder returns.

C lowering emits the explicit cleanup/return operations. Primitive LLVM lowering emits no branch
following a terminated arm and no unnecessary merge block when both arms return. Used heap/record
layouts still require the production C backend; the LLVM backend rejects those layouts explicitly.

## Evidence and remaining work

`research/experiments/returns31/check.py` runs the full stable/nightly conformance suite, explicit
TinyCC return tests, Clippy and independent Rust controls. Native tests link the selected backend's
immutable objects, not a replacement C recompile, with a separately compiled allocator wrapper.
Both return-field paths check exact live counts, balanced release and final free ordering. A hidden
provider allocates a temporary and returns one owned field through a branch or loop while freeing
the other field. A second program returns a captured span, frees its owned carrier name, and safely
regains source growth after the span's last use. Primitive C/LLVM paths execute empty/input-hit/
input-miss cases equally.

This is not a full CFG ownership join solution. Unequal continuing field states, owned assignment
and `break`/`continue` remain to implement. (Generic Result/Option, listed here at the time, have
since landed: [generic results](generic-results.md).) Postfix `?` uses this same return cleanup; see
[propagation](error-propagation.md). Concrete tagged enum
matching and unwrap are now implemented; see [tagged enums](tagged-enums.md). The synthetic flat
branch cost harness revealed cumulative-state clone overhead (roughly quadratic). The scalar/type
ledger issue is now addressed in [checker state](checker-state.md), retaining frozen before/after
measurements; this does not establish full self-hosting ergonomics/performance. It is a Rust seed
measurement, not a cost bound or a representative completed Grail compiler benchmark.
