# Structured dependency routes

2026-10-30. [Proof](../../research/experiments/instantiation11/Routes.lean),
[runner](../../research/experiments/instantiation11/README.md),
[evidence](../../research/evidence/routes12-20261030/). An extension of the
[symbolic-instantiation proof](symbolic-instantiation.md), not a full typed-language theorem.

## Why a flat root union is insufficient

A record may have left data requiring source A and right data requiring source B. Releasing A after
clearing left requires keeping the positions distinct. A safe whole-value union can retain too much;
copying it to every descendant destroys precision. Opaque generic forwarding therefore needs to
preserve a payload's unknown descendant paths, not merely forward its aggregate set of roots.

## Inspected implementation

In transforms05 `Value.project` filters paths by a prefix and removes that prefix.
`instantiate` with `Pre.tail = True` prefixes **each actual descendant suffix** with the output path,
unioning sources at that output position. Scalar view routes instead read the source's empty suffix.
`Value.assign` removes old entries below the target prefix and inserts the incoming subtree.

The decoder requires a tail route's source to be a type variable and its target to be that **same
variable**, not just any variable. `bindings_for` checks consistent substitutions. `Contract.apply`
copies entry flows before resolving result and posts. These observations agree with the proposed
route specification; they are not a proof that the Python implementation/decoder is correct.

Payload `*` is an abstract collection dependency position, not one element address. The inferencer
rejects wildcard storage places for strong updates. The existing 19 transformer tests pass,
including field-preserving opaque record forwarding and one-snapshot swap.

## Checked path algebra

A dependency tree maps paths to root predicates. A forward route from source prefix s to destination
d has this specification: at output path d ++ suffix, retain exactly the roots of source path
s ++ suffix. No assumption is made about the unknown suffix depth, shape or roots.

Eight new target declarations check:

- `sliced_iff_forward`: the take/drop prefix implementation equals this relational specification.
- `descendant_exact`: projecting the forwarded subtree recovers each corresponding source descendant.
- `no_unrelated_output`: paths outside the destination prefix receive no route contribution.
- `forward_union`: route contributions distribute over pointwise branch/source union.
- `instantiate_forward`: symbolic root-set substitution commutes with suffix-preserving forwarding.
- `forward_supported`: valid source dependency positions yield valid target positions **if** the
  supplied source-to-target suffix compatibility premise holds.
- `replace_project`: the replaced subtree projects back to the incoming dependency tree.
- `replace_outside`: an outside dependency path is unchanged by subtree replacement.

These are universal path/root statements, not finite tests of selected record layouts. The slicing
and replacement proofs use only standard `propext`; the other five targets report no axioms.
No introduced domain axioms, admitted proofs or new foundational dependencies are needed.

The runner now snapshots and checks three modules in order, compiling fresh Core and Instantiation
outputs before checking Routes. All 21 target axiom reports are retained. The earlier 13-target
report is historical evidence for the earlier runner/source version, not overwritten by this result.

## Explicit limits and next gate

`SupportedOn` is a predicate over dependency positions, not a source type system. The compatibility
premise captures the fact that the source and destination refer to the same instantiated payload
shape, but the theorem does not prove that the actual type parser/unifier/route validator establishes
it. Nor does a tree predicate distinguish an absent dictionary entry from an explicit empty set;
well-formed values and scalar-view completeness remain separate representation premises.

The take/drop implementation is a Lean mathematical counterpart of Python slicing. No proof connects
its list semantics to Python tuples, dictionary iteration/updates, JSON decoding or module provenance.
The original consumer still trusts a schema-valid but dishonest producer artifact.

Dependency-prefix separation is **not physical disjointness**. None of this permits aliasing mutable
arguments, updates through collection wildcards, stored exclusive-reference mutation or releasing
storage with outstanding work. Owner validity, authority, activation and cleanup gates remain open.

The next discriminating step is the type-substitution/allowed-descendant connection: show why a
checked same-T route remains shape-correct after substituting an arbitrary supported payload, without
silently flattening its fields. Keep that obligation distinct from physical loan preservation and
from an end-to-end certificate checker. No full compiler or adopted qualifier representation follows.
