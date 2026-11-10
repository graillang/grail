# Grail reassessment: are we spending complexity on the wrong problem?

2026-10-30. This challenges my own
[reassessment at 22cfb0f](https://github.com/graillang/grail/blob/22cfb0f/docs/design/architecture-reassessment.md),
using research on `main` at [c2d1708](https://github.com/graillang/grail/tree/c2d1708/docs/design).
It is an architectural recommendation. Nothing is authorised for implementation.

Labels used throughout:

| Label | Meaning |
| --- | --- |
| **[evidence]** | Published by the Rust project or measured here (method in §9) |
| **[record]** | From this repository's research |
| **[argument]** | Follows from how the algorithms work |
| **[conjecture]** | Plausible, unmeasured |

---

## 0. Verdict

**Abandon full G1. Adopt architecture A**: an explicit, modular ownership core whose semantics are
deliberately close to Rust's non-lexical-lifetimes (NLL) borrow checking, and whose only
cross-function ownership information is the written signature. Allow exactly one future class of
extension: purely intra-procedural improvements that accept more programs without changing any
interface (§3.3).

**Bootstrap and backend:**

- Seed compiler in Rust, written in a Grail-compatible profile.
- First backend emits C, one file per module, from a backend-neutral low-level IR.
- The self-hosted compiler's own generated C becomes the bootstrap artifact.

**Why:**

- G1's precision wins are ergonomic. Each one I could test has a cheap explicit workaround
  (§1.3).
- Its machinery changes the compilation model from "check a body against callee signatures" to
  "infer and propagate body-dependent summaries". That costs incremental predictability, a small
  checker and reusable formal foundations, which are the priorities this review was asked to
  weigh.
- Lifetimes are not where build time goes [evidence, §2]. The levers for fast edit–compile–test
  cycles are elsewhere, and Grail can pull all of them with explicit lifetimes.

**The honest corollary.** Under A, Grail's *ownership model is not a differentiator*. Grail is
justified only by the combination in §5:

- a small, self-hosted, trustworthy implementation;
- a compilation model built for fast edit cycles;
- sound structured concurrency without async/`Pin`/drop-cancellation;
- capability-based authority;
- integrated optional verification.

If those are not decisive for you, use a constrained Rust profile instead (§5).

---

## 1. What Rust's conservatism buys, and what G1 adds

### 1.1 The compositional property

In a Rust-like core, a function's entire borrowing behaviour is stated by its signature. Lifetime
parameters relate inputs to outputs and to caller storage. `&mut T` is invariant in `T`, so
everything ever stored through a reference is bounded by one type-level lifetime for that
reference's whole life. Consequences [argument]:

- **Checking a body needs only callee signatures.** Bodies can be checked in any order and in
  parallel, and there is no fixpoint across functions.
- **Body edits cannot change callers' checking results.** Incremental invalidation is decided by a
  signature hash, and errors appear in the edited function.
- **Interfaces are small and stable,** and API changes are visible in diffs. The research's N8
  failure mode (a body changed from replace to append under an unchanged API) is vacuous here.
  `fn f<'a>(h: &mut &'a str, new: &'a str) -> &'a str` is the signature of both versions, and no
  client can depend on the difference.
- **No changing-content state is needed.** Invariance means a slot's contents are always within
  the slot's declared lifetime, so no strong updates, target sets or writeback are required.
  Releasing a source requires that whole lifetime to end.
- **Generic code is ordinary parametric code.** Lifetimes are type parameters, and drop-check
  needs only a small rule for standard containers.
- **Formal foundations already exist and can be reused:**
  - RustBelt for type soundness;
  - Aeneas forward/backward functions for functional translation (pinned in [record]);
  - RustHorn and Creusot prophecies;
  - Tree Borrows for `unsafe` aliasing.

### 1.2 What G1 adds on top of NLL

Rust's checker already has place- and field-sensitive, flow-sensitive loan liveness, region
inference within bodies, and two-phase borrows. G1 adds:

1. Per-place content state that can **shrink** (strong updates), beyond loan liveness.
2. A **target may-set** on every exclusive position: a points-to analysis alongside the loans.
3. **Exported post-state transformers** for every mutable position reachable from parameters,
   including referents inside parameters, **per outcome**.
4. **Symbolic places, entry snapshots and commit-on-return** at every call.
5. **Inference across functions** to a fixpoint within a package, plus API-file freezing.
6. **Deferred type-dependent operations** (drop, call, method) for opaque generics, instantiated
   by callers.
7. **Outcome correlation and joins.**
8. **Budgets and deterministic widening.**

None of these exists in Rust. Items 3, 5 and 6 are what break the compositional property in §1.1.

### 1.3 Are the rejected patterns worth that machinery?

I probed four realistic programs with rustc 1.97 (§9).

| Realistic programme | Rust | Explicit-core remedy | Worth G1? |
| --- | --- | --- | --- |
| **Streaming tokenizer** reusing one `Vec<&str>` across chunks to avoid reallocation | Rejected, E0597 [evidence] | A standard `recycle` primitive: consume an emptied vector and return it with a new lifetime. Safe Rust accepts this, and the allocation was reused in the probe [evidence]. Grail should *guarantee* in-place reuse. | No: one line |
| **Get-or-insert** returning `&mut V` (Polonius problem case 3) | Rejected, E0499 [evidence] | An entry API, or a *local* location-sensitive liveness extension (§3.3) | No. It doesn't need G1 at all, because it is intra-procedural. |
| **Include-file parsing** temporarily redirecting `parser.src` (F2-like) | Restoring through a persistent handle is rejected [record: referents14] | The parser borrows from a source arena whose sources outlive it, or a sub-parser per include | No: minor restructuring |
| **Long-lived index re-pointed at a new buffer** (F1-like) | Rejected [record] | Rebuild the index per buffer, with `recycle` for allocations; or `Bundle` the buffer with its index | No |
| **Tail-cursor list append** (F5) | Compiles under NLL [evidence] | — | — |

None justifies items 1–8. They are API-shape questions that one explicit primitive or a local
analysis answers.

### 1.4 Reclassification of F1–F7

The safety obligations N1–N8 stay intact.

| Case | Class | Under A |
| --- | --- | --- |
| F1 stored-handle replace, then release the old owner | Optional ergonomic win | Restructure, or `recycle` / `Bundle` |
| F2 temporary insert and restore through a handle | Optional | A source arena, or a sub-parser |
| F3 release correlated with the ok path | Optional | Lifetimes in the `Result` type, or restructure |
| F4 generic forwarding of exclusive references (`Option<&mut T>`, `Vec<&mut T>`) | **Essential capability** | Provided by lifetime parameters. The strong-update part is optional and dropped. |
| F5 tail-cursor loop | Essential | Provided by NLL |
| F6 closure capturing `mut` state called by a generic higher-order function | **Essential** | Provided, with the closure's receiver mode recorded |
| F7 forgotten work handle plus error exit | **Essential safety and progress** | Independent of the borrow model: keep the scope-owned work registry in the runtime |
| Allocation reuse across sources | Essential for performance | Explicit `recycle` |
| Problem case 3 | Important | Entry API now; local extension later (§3.3) |

How N1–N8 are kept:

- **N1–N3:** stricter under invariant lifetimes.
- **N4:** trusted split primitives.
- **N5:** reborrow restriction (NLL).
- **N6:** self-installation rejected by exclusivity.
- **N7:** the scope registry.
- **N8:** vacuous by construction (§1.1).

---

## 2. Are lifetimes a compilation bottleneck?

### 2.1 Where Rust build time goes

What the Rust project has published [evidence]:

- **Clean debug builds** spend most of their time in LLVM.
- **Incremental patched builds** are dominated by linking and the frontend. Borrow checking
  "disappeared" there, because unchanged bodies are cached.
- **`cargo check`** is frontend-dominated, and the frontend is largely single-threaded (Beránek,
  2024, top-100 crates). The author calls the type-check and borrow-check splits rough estimates.
- **The 2025 survey (3,700+ responses)** names incremental rebuilds as "by far the most common
  complaint". It cites unnecessary workspace rebuilds, linking that is always done from scratch,
  and derive proc-macro expansion that is not cached. 55% wait more than 10 s per rebuild.
- **The 2026 Fast Builds roadmap** names:
  - a single-threaded frontend;
  - LLVM passes that do little for debug builds;
  - trait resolution and type checking as dominant phases.

  Its remedies are Cranelift (5–15% average incremental gain), TPDE (claimed 10–20× faster than
  LLVM -O0), relink-don't-rebuild (claimed 5–10×), a faster linker, and crate slicing.

What I measured here [evidence, synthetic, unpinned, §9]:

- **Borrow-heavy crate versus control.** A 34.5 kLOC borrow-heavy synthetic crate compiled with
  `cargo check`-equivalent flags against a structurally similar control without borrowed
  signatures or fields:

  | Variant | Time in `MIR_borrow_checking` pass | Total check time |
  | --- | ---: | ---: |
  | Borrow-heavy | 5.7 s | 10.0 s |
  | No borrowed signatures or fields | 5.0 s | 8.8 s |

  Lifetime-heavy code added about 12% to the check time. Most of the pass is per-body work (MIR
  construction plus checking) present either way. I could not isolate borrow checking itself: the
  profiler would have had to be installed from GitHub, which this session's permission policy
  blocked.
- **Frontend throughput** was about 3 kLOC/s in either variant. That cost is not caused by
  lifetimes.

### 2.2 Conclusions

| Claim | Status |
| --- | --- |
| Lifetimes are not Rust's build bottleneck. Per-body frontend cost, single-threading, monomorphisation volume, LLVM, macros and linking are. | [evidence] |
| A lifetime-based core can still compile slowly. Rust is the existence proof. Explicit is not automatically fast. | [evidence] |
| G1 is probably polynomial per function, of an order similar to NLL plus summary instantiation. Its real cost is structural: callers depend on callee *bodies*, which forces inter-function ordering, recomputing within packages, and invalidation cascades. Dense contracts can be large (727 KB in experiment 02 [record]). | [conjecture] for the per-function order; [argument] for the structural cost |
| Inferred is not inherently slow either. Hindley–Milner inference inside a body is cheap. What hurts is *inference whose results cross function boundaries*. | [argument] |

### 2.3 Grail choices that would actually improve the critical path

These are [argument], each to be measured:

1. **Signature-only dependencies:** a body edit re-checks and re-generates one function and its
   module, and nothing else. This requires A.
2. **Parallel per-function checking and per-module code generation.** No crate-sized
   single-threaded frontend.
3. **No proc macros.** Derive-like generation is built in, or comes later as cached compile-time
   evaluation.
4. **A simple coherent trait system:** no overlap, no specialisation, no negative reasoning,
   bounded associated-type projection, and method lookup without autoderef chains.
5. **Generic code volume control:** shared, dictionary-passing generic code in development
   builds, with specialisation reserved for small inline generics. This has a **cost**: tests run
   slower (§6, conflict K2).
6. **Granular backend invocation:** one C file per module, compiled in parallel and only when
   changed. In the probe, clang -O0 handled 57 kLOC of generated C in 6.8 s on one thread; a
   module of a few kLOC is well under a second [evidence, §9]. Granularity matters more than raw
   backend speed for edits.
7. **Fast or incremental linking,** and a test runner that loads changed modules instead of
   relinking. This is a later item.

---

## 3. Complexity budget

### 3.1 Inferred versus written

| Item | Inferred | Written |
| --- | --- | --- |
| Local types | Within bodies (bidirectional, Hindley–Milner-lite) | — |
| Function signatures | Never, apart from `-> some I` opaque returns | All parameter, result and error types; `suspend` |
| Lifetime relationships | Elision only, using Rust's three rules | When elision does not decide; storing into caller storage (`fn remember<'a>(cache: &mut Vec<&'a str>, s: &'a str)`); lifetime parameters of types holding references |
| Regions inside bodies, variance, implied outlives bounds from fields | Yes | — |
| Closure parameters | Fresh per call by default (the elided higher-ranked form) | Anything else uses a named lifetime from the enclosing signature |
| Target sets, post-states, outcome correlations | **Not computed** | — |

### 3.2 Annotation versus bookkeeping

**Written annotations are genuinely necessary information,** not exposed bookkeeping. They are API
commitments a caller and a reviewer need:

- which input a result borrows from;
- that a cache retains a value;
- that a struct holds borrowed data.

**The bookkeeping stays inferred:** regions inside bodies, variance and implied outlives bounds.

**Hard limits — there are no budgets, because nothing is inferred across calls:**

- Checking is per function, against signatures only.
- Its cost is NLL's: region constraints solved over strongly connected components, plus liveness
  dataflow. That is polynomial, with no inter-function fixpoint.
- Pathologically large generated functions are the only known risk. The remedy is to split them,
  not a new analysis.

**Escape hatches, all explicit:**

- `unsafe` with a documented contract, listed in the trust report.
- Arenas and generational handles for mutable graphs.
- `recycle` for retyping and reusing allocations (`Vec`, `String`, `HashMap`), guaranteed in place.
- `Bundle[O, V]` as a built-in for an owner plus internal views. It takes closure construction and
  a view family with exactly one lifetime parameter, following the candidate v1 boundary in
  `bundle-boundary.md`.
- A fixed `Lending` interface instead of general GATs.

**Expressiveness lost relative to G1:**

- F1–F3 strong updates through handles and helpers;
- reuse with a different source without `recycle`;
- restoring through a stored handle;
- problem case 3 without an entry API, until §3.3.

**Expressiveness kept relative to Rust:** everything the research's admission tests require —
zero-copy ASTs, containers of views across generics and modules, returned mutable spans, stored
`&mut`, scoped tasks.

### 3.3 The one allowed extension class (B, bounded)

Allowed later: **intra-procedural** improvements that accept strictly more programs and change no
interface. The concrete candidate is location-sensitive loan liveness within a body, which handles
problem case 3. It may be adopted only if measured cost on the seed corpus stays within a fixed
fraction of NLL. The Rust project's own Polonius alpha still has documented performance
regressions [record], so this is a measured option, not a default.

**Never allowed:** inferred cross-call contracts, exported post-states, or body-dependent
interfaces. Any such information must be *written* in the signature.

---

## 4. Comparison of the alternatives

**A.** Explicit modular core (recommended).
**B.** A plus the §3.3 local extension.
**C.** Full G1.
**D.** Rust or a constrained Rust profile.

| Criterion | A | B | C | D |
| --- | --- | --- | --- | --- |
| Semantic and implementation complexity | NLL-class checker; reuses existing theory | A + one local dataflow | New theory; place state, targets, per-outcome summaries, deferred operations, inference across functions, budgets | None to build; rustc is very large |
| Interface size and stability | Signatures; change only when edited | Same as A | Route maps per outcome; can change with bodies; needs frozen API files | Signatures (plus generic bodies in metadata) |
| Checking cost and worst case | Per function, parallel, polynomial | A + per-body set dataflow | Per-function polynomial [conjecture] plus a fixpoint inside the package and invalidation cascades [argument]; dense contracts | Slow frontend; per-body cost about 3 kLOC/s here [evidence] |
| Diagnostics and sensitivity to small edits | Local, stable, familiar | Same | Non-local inside a package; involves flow-sensitive state and joins | Familiar |
| Real API expressiveness | Rust-equivalent core minus the deferred features | + problem case 3 | Most permissive | Full Rust |
| AI generation, repair and review | Huge Rust training corpus; deterministic, local repair; reviewers read signatures [conjecture] | Same | No corpus; invisible inferred state; reviewers read contract diffs [conjecture] | Best today |
| Verification burden | Reuses RustBelt, Aeneas and RustHorn | + the extension's proof | New metatheory (the current Lean work covers fragments only [record]) | Verus, Aeneas, Creusot and Kani available |
| Time to self-host | Shortest (the seed transliterates) | Same, plus later work | Longest | Not applicable |

**The four kinds of cost, kept apart:**

1. **Mechanical annotations** — lifetime parameters and relationships where elision does not
   decide. A tool or model can derive most of them from the body, and the compiler checks them.
   A wrong annotation is rejected or merely over-restrictive, never unsafe. The cost is mainly
   reading noise.
2. **Restrictions that force API or data-structure changes** — self-reference, mutable graphs,
   reuse across sources, restore through a handle, conditional mutable returns, lending. Generated
   annotations do not remove these; they shape APIs. G1 removed *some* of them (F1–F3) by moving
   them into cost 3.
3. **Complexity moved into generated contracts** — per-outcome route maps that reviewers must
   understand and that change with bodies. This is G1's distinctive cost.
4. **What humans still pay for generated code** — understanding relationships between signatures,
   understanding borrow errors, reviewing API diffs, maintaining arenas. A keeps all of these
   local and familiar. C makes them non-local and novel.

---

## 5. Is Grail still sufficiently different from Rust?

Under A, the ownership core is Rust's, simplified. What remains:

1. **Implementation:**
   - a small, auditable, self-hosted compiler;
   - signature-only dependency tracking;
   - parallel per-function checking;
   - no macro system;
   - a deliberately small trait system;
   - development-mode generic sharing.

   Rust cannot become small, and its crate-level frontend and monomorphisation semantics are hard
   to change [argument].
2. **Concurrency:**
   - direct-style tasks with a static `suspend` effect;
   - structured scopes that always join;
   - cancellation as an error;
   - work owned by the scope, so a forgotten handle neither releases storage early nor stalls
     (F7, [record]);
   - no async/await, no `Pin`, no drop-cancellation.

   Rust's 2026 goals still treat async drop and scoped spawn as foundational work [evidence].
3. **Authority:** capabilities as values and no ambient I/O, so each dependency's authority
   footprint can be audited. Rust offers this only as an optional library discipline.
4. **Verification:** contracts, plus a translation to Lean that reuses the Aeneas approach for the
   eligible subset. No SMT in ordinary builds.

**Judgement.** That combination is coherent, and each part is a real Rust limitation. But it is a
*compiler-and-runtime* thesis, not a type-system thesis. The case is **strong only if** the team
values (1) and (2) enough to pay for a new ecosystem. If the goal is mostly a safe, fast systems
language with optional verification soon, **a constrained Rust profile wins**:

- no proc macros in your own code;
- arenas and indices;
- `std::thread::scope` plus a fiber library;
- Verus or Aeneas for proofs;
- `lld`/`mold` and, where it helps, Cranelift.

It gives up a small implementation, sound structured async, capability enforcement and
Go-class edit loops.

---

## 6. Conflicts, not simultaneous maxima

| | Conflict | Resolution |
| --- | --- | --- |
| **K1** | A small trustworthy implementation versus competitive native performance | An optimising C compiler or LLVM in the TCB for release builds. Optionally a small backend of our own later, for development builds. |
| **K2** | Fast compilation (shared generics, -O0) versus fast test execution | Specialise small inline generics even in development builds; measure test-time ratios. |
| **K3** | Low annotation burden versus compositional, predictable incremental checking | Choose compositional (§1.1). |
| **K4** | Maximum acceptance of mutable APIs versus a small checker and cheap verification | Choose the small checker. Spend precision only intra-procedurally (§3.3). |
| **K5** | Early self-hosting versus feature completeness | Leave concurrency, compile-time evaluation, verification and devices off the self-hosting path. |
| **K6** | A new language versus the ecosystem | §5 |

---

## 7. Bootstrap and backend

### 7.1 Seed language: Rust, in a Grail-compatible profile

The profile:

- arenas and indices for AST and IR;
- owned trees;
- explicit lifetimes only where Grail would need them;
- enums and `match`;
- simple traits;
- no proc macros beyond the derives Grail will build in;
- no `async`;
- `dyn` only where Grail will have it.

The profile's advantages:

1. **Self-hosting becomes transliteration.** Translation is near-mechanical and AI-assisted, module
   by module, because A's semantics match. It is not a redesign.
2. **The seed is the checker's first large corpus.** Translated modules should be accepted by
   Grail's checker exactly where rustc accepted the originals. This gives a free differential test
   of the borrow checker on real compiler code.
3. Rust's own checker keeps the seed memory-safe while it is written.

**OCaml** writes a throwaway frontend faster: garbage collection, excellent pattern matching, fast
builds. But its persistent, shared, garbage-collected data structures do not transliterate, so
self-hosting becomes a rewrite. It is not installed here, though that does not matter.

**Go** has the same trade-off as OCaml. **C** is slow to write safely. Neither offers a concrete
advantage over a Rust seed here.

### 7.2 Backend: C first, from a backend-neutral low-level IR

The low-level IR has explicit control flow, layout, calling convention and checks, so no
C-specific semantics leak into it.

**C emission:**

- One `.c` file per module, giving parallel and incremental compilation.
- A strict subset that avoids undefined behaviour:
  - unsigned arithmetic with explicit overflow checks;
  - `-fwrapv -fno-strict-aliasing`;
  - `memcpy` for type punning;
  - explicit bounds checks;
  - `restrict` only on exclusive-reference parameters, where its semantics match;
  - `#line` directives back to Grail source.
- Fibers through a tiny per-target assembly context switch.
- Development builds with clang -O0, or tcc where available. TCC claims 7–9× faster than gcc
  -O0 [evidence: vendor claim]. Release builds with clang or gcc -O2.

**Why C first:**

- Readable output makes early compiler bugs cheap to find.
- It runs everywhere and needs no LLVM-version coupling.
- **The self-hosted compiler's own generated C is the bootstrap artifact,** so the Rust seed
  retires after self-hosting. Zig needs a wasm-plus-C-backend route for the same purpose [evidence].
- The interface a Grail-written compiler needs is "write text, run a subprocess".
- The C emitter is a thin final stage, so the discarded work is small.

**Against C:**

- C parsing costs extra: clang -O0 took 6.8 s from C versus 4.2 s from equivalent LLVM IR in the
  probe [evidence].
- There is undefined behaviour to avoid, guaranteed tail calls are weaker, and aliasing
  information is coarser.
- Debug information is at C level, mapped by `#line`.

**The other options:**

| Option | Assessment |
| --- | --- |
| **LLVM IR text emission** | The best semantic fit (overflow intrinsics, `noalias`, no C undefined behaviour) and release parity with Rust. Development speed is the same LLVM at -O0: only about 1.6× faster than C in the probe. Unreadable, with heavier version-coupled dependencies. **The second backend**, added if release-performance gaps attributable to aliasing or overflow information appear. |
| **Cranelift** | Rust-only API with no stable C interface, so a Grail-written compiler would need Rust FFI. Modest gains in rustc: 5–15% incremental [evidence]. **Rejected.** |
| **Direct machine-code backend** | The fastest possible development builds and full control. But instruction selection, register allocation, ABIs, object formats and DWARF are needed per target. Zig needed years, and its debug-build runtime can be far slower [evidence: anecdote]. **Deferred until after self-hosting,** and only if profiles show the C compiler dominates the edit loop. TPDE-style or QBE-style designs are the models. |
| **QBE** | Small, text-based IL with reasonable code, targeting "70% of the performance in 10% of the code" (a stated goal, not a benchmark). A candidate model for a later trusted development backend. Not first. |

**Does C delay direct compilation or backend independence?**

- *Backend independence:* no, if the low-level IR is designed for machine backends and the C
  printer stays thin [argument].
- *Fast clean builds:* tcc or a later direct backend is needed for those. Per-module granularity
  covers edits.

---

## 8. Conclusion

### 8.1 What we gain over Rust

- A small self-hosted compiler.
- Signature-only incremental checking and parallel per-function checking.
- No macros, and a smaller trait system.
- Generic code volume controlled in development builds.
- Sound structured direct-style concurrency with scope-owned work.
- Capability authority.
- Integrated optional verification.

None of these is a new borrowing capability.

### 8.2 What we deliberately give up

- Annotation-free stored-reference APIs: types that hold references and non-elidable relationships
  are written.
- F1–F3-style strong updates.
- Restoring through a stored handle.
- Problem case 3, until the local extension (§3.3).
- General GATs and general higher-ranked bounds.
- Async-style future values.
- The Rust ecosystem.
- Some development-build runtime speed.
- A smaller TCB for release builds (K1).

### 8.3 Compiler complexity we refuse to implement

- Cross-function ownership or dependency inference.
- Exported post-states, target sets, per-outcome summaries and deferred generic operations.
- Body-dependent interfaces.
- Proc or token macros.
- Trait specialisation, overlap and negative reasoning.
- Autoderef method chains.
- General GATs and higher-ranked bounds.
- The async state-machine transform and `Pin`.
- Our own optimiser.
- Fine-grained incremental query graphs. Use coarse signature hashes instead.
- Whole-program analysis in development builds.
- SMT in ordinary builds.

### 8.4 Smallest discriminating experiment before committing

**X-A: a seed slice.** Write about 5–8 kLOC of the real seed (lexer, parser, resolver and a type
checker for a minimal Grail subset) in the Grail-compatible Rust profile, with AI assistance.
Measure:

1. Lifetime annotations per kLOC.
2. Restructurings forced by borrowing that G1 or the §3.3 extension would have avoided.
3. AI repair iterations per borrow error.
4. The best-case Rust edit loop on this code (`cargo check` and an incremental debug build, with
   `lld`/`mold`, and Cranelift where available). That is the baseline Grail must beat.

**X-B: backend probe.**

- Emit per-module C for the seed's own data structures and three kernels: tokenizer, hash-map
  counting, tree walk.
- Time clang -O0 per module, and tcc if it can be installed.
- Compare `-O2` runtime with equivalent Rust release builds.

**Commit if all of these hold:**

| | Criterion | Proposed threshold |
| --- | --- | --- |
| (a) | Restructurings that a G1-class feature would avoid | No more than a handful, each with an explicit workaround already listed |
| (b) | C `-O2` runtime against Rust on the kernels | Within about 10% |
| (c) | Rust-profile incremental loop for a one-function edit | Clearly above your target, for example more than 2 s at about 10 kLOC |

If (c) fails, the build-speed case for Grail is weak. Re-decide between Grail and D on §5's
remaining grounds.

### 8.5 Shortest credible route to self-hosting

1. **S0 — Seed (Rust profile).**
   - Pipeline: lexer, parser, name resolution, local type inference and interfaces (no
     specialisation), NLL borrow checker, low-level IR, C emitter.
   - Runtime: minimal C runtime with allocator, panic-abort, files through a capability passed to
     `main`.
   - Excluded: fibers, compile-time evaluation, verification, generics sharing (monomorphise at
     first).
2. **S1 — Minimal standard library in Grail:** `Vec`, `String`/`Str`, `HashMap`, `Option`/`Result`,
   `recycle`, arenas.
3. **S2 — Transliterate the seed** module by module. Golden tests compare emitted C from the seed
   and the translated compiler. Run the borrow checker on the translated code as a corpus.
4. **S3 — Stage 2 compiles stage 3,** reaching a fixpoint on emitted C. Check in the compiler's
   generated C as the bootstrap artifact, then retire the Rust seed.
5. **S4 — Afterwards:** the fiber runtime with the scope registry, development-mode generic
   sharing, a faster development backend if profiles demand it, LLVM IR emission if release gaps
   demand it, then verification.

### 8.6 Evidence that would reverse this recommendation

- **X-A shows frequent G1-class restructurings in real code,** not demonstration snippets. Adopt
  the *specific* bounded feature that removes them, written in signatures where it crosses calls.
  Still not full G1.
- **Assisted lifetime authoring proves unreliable or expensive** (many repair loops, or
  over-restrictive signatures needing human redesign). Revisit B more broadly.
- **The Rust-profile edit loop already meets the targets,** and a small or self-hosted
  implementation is not decisive. Choose D.
- **C `-O2` falls materially behind Rust,** or the subset that avoids undefined behaviour proves
  unworkable. Make LLVM IR text the primary backend.
- **Development-mode generic sharing makes tests too slow.** Specialise more in development builds
  (K2).
- **Fibers prove infeasible** because of memory or FFI. Revisit the concurrency implementation,
  keeping its semantics.

**What happens to G1 research.** Freeze it. The place-state and target-coverage work remains useful
theory for a future signature-written extension and for the verification translation. It is not
the compiler's foundation.

---

## 9. Probe methods and raw numbers

All probes ran on one shared 4-core cloud host (rustc 1.97.0, clang/llc 18.1.3, gcc 13.3) in this
session's scratch directory. Caches were warm, there were single runs, and nothing was pinned.
These are illustrations, not benchmarks.

**Borrow patterns** (`rustc --edition 2024 -O`):

| Probe | Result |
| --- | --- |
| Problem case 3 `get_default` | Rejected, E0499 |
| `last_slot` tail-cursor loop | Compiles and runs |
| `words.clear()` reuse of `Vec<&str>` across chunks | Rejected, E0597 |
| `recycle(v: Vec<&'a str>) -> Vec<&'b str>` via `clear` plus `into_iter().map(unreachable).collect()` | Compiles; pointer and capacity unchanged across three iterations. This relies on std's in-place collect, which is not guaranteed, hence a dedicated Grail primitive. |

**Phase times** (`RUSTC_BOOTSTRAP=1 rustc -Z time-passes`):

- *Generated crates:* 1,500 groups. Each group has a token struct, a parser struct holding
  `&'p mut Vec<Tok<'a>>`, a lexer storing `&'a str` views, and a counter using
  `HashMap<&'a str, u32>`, `entry`, `get_mut` and iterator chains with closures. That is 34.5 kLOC.
- *Control:* the same shapes with owned `Vec`/`String` passed by value and `(u32, u32)` spans.
  That is 39.0 kLOC.

| Configuration | `type_check_crate` | `MIR_borrow_checking` | Codegen / LLVM / link | Total |
| --- | ---: | ---: | --- | ---: |
| Borrow-heavy, metadata only | 3.36 s | 5.68 s | — | 9.95 s |
| Control, metadata only | 2.85 s | 5.02 s | — | 8.85 s |
| Borrow-heavy, debug | 3.45 s | 7.41 s | 0.33 / 0.13 / 0.06 s | 12.1 s |
| Borrow-heavy, `-O2` | 3.19 s | 6.89 s | 4.12 s total codegen, LLVM 0.43 s | 16.1 s |

Notes on the table:

- The `-O2` codegen figure is mostly the monomorphisation collector.
- Most functions are unreachable from `main` in this binary crate, so code generation volume is
  artificially small.
- `MIR_borrow_checking` includes demand-driven MIR construction.

**C versus LLVM IR** (57 kLOC generated C, 3,000 lexer/counter groups with bounds and overflow
checks, a single translation unit):

| Command | Time |
| --- | ---: |
| `gcc -O0 -c` | 15.28 s |
| `clang -O0 -c` | 6.76 s |
| `clang -O2 -c` | 56.89 s |
| `llc -O0` on the clang-emitted `.ll` (35 MB) | 4.69 s |
| `clang -O0 -c gen.ll` | 4.20 s |

**External sources:**

- [Beránek, "What part of Rust compilation is the bottleneck?" (2024)](https://kobzol.github.io/rust/rustc/2024/03/15/rustc-what-takes-so-long.html)
- [Rust compiler performance survey 2025 results](https://blog.rust-lang.org/2025/09/10/rust-compiler-performance-survey-2025-results)
- [Rust 2026 Fast Builds roadmap](https://goals.rust-lang.org/2026/roadmap-fast-builds.html)
- [Zig self-hosted x86 backend as debug default](https://ziggit.dev/t/self-hosted-x86-backend-is-now-default-in-debug-mode/10447)
- [Hashimoto on Zig 0.15 build speed](https://mitchellh.com/writing/zig-builds-getting-faster)
- [QBE](https://c9x.me/compile)
- [Tiny C Compiler](https://bellard.org/tcc/)
