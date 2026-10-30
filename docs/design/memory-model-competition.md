# Memory-model competition: values, loans, and roots

**Measured follow-up:** [experiment results 01](experiment-results-01.md) adds executed reference
probes and qualifies the earlier Hylo provenance and Goose specialization discussion. Earlier
“not executed” statements describe their original research tranche, not the current evidence set.

2026-10-30, second research tranche. **Design-level comparison, not implementations or benchmark
results.** No candidate checker or complete workload has been built. Tables below give semantic
expectations and specific implementation evidence, not measured acceptance/performance scores.
The initial architecture remains a candidate, not a decision.

## 1. Assessment of the critique

Accept: do not permanently ban borrowed aggregates; keep access syntax unsettled; evaluate typed
context passing instead of parameter plumbing; require useful diagnostics; make zero-copy APIs and
separate generic compilation admission tests rather than optional future polish.

Correct: compact exported ownership relationships are **not a new idea in themselves**. Rust lifetime
signatures already express modular constraints and common cases use lifetime elision. Polonius models
origins, loans and subset relations. Region/effect inference long predates Grail. Potential novelty
would require demonstrating a materially better expressivity/inference/modularity/cost trade-off.

Also correct the framing: these are not three disjoint mathematical foundations. Mutable value
semantics is an observable independence discipline; loans govern temporary access; roots describe
provenance/lifetime bounds. A viable system may use all three. Compare operational restrictions,
API shapes and exported information, not project brands or punctuation.

## 2. Four different meanings of “persistent reference”

1. **Long-duration external borrowing.** An AST stores thousands of views into a separate immutable
   source buffer. The source outlives the AST. This can be both long-lived and scope-bounded.
2. **Captured/returned borrowed aggregates.** A function returns an AST of views and containers of
   those views; generics and closures preserve its origin. This is harder than a single borrowed slice
   but does not inherently require runtime lifetime checks or copies of source bytes.
3. **Owner and its internal views packaged together.** A returned document owns the source and its
   AST points into that source. Ownership transfer, storage stability, field mutation, destruction order
   and which views may escape now need an additional rule. Moving a heap-buffer descriptor need not
   move its bytes, but does not by itself establish a sound source-level owner/view relationship.
4. **Freely aliased mutable graphs with deletion/invalidation.** Independent aliases remain usable
   as nodes/pages move, mutate or disappear. Lifetime inference alone cannot make invalidation safe.
   Restrict access, retain stable storage, use checked handles/synchronization, or reject operations.

Calling all four “persistent” obscures the architectural decision. **Make cases 1 and 2 first-class
requirements of the design competition**, not prohibit them by conflating duration with self-reference.
Cases 3 and 4 are separate tracks, not assumed solved by permitting reference fields.

## 3. Candidates and what is actually demonstrated

### A — Rust-inspired modular loans, with more interface inference

Owned values plus shared/exclusive loans; local liveness; symbolic origins/outlives relationships
exported in interfaces. Rust establishes much of the expressivity envelope, not automatic inference
of every exported relationship. Do not claim Polonius is already Grail's inference algorithm or that
implementing it automatically makes analysis fast.

- Best expected expressivity for ordinary externally borrowed records and slice APIs.
- Costs: field-sensitive relationships, variance, nested mutable loans, callback quantification and
  lending iterators must be represented; fewer written lifetimes do not remove those semantics.
- Reject caller-root-specific specialization as a default. Generics can be checked against symbolic
  contracts while release codegen still specializes layouts/operations.

### B — Hylo-inspired value-first operations and projections

Values are independent; operations request read/modify/consume access. Prefer temporary projections
and value-transforming APIs; captured projections may extend access for a receiving value.

- Strict MVS can simplify checking **by restricting** reference storage, not by making arbitrary
  reference semantics free. The 2022 MVS paper explicitly describes second-class references and
  studies COW containers; neither that paper's COW strategy nor its strictest reference restriction
  should be attributed indiscriminately to the current Hylo implementation or adopted as Grail policy.
- Hylo's separately pinned specification permits objects/closures to capture projections (rule 10)
  and defines projection constraints transitively (rule 3). This is important evidence against a
  simplistic “Hylo cannot store a view” characterization.
- Actual compiler `CaptureIn` requires target provenance from stack allocation; borrow closure has
  an explicit unimplemented branch for other storage. These excerpts do not demonstrate general
  heap-stored view containers or every zero-copy parser API. Do not generalize their absence from
  a file-name search, either.
