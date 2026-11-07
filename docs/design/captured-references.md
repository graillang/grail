# Readonly references with captured sources

This records the shared-reference / stored-source versus outer-frame checkpoint. It is now extended
by [mutable lifetime witnesses and opaque writeback](mutable-references.md). General heap containers,
ownership joins and bootstrap remain required; this is not completion of v0.

## Source contracts

```grl
struct Cursor<data>{source:read<data>,name:string}
fn source<outer,data>(cursor:(&outer Cursor<data>))->read<data>{
    return &cursor.source;
}
struct Unique<data>{source:mut<data>}
fn short<outer,data>(cursor:(&outer Unique<data>))->read<outer>{
    return &cursor.source;
}
```

The first operation copies a shared descriptor. Its output retains the data source independently
of the cursor's short storage loan: the cursor/name can be destroyed while the source view remains.
The second reborrows a unique descriptor held in borrowed storage. It retains both the data source
**and** the outer frame/authority and cannot claim the field's longer `data` lifetime. Adding an
unrelated long-lived input to its signature does not excuse returning the wrong body's short borrow.
Neither same lifetime labels nor origin unions establish aliasing or unique authority.

Known shared descriptors can be explicitly copied with `load`: readonly byte views/holders and
readonly typed-reference descriptors. Affine owners and unique descriptors cannot be copied by
`load`. Numeric/unit loads remain as before. For example, loading `(&outer (&data num))` returns
a pointer retaining `data`, not the short descriptor-storage lifetime. This is an explicit operation,
not a new blanket Copy trait or arbitrary projection rule. `read` also copies/reborrows byte
view/holder descriptors behind a typed reference. Typed field byte access rejects numeric pointers,
rather than checking them as byte views and later emitting an invalid C member access.

Readonly typed references now admit captured values, including bounded nested typed references.
`borrow(value)` is therefore universal over admitted opaque `T` without a hidden plain-type bound.
Mutable captured references now use invariant witnesses instead of a lifetime-free kind restriction;
see the [mutable checkpoint](mutable-references.md).

## Provenance and implied bounds

A typed storage path has an explicit dereference step. Parameter frame roots and roots inside
stored descriptors can no longer collide at the same field path. Abstract pointee cells and local
possible places remain separate from data/capability roots. No root, loan, lifetime value or witness
is added to native specialization keys.

Written input types determine a reference-source contract and implied outlives graph. In
`(&outer Cursor<data>)`, the physically stored source must outlive the outer borrow (`data ≥ outer`).
Nested references add the corresponding transitive constraints. Unused nominal lifetime/type
arguments do **not** invent physical-capture outlives facts. Output types do not supply assumptions
that their own producer was supposed to prove.

Call results conservatively collect all eligible sources from these declared contracts, including
stored sources reached through pointees. A stored shared descriptor may contribute independently
of enclosing short frames. A stored unique descriptor may contribute a reborrow only within every
relevant frame's validity and permitted mode. Its parent authority is retained. Actual value paths
are read without repeatedly cloning entire pointee trees. This is G0 signature/type accounting,
not private-body post-state inference or caller-root specialization of generic checking.

Return checking also descends through referenced values. Merely returning the same outer pointer
cannot change `Cursor<short>` into `Cursor<long>` when its actual stored roots do not satisfy the
written relationship. Local address/capture escapes still reject. Mutable referent invariance is
separately enforced by the witness implementation, not inferred from readonly covariance/origin checks.

Automatic capture ending must respect live storage-frame loans: a cursor's stored descriptor cannot
expire while a reference can still access it. A long copied shared result releases only the cursor
frame; its independent data loan still prevents data-owner growth/destruction until the result ends.
A short unique-field result retains the cursor frame and blocks dropping/reusing it prematurely.

## Lowering, limits and TCB

C emits proper nested const qualification, pointer/descriptor loads and field accesses. Comparison
LLVM executes descriptor copies and numeric nested pointers at development/optimized settings;
heap/nominal operations retain the backend restrictions. Existing canonical schemas gain no second
reader or compatibility path; old unaffected C/API outputs remain exactly identical.

Reference/pointee provenance expansion is bounded to depth 64 / 4096 nodes per type; possible-place
and dereference-result cardinalities cap at 4096. Recursive reference shapes that exceed this graph
budget reject before recursive parameter materialization. This is a current implementation limit,
not a claim to have solved regular recursive pointer graphs or to exclude their needs from v0.
Existing ownership joins, mutable parent field-splitting and coarse diagnostics remain limitations.

The compiler/checker, provenance/substitution/IR codec, native producers/toolchains/runtime and host
are in the TCB. Hashes bind bytes, not producer honesty or a soundness theorem. Source-hidden bodies
and generic templates independently check; native instantiation substitutes layouts, not caller
roots. No provider/model changes or delegation are involved in this work.

## Evidence / remaining hard gates

Run `python research/experiments/captures41/check.py`; see
[retained evidence](../../research/evidence/captures41-20261031/README.md). It combines independent
Rust positives/negatives, source-hidden mixed-native calls, C/LLVM ABI controls, exact allocator /
ASan/UBSan traces, frozen old-compiler replay, capture-cardinality checking costs and a real
131072-token library workload with a borrowed cursor and owned names.

The [mutable checkpoint](mutable-references.md) extends this evidence with invariant stored bounds,
opaque writeback, unique take/pop and mutable cursor updates. Arbitrary-element heap collections,
general joins, the real seed port, stage-2/stage-3 and a reproducible bootstrap artifact remain mandatory.
