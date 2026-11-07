# Mutable captured storage — witness/writeback checkpoint

Typed mutable references now admit captured values, including references in generic arguments.
This removes the temporary lifetime-free referent/kind gate, not any v0 requirement. General heap
collections, changing-state ownership joins, practical diagnostics, the real compiler port and
self-compilation are still required. See [the retained gate](../../research/evidence/mutable42-20261031/README.md).

```grl
struct Cell<data>{source:mut<data>,name:string}
fn take<outer,data>(slot:(&mut outer Cell<data>),next:mut<data>)->mut<data>{
    return exchange(borrow_mut(slot.source),next);
}
```

## Bounds belong to types, not current contents

Each checked value has lifetime witnesses separate from native type labels and possible data roots.
A witness is an intersection of declared lifetime bounds and lexical storage scopes. Formal bounds
outlive local scopes; scope nesting and input-implied relationships determine the remaining order.
Scopes are discovered structurally before cleanup, with depth/operation limits. Constructor label
zero is never evidence that two independently scoped owners have the same lifetime.

Shared value/reference coercion is covariant where the physical type permits it. A mutable reference's
**entire pointee lifetime instance is invariant**, including unused nominal slots/type arguments.
The outer pointer lifetime may shorten without changing that stored instance. Call inference first
pins invariant positions, then solves covariant and referent-well-formedness constraints. An incoming
short source cannot shorten an existing cell's stored bound. Explicit constructor ascriptions check
against the named formal bounds; inactive enum alternatives can be instantiated without inventing a
live reference. Finite phantom layouts do not recursively expand unused argument structure.

Generic type arguments keep lifetime namespaces independent of callee binders and other type
arguments. Instantiating opaque `T` does not accidentally equate its captured lifetimes with the
short borrow of `(&mut outer T)`. Bodies still check universally; caller roots do not recheck them.
Witnesses, scopes and roots do not enter native instance keys or runtime descriptors.

## Exchange, transfer and opaque calls

Primitive `exchange` checks the incoming value against the target's established bound, returns the
old value with its actual captures/targets, and assigns fresh returned capabilities. Stored slot
capabilities retain their positional identities. Index updates cover local and external pointees;
ghost external cells are not heap owners requiring local destruction.

A unique descriptor behind shared storage can only be reborrowed within its enclosing frames.
With all enclosing frames mutable, a verified body may instead transfer a unique value out by
replacement. A long transfer retains its data/parent authority but not the discarded slot borrow.
Merely reborrowing the field is still short; adding a long input anchor does not excuse a bad body.
Typed result targets are filtered by nested variance/invariance, not just native layout compatibility.

Opaque writeback uses **all eligible sources in the written signature**, including old contents and
incoming captures. It does not assert which field a private body actually modified, or assume a pop
left None. Residual and returned unique capabilities may have overlapping origin may-sets without
being the same authority. Both conservatively retain the relevant data owners. Post-state values
keep the target's established lifetime instance. One call caches reference projections by full written
type over its immutable input snapshot; equal fields reuse a union rather than recomputing it.
This is G0 contract accounting, not private-body G1 effects.

## Cleanup and current closure limits

Capture expiry tentatively removes a container's own capture group, restores every member still
needed by external users to a fixed point, then retires the remaining internal-only group together.
Default destruction similarly distinguishes internal capture cycles from external loans. This does
not let a live external frame/child lose the descriptor it can still access. Owned fields continue
to receive deterministic recursive cleanup; descriptor destruction does not free borrowed data.

A reproduced stale-proof bug showed why checking only local loop-entry values was insufficient.
[Retained-slot joins and fixed points](capture-joins.md) now widen local/external captures and recheck
later iterations, while preserving zero paths, live parent freezes and immutable stored bounds.
The temporary exact external-state barrier was removed. General conditional ownership, differing
partial initialization, addressed-scalar joins and finer field/parent loan ending still remain; they
are not approved permanent concessions to v0.

## Protocol, limits and evidence

Canonical checked IR and template bundles are schema **2**, including an explicit lifetime-ascription
operation. Old payloads require rebuilding; there is no alternate reader or retired kind-check route.
Existing module/function/artifact schemas remain unchanged. C and numeric/descriptor LLVM execute
captured exchange; the existing nominal/heap LLVM limits remain.

Reference expansion, source/target/projection cardinalities and lifetime comparisons are bounded;
structural depth is 64, source/target sets and distinct per-call projections cap at 4096. Scope walks
cap at 262144 operations. Loop capture fixed points cap at 4096 rounds. Regular recursive reference graphs and general ownership joins are still
unfinished, not language requirements silently excluded from bootstrap. The checker, provenance,
substitution/IR codec, native producers/toolchains/runtime and host remain in the TCB. Passing these
finite tests is not a soundness theorem or whole-compiler performance result.

Run `python research/experiments/captures41/check.py --mutable`. It shares the maintained readonly gate,
checks stable/pinned-nightly Rust, source-hidden mixed native calls, generic Option pop and Result
cleanup, C/LLVM exchange, allocator/sanitizer contracts, a frozen replay, checking costs and a real
131072-token mutable cursor workload. This remains library/compiler groundwork, not self-hosting.