- As captured views become more expressive, B also needs provenance/liveness information. Evaluate
  whether its preferred APIs genuinely keep that information simpler and its diagnostics better.

### C — Goose-inspired concrete roots, then a separate modular variant

C0 is actual Goose: root bounds, root-dependent whole-program specialization, non-moving data-stack
layouts and storage restrictions. It supports stored references, relative references, parser-style
recursion, and isolated workers. It is not merely a toy scoped-reference language.

C1 is a **Grail research variant**: abstract roots and root constraints in exported signatures instead
of specializing safety analysis per concrete caller root. This is not an implemented Goose feature.

- C0 fails our separate-compilation gate as documented, irrespective of attractive source ergonomics.
- C1 must also solve reclamation/layout without whole-program stack assignment. Conventional owned
  allocations or separately abstracted regions change the model; document that change explicitly.
- Goose roots do not supply Rust-style exclusive alias guarantees. To support Grail's shared-memory
  concurrency, C1 needs permissions/isolation or synchronization. Adding these may make it close to A/B.

## 4. Shared workload competition

Use one behavioral/ownership specification for each workload. Ports may change API shape, but report
that change. No candidate wins by cloning input, adding RC, forbidding required operations, or changing
threading behavior without counting the compromise.

Legend: A/B/C1 entries are design expectations, not successful compiler executions. C0 is documented
Goose, with source-level supporting cases listed in the evidence section.

| Workload and required behavior | A: inferred modular loans | B: value/projection APIs | C0 roots / C1 modular hypothesis |
| --- | --- | --- | --- |
| W1 JSON-like parser; vector/tree of string views into caller-owned immutable bytes; returned across a module boundary | Natural borrowed aggregate; infer type-level origins through containers | Captured projections or input-bounded view aggregate needed; strict second-class-only variant fails this shape | Goose documents reference-bearing struct returns; C1 needs symbolic captured-root metadata |
| W2 Document owns bytes and AST; return/move whole document, expose temporary text views | Ordinary borrowing alone insufficient; frozen owning package, stable-storage abstraction, or offsets | Whole value is natural; internal captured-owner relationship still needs a sound rule | Relative references are a relevant alternative in Goose; C1 must preserve relocation/invalidating-access rules |
| W3 Database page guard; row views remain valid while page pinned, eviction resumes afterward | Loan tied to guard; cache cannot release/unmap while views live | Scope/projection API may make guard region natural; returned views must capture guard permission | Root bounds lifetime, but pin/evict protocol is extra in both C0/C1; root name alone cannot guarantee mapped storage |
| W4 Hash-map entry API; mutate selected entry then insert/rehash | Exclusive loan prevents conflicting rehash until last use | Mutating projection can make operation scope explicit | Non-moving growth changes some invalidations, but shrink/type changes still need checks; no inference permits dangling entries |
| W5 Immutable slice iterator; map/filter and collect borrowed substrings | Output views borrow stable original owner, not iterator frame | Scoped iterator captures projection; generic forwarding must preserve captures | Root sets must survive function values and generic instances; modular C1 not established |
| W6 Lending decoder; `next` reuses one scratch buffer | Output borrows receiver until next mutation; cannot retain all outputs without copies/storage redesign | Yield/projection API may encode access directly | Non-moving storage is not enough: reusing/overwriting scratch changes retained views; semantics must be specified |
| W7 Callback visits mutable tree nodes; callback may not retain the temporary node loan | Fresh per-invocation loan contract, unlike an outer input loan | Temporary access convention is a promising simplification | Callbacks need root abstraction/retention rules; union of all concrete roots is not sufficient |
| W8 Async read into caller buffer, cancellation during I/O, parent exits | Loan held until completion/cancellation acknowledged, then join before reclaim | Same temporal requirement despite value-oriented syntax | Goose isolated-worker semantics do not demonstrate this shared-buffer model; C1 requires additional runtime/permission rules |
| W9 Intrusive cyclic graph, pointer aliases, node deletion | Not automatically possible with unrestricted safe aliases; choose stable region/controlled access/handles | Strict independent values require region/relationship abstraction or redesigned graph | Goose pools/relative references useful, with actual storage/shrink restrictions; not arbitrary individual deallocation |
| W10 Separately compiled generic adapters and stored callback | Type/origin/effect parameters, capture bounds and monomorphic ABI decisions | Access-polymorphic conventions must carry captured-projection constraints | C0 whole-program design fails gate; C1 is unimplemented and may converge on A/B |

