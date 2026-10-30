# Quint: useful lessons, with an executed bounded example

2026-10-30. Source: Quint current commit `825e0dcd477e33d7ab4c733195d4f3d1b5e5ddcc` (0.33.1),
plus version-matched tag v0.30.0 `0482e47c82a5c540843858f9edfbab3da4d64521`. The installed CLI
executed here is **0.30.0**, not the current source checkout. Official repository now redirects to
https://github.com/quint-co/quint. This is not a full implementation/soundness audit.

## What to learn

1. **A coherent model workflow matters:** edit → cheap type/effect feedback → simulate → replay a
   counterexample → use stronger checking where applicable. Grail's verification should be useful
   before users become theorem-proving experts. ITF-style machine-readable traces help agents/tools
   inspect concrete failing executions rather than guess from "verification failed."
2. **Effects can remain inspectable without a general handler language.** Quint infers separate
   read/update/temporal information and checks declared modes against it. Higher-order effects
   propagate through combinators. We tested that a stateful callback is accepted by a relative-
   pure combinator, but its resulting call cannot be mislabeled state-independent.
3. **Keep result claims stratified.** Mode/type checks, sampled executions, bounded symbolic checks,
   explicit finite-state exploration, inductive arguments and source/implementation proofs are
   different things. A simulator's passing result does not establish an invariant universally.
4. **Safety and liveness are different.** A model may preserve storage safety while never completing
   cancellation. State the fairness/progress assumptions and deadline policy separately.

## Concrete experiment

[Runnable sources](../../research/experiments/quint03/README.md) and
[raw outcomes](../../research/evidence/prior-art03-20261030/quint-experiment.json).
All eight expected outcomes matched:

- Two valid specifications typechecked.
- Hidden state reads in pure definitions/calls failed with QNT200.
- A duplicate next-state assignment failed with QNT202.
- Guarded cleanup produced no counterexample under the requested sampled bounds.
- Early release after cancellation request produced a trace with `loan=true, alive=false`.
- Reallocation while pending produced a trace with parent still alive but mismatched loan/storage
  generations. Origin lifetime alone is not sufficient if its referent can be invalidated.

The bad traces each contain seven states with this seed, including stuttering. They are replayable
counterexamples, not claimed shortest traces. The good model was sampled with max-samples=1000 and
max-steps=12; this is NOT an unbounded proof. No actual Grail runtime bug was found: these are models
of proposed cleanup policies. Cancellation request is not cancellation acknowledgment.

## Do not copy the wrong semantics

Quint is a specification/state-machine language, not a no-GC native systems language. It restricts
recursion and uses relational current/next-state actions. `all`/`any` action composition, backtracking
and next-state assignment are not ordinary sequential mutation. Its named-state effect analysis
avoids much of Grail's heap-alias/provenance problem. It does not solve memory reclamation for us.

Sharing pure data/transition definitions between execution and models can reduce duplication. But
an adapter/refinement argument is still needed when an implementation performs real I/O or uses a
different state representation. A counterexample is to the model, not automatically to production.

## Architectural implications (proposals, not decisions)

- Retain more static behavior information than a lone suspension bit, even if most effects remain
  inferred/internal and the ordinary syntax stays small.
- Consider a model/test workflow for protocols, cancellation and resource state machines alongside
  optional functional proofs; do not turn every ordinary build into model checking.
- Use explicit pure transition kernels and library/tooling integration before inventing another
  general language inside Grail. Quint's numerous modes are not a proposed Grail keyword list.
- Never release borrowed storage merely because a deadline/cancel request fired. Join/acknowledge,
  preserve the resource/loan, or follow an explicit abort/isolation policy.

## Primary sources inspected

- [Design principles](https://github.com/quint-co/quint/blob/825e0dcd477e33d7ab4c733195d4f3d1b5e5ddcc/docs/content/docs/design-principles.md)
- [Effect-system rationale](https://quint.sh/docs/development-docs/architecture-decision-records/adr004-effect-system)
- [Version-matched mode checker](https://github.com/quint-co/quint/blob/0482e47c82a5c540843858f9edfbab3da4d64521/quint/src/effects/modeChecker.ts)
- [Version-matched duplicate-update checker](https://github.com/quint-co/quint/blob/0482e47c82a5c540843858f9edfbab3da4d64521/quint/src/effects/MultipleUpdatesChecker.ts)
- [Language/model distinction](https://quint.sh/docs/language-basics)
- [Model-checker scope](https://quint.sh/docs/model-checkers)

The model-checker documentation/API descriptions differ across versions; no claim about current
TLC integration is established by our 0.30.0 simulation. Apalache bounded results must state bounds;
induction and temporal/fairness claims require their own supported method and assumptions.
