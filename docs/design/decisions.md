# Design ledger

Status: second research tranche, 2026-10-30. Recommendations are **not agreements**.
See [the memory-model competition](memory-model-competition.md) for revisions prompted by the critique.

## Agreed / directed by the human

- Project: Grail; repository: https://github.com/graillang/grail.
- Source-file extension: `.grl`.
- Design and research before a full compiler. Small experiments may resolve uncertainties.
- Priorities: fast builds, safe deterministic memory without tracing GC or mandatory RC,
  strong performance, little lifetime syntax, and a compelling ordinary CPU language.
- Expensive proof search must not be mandatory for ordinary builds.
- AI is an untrusted proposer, never a correctness authority.
- Preserve independent intent; deriving behavior from implementation is not requirements validation.

## Recommended, awaiting discussion

| ID | Proposal | Reason / cost |
| --- | --- | --- |
| P01 | Affine owned values; shared-read/exclusive-write loans | Predictable reclamation and modular reasoning; alias-heavy APIs need alternatives |
| P02 | Local inference plus exported symbolic origin/effect summaries | Separate compilation without root-per-call specialization; conservative rejection remains |
| P03 | Scoped core for experiments, not a permanent ban on borrowed aggregates | External-owner AST/page views are required competition cases; owner-plus-internal-view packaging is a separate problem |
| P04 | Explicit authority at boundaries; compare ordinary arguments with lexical typed context passing | Reduce plumbing without ambient authority, runtime lookup, global implicit search or unchecked capture |
| P05 | Direct-style calls, explicit structured spawning, fixed suspension effect | Avoid async syntax, not effect distinctions; stack/runtime design remains open |
| P06 | Operational resource semantics plus a proved value interpretation for an eligible subset | Functional proof benefits without pretending all mutation/concurrency is pure |
| P07 | Total logical fragment; potentially partial executable fragment | Avoid proving false propositions using divergence; ordinary runtime code need not terminate |
| P08 | `Result[T,E]`, `!` shorthand, explicit `?` | One error mechanism, typed public error boundaries; no inferred open global error universe |
| P09 | No user-defined general control handlers in version one | One-shot runtime operations suffice to test direct style; no multi-shot affine-resource problem |
| P10 | CPU first; device support via typed resources and restricted kernels | Host types stay simple; GPUs/NPUs are not universal execution targets |
| P11 | Fast build and verification lanes share elaborated semantics and evidence hashes | No stale green badges; proof-dependent assumptions cannot leak into unverified builds |
| P12 | Default static generics, specialization accounting and caches | No fictitious zero-cost universal sharing; dev/release codegen policies may differ |

## First decisions to discuss

1. **Borrowing envelope.** Require external-owner zero-copy aggregates (ASTs/page views) in the
   comparison. Start a restricted checker, but do not turn that restriction into a permanent ban.
   Treat self-reference and freely aliased mutable graphs as separate cases; arena IDs are an option,
   not an adequate presumed replacement for all views.
2. **Access surface.** Compare reference spelling, explicit access conventions, and conventions
   with inferred call-site access. Recommendation: value-first declarations; keep read calls quiet,
   test explicit versus inferred modify/consume markers. No syntax winner selected.
3. **Suspension transparency.** Accept direct-style calls with suspension shown in API effects,
   and a compiler-enforced non-suspending context? Recommendation: yes, no `async`/`await` syntax.
4. **Proof scope.** Accept contracts and an erased total logic before full dependent runtime types?
   Recommendation: yes. Use an established kernel for the research model.

## Rejected for the proposed baseline (not human decisions)

- Whole-program lifetime inference as a prerequisite for compiling a client module.
- Copy-on-write or reference counting silently implementing ordinary value assignment.
- Full dependent elaboration or SMT search in every ordinary build.
- An unverified precondition or theorem authorizing unchecked memory access or optimization.
- Automatic offloading of arbitrary pure code; purity is neither GPU legality nor profitability.
- Multi-shot continuation capture over live affine resources.
- Automatic background tasks, invisible exceptions, hidden blocking destructors.
- A universal LLVM-only source semantics or an initially universal cross-language proof IR.
- Whole-compiler correctness as a prerequisite to testing the memory model.

## Open / must not be silently filled in

- Precisely which scoped view types, captures, reborrows, and callback shapes have principal summaries?
- Are inferred published summaries frozen automatically in an interface artifact, or written explicitly?
- Closure access/effect polymorphism without a large trait solver.
- Lock guard and asynchronous resource cleanup rules; cancellation invariants and failure ordering.
- Stackful fibers versus effect-directed stackless lowering and their ABI/FFI costs.
- Allocation failure policy and effect; leak freedom versus affine disposal; recursive destruction depth.
- Proof certificates for SMT-supported theories, especially bitvectors, arrays, and arithmetic.
- Specialization policy: how much development runtime slowdown is acceptable to save build time?
- Formal correspondence between imperative execution, value interpretation, staging, and optimizations.
- GPU barrier/convergence rules, device ABI, address spaces, dynamic reservation, and driver assumptions.
- Whether extending Hylo, adding a Rust tool, or creating a new frontend wins after measured prototypes.

## Revision after the supplied critique

- The critique is input to assess, not blanket approval of its claims or our previous proposals.
- Exported lifetime/origin contracts are prior art, not Grail's established breakthrough. Novelty
  requires measured improvement in inferred relationships, expressivity, modularity and diagnostics.
- “Scoped” does not mean “short-lived.” Distinguish externally borrowed aggregates, packaged
  owner/internal views, and mutable aliased graphs with invalidation.
