# Required gates before aggregate/reference expansion

2026-10-30. Follow-up implementation criteria, **not implemented functionality**. The complete v0
goal stays active. See [bootstrap v0](bootstrap-v0.md), [modern Rust baseline](rust-next-baseline.md),
and the [Blu/Lust source review and executable aggregate controls](lust-and-blu-notes.md).

The primitive seed is deliberately simpler than a general ownership checker. Its byte/string owners
contain no references. Extending that representation by unioning every root into one set would be
wrong: an owner's **storage** and the loans **captured in its contents** are different obligations.

## Concrete compiler/library programs that must drive the implementation

1. A token record with a borrowed source span and numeric offset; collect tokens while reading the
   same source. The source stays live through the collection, without freezing readonly descriptors.
2. A record containing an owned name and a borrowed span. Moving/dropping one field cannot lose the
   other field's cleanup/loan. Freeing the record must release its captures, not wait forever on them.
3. Owned fields moved through functions and returned on different branches; reject use of moved or
   possibly-uninitialized fields, but free every remaining owner exactly once on every normal exit.
4. Generic vectors of tokens and of owners; moving/extracting an element transfers its obligations.
   Unique-reference elements are affine, not implicitly duplicated. Trusted splits/iterators require
   disjointness validation, not the false inference that equal lifetime roots imply equal targets.
5. A setter taking a mutable reference to a cell containing a borrowed view. Its written lifetime
   bounds must keep **all** potentially installed sources live, even with the provider body hidden.
   The implementation may conservatively retain old sources; it must never forget new ones.
6. Enum/Result variants with owning/borrowing payloads: discriminate before projection, transfer only
   the active payload and clean up on both success/error and early return. Dropping an inactive
   variant's payload or freeing a source retained by the error payload is a failure.

## Representation/analysis requirements

- Separate place/storage identity, captured lifetime dependencies, and exclusive authority. No
  inference of full alias safety from an aggregate union of lifetime roots.
- General references must distinguish borrowing a cell/container object from reading its contents.
  The current byte-view descriptor-copy rule does not license copying arbitrary exclusive accesses.
- Fields need initialized/moved state and recursive cleanup. When control flow leaves different
  states, implement sound joining/drop flags or diagnose a genuinely unsupported case explicitly;
  do not silently discard a cleanup obligation or declare this part of v0 complete.
- A mutable reference to a reference-containing T cannot preserve only the caller's pre-call contents.
  Type/region constraints must account for other values admitted by invariant T. This can come from
  written types and local region facts; it need not adopt G1's precise post-state transformer.
- Calls must honor value materialization/evaluation order before adding general mutable references.
  The source frontend now copies/moves each user-call argument into a fresh value immediately,
  rather than retaining its register place until the final call. The primitive affine-use regression
  is covered. Richer mutable-reference effects and indexed/field operands still need their own
  execution cases; recheck the earlier call-activation study, not just the byte-only subset.
- Exported type definitions/layouts, lifetime bounds and recursive drop behavior must be part of the
  checked interface/invalidation boundary. A bare record name is not a complete ABI fingerprint.

## Validation and stopping conditions

Use actual compiled source programs, allocator/generation/permission checks where applicable, and
stable plus pinned modern Rust controls. Unsupported syntax is not a passing safety test. The type
checker must have enough semantics to exercise a failure before its rejection counts as evidence.
Retain positive cases as well as negatives so conservative rejection cannot masquerade as precision.

If the architecture cannot support these programs without whole-program analysis, excessive cost or
new user bookkeeping, record the counterexample and revise the design explicitly. Do not silently
replace v0 with an owner-only subset, permanently ban reference-containing containers, or mark a
partial implementation complete. No general soundness claim follows from the current finite tests.
