# Haskell: lessons without a failure mythology

2026-10-30. Primary documents and case studies were read; **no GHC runtime/build benchmark was run**
(GHC is not installed). This is not evidence that functional programming failed, nor a causal study
of why one language has more users than another. Recommendations below are not human decisions.

## 1. Separate successes, costs, and product fit

Haskell succeeded as a research vehicle and in selected production domains. Its designers' history
records major contributions in typed functional programming, type classes, I/O and compilation.
Meta's 2015 engineering report describes a successful Haskell/Haxl Sigma deployment at more than
one million requests per second. That is a dated first-party deployment report, not our independent
measurement or a statement about Meta's current architecture.

The April 2026 Haskell community analysis of the 2025 survey reports recurring concerns about
complexity, compile time, debugging, docs/onboarding, tool fragmentation, partial defaults and
laziness. Its authors analysed **553 free-form responses** and explicitly distinguish actionable
findings from vague mood. Self-selected community reports reveal pain points; they do not establish
market-wide prevalence, comparative superiority or causes of limited adoption.

Grail should learn from both, rather than conclude that purity, algebraic types or strong types are
mistakes. Our general-purpose no-GC systems priorities are different from Haskell's original goals.

## 2. Operational predictability must survive mathematical elegance

The designers' [history, §3.1](https://simon.peytonjones.org/assets/pdfs/haskell-being-lazy-with-class.pdf)
explicitly describes the difficulty of predicting lazy programs' space behavior. Non-strict
semantics and call-by-need implementation are related but not identical; do not conflate either with
purity itself. Strict languages can be pure and lazy facilities can be explicit libraries.