### Shared interface sketches for W1, not three implementations

Common requirement: parse once without copying source lexemes; return aggregate/container of views;
traverse after parser temporaries die; reject freeing/reallocating the source while the AST is used.

```text
A: fn parse(source: &Bytes, mem: &Allocator) !Ast
   Ast contains borrowed text; exported origins tie those fields to source.

B: fn parse(read source: Bytes, use mem: Allocator) !Ast
   Ast captures read projections of source; no transient parser frame is captured.

C1: fn parse(source: BytesView, mem: Allocator) !Ast
    Ast's fields are bounded by an abstract input root, not a concrete caller variable.
```

Names and punctuation above are illustrative. Merely renaming `&Bytes` to `read Bytes` does not
constitute a different memory model. C1 is not Goose syntax or a working compiler feature.

Required invalid case in every candidate:

```text
let ast = parse(source)
source.clear_or_replace_storage()  // invalid while ast's views can still be read
use(ast)
```

Zero-copy is compatible with this rejection. Requiring *both* arbitrary invalidating mutation and
unchanged raw views would be requiring the impossible behavior, not a better inference algorithm.

## 5. Candidate summary: more than “output derives from input”

A proposed module summary must describe:

- Input access modes and symbolic storage/origin parameters.
- Result origins **per relevant field/type component**, including borrows nested in containers.
- Retained/captured loans and writes of views into caller-provided storage.
- Required outlives constraints, permission transfers, and disjointness preconditions.
- Callback invocation access, fresh per-invocation loans, allowed escape/capture behavior.
- Effects and capability identity, including suspension and task capture.
- Cleanup/owner dependencies such as allocator or pinned-page lifetime where relevant.

An illustrative mathematical sketch (not a selected IR):

```text
choose: forall rA,rB.
  (read Bytes@rA, read Bytes@rB) -> View[Bytes]@{rA,rB}

tokenize: forall r.
  read Bytes@r -> Vec[Token[text@r]]

visit: forall r.
  (modify Tree@r, callback forall q within r. modify Node@q -> Unit)
  callback may not retain q outside that invocation
```

For `choose`, `{rA,rB}` is a conservative set of possible origins; safe caller storage must respect
both bounds. It is not a claim that the implementation holds both pointers or needs a runtime set.

A flat result-origin union is insufficient. If an object has one field borrowing a long-lived source
and one field borrowing scratch, unioning both into every field can reject valid independent use.
Preserving every branch/path correlation can in turn make summaries and inference expensive. Start
with bounded field-sensitive graphs; record where conservative widening loses required programs.
Do not assume principal minimal summaries exist for the eventual entire language.

Inference policy proposal: infer/check against symbolic interfaces locally; use explicit public
upper bounds or a reviewable generated interface snapshot for stability. Changing which input a
public result borrows from is an API change even if the surface signature is unchanged. A body-only
edit may therefore legitimately invalidate dependents. Never sell inference as free API stability.

## 6. Three access syntaxes, same semantics

All variants distinguish **read**, **modify**, and **consume**. Exact words are provisional. A
read parameter does not implicitly clone; mutable access does not silently copy to break aliasing.

| Surface model | Declaration | Call | Strength / cost |
| --- | --- | --- | --- |
| S1 reference spelling | `fn debit(a: &mut Account, n: Money)` | `debit(&mut account, n)` | Explicit and familiar; reference-oriented mental model and repeated markers |
| S2 parameter and call conventions | `fn debit(inout a: Account, n: Money)` | `debit(inout account, n)` | Value/operation framing and visible mutation; verbosity remains and consume/read conventions still need rules |
| S3 parameter conventions, inferred call access | `fn debit(inout a: Account, n: Money)` | `debit(account, n)` | Lowest routine call-site noise; reader needs declaration/tooling, and API mode changes are less obvious in diffs |

S2 is inspired by, not an exact transcription of, Hylo syntax. Hylo's actual access vocabulary includes
`let`, `set`, `inout`, `sink`, `yielded`; Grail must not import all five without a demonstrated need.

