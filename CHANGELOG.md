# Changelog

## Unreleased

- Establish the Grail research workspace and living architectural design record.
- Record `.grl` as the agreed source-file extension.
- Add an initial source-backed comparison, provisional semantic core, syntax sketches,
  and falsifiable experiments. No compiler implementation or verified Grail programs yet.

- Add a source-backed memory-model competition; keep persistent external borrowing and access syntax
  open, assess lexical capability contexts, and make zero-copy APIs/diagnostics explicit design gates.

- Record targeted V lessons and caveats for ownership, ergonomics and fast-build architecture.

- Add isolated executable ownership probes, zero-copy representation measurements, and a synthetic
  generic-compilation experiment with raw data and source/toolchain provenance.
- Correct Hylo research to distinguish the former compiler from `hylo-new`, and qualify Goose
  specialization claims using observed root-class reuse. No Grail compiler implemented.

- Add a bounded typed-IR origin/capture inference experiment, imported contract composition, isolated
  client checking and adversarial tests. Contracts are not independently proof-certified.

- Stress-test origin/capture contracts against separate finite dependency and allocation-epoch models.
- Measure generic forwarding, source-set growth and root-indexed client lookup; document unsupported
  ownership/effect features and the trust limit of schema-valid but dishonest contracts.

- Record assessment of the external Opus design review, checked prior-art updates, and unresolved
  public-contract and scoped-exclusivity choices without treating peer recommendations as decisions.

- Add isolated Quint effect/cancellation experiments and distinguish sampled counterexamples from
  verification; record version-matched source provenance and design lessons.

- Record evidence-backed Haskell successes/costs, retention and inference lessons; distinguish
  community pain reports from causal adoption/performance claims.
- Add Swift/OxCaml/Mojo ownership findings and inspected Quint Connect adapter boundaries.

- Assess the external rooted-value proposal without merging it; add six isolated Rust probes for
  cache-reset and callable/thread-sharing distinctions, and identify mutation/cleanup contract gaps.

- Add a bounded pre/post dependency-state experiment for generic append, clear, replacement, old-value
  returns and disjoint-place updates, with independent concrete comparisons and body-hidden clients.
- State the restricted preservation obligation and expose the remaining forged-artifact trust gap;
  no full memory-model, allocation-reuse or runtime-performance claim follows.

- Exhaustively explore finite error-cleanup models with separate user handles and scope-owned work;
  expose premature buffer release and incorrect all-on-one-acknowledgment policies.
- Record status-specific liburing cancellation guarantees and distinguish storage safety, resource
  discipline, cleanup effects and bounded progress. No actual device/runtime verification claimed.

- Add eighteen isolated Rust/Yoke/self_cell probes for Bundle projection, variance, owned ASTs,
  inline-owner stabilization, external dependencies and dependent-before-owner destruction.
- Distinguish scoped covariant field projection from whole invariant-container escape; document
  candidate Bundle rules and explicit allocation choices without adopting a language primitive.

- Distinguish owner lifetimes, carrier loans, authority transfer and temporary reborrows with fifteen
  isolated Rust probes and bounded interval/cell permission comparisons.
- Record minimal construction/permission proof obligations and Aeneas/Hylo precedent; do not infer
  that extra public lifetime syntax, a runtime loan graph or a full checker is required or implemented.

- Test delayed call activation against nested argument effects, early dependency snapshots,
  materialized storage views and copied-view aliasing, with five Rust reference probes.
- Document stable-place premises and unresolved selector/address/bounds-check timing; no frontend
  implementation, general safety proof or bug in the older restricted IR is claimed.

- Add a pinned, isolated Lean preservation core for pure shared-data dependency state, public-bound
  composition and conditional tracked-root validity, with checked counterexamples and axiom reports.
- Consolidate distinct shape/support/authority/activation/cleanup obligations; explicitly exclude
  earlier artifact certification, physical ownership/alias safety and full-language verification.

- Prove symbolic pre-source substitution commutes with the restricted core analysis and preserves
  public bounds under arbitrary overlapping/empty source images; check the one-entry-snapshot boundary.
- Record separate-module proof provenance and standard quotient-soundness dependencies; do not claim
  physical alias safety, structured generic-route correctness or a certified artifact pipeline.

- Add eight checked structured-route targets for suffix-preserving opaque payload forwarding,
  root substitution and dependency-subtree replacement; extend the existing runner to three modules.
- Keep shape-substitution validation, Python implementation correspondence and physical disjointness
  explicit open premises rather than inferring them from dependency-path separation.

- Prove successful dependency-shape projections survive substitution and same-T prefixes have
  compatible descendants; connect that premise to structured forwarding in a restricted model.
- Check counterexamples for newly revealed opaque paths and different-variable incompatibility;
  keep full source typing, parser/unifier correctness and mutable referent state outside the claim.