[Well-Typed's 2025 case study](https://well-typed.com/blog/2025/10/case-study-debugging-space-leak/)
shows shared thunks retaining otherwise unwanted parts of data. Its
[nothunks work](https://well-typed.com/blog/2020/09/nothunks/) shows why even a strict map is not enough
when its elements contain unevaluated structure. These are concrete diagnosed cases, not a claim
that all lazy programs leak or that Haskell cannot be optimized.

**Recommendation for Grail:** eager evaluation with a specified order by default; deferred work via
explicit closures/iterators/streams with checked captures and visible execution operations. Specify
failure/destruction/effect ordering rather than relying on an equational value model to answer cost
questions. A pure function may still diverge, trap or allocate; purity is not totality or cheapness.

### The warning applies even without GC or laziness

A one-byte view can keep a multi-gigabyte buffer alive. A closure can retain an owner/region long
after most of it is useful. A region can retain an entire graph for one node. Deterministic
reclamation and memory safety do NOT imply low retention or bounded memory consumption.

Grail should expose "why is this allocation still alive?" dependency/capture reports and profiling,
with source locations. Static reports identify possible dependencies; actual retained byte counts
may require runtime profiling. Offer explicit copy/compaction/ownership conversion, never a hidden
copy inserted to make a small retained view cheap. Our existing origin graphs may help implement
this, but no such complete profiler or cost proof exists yet.

## 3. Do not hide I/O behind an ordinary-looking value

The [base System.IO documentation](https://hackage.haskell.org/package/base/docs/System-IO.html)
distinguishes lazy `readFile` from the strict `readFile'` that finishes reading before returning.
Lazy consumption changes when resource use and failures occur. This is not a reason to reject
streaming; it is a reason to make streaming a distinct operational contract.

**Recommendation:** a Grail read-all operation finishes its promised read before returning; a
stream explicitly retains the resource and its `next`/read operation carries I/O, failure and
suspension behavior. A stream leaving a scope must move/retain valid ownership or be rejected.
An effectful lazy computation cannot masquerade as an effect-free string merely because the
initial function already returned. Closures/iterators need latent effects as well as capture origins.

## 4. A small core can conceal a large static language

The Haskell history notes that much complexity lives in static semantics. The
[OutsideIn(X) work](https://www.microsoft.com/en-us/research/publication/outsideinx-modular-type-inference-with-local-assumptions/)
explains how GADTs, type families/classes and local assumptions complicate principal inference and
local generalization. The current
[GHC guide](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/let_generalisation.html)
states why `MonoLocalBinds` uses a conservative policy and why disabling it can make inference less
predictable. The [instance rules](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/instances.html)
explicitly discuss termination restrictions and `UndecidableInstances`.

These mechanisms are useful; their existence is not a failed design proof. The lesson is that
"one powerful abstraction" does not make its interactions free. A tiny desugared core or few
keywords are not evidence of a small compiler, predictable inference or easy errors.

**Recommendations:** one coherent constrained interface mechanism; bounded local inference;
checked public contracts; no unrestricted global implicit search or overlapping specialization by
default. Keep theorem discovery and general proof elaboration out of normal builds. Avoid combining
ownership, overload resolution, implicit conversions and capability selection into one speculative
search that tries many meanings of a call.

Swift's own [type-checker design](https://github.com/swiftlang/swift/blob/main/docs/TypeChecker.md)
provides an independent warning about worst-case exponential solving and overloads. This is not a
current Swift speed benchmark, and some past exponential cases have been improved substantially.
The design obligation for Grail is to constrain/search-budget difficult cases and measure them,
not merely say our new inference engine will be cleverer.

## 5. Standard-library defaults are language design

The 2026 survey analysis reports demand for canonical text APIs, fewer partial Prelude functions,
more coherent records, current working examples and a clearer beginner entry point. In particular,
`String` versus `Text` is reported as a recurring source of friction. Do not mechanically copy that
type choice or its history into Grail.

**Recommendations:** one obvious default text representation with a corresponding borrowed view;
explicit bytes and encoding boundaries; consistent collection/error conventions; exhaustive matching;
fallible lookups as the ordinary safe API. Checked traps and proved unchecked operations can exist,
but normal APIs should not force users to discover hidden partiality by production failure.
These are API principles, not a finalized Grail string layout or allocation policy.

Grail's effects and proof language must not turn mundane code into competing dialects. Optional
advanced facilities still need coherent interfaces; moving complexity into annotations, library
operators or generated signatures does not remove it. Teach useful ordinary programs first rather
than requiring category-theory vocabulary to read filesystem or collection code.

## 6. Tooling and compatibility are part of the product

The survey requests a coherent toolchain, faster feedback and end-user-oriented errors. Treat these
as priorities, not a claim that modern Haskell has made no progress: the authors note ongoing error
index/debugger improvements and distinguish vague complaints from actionable reports.

**Recommendations:** one supported formatter/build/test/package/LSP workflow; reproducible pinned
toolchains; reviewable public interface changes; diagnostics showing both inferred contract and
conflicting use. Do not require users or agents to understand internal region variables to repair
an ordinary failure. Measure time-to-fix and edit-to-feedback, not just source brevity.

## 7. Positive Haskell lesson: independence can enable scheduling

[Haxl's original description](https://engineering.fb.com/2014/06/10/web/open-sourcing-haxl-a-library-for-haskell/)
explains batching, caching and concurrent requests in a restricted data-fetch abstraction. It is
important prior art for the desired separation between program meaning and execution scheduling.
Caching/freshness and dependency assumptions matter; it does not establish that arbitrary I/O can
be reordered or that every sequential-looking call can profitably execute in parallel.

**Recommendation:** investigate explicit batch/query/parallel regions or library plans with precise
semantics. Let the implementation schedule within that selected domain. This can coexist with
"spawning/concurrency is explicit" at the region boundary, without introducing a universal handler
language or transparently spawning arbitrary effectful calls. Keep ordinary `.map` sequential unless
a distinct API/region grants different scheduling semantics.

Also retain Haskell's positive examples: algebraic modeling, higher-order composition, property-based
counterexample search and effect isolation. Do not throw these away while rejecting pervasive
laziness, accidental resource retention or unbounded static complexity.

## 8. Proposed design changes to consider

| Lesson | Grail consequence | Evidence status |
| --- | --- | --- |
| Lazy evaluation obscures space/resource timing | Eager ordered default; explicit deferred computation | History + diagnosed cases; not a universal performance theorem |
| Ownership can also retain too much | Capture/retention diagnostics and optional profiling | Direct design consequence; tooling not implemented |
| Rich inference features interact | Restrained polymorphism, local inference, explicit boundaries/budgets | Compiler docs/paper; Grail scalability still needs experiments |
| Unsafe/awkward defaults spread through libraries | Canonical text, checked fallible APIs, coherent ordinary subset | User reports + design judgment |
| Tooling fragmentation burdens adoption | One supported workflow, diagnostics for users | Qualitative survey, not causal adoption proof |
| Restricted declarative domains permit scheduling | Explicit batch/query regions as an optional library direction | Haxl implementation experience; not Grail benchmark evidence |

No wholesale adoption or "Haskell failed" conclusion follows. We should favor a language whose
mathematics simplifies everyday semantics, not one whose users must reconstruct implementation
machinery to predict memory, effects or compile time.
