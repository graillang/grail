# Research catalogue and evidence boundaries

Accessed 2026-10-30. All source repository revisions are recorded in
[`repository-pins.json`](../../research/evidence/repository-pins.json); Zig uses
[`zig-current-pin.json`](../../research/evidence/zig-current-pin.json).

Classification: **source inspected** is stronger than a roadmap claim, but weaker than
an independently reproduced experiment or machine-checked assurance audit. Search snapshots
are preserved under `research/evidence/`; their snippets may be truncated or stale.
No benchmark or formal-proof build was run in this tranche. Third-party checkout files are
read-only research material and are excluded from the project Git index.

<a id="s1"></a>
## S1 — Hylo: actual access/lifetime passes

- [Compiler repository](https://github.com/hylo-lang/hylo)
- [Borrow-region closing](https://github.com/hylo-lang/hylo/blob/6889158246df571baa9079115817ab2bff61156b/Sources/IR/Analysis/Module+CloseBorrows.swift)
- [Object-state abstract interpreter](https://github.com/hylo-lang/hylo/blob/6889158246df571baa9079115817ab2bff61156b/Sources/IR/Analysis/Module+NormalizeObjectStates.swift)
- [Older specification (separate repository, pinned in follow-up)](https://github.com/hylo-lang/specification/blob/6f4c645101bac80dbb7bd5833cf07c8cbf699bd1/spec.md)
- [Borrow-checking paper abstract](https://2023.splashcon.org/details/iwaco-2023-papers/5/Borrow-checking-Hylo)

Read compiler pass code. Research presentation/specification complement it; no Hylo build or soundness audit performed.

<a id="s2"></a>
## S2 — Goose memory-safe language, not Perennial

- [Specification: whole-program compilation §10](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/docs/goose_spec.md#10-compilation-model)
- [Compiler root analysis](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/src/typecheck_types.h)
- [Backend root/stack treatment](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/src/codegen.h)
- [Prior-art discussion](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/docs/design/prior_art.md)

Read spec §§9–11 and root/backend implementation excerpts. Whole-program roots/stack specialization is explicitly documented, not inferred from a slogan. Repository benchmark claims were not reproduced.

<a id="s3"></a>
## S3 — Koka and Perceus

- [Repository](https://github.com/koka-lang/koka)
- [Borrow analysis](https://github.com/koka-lang/koka/blob/d23ee7cd73737c1da7a7a5fa837a2806facc3d6b/src/Core/Borrowed.hs)
- [Reuse pass](https://github.com/koka-lang/koka/blob/d23ee7cd73737c1da7a7a5fa837a2806facc3d6b/src/Backend/C/ParcReuse.hs)
- [Perceus paper](https://doi.org/10.1145/3453483.3454032)
- [Author-hosted report](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/11/perceus-tr-v4.pdf)

Read repository architecture claims and located actual borrow/reuse passes; paper abstract/report describe cycle-free precise RC and reuse. This is not no-RC ownership.

<a id="s4"></a>
## S4 — Bend 2: compiler, runtime and independent kernel path

- [Current limitations](https://github.com/bendlang/bend/blob/9d514f3bb0d77524fcaa652645c902e4524eb838/README.md#limitations)
- [Sharing quantities](https://github.com/bendlang/bend/blob/9d514f3bb0d77524fcaa652645c902e4524eb838/guide/GUIDE.md)
- [Elaboration and kernel invocation](https://github.com/bendlang/bend/blob/9d514f3bb0d77524fcaa652645c902e4524eb838/bend2/safe.ts)
- [BendTT implementation and theorem statements/proofs](https://github.com/bendlang/bend/blob/9d514f3bb0d77524fcaa652645c902e4524eb838/bend2/bendtt.lean)
- [Runtime/compiler](https://github.com/bendlang/bend/blob/9d514f3bb0d77524fcaa652645c902e4524eb838/bend2/comp.ts)
- [BendTT paper](https://github.com/bendlang/bend/blob/9d514f3bb0d77524fcaa652645c902e4524eb838/paper/BendTT.pdf)
- [BendRT paper](https://github.com/bendlang/bend/blob/9d514f3bb0d77524fcaa652645c902e4524eb838/paper/BendRT.pdf)

Read README/guide and targeted implementation excerpts, including kernel claims and --verdict failure for out-of-scope/unsafe terms. Did not rebuild Lean proofs, run benchmarks or fully audit the papers/backend. README acknowledges backend mismatch and source→kernel translation trust. No reliance on unofficial bend2.dev for assurance claims.

<a id="s5"></a>
## S5 — Verus: actual dual-spec and spec-to-exec status

- [dual_spec implementation](https://github.com/verus-lang/verus/blob/310296664f467a1b139d1bd647b13ec289ff4791/source/builtin_macros/src/attr_rewrite.rs)
- [dual_spec tests and unsupported mutable parameter test](https://github.com/verus-lang/verus/blob/310296664f467a1b139d1bd647b13ec289ff4791/source/rust_verify_test/tests/syntax_attr.rs)
- [Spec-to-exec guide and unverified library translations](https://github.com/verus-lang/verus/blob/310296664f467a1b139d1bd647b13ec289ff4791/source/docs/guide/src/exec_spec.md)
- [Verified-generation tests](https://github.com/verus-lang/verus/blob/310296664f467a1b139d1bd647b13ec289ff4791/source/rust_verify_test/tests/exec_spec_verified.rs)

Read macro implementation, test excerpts, and guide. Implementation calls dual_spec a limited macro-level hack, not completed general dual mode. The guide marks some library translations unverified. No blanket independent small-kernel certification claim for Verus.

<a id="s6"></a>
## S6 — Aeneas: functionalizing ownership

- [Current subset limitations](https://github.com/AeneasVerif/aeneas/blob/de16f3cf877976e966906dc890f63dcb418884fa/README.md#targeted-subset-and-current-limitations)
- [Tutorial source](https://github.com/AeneasVerif/aeneas/blob/de16f3cf877976e966906dc890f63dcb418884fa/tests/src/tutorial/src/lib.rs)
- [Documentation](https://aeneasverif.github.io/aeneas/)

Read pinned README; indexed documentation returned older limitations, so the current README takes precedence. Formalization publications are linked there; not independently rebuilt.

<a id="s7"></a>
## S7 — Goose/Perennial verification infrastructure

- [Current Perennial repository](https://github.com/mit-pdos/perennial)
- [Older Goose translator repository/migration notice](https://github.com/goose-lang/goose)

Authoritative repository search results explain Go subset translation, Iris/Rocq verification, and migration. Not cloned or implementation-audited this tranche; never conflated with aardappel/goose.

<a id="s8"></a>
## S8 — Vx: types, capacity and bounded formal scope

- [Repository](https://github.com/vx-lang/Vx)
- [Cross-call capacity fold](https://github.com/vx-lang/Vx/blob/a681d483ea924f6413db8722c0a0af0e4ff0cbfe/src/hir/check/capacity_fold.rs)
- [Transfer checking](https://github.com/vx-lang/Vx/blob/a681d483ea924f6413db8722c0a0af0e4ff0cbfe/src/hir/check/transfer.rs)
- [Formal memory model, theorems, assumptions and limits](https://github.com/vx-lang/Vx/blob/a681d483ea924f6413db8722c0a0af0e4ff0cbfe/formal/memory_model/README.md)
- [Frontend rejection-test directory](https://github.com/vx-lang/Vx/tree/a681d483ea924f6413db8722c0a0af0e4ff0cbfe/tests/frontend/fail)

Read checker excerpts and formal-model README; inspected test filenames, did not run tests. Capacity fold explicitly ignores unknown extern/registry-import summaries as no known placements. This limits what that check alone establishes; no whole-project vulnerability claim. Formal model documents CPU/scope/barrier/core-language limits.

<a id="s9"></a>
## S9 — Futhark: uniqueness and scheduling

- [Uniqueness explanation](https://futhark-lang.org/blog/2022-06-13-uniqueness-types.html)
- [Incremental flattening paper](https://www.futhark-lang.org/publications/ppopp19.pdf)
- [Author explanation of workload-dependent scheduling](https://futhark-lang.org/blog/2019-02-18-futhark-at-ppopp.html)

Authoritative author-site search excerpts/paper abstract; not a compiler source audit or independent GPU benchmark. Paper describes guarded alternatives, including potential code-version expansion.

<a id="s10"></a>
## S10 — Cogent: important prior art for the proposed semantic bridge

- [Uniqueness and certifying compilation paper](https://doi.org/10.1017/S095679682100023X)
- [Earlier self-certifying compiler paper](https://arxiv.org/abs/1601.05520)
- [Verification architecture](https://cogent.readthedocs.io/en/latest/verification.html)

Published abstract and architecture documentation, not implementation rebuilt. Dual functional/imperative semantics and certified C correspondence predate Grail; no claim the downstream C toolchain is universally verified.

<a id="s11"></a>
## S11 — Lean: logic, execution and trust

- [Elaboration, kernel and compilation](https://lean-lang.org/doc/reference/latest/Elaboration-and-Compilation/)
- [Axioms](https://lean-lang.org/doc/reference/latest/Axioms/)
- [Proof validation and dependency auditing](https://lean-lang.org/doc/reference/latest/ValidatingProofs/)
- [partial/unsafe modifiers](https://lean-lang.org/doc/reference/latest/Definitions/Modifiers/)

Official reference search excerpts establish kernel/elaborator separation, axioms, unsafe/partial concerns and native-evaluation trust. Not a current compiler/runtime implementation audit.

<a id="s12"></a>
## S12 — Zig: canonical current I/O source

- [Official migration announcement](https://ziglang.org/news/migrating-from-github-to-codeberg/)
- [Current Io.zig](https://codeberg.org/ziglang/zig/src/commit/9271780c41baeb6f5c435f3c3b718ece9ed6186c/lib/std/Io.zig)
- [Current Threaded implementation](https://codeberg.org/ziglang/zig/src/commit/9271780c41baeb6f5c435f3c3b718ece9ed6186c/lib/std/Io/Threaded.zig)
- [Historical merged Io proposal (not current implementation)](https://github.com/ziglang/zig/pull/25592)

Downloaded immutable canonical snapshots, read interface/backend exports, async/concurrent contracts and cancellation API. GitHub source was first fetched, found stale, superseded and retained only as provenance. Evented is a platform-selected alias, not an Evented.zig file; the failed 404 is recorded. No runtime performance or completeness claim.

<a id="s13"></a>
## S13 — Regions and concurrent ownership

- [Project Verona research goals](https://www.microsoft.com/en-us/research/project/project-verona/)
- [Research implementation status](https://github.com/microsoft/verona)
- [Dynamic region ownership paper](https://doi.org/10.1145/3729313)

Research-source excerpts only. Distinguish dynamic region-ownership work with local reference counting from purely static region inference; do not attribute one uniform memory model to every Verona experiment.

<a id="s14"></a>
## S14 — Halide and Descend

- [Halide algorithm/schedule introduction](https://halide-lang.org/assets/lectures/Halide_CVPR_intro.pdf)
- [Halide autoscheduler research](https://halide-lang.org/papers/halide_autoscheduler_2019.pdf)
- [Descend PLDI 2024 paper](https://doi.org/10.1145/3656411)
- [Descend research site](https://descend-lang.org/)

Published/author-site descriptions, no implementation audit. Descend tracks execution resources, ownership, lifetimes and memory access; device residency alone is not all of GPU safety.

<a id="s15"></a>
## S15 — Go compilation architecture

- [Current compiler overview](https://go.dev/src/cmd/compile/README)
- [Export-data talk](https://go.dev/talks/2017/exporting-go.pdf)
- [Language/build design rationale](https://go.dev/talks/2012/splash.article)

Official documentation excerpts. Current unified export data includes types, generic/inline bodies and escape summaries; simplistic historical interface-only accounts miss this. No build benchmarking performed.

<a id="s16"></a>
## S16 — Cranelift

- [Official backend description and qualified benchmark claims](https://cranelift.dev/)

Backend authors describe fast code generation and less aggressive optimization. Their numbers are workload-specific, not Grail build/runtime predictions. Cranelift is commonly a Wasm-to-native compiler, not automatically a Wasm emitter.

<a id="s17"></a>
## S17 — MLIR

- [Architecture rationale](https://mlir.llvm.org/docs/Rationale/Rationale/)
- [Linalg progressive lowering](https://mlir.llvm.org/docs/Rationale/RationaleLinalgDialect/)
- [Incremental adoption/rationale index](https://mlir.llvm.org/docs/Rationale/)

Official architecture documentation excerpts; no measured claim that MLIR necessarily causes slow builds. Adopt only where representations/passes justify it.

<a id="s18"></a>
## S18 — Alive2

- [Actual supported scope and warnings](https://github.com/AliveToolkit/alive2)
- [Loop-bound coverage discussion (historical example)](https://github.com/AliveToolkit/alive2/issues/727)

Repository documentation/search excerpts warn about interprocedural transformations; bounded results must state bounds. Historical issue is not evidence that current code has an unfixed specific bug.

<a id="s19"></a>
## S19 — LLM-assisted verification research

- [AutoVerus published paper](https://doi.org/10.1145/3763174)
- [VeruSAGE study](https://arxiv.org/html/2512.18436v2)
- [VeriStruct study](https://arxiv.org/html/2510.25015v3)

Paper abstracts and benchmark descriptions, not replicated evaluations. Reported proof success is not autonomous validation of intended requirements or evidence of universal end-to-end correctness.

<a id="s20"></a>
## S20 — Commercial overlap: positioning, not audited assurance

- [Galois AI/formal methods](https://www.galois.com/ai-formal-methods)
- [TrustInSoft on AI-generated code](https://www.trust-in-soft.com/resources/blogs/formal-methods-ensuring-the-safety-of-ai-generated-code)
- [Code Metal formal-methods role/product description](https://jobs.ashbyhq.com/code-metal/550aed7b-86d2-48c3-af27-e61671e2d493)

First-party marketing/recruiting establishes overlap in product positioning only. Current product guarantees, business performance and independent customer outcomes not audited. Theorem/Certora/Polyspace still pending.

## Follow-up memory-model evidence

The [competition record](memory-model-competition.md#10-primary-evidence-and-revisions) includes
exact Hylo/Goose source links, the older separately pinned Hylo specification, the inspected MVS
paper, and Rust/Polonius/context-capture prior art. Source/specification/test inspection is kept
distinct from running complete workloads or measuring candidate compiler performance.

## V follow-up

See [V: targeted lessons](vlang-lessons.md) for the pinned revision and qualified findings on
access ergonomics, GC/autofree, implicit slicing clones, backend parity and build measurement.

## Executed reference experiments and current Hylo correction

See [results 01](experiment-results-01.md) and the [experiment manifest](../../research/evidence/experiments-20261030/manifest.json).
The prior `hylo-lang/hylo` source findings concern the former implementation. Current pinned source:

- [hylo-new README/toolchain requirements](https://github.com/hylo-lang/hylo-new/blob/36f135edd2f49b6951aaf6f753117340fbb232b3/README.md)
- [Current lifetime normalization](https://github.com/hylo-lang/hylo-new/blob/36f135edd2f49b6951aaf6f753117340fbb232b3/Sources/FrontEnd/IR/Transforms/IRFunction+LifetimeNormalization.swift)
- [Current module serialization](https://github.com/hylo-lang/hylo-new/blob/36f135edd2f49b6951aaf6f753117340fbb232b3/Sources/FrontEnd/Module.swift)
- [Current exclusivity fixture](https://github.com/hylo-lang/hylo-new/blob/36f135edd2f49b6951aaf6f753117340fbb232b3/Tests/CompilerTests/negative/exclusivity-violation.hylo)
- [Goose root classification and reuse](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/src/typecheck_calls.h)

Current Hylo sources/tests were read, not built. Goose was built and tiny tests were executed in
isolation. Neither is a formal audit; compare the explicit assurance boundaries in the report.

## Origin/capture contract experiment

[Results 02](experiment-results-02.md) links authored IR, implementation, isolated consumer evidence,
seeded finite checks and measurements. This is original experimental engineering evidence, not a
published novelty claim or independently checked soundness theorem. No new language commitment.
