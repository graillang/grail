# Preservation core and architectural synthesis

2026-10-30. [Lean model](../../research/experiments/core10/Core.lean),
[reproduction](../../research/experiments/core10/README.md),
[evidence](../../research/evidence/core10-20261030/). This is a small formal research checkpoint,
**not an adopted language, full safety theorem or compiler implementation**.

## Why consolidate now

The [transformer experiment](experiment-results-05.md) exercised concrete data versus inferred
contracts, but only finitely. The later [cleanup](cleanup-boundary.md),
[Bundle](bundle-boundary.md), [authority](authority-boundary.md) and
[call-activation](call-activation-boundary.md) studies exposed different obligations. Continuing
only to add successful probes would not establish a preservation argument.

The first checked core deliberately formalizes just dependency support. It supplies a reusable
lemma under explicit embedding premises, rather than pretending a small root-set model includes
ownership, authority, call evaluation and cleanup merely because they all mention lifetimes.

## Smallest useful decomposition so far

| Information / invariant | What it answers | What it does not answer |
| --- | --- | --- |
| Base value shape T | Which operations and structural positions exist? | Which current owner generations are retained? |
| Current dependency state q | Which sources may the value/result still require? | Whether exclusive access is legal or a descriptor was moved |
| Owner/carrier and authority validity | Which storage is stable, which capability exists, which parent access is restricted? | The latent effects of abandoning pending work |
| Evaluation/activation state | Which argument effects have happened and which loans already exist? | Whether cancellation acknowledgment ends backend access |
| Scope-owned outstanding work and cleanup effects | What must finish before storage can disappear, including on error? | A bounded shutdown time or universal no-block guarantee |

These are semantic distinctions, **not five required user annotations or runtime data structures**.
Some can be construction invariants, private checker state or erased proof information. Root paths
and trusted disjoint constructors may provide authority facts without adding more public root slots.
Nothing here establishes a mandatory runtime borrow graph, tracing collector or reference counting.

The remaining minimization question is whether one small coherent typing judgment can maintain
these facts with tractable inference and interfaces. Counting keywords does not answer that.

## Concrete model

A state has mathematical numbered slots containing lists of arbitrary α and one saved-result list.
An external input environment supplies immutable lists. `deps(x, r)` is an arbitrary predicate
saying payload x requires root r. It may model owner-generation pairs, but the core itself does not
allocate, expire or reuse owners. An abstract state has a root predicate for each slot/result.

`Covered(deps, xs, q)` means every root required by every element of xs satisfies q. `Related`
requires this for every tracked slot and the saved result. It is an upper bound, not equality.

Concrete `Exec` rules operate on list contents. Separately defined `analyze` rules operate on
predicates. Their primitive correspondence is:

| Command | Contents | Abstract support |
| --- | --- | --- |
| clear | slot becomes empty | slot becomes empty |
| append input | concatenate incoming contents | union old and incoming support |
| replace | write incoming; save old contents | write incoming bound; save entry bound |
| take | empty slot; save old contents | empty slot; save entry bound |
| swap | exchange entry contents | exchange entry bounds |
| forget | empty saved result | empty saved bound |
| sequence | execute first, then second | compose analyses |
| choice | either execution | pointwise union of both analyses |

Swap and returned-old operations read one entry state. Clearing a slot does not clear the saved
result. Same-number swap is an identity in this mathematical semantics; it does **not** authorize
aliased mutable arguments in a source language. Distinct Nat slots are independent by construction;
no theorem maps arbitrary physical places, field/index expressions or overlapping slices to them.

## Checked statements

`preservation` proves: given covered inputs and a related initial state, **every concrete execution**
is related to its analyzed post-state. The proof is induction on the execution derivation, using
list-membership, slot-update and branch-union lemmas. It covers all finite programs of this grammar,
arbitrary payload/list sizes and branch choices, not a sampled population. There are no loops,
recursion or exceptional executions in the grammar.

`public_bound` proves that pointwise widening remains sound. `checked_contract` composes this with
preservation: a producer execution, related entry state and checked derived-to-public inclusion
establish the advertised post-bound. This is a sufficient refinement condition, not principal
contract inference or complete semantic subtyping.

`absent_root` proves absence from **tracked** payload dependencies when the root is absent from all
tracked bounds. It says nothing about untracked external inputs, closures, scope work or owners.
It is not a global permission to release an owner. `tracked_valid` proves tracked data satisfies a
supplied live-root predicate when the bounds do. Truthful dependencies and root liveness are explicit
premises, not established facts about a heap implementation.

Two closed countertheorems establish that a singleton retaining source 0 cannot be covered by empty
support or by support containing only source 1. These model the forged-empty and wrong-old-return
mistakes. They do not execute or certify the Python artifact decoder.

## Evidence and trust

The official Lean 4.35.0 release archive is pinned by URL, byte length and published SHA-256; checks
run with warnings as errors inside the no-network/home sandbox. The report retains exact compiler
version/commit, source/runner/compiler hashes, output and all seven `#print axioms` results.

Preservation, checked-contract composition and the two countertheorems depend only on standard
propositional extensionality (`propext`). Public widening, tracked-root absence and conditional
validity report no axiom dependencies. There are no admitted proofs or introduced domain axioms.
The runner rejects incomplete/unexpected axiom reports and accidental proof holes. This is not a
hostile-source proof importer or an independent audit of Lean's binary, standard library or kernel.
Local universally quantified hypotheses do not appear as axioms; their applicability must be checked.

The already-running Borg process still predates the source repairs
[3e320675](https://github.com/borg-ml/agent/commit/3e320675) (workspace initialization) and
[d4566bd5](https://github.com/borg-ml/agent/commit/d4566bd5) (workspace diagnostic capability).
Both repairs passed the focused 33-test LSP suite before push. Do not treat an old-process partial
workspace report as a clean check, or silently hot-replace active processes. Correct-root direct
Pyright LSP and CLI checks provide separate runner validation; Lean CLI checks the proof itself.

## What remains outside the theorem

- No proof connects this Lean grammar/analysis to transforms05's structured Ty, inference,
  unification, field/prefix routes, serialization, fingerprints or body-hidden clients. Earlier
  generated tests remain finite evidence; they do not inherit this theorem automatically.
- A schema-valid lying artifact still fools the earlier consumer. A future proof-carrying path
  needs an authenticated correspondence between checked body/semantics, public signature, imported
  assumptions and consumed artifact. A producer theorem in a different model does not close that TCB.
- α is arbitrary mathematically, but operations duplicate pure values. This proves no Copy/affinity,
  destructor, owning-allocation, invariant mutable-referent or full generic-T typing rule.
- No backing-storage views, address relocation, capability splitting/reborrowing, move availability,
  physical alias validation, source evaluation order or call activation is modeled. Embedding this
  core requires those gates first; the analysis sees the actual entry state at the chosen boundary.
- No errors, suspension, cancellation, partial construction, deallocation, FFI, concurrency or races.
  The finite cleanup model's acknowledgment premise is still an external backend obligation.
- Root predicates are mathematical functions, not a measured compact interface representation.
  No compiler-build, native runtime, allocation-count, metadata-size or proof-maintenance performance
  guarantee follows. Lean is research tooling here, not a proposed mandatory normal-build dependency.

## Next discriminating work

Prefer connecting a meaningful boundary over multiplying isolated examples: symbolic pre-source
instantiation and a single entry snapshot are candidates for the next proof, followed by the
structured/opaque-T representation boundary. Separately, authority must have a preservation argument
and a usable inference story. Keep candidate architecture status provisional until these compose.