- Value semantics, loan permissions and root provenance are overlapping dimensions, not three
  interchangeable complete memory managers. A proposed combination remains unproven.
- Compare three access surfaces before selecting punctuation; `&` / `&mut` are not commitments.
- Treat zero-copy ASTs, pinned-page views, separate generic compilation and explainable failures as
  admission tests, not future polish. No actual three-compiler workload experiment has run yet.
- Investigate lexical typed capability contexts; preserve identity, affine use and escape bounds.

## First executable evidence (not new agreements)

See [experiment results 01](experiment-results-01.md). Twenty-one Rust acceptance/rejection probes
matched expectations with provider sources unavailable to clients. Six targeted Goose cases matched
expectations; the 16/64/256-root fixture reused two specializations rather than one per root.
Checked relative offsets are a credible compact zero-copy owning-document representation in the
measured token workload; do not infer that they replace all borrowed structures.

The `hylo-lang/hylo` checkout is the former compiler; current implementation is in `hylo-new`.
Earlier implementation-specific Hylo conclusions must be read as historical. Current source was
inspected but not executed because Swift 6.3.2+ is unavailable. No Hylo benchmark ranking exists.

Priority: specify and experimentally infer modular origin/capture contracts for the recursive AST,
generic adapter and callback cases. The Rust baseline demonstrates expressivity, not Grail inference.

## Origin/capture inference experiment

See [results 02](experiment-results-02.md). A restricted typed-IR producer now infers and exports
shared-view field/capture origins; isolated clients and a downstream provider use contracts without
upstream bodies. Generic prefix forwarding is compact, while dense distinct source sets still grow
large. Field-sensitive future uses avoid demonstrated false rejections from whole-result unions.

The callback rule is a fixed scoped protocol, not general higher-order inference. Owning moves,
exclusive-view returns, general control flow, allocation/drop, real closures and async remain out
of scope. Source/import hashes are dependency identifiers, not proof certificates. A valid-looking
forged contract is deliberately shown to fool a client unless producer/evidence trust is established.

Recommendation: retain the candidate architecture, not commit to it. Next specify a formal safety
statement for this fragment, then investigate a small mutation/control-flow extension. Do not
interpret passing finite tests as Rust-class guarantees or native compile-speed evidence.

## External Opus review

The [review assessment](opus-review-response.md) records useful recommendations and qualifications.
Favor investigating stable, checked public contract bounds and mutation/input-flow semantics next.
Scoped exclusivity, stackful fibers, a single pervasive surface effect, linear must-close resources
and a verified-component product are still proposals, not adopted decisions.

## Quint, Haskell and ownership precedent research

See [Quint](quint-lessons.md), [Haskell](haskell-lessons.md), and the
[ownership update](ownership-prior-art-update.md). Proposed priorities, not adopted language rules:

- Eager, ordered ordinary evaluation; explicit deferred streams/computations and latent effects.
- Explain retention/capture dependencies as well as invalid borrowing; no hidden copy to reduce retention.
- Count static inference/search/metadata complexity, not only core size or keyword count.
- Keep proof, type checking, sampled testing, bounded model checking and implementation conformance
  visibly distinct. Counterexamples must identify the model and assumptions they concern.
- Study scoped generics/wrappers and stateful input-flow contracts before more pure-origin prototypes.
- Consider an optional explicit batch/query domain, learning from Haxl without hidden global spawning.

Quint Connect already implements model-to-Rust trace replay/state comparison. This is prior art, not
a newly discovered Grail product differentiation. Swift/OxCaml/Mojo offer important mechanisms but
none was benchmarked or shown here to satisfy the entire Grail brief.

## Ongoing research direction (human-authorized)

Continue research, counterexamples, formalization and bounded experiments until explicitly told to
stop. Keep tested milestones committed/pushed. This authorizes continued investigation, not adoption
of a candidate or premature construction of a full compiler.

The external [rooted-value review assessment](rooted-values-review.md) identifies precise next tests:
pre/post input dependency transformers, independent callable access/sharing, split/reborrow authority,
nominal-slot precision, Bundle projection, and pending operation ownership on error. The external
branch was read, not merged. No recommendation in it has become an agreed language rule.

## Dependency state-transformer experiment

[Results 05](experiment-results-05.md) exercise preserve/add/replace/empty post-states with explicit
entry snapshots, opaque view-data generics and disjoint exact caller places. Finite concrete tests
support investigating this interface mechanism; they do not settle full ownership or source syntax.
Base types and per-value dependency state are separated in this prototype. First-class mutable-view
variance, backing-storage borrows, effectful destruction and exceptional post-states remain open.

Next connect error exits and pending-work cleanup to the preservation obligation, and test Bundle
projection/call authority rather than expanding the compiler surface. The source/contract producer
remains trusted: a forged but schema-valid empty post-state still fools the isolated consumer.

## Error-cleanup ownership boundary

The [finite cleanup study](cleanup-boundary.md) distinguishes user handles from scope-retained work.
Normal-path handle consumption and error-path abandonment do not by themselves keep buffers alive.
Pending borrowed work needs an owner through every exit; acknowledgment must correspond to that
operation's final storage use, not merely a cancel request or another operation's completion.

Completing one of several operations sharing a root cannot erase the whole dependency union. A
join-all barrier is a conservative candidate; more precise release needs operation/loan identity.
Cleanup suspension must contribute to effect summaries. Safety does not imply a cleanup deadline.
These are research constraints, not an adopted registry implementation or new surface syntax.
