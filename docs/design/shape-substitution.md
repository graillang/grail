# Same-T routes after shape substitution

2026-10-30. [Proof](../../research/experiments/instantiation11/Shapes.lean),
[runner](../../research/experiments/instantiation11/README.md),
[evidence](../../research/evidence/shapes13-20261030/).
This connects the [route proof](structured-routes.md) to a restricted dependency-shape model,
not to an implemented source type checker or the full Python type representation.

## Model and correspondence boundary

`Shape` contains unit, view, named variable, named field-spine and collection-payload nodes.
Unit also terminates field spines; empty records and unit therefore share a dependency shape.
This is intentional dependency erasure, **not equality of source base types**. Lookup selects a
matching field or the collection `*` payload, and `focus` follows a sequence of these steps.
Variables do not expose unknown fields. Allowed dependency positions end in a view or a still-opaque
variable placeholder. A substitution maps variable names to arbitrary shapes.

The actual Python representation uses record field tuples, validates unique/non-wildcard field
names when parsing, and substitutes a partial binding dictionary. This model uses field spines and
a total substitution (identity may represent an unbound variable). No proof yet connects these
representations, their parser, unifier or canonicality checks. The shape theorem must not be used as
proof that two source types, ownership modes or invariance conditions are interchangeable.

## Seven checked targets

1. `lookup_substitute`: an already successful one-step projection remains successful and reaches
   the substituted payload.
2. `at_substitute`: the corresponding result for an arbitrary successful formal path.
3. `at_append`: after reaching a payload, following a suffix is equivalent to following the
   concatenated path in the enclosing shape.
4. `same_var_descendants`: when source and destination prefixes both reach the **same named T**,
   their allowed suffix positions agree after any one substitution.
5. `generic_route_supported`: combine that fact with the route theorem to preserve supported
   dependency positions when forwarding an opaque payload subtree.
6. `unknown_path_can_appear`: a closed counterexample showing a field unavailable in formal T
   can become available after substituting a record shape.
7. `distinct_vars_can_diverge`: a closed counterexample showing T and U can have incompatible
   descendants after substitution. Merely being generic positions is not sufficient.

These quantify arbitrary finite shapes and successful path lengths; they are not sampled layouts.
All seven axiom reports contain only standard propositional extensionality (`propext`). There are
no admitted proofs, introduced domain axioms or classical-choice dependencies in these targets.

## What this discharges

Within these mathematical models, the route proof's suffix-compatibility premise follows from
successful formal projections to the same T and a common substitution. The proof does not have to
inspect or flatten T's eventual fields. The forwarded roots remain separated by descendant position.

The result is deliberately one-way for successful projections. Failed formal lookup does not have
to remain failed: instantiation reveals descendants under opaque variables. This is why copying
actual suffixes is different from enumerating only the formal placeholder's current leaf path.
A generic body is not thereby permitted to select arbitrary fields of unknown T.

## Remaining gates

- Show the actual type binding/route-validation implementation establishes the formal projection,
  common substitution and representation premises. Code inspection found same-variable equality
  and consistent binding checks, but no implementation-correctness theorem follows from inspection.
- Connect finite dictionary flows and sparse absent-as-empty encoding to the pointwise tree model,
  including scalar completeness, container emptiness and wildcard aggregation.
- Preserve full base-type shape and operation legality, not just allowed dependency positions.
  Mutable referent invariance, affinity, destructors, callbacks and stored exclusive access are absent.
- Prove physical place/authority validity, caller activation conditions and cleanup independently.
  Two dependency paths or shape positions do not establish disjoint physical storage.
- Authenticate the checked body/interface/artifact correspondence before claiming independent
  certification. Earlier schema-valid lying artifacts still expose the original consumer's TCB.

The runner now freshly compiles three imports and checks the fourth module, recording 28 target
axiom reports. Earlier 13- and 21-target evidence remains historical and unmodified. CLI/direct
correct-workspace LSP validate the runner; old installed-process false-import/partial reports are
retained separately as known pre-repair harness limitations, not clean validation.

The next architectural discriminator is mutable referent state: whether a stored access can expose
changing dependency contents without freezing old roots forever, losing updates or requiring a
mandatory runtime borrow graph. This shape result does not resolve that question or adopt a language.