- Add eleven isolated Rust referent-state probes and complete finite exploration of five single-cell
  policies, including retained-old-value and temporary-source controls.
- Distinguish storage lifetime, current contents and writeback; record two precise ghost-state styles
  and Aeneas precedent without claiming a general mutable-reference checker or runtime graph requirement.

- Add seven pinned Rust generic/resource controls for ownership forwarding, skipped/destructor
  effects and scoped work; retain an expected bounded stall separately from completed executions.
- Record public-source-matched scope accounting and distinguish root captures, logical loans,
  destructor effects and ambient work obligations without adopting safe forget or Rust's runtime ABI.

- Test target coverage beyond lifetime validity with five Rust cases and 2,140 finite transfer/write
  combinations; distinguish conservative weak updates from unsupported strong may-target updates.
- Add six conditional coverage/post-bound Lean targets with explicit logical dependencies; retain
  target-provenance, producer checking and full ownership/erasure composition as separate obligations.

- Prove may/must interval refinement polarity and test 7,380 interval pairs plus a toy stale-cache
  acceptance when coverage guarantees are omitted from dependencies; no production compiler cache claimed.
- Keep body-contract truthfulness, memory-interface invalidation and value/code proof dependencies
  separate; make the transfer smoke check report the actual shared proof-corpus target count.

- Start a dependency-free Rust typed-IR seed with explicit signature regions, affine views,
  carrier reborrows, guarded C/LLVM lowering and body-hidden interface tests. The first scan-based
  checker is a measured baseline, not the final algorithm or a complete language implementation.

- Replace repeated live-value scans with indexed origin/parent-loan checks in the Rust seed;
  preserve owner/authority checks across carrier moves and shared-view ending.
- Add reproducible paired checker, native backend and module-edit measurements with an independent
  checksum oracle, raw CPU/RSS/commands and explicit limits. Retain TinyCC as a measured development
  candidate, without claiming full-language performance, soundness or self-hosting.

- Freeze bootstrap-v0 decisions and add the first `.grl` source-to-native path: borrowed-token
  parsing, explicit signature regions, inferred local loan endings, counted loops, numeric branches,
  guarded byte slices/writes, imported interfaces and clang/TinyCC source builds.
- Add a two-module zero-copy decimal-token parser and source/native safety checks, including
  hidden producer source, wrong-region/local escapes, live-child write conflicts and abort guards.
  Heap containers, general generics, Result and self-hosting remain unimplemented.

- Add owned heap byte vectors, explicit deep copying, geometric growth and owned parameter/return
  transfer in the C backend. Reject growth/movement while borrowed and insert reverse lexical owner
  cleanup separately from last-use loan ending. Bump seed interfaces to schema 2.
- Validate heap cleanup and reverse drop order with independent allocator wrappers, including loops,
  clones and returned owners. LLVM comparison explicitly rejects unsupported heap layouts.

- Audit stable and pinned modern Rust (2026-10-29 nightly) with Polonius/next-solver flag isolation:
  conditional reborrows and get-or-insert now pass; stored-referent replacement/restoration still
  reject in the tested forms. Correct the comparison baseline without claiming a soundness proof.

- Add owned UTF-8 strings, validated literals/escapes, checked text copying and append, while
  rejecting raw byte mutation and growth under live views. Bump seed interfaces to schema 3.
- Differentially validate text construction on 26 byte sequences through clang/TinyCC, including
  malformed encodings, and exercise owned string calls/returns across a hidden-source boundary.

- Allow readonly byte-view descriptors to be read, moved or ended while derived readonly views
  live, without releasing their data owners or exclusive ancestors. Add paired positive/negative
  source checks for lexer-style retained slices.

- Add while loops to source, checked IR and C/LLVM lowering. Re-evaluate conditions, close their
  temporary owner/loan scope on both outgoing edges, and preserve loop-carried resource obligations.
- Validate zero-iteration execution, mutable counters, condition allocations and retained-view
  growth rejection with native and allocator-audited cases.

- Add lexical shadowing and standalone source blocks with reverse lexical cleanup. Keep old storage
  identities and outer-owner lifetimes distinct from names, restore names on scope exit, preserve
  explicit unconditional moves/drops, and reject duplicate parameters and use after scope/consumption.
  Validate C/LLVM behavior, live-loan rejection and allocator-audited shadowed-owner cleanup.

- Fix source call evaluation to copy/move each user-function argument left-to-right before evaluating
  the next. Reject later use of an already moved owner/view, retain builtin borrowing rules, and
  preserve explicit precomputed values/reborrows. No interface-schema or runtime-borrow-check change.

- Review pinned Blu/Lust frontend and ownership implementations; retain 15 modern-Rust/Lust
  acceptance pairs and seven equal native executions for aggregate/region gates. Record the useful
  field/variance/drop-liveness distinctions, remaining Grail work and Lust's older NLL restrictions
  without treating external subset/performance claims as Grail guarantees.
