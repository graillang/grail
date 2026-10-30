# Grail: initial architectural review

**Measured follow-up:** [experiment results 01](experiment-results-01.md) adds executed reference
probes and qualifies the earlier Hylo provenance and Goose specialization discussion. Earlier
“not executed” statements describe their original research tranche, not the current evidence set.

2026-10-30. **Research recommendation, not a settled language specification.**
**Follow-up:** [the memory-model competition](memory-model-competition.md) revises the borrowing
envelope and access/capability-syntax recommendations. This initial review is retained as history;
no permanent ban on externally borrowed aggregates or commitment to Rust punctuation was agreed.

This tranche prioritizes memory/modularity, effects/suspension, proof boundaries, and
closest implementations. It does not finish the full prior-art or commercial audit.
Source IDs link to [the evidence catalogue](sources.md). No third-party builds or installers
were run; no compiler, benchmarks, or machine-checked Grail proofs were produced.

## 1. Verdict

A useful, ambitious subset is feasible. The full brief is not a demonstrated combination.
The highest-risk demand is not memory safety without lifetime *spelling*: it is that plus
Rust-like borrowing expressivity, cheap inference, independent libraries, closures,
suspension, and unrestricted mutable data structures. Something must become explicit,
restricted, dynamically managed, or more expensive to analyze. This is a design trade-off,
not a proved impossibility theorem about all future languages.

Recommendation: **a value-oriented affine systems language with scoped loans and explicit
capabilities, not Rust plus Lean and not a pure lambda calculus for all programs.**
Keep a small operational resource semantics. Derive a functional interpretation where
ownership and effects justify it. Verification and scheduling consume that same typed core;
neither dictates every source-level construct.

There is no established new underlying abstraction here. Ownership, uniqueness, capabilities,
regions, effect rows, proof erasure, staging, and certifying compilation all have extensive
prior art. A potential contribution is the *particular modular contract*: inexpensive,
understandable summaries of access, origin, effects, and proof dependencies, validated on real
APIs. This must be demonstrated rather than branded as a breakthrough.

## 2. Closest implementations and what they actually establish

| Project | Useful evidence | Mismatch / boundary |
| --- | --- | --- |
| Hylo [S1] | Mutable value semantics; IR access/projection regions, liveness closure, abstract interpretation of initialization/destruction | Not evidence for integrated proofs, direct-style effects, or Rust-equivalent arbitrary borrowed structures; current compiler still has explicitly unimplemented paths |
| Goose memory-safe language [S2] | Root inference; data stacks; source implements specialized roots and stack assignment | Spec explicitly says closed-world, whole-program specialization on types, roots, writability, stack destinations, static functions. This conflicts with the modular baseline. Workers use isolated program stacks/message passing, not general shared-memory borrowing |
| Koka [S3] | Effect inference/handlers; Perceus and in-place reuse, implemented compiler passes | Reference counting is fundamental to this route; it does not meet no-mandatory-RC simply because it has no tracing GC |
| Bend 2 [S4] | Affine dependent language; CPU/GPU runtime; separate BendTT kernel implemented in Lean; law/proof workflow | Current README lists no separate/incremental compilation, slow native compilation, no proof search, mandatory annotations, balanced parallel calls, restricted scalar types. Sharing reusable data can incur RC. Source proof is not backend correctness |
| Rust + Verus / Aeneas [S5,S6] | Most direct existing route to systems ownership plus program verification; functionalization is real | Rust ergonomics/build costs remain. Aeneas documents subset boundaries for mutable-reference generics, nested loop exits, unsafe code, concurrency |
| Vx [S8] | Real placement/transfer/capacity checking code and failure tests, MLIR path, scoped formal memory-model artifacts | Capacity is conditional on a declared model and known summaries; formal core has stated restrictions and is not a proof of the production compiler or global GPU OOM freedom |
| Futhark [S9] | Uniqueness plus pure array semantics and effective data-parallel compilation | Specialized array language, not a general systems language; automatic schedule choice still needs runtime/workload information |
| Cogent [S10] | Uniqueness, functional and imperative semantics, certifying translation to C | Very relevant omitted prior art, not a drop-in general language with the requested async/generic/GPU ergonomics |
| Lean 4 [S11] | Small kernel, erased proofs, executable mathematics, tactic ecosystem | RC runtime and powerful elaboration are not the requested ordinary systems/build model |