**Revised recommendation:** lead with S3 for read access; compare S2 vs S3 for modify/consume. Keep
S1 as the control, not the default winner. Require a uniquely resolved callee and declared mode; no
meaning-changing ownership inference from callee bodies at call sites, mode-dependent overload
search, hidden clone, implicit RC or user-defined conversions. Generic callback access modes must
also be in signatures. Compiler-inserted borrowing is not runtime borrow checking.

Reader study: identify mutated/consumed values without IDE, then with mode hints; predict alias
errors, explain moves, diagnose a changed callee mode. Count mistaken predictions, repair time,
explicit markers, review churn and hidden runtime work—not only source characters.

## 7. Contextual capability passing without ambient authority

Explicit values at trust/execution boundaries need not mean every internal call repeats `fs, net, mem`.
Compare explicit arguments against **lexically resolved typed context parameters**, elaborated to
ordinary parameters/evidence. This is constrained elaboration, not permission for a global implicit
search engine or general effect-handler language.

Illustrative alternative:

```text
fn load(path: Path) !Bytes uses { fs: Dir, mem: Allocator } {
    fs.read_all(path, mem)?
}

with { fs = sandbox_dir, mem = request_arena } {
    load(path)  // compiler supplies the named context arguments
}
```

`uses`/`with` are tentative display syntax, not approved new keywords. Locals may infer requirements;
published interfaces expose checked bounds. The declaration need not list authority already explicit
in normal parameters. If a receiver/context already contains `mem`, do not invent a second allocator.

Rules required before choosing this model:

1. Resolve lexical named requirements at compile time; ambiguity is an error, not a search heuristic.
   Two directory capabilities are not interchangeable just because both have type `Dir`.
2. No process-global/thread-local context lookup or import-granted filesystem/network authority.
   Modules can declare requirements; instances/execution boundaries supply capabilities.
3. A closure either captures the selected capability (and its origin/permission) or remains context-
   polymorphic for invocation. Those are different checked types; never silently choose the former.
4. Context insertion cannot duplicate exclusive capabilities or move affine ones twice. A capability
   needed by concurrent children requires shareable permission or explicit splitting/serialization.
5. Values escaping a scoped allocator/page context must retain valid owner dependencies or be rejected.
   A `Bytes` result allocated in a request arena cannot simply outlive that arena because its name
   omits a lifetime. General allocating contexts may therefore affect result types/summaries.
6. Effects describe operations; captures describe retained authority. No network effect is not the
   same claim as possessing no network capability. Raw syscalls/FFI/unsafe code remain explicit TCB.
7. Context lookup never selects an unrelated new instance at runtime. Scheduling implementation and
   resource authority stay separable; public suspension bounds do not change with runtime choice.

Scala's experimental capture checking/context function work is relevant prior art, not an off-the-
shelf no-GC memory solution. Assess its capture/escape machinery and complexity before borrowing it.

## 8. Diagnostics are a design gate

Proposed diagnostic, not current compiler output:

```text
Cannot resize `input`: `ast` still reads its bytes.
  The views were created by `parse(input)` at parser.grl:18.
  `ast` is read again at parser.grl:27.
  `resize` may move or discard the viewed storage.
Try resizing before parsing, ending the AST's use first, or explicitly copying retained text.
```

For lending iteration: “`record` uses the decoder's reusable buffer; calling `next` overwrites it.”
For mmap: “`row` keeps this page pinned; releasing the page would invalidate the row.”
For an inferred API: “this result may refer to either `left` or `right` according to the library's
exported ownership contract,” with the interface source span. Do not invent a uniquely known root
when analysis has only a conservative set. Suggest a more precise API contract only when sound.

Keep explanation provenance in a side table so fast-path checking can use compact identifiers. A
small counterexample/error slice is preferable to dumping a whole constraint graph. Measure cost
and diagnostic quality; inferred ownership is not acceptable if users cannot explain or repair it.

## 9. Initial ranking and go/no-go gates

**Leading hypothesis:** B's value-first API discipline, A's abstract permissions/relationships where
views need them, and root inference as a local provenance technique. This is a research direction,
not proof that the synthesis is simpler. Do not adopt Goose's whole-program compilation policy or
Rust's complete surface/type-system complexity as unavoidable packages.

- Pure strict-MVS variant: simplest access model, but loses required persistent external-view APIs
  unless extended; do not declare victory by rewriting every workload into callbacks.
