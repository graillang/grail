# Response to the external Opus review

Read 2026-10-30 from the human-provided Markdown export, with PDF text cross-check.
Artifact: https://claude.ai/artifact/B8s3h65YwopQ26as3FeXHP#03da335a-d572
Export SHA-256: `d61ad1962ebef6cf26d64910c13f8d07b1cb0e529820a91c6f1d70b90e4c5735`.
The original export is not republished here. These are research recommendations, not human approval.

## Strong additions

- Prefer precise inferred internal contracts plus stable public upper-bound contracts, using elision
  defaults or tool-written snapshots checked against bodies. This was already an open option in our
  ledger, not a reversal of an agreed fully-inferred-public policy. Public changes need review.
- Define semantic contract refinement/subsumption before optimizing its serialization. Returned
  origins, input-to-input stores, capture/escape behavior and access requirements all need coverage.
- Next test mutation, input-to-input flows, moves, invalidation and conditional exclusive access.
  Further pure shared-origin microbenchmarks have diminishing value for the full memory-model claim.
- Add current Mojo, Swift lifetime-dependency/non-escapability, OxCaml modes and reachability/capture
  work to the priority audit. Existing language overlap is stronger than the original survey suggested.
- State race-freedom/shareability rules and distinguish source-level proof from backend correspondence.

## Claims to qualify

- "Scoped exclusive" is not a precise restriction yet: the review permits returned MutableSpan-like
  values and scoped records. Define the escape boundary (callee frame, referent, region, heap or task).
  Inout containers of views still require invariance/flow reasoning; reborrowing and conditional
  access do not disappear merely by renaming them scoped. Prophecy-free translation is a hypothesis
  dependent on the actual restriction, not a consequence of terminology.
- Goose is not a drop-in memory model, but heap versus stack is not the fundamental distinction.
  Address stability, shrink/reuse, reclamation and sharing rules determine invalidation requirements.
  Its normalized root-provenance machinery may still inform a heap-backed design.
- Our client epoch oracle DOES model invalidation/end abstractly. It does not model full Vec
  reallocation, owned moves or provider-side mutation. "Nothing about invalidation" overstates the
  limitation; "only the abstract invalidation rule is tested" is accurate.
- Precise inference is not synonymous with the finest possible semantic contract. Our analysis is
  conservative, and general body-minimal contract computation is not a cheap decidable operation.
  Start corpus research with syntactic elision/annotation patterns and manual API classification.
- Contract changes, rechecking dependents, and breaking actual clients are different measurements.
  Define refinement and compatibility before claiming a percentage of releases breaks clients.
- Suspension as the only pervasive SURFACE effect is plausible; allocation, external mutation,
  nondeterminism and authority still need static accounting for purity, proofs and parallelism.
- Stackful fibers are a candidate, not free generic suspension. Measure stacks/context switches,
  thread affinity and FFI restrictions. A cleanup deadline must specify whether it requests
  cancellation, aborts, or retains resources; it cannot authorize freeing live borrowed storage.
- Scoped exclusivity does not automatically justify every LLVM noalias annotation. That requires a
  correspondence to LLVM's actual reachable-memory and aliasing rules, including unsafe/FFI boundaries.
- Must-close kinds, errdefer, aborting allocation and a verified-component product are proposals with
  real costs, not automatic consequences of our goals. In particular, aborting OOM matters for
  libraries embedded in a host process. No product pivot or semantic commitment has been made.
- Hylo's inability to support required zero-copy API shapes must be checked against CURRENT Hylo,
  not inferred from the former implementation or the phrase "no first-class references" alone.

## Checked external facts

These checks confirm selected documentation, not an implementation or guarantee audit:

- Modular's announcement says Mojo reached 1.0 with source stability and that its compiler/toolchain
  became open source on 18 August 2026: https://modular.com/blog/mojo-open-source
- Mojo's manual documents origins tracking lifetime and reference mutability:
  https://docs.modular.com/mojo/manual/values/lifetimes
- The official Rust post describes Polonius Alpha on nightly and remaining limitations/performance
  regressions: https://blog.rust-lang.org/2026/08/04/enabling-polonius-alpha-on-nightly
- Swift's pitch describes lifetime dependencies, Span/MutableSpan and related borrowing work:
  https://forums.swift.org/t/pitch-3-compile-time-lifetime-dependency-annotations/84968
- The cited OxCaml Mode Crossing PDF was reachable, but its contents were not independently audited:
  https://iris-project.org/pdfs/2026-icfp-modecrossing.pdf

## Recommended next scope, awaiting discussion

1. Specify a small refinement order for contracts, including post-state flows into inputs.
2. State a safety theorem with owned storage, generations/freezing, moves and reallocating containers.
3. Hand-classify a small diverse corpus of real parser/container/callback APIs. Avoid attempting
   exact inference over fifty crates before a suitable analysis exists. Proposed numeric kill
   thresholds are research choices, not established facts.
4. Compare exact variants of scoped exclusivity on lending iterators, map entry APIs, split access,
   parsers retaining inout state and returned mutable spans.
5. Continue to defer a full compiler, broader runtime and GPU work until these boundaries are clear.
