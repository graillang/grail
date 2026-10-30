# First experimental results: ownership, representation and modular builds

2026-10-30. **Measured reference experiments, not a Grail implementation or proof.**
See [runnable sources](../../research/experiments/memory01/README.md),
[raw evidence](../../research/evidence/experiments-20261030/manifest.json), and
[pinned third-party revisions](../../research/evidence/repository-pins.json).

## 1. Corrections to previous research

**Hylo:** `hylo-lang/hylo` explicitly identifies itself as the former implementation and points to
`hylo-new`. The earlier source findings are historical, not a current-compiler audit. Pinned current
source is `hylo-lang/hylo-new@36f135edd2f49b6951aaf6f753117340fbb232b3`. Its lifetime-normalization
pass, access conventions, module archive and exclusivity tests were inspected. No Hylo executable
was tested: the required Swift 6.3.2+ toolchain is not installed. Do not rank Hylo runtime/build speed.

**Goose:** do not interpret root specialization as necessarily one body per caller variable. Actual
code builds root equivalence/depth classes and compares those normalized relationships for reuse.
Our 16-, 64- and 256-root call-site fixtures all report **2 specializations** (main plus helper).
Whole-program compilation is still real, but naive per-root explosion was not observed here.
This makes the prior-art baseline stronger and narrows any plausible Grail novelty claim further.

## 2. Cross-module Rust envelope

**21/21 probes matched their expected outcomes:** 11 positive clients compile/run;
10 negatives reject with the expected compiler error codes.

The provider compiles once to an rlib. During client checking its source is not mounted in the
sandbox. The rlib can contain typed generic bodies as well as signatures; this is ordinary separate
library compilation, not a contracts-only artifact or inferred Grail interface.

Positive cases cover borrowed token aggregates, a recursive atoms/groups AST with 10,001 leaves,
borrowed leaves surviving destruction of intermediate AST containers, generic view adapters,
captured views, field-specific origins, temporary mutable callbacks, slice splitting, lending
iteration, scoped worker threads, a page-guard lifetime and releasing an unpolled future's loan.
Pointer identity/range assertions establish that the exercised token text is not copied.

An owning `Document` with private checked offsets also survives moves, exposes borrowed text,
and preserves the source buffer pointer. Mutating/replacing it while a text view is used is rejected.
No self-referential pointer machinery or unsafe parser code is needed for this representation.

Negative cases include invalidating viewed storage, callback escape, retaining a lending item
across `next`, conflicting access while a future retains a mutable borrow, releasing a viewed guard,
escaping local/captured owners, and missing lifetime relationships in ambiguous/closure signatures.

This confirms a useful target envelope, not that Grail can infer it cheaply. Rust already elides
routine callback lifetimes; the test API uses that elision rather than artificially requiring an
explicit higher-ranked lifetime. Captured borrowed-return closures and richer stored relationships
still demonstrate cases beyond simple input/output elision.

## 3. Goose execution and rejection

Six targeted cases matched expectations. An externally borrowed token aggregate compiles and runs
without lifetime annotations; local-owner escape and retained-element shrink are rejected. Two
existing reference/root fixtures typecheck. A scalar alias remains usable while the original is
mutated: this is Goose's allowed sequential alias model, not evidence of exclusive borrowing.

The root-count timings include sandbox/process overhead and are too small for a compiler-performance
ranking. The useful observation is structural: reported specialization count stays constant in this
fixture. Other alias/depth/type/static-function/stack patterns may still produce more instances.

## 4. Views versus offsets versus copies

One scanner builds the same token table in three forms: `&str`, checked `u32` start/end offsets,
or owned `String`. Every timed traversal reads all token bytes and checks the same checksum.
Correctness tests also compare exact token sequences over empty, whitespace, ASCII and Unicode cases.
There is no unchecked offset reconstruction or runtime borrow checker.

At **200,000 tokens**, optimized Rust, one host:

| Representation | Descriptor bytes/token | Construction allocations | Requested bytes | Median build+traverse+drop, ms | Median process peak, MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| views | 16 | 1 | 3,200,000 | 1.800 | 7.79 |
| offsets | 8 | 1 | 1,600,000 | 1.721 | 6.28 |
| owned | 24 | 200,001 | 7,092,092 | 9.164 | 15.23 |