**Bend 2 already substantially overlaps the AI + laws + proofs + CPU/GPU positioning.**
Do not claim that combination as Grail's novelty. Its documented limitations leave material
room for modular systems programming, predictable memory, fast native iteration, and simpler
ordinary code. Nothing in this tranche establishes that one existing language meets the full brief.

Do not confuse [aardappel/goose](https://github.com/aardappel/goose) with the Go-to-Rocq
translator used by [Perennial](https://github.com/mit-pdos/perennial) [S7]. The latter addresses
concurrent/crash-safe verification using Iris, not annotation-free manual-free memory for a new language.

### Fresh-status corrections

- Zig's GitHub repository is not a current mirror. Its canonical source moved to Codeberg [S12].
  The current `Io.zig` has a userdata/vtable boundary, Threaded and platform-dependent evented
  implementations, explicit concurrency, cancellation and groups. `Io.async` may run immediately;
  `Io.concurrent` promises a concurrency unit or fails. These are **library APIs**, not a static
  effect system or a general borrow safety proof.
- Verus `dual_spec` is present in implementation and tests, but its implementation explicitly calls
  it a limited macro-level workaround for pure computation; the full dual mode is not ready [S5].
- Verus `exec_spec_verified!` generates executable counterparts and equivalence obligations for a
  supported fragment. Its documentation warns that some library operation translations remain
  unverified, even inside that facility. The separately named unverified variant uses external bodies.
- Bend's default checker and `--verdict` are different assurance paths. Inspecting the Lean file
  and elaborator is not independently rebuilding or auditing its kernel theorems.
- Aeneas's live README is less restrictive than older indexed documentation. Use the pinned README,
  not an old claim that all nested loops or all closures are universally unsupported.

## 3. Minimal principles

1. **Ownership buys independence.** An owned value is independent of other owned values;
   moving transfers responsibility. No silent deep clone or shared mutable alias.
2. **Access is temporary permission.** Many readers or one writer, with inference local to a function
   and origin relationships exported across boundaries. Be explicit about access modes, not lifetime names.
3. **Authority is passed; behavior is summarized.** Capability values authorize operations. Effects
   describe what calls may do, including suspension. A capability is not interchangeable with an effect.
4. **Logic observes execution; it cannot smuggle assumptions into it.** Share definitions/models,
   erase proofs, separate total logical computation from partial runtime computation, and track trust.
5. **Scheduling and staging preserve meaning.** They are constrained transformations, not permissions
   for different arithmetic, failure ordering, allocation visibility, or undisclosed transfers.

This is not literally one universal mechanism. Spatial aliasing, temporal suspension, and logical
truth solve distinct problems. Forcing all of them into one capability token would likely obscure
rather than simplify the language. Keep the mechanisms small and their interfaces explicit.

## 4. Competing foundations

Qualitative expectations below are hypotheses, not measured rankings.

| Architecture | Advantages | Main costs | Recommendation |
| --- | --- | --- | --- |
| A: Rust-like imperative | Direct systems/FFI model; familiar static performance; mature borrowing literature | Persistent borrowed aggregates, higher-ranked APIs, unsafe/interior mutation increase surface and proof complexity | Useful reference and escape-hatch envelope, not the whole ergonomic baseline |
| B: Pure functional | Equational reasoning; data parallelism; simple value-level specifications | Purity alone does not supply deterministic reclamation, cheap sharing, or locality; RC/copies/uniqueness still required | Use as an interpretation of suitable code, not a universal operational fiction |
| C: Region/capability | Cyclic graphs and bulk ownership; authority and transfer can be explicit | Retention until region end, cross-region links, regional alias rules, dynamic region costs; not all Verona variants are fully static [S13] | Offer arenas/handles and perhaps isolated regions as libraries/advanced facilities |
| D: Affine values + scoped loans + capability effects | Local ownership checks, controlled mutation, useful functional projection; modules export finite summaries | Rejects some zero-copy APIs; effects/views/closures still require formal design | Recommended working hypothesis |

D is a constrained synthesis of A/B/C, not a newly proven calculus. The first experiment must try to
break its claimed modularity and ergonomics rather than build attractive syntax around it.

## 5. Proposed semantic core

### Values, places, and permissions

Runtime values: scalars, records, tagged unions, functions/closures, and owned allocations.
A *place* is addressable storage owned through a finite ownership tree. Owned heap boxes and
buffers are normal values. Resource ownership is affine (no duplication); disposal elaboration
inserts deterministic reclamation on ordinary exits. Affinity alone does **not** imply no leaks:
nontermination, abort, foreign code, and an explicit forget operation need separate policies.

Moves invalidate the source. Only designated trivial scalar/layout types copy implicitly.
Expensive clone is an ordinary explicit operation. Mutable bindings permit updating owned places.
Shared loans permit reads; exclusive loans permit mutation and reborrowing. Owners cannot move,
shrink, or reallocate storage while incompatible views exist. Disjoint field/slice splitting
requires a checked rule or a safe primitive with a proved/assumed implementation boundary.
A root by itself establishes a lifetime bound, **not** exclusive access or race freedom.

Do not force a whole-function borrow region: use local last-use analysis. At module boundaries,
compile against symbolic roots: e.g. output loan derives from input 0, or conservatively from
inputs {0,1}. Export access modes, returned/captured origins, and effect parameters. The client
substitutes its places into the summary; it does not reanalyze the callee or specialize on root names.
If a precise representable summary cannot be produced, reject, require an explicit contract, or
use a callback/owned result. Never silently trigger whole-program inference.

Baseline: owning aggregates plus scoped loan-carrying views, closures and iterators whose origins
are statically tracked. No arbitrary persistent reference fields or movable self-reference initially.
This restriction must still admit useful library iterators: an iterator that holds a loan is a
scoped value, and its borrow metadata must survive generic and module boundaries. That is an
unresolved formal obligation, not solved by calling the type a `View`.

Graphs and intrusive relationships: use `Arena[Node]` plus typed indices/IDs. Reusable slots need
non-wrapping generations or another sound invalidation scheme, with checked lookup if removal is
allowed. Handles can avoid pointer lifetimes; they do not guarantee static existence or zero lookup
cost. Optional shared ownership, lock-protected structures and regions must be explicit.

### Destruction and failure

Compiler-generated memory cleanup has predictable structure and a cost report, but recursive
cleanup is still work and may overflow a naive stack. Do not initially allow arbitrary hidden
user destructors, I/O, or suspension on drop. Use explicit `defer` for non-suspending cleanup and
explicit close/finish for fallible or suspending operations. A safe resource library must define
what happens on every `?`/cancellation path; asynchronous close cannot simply be hidden in `defer`.
Forgetting an OS handle may leak a resource without becoming memory-unsafe; stronger protocol
obligations need a separate linear/must-finish policy rather than a false affine guarantee.

### Types, functions, and polymorphism

Nominal records/unions; exhaustive matching; local type inference; explicit public parameter and
result types. One constrained interface mechanism with coherence, no overlapping specialization,
no unbounded implicit search. A closure type includes captured permissions and effects. Static
dispatch is the performance baseline; explicit erased/dynamic interfaces are allowed where useful.
Method notation resolves a uniquely visible ordinary function, then desugars `x.f(y)` to `f(x,y)`;
no arbitrary extension-method search or property execution. Fixed operators only initially.

### Effects and capabilities

Track a small operational set: authority use, allocation, external mutation, suspension, spawn,
nondeterminism, foreign/unsafe. Mutation of an unaliased local value can be encapsulated rather
than polluting every caller's signature. Model reads/writes with a resource identity, not merely a
Boolean `mutates`; coarse effects cannot prove two writes independent. Externally visible destructor
or allocation/failure behavior also matters for reordering.

Explicit values grant filesystem/network/device/allocator authority. Prefer narrow `Dir`/`Net`
capabilities to a universal `Io` authority; runtime scheduling implementation is a separate argument
or component. Locals infer effects, higher-order combinators abstract over callback effects, and
published signatures have inspectable checked summaries/upper bounds. Effect rows are plausible,
not yet selected syntax. Passing a powerful capability but not using it and actually performing
an effect are different facts.

Errors are tagged values `Result[T,E]`; `!T` abbreviates a default *named closed* error union,
with an explicit typed variant for APIs. `?` returns the error from the current function and runs
scoped cleanup. Error inclusion/widening must be explicit or a restricted checked injection rule.
No separate exception mechanism or panic unwinding. A safe trap for bounds/overflow is not memory
UB; checked arithmetic is the baseline recommendation, explicit wrapping is an ordinary operation.
Allocator exhaustion policy is still open; no undefined behavior in either debug or release.

### Suspension and structured concurrency

An ordinary call can suspend **only** if its effect permits it. There is no async function color
in syntax or `Future`-returning twin of every API, but there remains a real suspends/non-suspends
type distinction. An evented and a blocking implementation of an API share the same conservative
published effect bound so changing runtime does not change safety typing.

A borrow may cross suspension if its owner/frame remains live and stationary, no conflicting
access runs concurrently, and cancellation cannot reclaim it early. This is not a universal ban
on mutable loans across suspension. Affine handles/loans move into children; a task scope joins
children before parents' storage expires. A lock guard is non-suspending by default; an async mutex
has a different documented contract. Memory safety does not prove deadlock freedom or bounded latency.

Spawning is explicit. Exiting a task scope requests cancellation of unfinished children and joins
them before reclamation; failures have a specified selection/order policy, not a timing accident.
Cancellation is cooperative at documented points, represented as an explicit result, not arbitrary
stack destruction. A noncooperative child can prevent the scope from exiting: no bounded-cancellation
promise. Cleanup may require a bounded/noncancelable region; its semantics must be tested.

Start with one-shot runtime operations, not general multi-shot continuations. Runtime alternatives:
stackful fibers (simpler direct-style native stack/FFI, per-task stacks/context switches) versus
compiler-lowered frames (effect-directed ABI, complex higher-order calls, code-size costs). This is
an experiment, not a choice solved merely by writing effect types.

### Mathematical propositions and executable contracts

Use one typed source core with an erased logical stratum. Pure terminating functions may be
reflected into logic using their actual definitions, including machine integer semantics. General
recursion, I/O and concurrency receive relational/trace/Hoare specifications, not total definitional
equations. Mathematical integers are a distinct explicit model of machine integers; overflow,
float rounding/NaN, aliasing and allocation behavior must not disappear during functionalization.

Propositions/proof terms are checked by an established small kernel in the research phase.
SMT and AI are proof search tools. If an SMT outcome has no checked certificate for the relevant
encoding/theory, list the solver and encoder in the TCB; do not describe it as independently
kernel-certified. Native evaluation of propositions can likewise enlarge the TCB.

Basic type/ownership safety never depends on a skipped advanced proof. In `build`, an unproved
executable precondition must retain a runtime check, be cheaply established, or cause rejection;
a nonexecutable proof obligation cannot silently be assumed. `verify` proves deeper contracts;
`build -release` may remove checks based on applicable checked evidence. A release policy can
require proof coverage but cannot turn unknown into proven.

Evidence identifies normalized definitions, contracts, transitive assumptions, target model,
semantic version, toolchain/unsafe/FFI boundary, and proof dependency hashes. Separate status:
safe / contract checked / assumed / bounded result / unsupported / unknown. A theorem is not a
badge for all behaviors of a package. Source correspondence and backend correspondence are
separate coverage dimensions. Proof caching uses semantic dependencies, not timestamps or comments;
ABI/target/model changes invalidate relevant evidence. Certificates from packages still need
checking or an explicitly trusted certification chain.

### Compile-time evaluation

Evaluate ordinary code in a deterministic capability-free environment unless inputs are declared.
Start with first-order data, types and finite static parameters, explicit fuel/memory/specialization
budgets, reproducible errors and content-addressed caches. Exhaustion means a diagnostic, not a
logical proof of divergence. Runtime code may remain partial; logic reflection requires totality.
No filesystem/network access hidden in compile-time evaluation. Build scripts are a separate trust
boundary. Partial evaluation of one input is not a proof for all inputs; specialization needs a
semantic preservation argument or checked instance evidence.

### Placement and scheduling

Represent accelerator residency in advanced `Buffer[T,Space]` types and execution authority in a
`Device[Space]` capability, with transfer/launch effects. A pending transfer owns/loans its source
and yields a completion token; destination access requires completion. Synchronous convenience
transfers may suspend. Unified physical memory does not erase synchronization/coherence rules.
Safe kernels require a supported subset, bounds/race/access checks, and convergence/barrier rules.
An NPU generally executes supported graphs/operators, not every systems-language function.

Static capacity guarantees apply only to bounded live allocations in a declared/reserved budget.
Other processes, fragmentation, driver allocations and runtime shapes require reservation/admission
and fallible runtime allocation. In Vx's inspected capacity fold, missing external/imported summaries
contribute no known placements; that branch is a concrete reason to qualify whole-program claims,
not a demonstrated general soundness bug. Grail should propagate **unknown**, not pretend it is zero.

Automatic parallelism: first pure, suitably total, failure-order-insensitive computations or
explicit disjoint borrowed footprints. Pure calls that can diverge/trap/allocate are not freely
reorderable under every observable semantics. Floating-point reduction reordering changes results;
require a specified tree/order or explicit relaxed numerical policy. No observable hidden spawn
for effects. Start with library parallel map/reduce; compiler may fuse/vectorize/schedule inside
a declared parallel region. Cost models determine profitability, not proofs of independence.
Halide/Futhark teach that scheduling remains a serious optimization problem [S9,S14].

## 6. Explicit feature budget

| Category | Proposed budget |
| --- | --- |
| Essential semantic foundations | Affine ownership, scoped shared/exclusive permissions, typed functions/ADTs, constrained polymorphism, resource-indexed effects/capabilities; erased total logic kept distinct from partial execution |
| Essential surface | `fn`, immutable/mutable bindings, records/unions, blocks/loops/match, explicit move/borrow boundaries, ordinary calls/closures, `!`/`?`, explicit scoped cleanup; exact grammar undecided |
| Compiler-derived conveniences | Last-use borrow ending, local inference, origin/effect summaries, method desugaring, iterator specialization/fusion, routine bounds facts |
| Standard library | Owned containers, iterators, arenas/IDs, `Result`, files/network capabilities, task scopes, cancellation tokens, parallel combinators, explicit allocators |
| Advanced optional facilities | Contracts/proof terms, explicit shared ownership, typestate via ADTs/generics, device buffers, explicit dynamic dispatch, proof-carrying packages |
| Experimental research | More general stored views, isolated cyclic regions, effect-directed stackless ABI, proof-certified optimizations, auto scheduling/offload, richer dependent types, flow security, resource bounds |
| Reject initially | Inheritance, implicit conversions/clones/COW, general operator overloading, executable properties, global typeclass search, macros in addition to staging, unstructured detached tasks, multi-shot handlers, universal device execution, universal cross-language frontend |

Contracts, proofs and staging need not be ordinary-build costs beyond their small checked interface.
Do not advertise a five-keyword language while hiding a second huge language in annotations.

## 7. Compiler strategy and achievable compromises

Pipeline: `.grl` → parsed AST → typed/resource-checked core → per-function operational IR →
lightweight backend IR → native code. Retain stable source mapping and logical interpretation of
eligible core terms. Verification branches from typed core **before** destructive lowering;
checked transformations preserve links to later IR.

- Separate package compilation with lazily decoded export data: types/layouts, access/origin/effect
  summaries, contracts, generic bodies and selected inline bodies. Go's current export data also
  includes generic/inlining IR and escape summaries; fast builds do not mean interface-only metadata [S15].
- Bounded local inference; nominal recursive types; reject recursive inference cycles without signatures.
  Avoid theorem search, root-per-call monomorphization and global implicit instance search.
- Hash syntax/semantic entities; separate body-only changes from interface/effect changes; cache summaries,
  generic specializations, code objects and checked proof dependencies. Measure hashing/serialization too.
- First serious codegen experiment: one backend only. Cranelift is a plausible fast native path [S16].
  It does not remove frontend, linking, debug-info, generics, or compile-time evaluation costs.
- Default static specialization has a real compile/code-size price. Cache and merge compatible bodies;
  optionally use shared dictionary/erased bodies in development, with explicit performance expectations.
  Representation sharing does not guarantee zero-cost callback dispatch. No promise of simultaneously
  full monomorphized performance and monomorphic compile cost for arbitrary generics.
- Later LLVM release path for inlining, vectorization, target support; release can be slower to compile.
  Neither LLVM nor Cranelift is the source semantics. They must agree on traps, ABI, floats and aliasing.
- MLIR is an optional accelerator/array pipeline, not mandatory for ordinary CPU builds [S17]. Its
  overhead is workload/pass dependent and must be measured; a fast path can bypass it.
- Native CPU first. Wasm is an output target via an explicit lowering strategy/appropriate backend,
  not something Cranelift automatically emits (it commonly consumes Wasm). Stack/allocator assumptions
  must be rechecked for Wasm. GPU/graph targets come later and need separate runtime/toolchain boundaries.
- Proof search out of band; kernel checking may still be expensive and gets explicit budgets/caches.
  No claim that independent proof checking is inherently negligible.
- Translation validation of selected passes can reduce risk. Alive2 is useful, not whole-compiler
  verification; its support/bounds and lack of interprocedural transformation support matter [S18].
  Source→core, ownership elaboration, runtime, FFI, lowering, backend, linker, OS/device assumptions
  remain in the assurance ledger until independently justified.

**Go-like development builds and Rust-like optimized runtime are compatible as goals in different
build modes, not established simultaneous outcomes.** Forcing aggressive optimization and unrestricted
specialization into every edit build would undermine the first goal.

## 8. Prototype and research priorities

See [experiments](experiments.md). First test the modular loan/effect contract, not a complete
parser, GPU backend or prover. Include iterator/closure captures and a minimal simulated suspension:
otherwise we risk approving a memory design that cannot support the async pillar.

Prove a small calculus's preservation and loan/owner validity in an existing prover. Also implement
only enough checker/IR machinery to measure analysis scaling. A paper proof alone does not establish
compile speed; a benchmark alone does not establish soundness.

## 9. Commercial assessment, after architecture

Technical novelty, product differentiation, and business viability are distinct. AI proof repair,
source-level contracts, and verified translation are crowded areas: AutoVerus/VeruSAGE/VeriStruct
already study proof automation; Galois, TrustInSoft and Code Metal already market AI-plus-formal
assurance [S19,S20]. Their materials are evidence of positioning, not an independent audit of products.
Theorem, Certora, Polyspace and additional competitors still need a focused current-capability review.

Best initial wedge hypothesis: small safety-sensitive native components generated/edited by agents,
with fast rejection of unsafe changes and precise contract evidence at a C ABI boundary. Examples:
binary parsers, codecs, bounded data transformations. This minimizes migration and tests ordinary
CPU merit. Do not begin by claiming verification of arbitrary C++/Rust via LLVM.

Keep the language frontend separate from the proof/evidence service. A second frontend should be a
narrow Rust-MIR adapter only after shared needs are concrete; high-level semantics require language
adapters, and LLVM IR alone cannot restore erased ownership or intent. Avoid a universal verification
IR: share selected typed operations and explicit semantic interfaces, retain language-specific models.

Possible paid value: reliable incremental proof/evidence CI, assurance policies, integrations and
specialized support. A compiler can remain open source. Demand must be tested against Rust+Verus/Aeneas
and incumbents by measuring proof maintenance, build latency, interop effort and customer willingness
to pay. No market-size or defensibility claim is established here.

## 10. Unfinished investigation

This first tranche is not the complete requested literature review. Next: deeper Hylo projection/
closure APIs and Goose specialization measurements; Lean-model ownership contract; Zig runtime
implementation costs; Koka one-shot lowering; Cogent proof architecture. Then compare Dafny, F*,
Idris 2, SPARK, ATS, Eio, Java virtual threads, Descend, Kuiper/NVIDIA work, P, information flow,
resource analysis, and Kani/SAW/Crux/SeaHorn/SMACK/ESBMC/CompCert/CakeML/Vellvm on exact use cases.
An index hit is not an implementation audit. Do not fill missing cells with remembered marketing.

[S1]: sources.md#s1
[S2]: sources.md#s2
[S3]: sources.md#s3
[S4]: sources.md#s4
[S5]: sources.md#s5
[S6]: sources.md#s6
[S7]: sources.md#s7
[S8]: sources.md#s8
[S9]: sources.md#s9
[S10]: sources.md#s10
[S11]: sources.md#s11
[S12]: sources.md#s12
[S13]: sources.md#s13
[S14]: sources.md#s14
[S15]: sources.md#s15
[S16]: sources.md#s16
[S17]: sources.md#s17
[S18]: sources.md#s18
[S19]: sources.md#s19
[S20]: sources.md#s20
