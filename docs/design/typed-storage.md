# Typed storage foundation — partial reference gate

This records the initial addressable-storage checkpoint, now extended by
[readonly captures](captured-references.md) and [mutable witnesses/writeback](mutable-references.md).
The temporary lifetime-free referent/kind gate has been removed. General heap containers, joins and
self-hosting remain required work, not successful unsupported-type rejection proofs.

## Source

- `(&a T)` and `(&mut a T)` reference a storage object, unlike byte-data `read<a>` / `mut<a>`.
- `borrow(place)` / `borrow_mut(place)` take or reborrow a typed reference. Places include record
  fields. Reborrowing a mutable reference freezes its parent until the child ends. Existing
  byte-data borrow syntax and the UTF-8 prohibition on mutable string bytes are unchanged.
- `*reference` copies a number/unit, not an arbitrary affine value. `exchange(reference,value)`
  replaces a whole initialized referent and returns its previous value by move. `core::replace`
  is a real universally checked Grail wrapper around that operation.
- Numbers/unit, owned text and byte vectors and lifetime-free records/enums can be referents. Numeric fields
  can be read through references; byte fields can be read/borrowed, and fields can be separately
  addressed. `.push(...)` / `.append(...)` accept a suitable mutable reference to the owner descriptor.
  `.len()` accepts referenced byte/text storage; use `&reference` for indexed byte access.
- `mut` still governs bare `=` syntax. It is not deep const qualification of owned values; requesting
  mutable access remains explicit, as with the prior mutable byte-owner operations.

```grl
fn change<a>(slot:(&mut a string),value:string)->string{return exchange(slot,value);}
pub fn run()->num{
    mut name="old";
    previous := change(borrow_mut(name), "newer");
    return name.len()+previous.len();
}
```


## Storage, ownership and effects

Typed references carry possible **places** independently of data/lifetime roots. External cells are
abstractly initialized from the signature; local cells remain tied to their register/field storage.
A result reference conservatively admits compatible subplaces of declared inputs. Linear references
retain their own authority even when those may-place/root sets overlap. Mutable calls uniformly
invalidate/reconstruct possible pointee content metadata according to its declared type, including
references nested in by-value carriers: they do not inspect private bodies for G1 post-states.
The initial plain-cell implementation refreshed ownership/tag metadata only. The
[mutable extension](mutable-references.md) now retains old/incoming captures and invariant bounds.

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