Seven interleaved observations per representation/size; each observation includes 12 construction,
traversal and destruction rounds. 20,000-token measurements are also in the raw data. Reported
allocation counts come from a separate instrumented run; timing binaries do not count allocations.
Timing includes neither input construction nor process startup. Requested bytes exclude the original
input allocation, are not peak live heap, and are not a universal allocation cost prediction.

**Interpretation:** compact offsets are a credible zero-copy alternative for a frozen owning document,
not inherently a slow hash-table/arena lookup. The 32-bit format is restricted to inputs no larger
than 4 GiB; wider offsets lose this particular size advantage. Bounds/UTF-8 slice checks remain.
Traversal timings are close in this workload; do not claim universal pointer/offset superiority.
Per-token ownership copies are much more allocation-heavy here. They may still be appropriate when
independent ownership lets a program discard most of a large input earlier.

Offsets must remain associated with the correct immutable document. The safe owning example keeps
them private; arbitrary public offsets used with the wrong source are not made semantically correct
by bounds checks. This experiment does not justify replacing every persistent reference with IDs.

## 5. Generic specialization versus shared implementation

Synthetic fixture: 16/64/256 distinct types, one generic function or an equivalent shared
trait-object implementation, provider precompiled, no LTO. Warmup then three interleaved observations
per configuration. Compiled native outputs were checked against a separate Python calculation.

At **256 types**, median compiler process wall time in ms:

| Dispatch | Metadata-only check | Unoptimized native build | Optimized native build |
| --- | ---: | ---: | ---: |
| generic | 56.0 | 99.8 | 665.3 |
| erased | 49.2 | 109.4 | 186.7 |

Metadata-only checks are front-end checks for binary crates, not measurements of a new compact
interface format. Native builds include code generation and linking. These are not incremental
Cargo builds, and there is no Go/Zig/Grail comparison here.

**Interpretation:** for this workload, optimization/specialization adds much more cost than merely
checking the generic clients. Avoid turning every edit build into full release optimization. Shared
code can reduce compiler work, but changes runtime dispatch; runtime trade-offs were not benchmarked,
so this does not select erased generics as Grail's default. Binary size also grows differently; see
raw artifacts sizes, noting that standard runtime/linker overhead dominates these small executables.

## 6. Method and confidence boundaries

Host: AMD Ryzen 9 7900X, Linux x86-64, rustc 1.98.0, Clang 23.1.3. Exact versions, flags, hashes,
CPU data and command outputs are in the manifest/results. Shared host, unfixed frequency and no CPU
pinning; caches warmed rather than flushed. These are local exploratory measurements, not portable
performance promises or independent benchmark-suite results. Min/max observations are retained;
small timing differences are not established statistically significant wins.

Third-party builds run without network access or user's home files, source mounted read-only,
output in the experiment tree; no system packages installed and no third-party sources modified.
Goose's CMake/TinyCC inputs were inspected before the isolated build. No third-party test script or
installer was run. The actual Goose compiler executable and our tiny programs were executed.

The page guard is not an mmap eviction system. The pending future is never polled; its test does not
exercise in-flight kernel I/O cancellation. No direct-style runtime, GPU system, proof checker,
whole-language safety theorem or automatic ownership-inference algorithm was implemented.

## 7. Decisions this evidence supports—and does not

- Keep both external borrowed aggregates and owning relative-view documents in the design envelope.
- Give Goose's normalized root relationships serious attention; retain separate compilation as a
  requirement rather than using a nonexistent demonstrated root-count explosion to reject it.
- Evaluate frontend analysis and specialization/codegen costs separately.
- Prefer an experiment with symbolic contracts before choosing ownership punctuation or building
  backends. Rust's successful APIs supply adversarial targets, not an instruction to copy Rust.
- Do not select a permanent memory model from these microbenchmarks. Hylo runtime tests, real async
  cancellation, map-entry/complex graphs, diagnostic user testing, and rich summary inference remain.

**Next highest-value experiment:** infer and serialize checked origin/capture contracts for the
borrowed recursive parser, generic adapters and nonretaining callback; check clients without bodies.
Use normalized root classes as a candidate technique. First specify handling of field paths,
fresh callback loans and invalidation, then implement only that typed experimental checker. This
is the remaining architectural risk; another broad language-speed shootout would not resolve it.
