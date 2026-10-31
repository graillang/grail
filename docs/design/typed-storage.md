# Typed storage foundation — partial reference gate

This implements addressable storage and **lifetime-free referents**. It is not the complete
[typed-reference/invariance/writeback gate](generic-lowering-gates.md). Captured-reference cursors,
mutable cells/vectors of references and arbitrary-element heap containers remain required work.
Their unsupported cases are not counted as successful rejection proofs.

## Source

- `ref<a,T>` and `ref_mut<a,T>` reference a storage object, unlike byte-data `read<a>` / `mut<a>`.
- `borrow(place)` / `borrow_mut(place)` take or reborrow a typed reference. Places include record
  fields. Reborrowing a mutable reference freezes its parent until the child ends. Existing
  byte-data borrow syntax and the UTF-8 prohibition on mutable string bytes are unchanged.
- `load(reference)` copies a number/unit, not an arbitrary affine value. `exchange(reference,value)`
  replaces a whole initialized referent and returns its previous value by move. `core::replace`
  is a real universally checked Grail wrapper around that operation.
- Numbers/unit, owned text/bytes and lifetime-free records/enums can be referents. Numeric fields
  can be read through references; byte fields can be read/borrowed, and fields can be separately
  addressed. `push` / `append_text` accept a suitable mutable reference to the owner descriptor.
  `len` accepts referenced byte/text storage; use `read(reference)` for indexed byte access.
- `var` still governs bare `=` syntax. It is not deep const qualification of owned values; requesting
  mutable access remains explicit, as with the prior `mut(bytes_owner)` operations.

```grl
fn change<a>(slot:ref_mut<a,string>,value:string)->string{return exchange(slot,value);}
pub fn run()->num{
    let name="old";
    let previous=change(borrow_mut(name),"newer");
    return len(name)+len(previous);
}
```

Current formal typed references cannot have any lifetime-bearing referent, including phantom
lifetime slots or references in unused nominal type arguments. These deliberately fail closed:
`ref_mut<short,Cell<long>>`, `ref_mut<short,Vec<read<long>>>`, nested reference types and equivalent
nominal wrappers. Local constructor placeholder labels have **not** been upgraded to invariant
witnesses. The source/IR type universe for this checkpoint excludes those referents, not v0 itself.

A generic body must not hide a restriction by forming `ref<T>` internally and waiting for native
specialization to fail. Well-formed reference uses in its **written signature** expose which type
parameters must have lifetime-free instantiations. Universal body/call/constructor checking admits
only those requirements. For example, `replace(ref_mut<a,T>,T)->T` exposes its requirement, whereas
`f<T>(T)->num` cannot silently take a restricted typed borrow of its opaque input. The requirement
is derived from canonical signature/layout types; there is no unencoded private-body predicate or
caller-root rechecking. This temporary kind restriction is not an elaborate trait system and must
be removed/revised with the full witness/writeback implementation, not treated as a v0 concession.

## Storage, ownership and effects

Typed references carry possible **places** independently of data/lifetime roots. External cells are
abstractly initialized from the signature; local cells remain tied to their register/field storage.
A result reference conservatively admits compatible subplaces of declared inputs. Linear references
retain their own authority even when those may-place/root sets overlap. Mutable calls uniformly
invalidate/reconstruct possible pointee content metadata according to its declared type, including
references nested in by-value carriers: they do not inspect private bodies for G1 post-states.
With no captured references in referents, this concerns initialized ownership/tag metadata only.
It is **not** the general capture-retaining writeback solution.

An addressed scalar stays in the checker until its loans end; direct reads, overwrite or end obey
shared/exclusive storage exclusion. Once no reference remains, the scalar can use the prior compact
liveness path again. Owned moves re-identify only owned storage at the destination; captured external
roots/capabilities are preserved. Outstanding storage/data borrows still prevent relocation. This
keeps moved fields independent of their former container and keeps mutable replacement stable over
loop edges. Prefix queries use the existing ordered access index instead of scanning all live roots. Loan
retirement visits only possible targets, not every addressed scalar. Loop-body live-out sets retain
borrowed entry values across nested expression blocks; the mutable scanner exposed and tests the
previous premature ending before a counted backedge.

References cannot move affine values out with `load`, fabricate local escapes, bypass string UTF-8,
borrow uninitialized/partially moved storage, or release a borrowed owner. Field reborrows through
one mutable reference currently freeze that whole parent; simultaneous disjoint projections through
that parent are less precise than Rust. Direct disjoint local-field loans and sequential exchanges
are available. Remaining ownership joins and practical precision are not claimed complete.

C emits typed pointers and real indirect loads/stores, with move/drop flags preserved for both old
and new owners. Numeric references also execute through comparison LLVM at `-O0`/`-O2`; nominal/heap
LLVM restrictions remain. Existing schema numbers are extended with canonical reference words and
address/load/exchange operations, without an alternate compatibility reader. Old readers cannot
consume the new words/operations. Native keys still erase lifetime values, not modes/layouts.
Possible reference target sets are bounded to 4096; existing structural budgets apply too.

## Evidence and next gate

`python research/experiments/references40/check.py` checks full stable/nightly suites, hidden-source
mixed-profile calls, generic exchange/owned destruction, allocator balance/ASan/UBSan, independent
Rust, exact frozen compiler replay and scalar/reference checking costs. See
[retained evidence](../../research/evidence/references40-20261031/README.md).

Next remain real invariant lifetime witnesses, outer-frame versus stored-source validity, opaque
capture writeback, unique take/pop authority with residual may-sources, arbitrary-element containers,
usable captured-reference cursors, the real seed port and deterministic stage-2/stage-3/artifact.
None is silently excluded, and bootstrap v0 remains active.