- Rust-inspired modular variant: strongest established expressivity reference; greatest risk of
  hiding Rust complexity behind inference.
- Goose as implemented: compelling annotation-free data layout/provenance, but fails modularity.
  Modified modular roots plus permission checking may converge on the same underlying hybrid.

Before committing to a permanent model require:

1. W1 and W3 zero-copy APIs, W5 immutable view collection, W7 nonretaining callback, and W10 generic
   modules, with clients checked without provider bodies and without root-specific specialization.
2. Invalidating source/page operations rejected; no runtime lifetime/borrow checks added secretly.
3. Explicit outcomes for W2/W6/W9, including restrictions/copies/handles and why. No universal promise
   of arbitrary mutable graphs without unsafe implementation boundaries or runtime mechanisms.
4. Report annotation and analysis complexity, summary size, allocations/copies/metadata, and diagnostics.
5. If summaries balloon or the everyday mental model remains expert-only, revise the architecture
   before building backends. Favor a credible bounded feature envelope over an inference miracle.

Next step is a shared workload specification plus hand-derived interfaces, then the smallest typed
IR/checker experiment. Actual implementation competition, runtime measurements and a formal safety
argument remain to be done. Source inspection is not a substitute for any of these.

## 10. Primary evidence and revisions

- **Rust Reference, lifetime elision:** https://doc.rust-lang.org/reference/lifetime-elision.html
  (official documentation, read as search excerpts; not a pinned rustc implementation audit).
- **Polonius:** https://rust-lang.github.io/polonius/rules/relations.html and
  https://rust-lang.github.io/polonius/rules/loans.html (existing origin/loan/subset machinery).
- **Hylo compiler** `6889158246df571baa9079115817ab2bff61156b`:
  [access modes](https://github.com/hylo-lang/hylo/blob/6889158246df571baa9079115817ab2bff61156b/Sources/FrontEnd/AccessEffect.swift),
  [remote types](https://github.com/hylo-lang/hylo/blob/6889158246df571baa9079115817ab2bff61156b/Sources/FrontEnd/Types/RemoteType.swift),
  [capture invariants](https://github.com/hylo-lang/hylo/blob/6889158246df571baa9079115817ab2bff61156b/Sources/IR/Operands/Instruction/CaptureIn.swift),
  [capture/lifetime closure](https://github.com/hylo-lang/hylo/blob/6889158246df571baa9079115817ab2bff61156b/Sources/IR/Analysis/Module+CloseBorrows.swift),
  [array projection/callback APIs](https://github.com/hylo-lang/hylo/blob/6889158246df571baa9079115817ab2bff61156b/StandardLibrary/Sources/Array.hylo).
  These files were read; tests were not run.
- **Hylo specification** `6f4c645101bac80dbb7bd5833cf07c8cbf699bd1`:
  [projection rules 3, 8, 10](https://github.com/hylo-lang/specification/blob/6f4c645101bac80dbb7bd5833cf07c8cbf699bd1/spec.md#projections).
  This is an older specification repository (last pinned commit 2024-07-19), not proof every rule is
  fully implemented in the 2026 compiler. The date discrepancy is intentional evidence qualification.
- **Goose** `0357b1c2e261fa0680008e79d6879f9ccc7aedb9`:
  [specification §§3.9, 7.8, 9, 10](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/docs/goose_spec.md),
  [reference-bearing structs test](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/test/codegen/reference_only_structs.goose),
  [root identity/call test](https://github.com/aardappel/goose/blob/0357b1c2e261fa0680008e79d6879f9ccc7aedb9/test/codegen/root_call_identity.goose).
  Read source/tests, not executed results.
- **MVS paper**, Racordon et al., 2022: https://doi.org/10.5381/jot.2022.21.2.a2.
  Downloaded author-hosted PDF and inspected extracted text, particularly references, inout,
  exclusivity, copies and COW; this is not a benchmark reproduction or a current-Hylo guarantee.
- **Region/effect inference precedent:** https://doi.org/10.1145/174675.177855
  (1994 paper abstract, not an implementation audit).
- **Context/capture precedent:** https://docs.scala-lang.org/scala3/reference/experimental/cc.html
  and https://docs.scala-lang.org/scala3/reference/experimental/capture-checking/basics.html
  (official experimental documentation excerpts; no claim Scala supplies Grail's memory guarantees).
