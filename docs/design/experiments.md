# Validation plan and smallest serious prototype

**Measured follow-up:** [experiment results 01](experiment-results-01.md) adds executed reference
probes and qualifies the earlier Hylo provenance and Goose specialization discussion. Earlier
“not executed” statements describe their original research tranche, not the current evidence set.

Status: proposed experiments, not implemented; no measured performance claims.
The [memory-model competition](memory-model-competition.md) refines the shared workloads and gates.
Borrowed external-owner aggregates are required cases; scoped-only checker milestones are not a
permanent exclusion of those APIs. Add mode-reading/diagnostic tests and contextual-capability escape
cases before selecting source syntax.

## First prototype: an interface checker, not a language ecosystem

**Question:** can scoped loans, origin summaries and callback effects compose across independently
compiled modules cheaply enough, with useful iterators and suspension?

1. Freeze a tiny typed core on paper: records, sums, owned boxes/buffers, shared/exclusive loans,
   functions, closures, scopes, move, disposal, one suspension operation and structured join.
   No parser beyond a typed test IR, custom theorem prover, full standard library or GPU compiler.
2. Define the symbolic module signature: parameter access, result/capture origins, effect variables,
   required capabilities, types/layout. Check clients from signature artifacts **without provider bodies**.
3. Formally model owner/loan validity and task-scope exit in an established proof assistant.
   State preservation, no dangling loans/double frees, and disjoint-access race freedom for the subset.
   Separate progress, bounds traps, nontermination, cancellation and external runtime assumptions.
4. Implement the smallest local dataflow checker and serialize interfaces. Use a reference interpreter
   if needed to find counterexamples; no untrusted third-party executable is needed to inspect sources.
5. Only if the checker is viable, add one fast backend to test layout/moves/fusion. Do not add LLVM,
   Cranelift, MLIR and GPU support simultaneously.

## Adversarial API corpus

For every case, record: expressible unchanged / scoped rewrite / owned copy / handle rewrite /
explicit origin contract / rejected, and why. Count annotations, hidden work, summary size and checks.

- Scalar/record ownership and partially initialized values on error branches.
- Vector growth while a slice is live (must reject invalidating growth).
- `first(xs)` returning a borrow; `choose(a,b)` with conservative multi-root provenance.
- Returning a reference into a local (must reject), including through closure/container indirection.
- Reborrow a mutable slice and split it into disjoint slices.
- Iterator adapters that retain loans, `map` callbacks, nested closure capture and generic forwarding.
- A map entry API, parser cursor and zero-copy packet fields with independent lifetimes.
- Owned recursive tree; arena graph with deletion; intrusive doubly linked list; movable self-reference.
  Rejection is an expected data point, not permission to cheat with unchecked pointers.
- Scoped worker reads/writes and shared capability constraints; conflicting sibling mutation rejected.
- Loan across direct-style suspension, stable owner frame, nested task scopes, error/cancel path joins.
- Mutex guard crossing suspension (reject baseline); child that never cooperates with cancellation.
- Foreign callback attempting to retain a scoped pointer; ABI wrapper must not falsely declare it safe.
- Public API body change that changes the returned origin or suspension effect: reject incompatible
  implementation or invalidate/recheck clients, never silently reuse stale summaries.

**Go/no-go gate:** representative libraries compile against exported summaries only; no concrete
caller roots enter specialization keys; scoped iterators/closures work without whole-program inference;
invalid examples are rejected; any remaining escape hatches are explicit. If this fails, reconsider
Hylo-style projection APIs, a smaller borrowing envelope, or explicit lifetime relations. Do not hide
failure behind an ever-growing global inference engine.

## Measurement discipline

Pin versions/flags/commits, hardware, OS, allocator, CPU governor, task runtime, and safety checks.
Do warmup and repeated independent runs; report distributions and confidence intervals, not one best
number. Distinguish cold filesystem/process/compiler caches, warm package caches and incremental
semantic caches. Record excluded workloads and failed compiles. Publish raw results and scripts.
Do not compare Grail debug builds to optimized competitors or use relaxed floats for only one language.

| Experiment | Workloads | Metrics / hypothesis to test |
| --- | --- | --- |
| Frontend build cost | Generated modules varying declarations, import depth/fanout, generic nesting, root fanout | Parse/type/loan/effect times separately; peak RSS; summary bytes; scaling curve and worst cases |
| Full clean native build | Equivalent CLI/parser/HTTP components in Go/Rust/Zig/Grail when available | Wall time, CPU time, link/debug-info time; no claim of Go parity from backend-only timings |
| Incremental edits | Body-only, interface/layout, effect, contract, shared generic change | p50/p95 edit-to-diagnostic and edit-to-binary; rechecked entities; cache-hit rates |
| Ownership ergonomics | Adversarial corpus plus ported small libraries | Accepted API shapes, explicit annotations, necessary copies/allocations, diagnostic quality; not merely LOC |
| Runtime | Binary parser, hash map, arena graph, tree transforms, sorting, stencil, numerical kernels | Against optimized Rust/C++; throughput/latency, cycles, RSS, allocations, drop cost, code size |
| Iterator fusion | filter→map→sum, fallible map, captured closure, borrowed and owned variants | Generated IR/assembly, intermediate allocations, branches/callback dispatch, throughput |
| Generic policy | Many types/closures/shapes and repeated imports | Instantiations, cache sharing, code size, compile time vs dictionary dispatch cost |
| Direct-style runtime | Echo server, file pipeline, timers, fanout RPC simulation, tiny and deep call stacks | Throughput and p50/p95/p99 latency, per-task stack/frame memory, allocations, fairness/cancel latency |
| Deterministic cancellation | Scripted scheduler exploring fail/cancel/join order, noncooperative child | No reclaimed-live frames, no double cleanup; explicitly identify unbounded shutdown cases |
| Proof effort | Bounds-safe parser, binary search, sorting/permutation, protocol transition | Independently reviewed requirements, annotations/lemmas, search time vs check time, proof maintenance |
| Evidence invalidation | Mutate body, contract, imported theorem/axiom, ABI, arithmetic policy, target | No stale certificate accepted; malformed/incorrect certificates rejected; report unsupported checks |
| Parallel scheduling | map/reduce, divide/conquer, irregular trees; tiny tasks and skewed inputs | Break-even sizes, work/span, memory overhead, determinism, slowdown vs sequential |
| Device placement (later) | vector map, scan, stencil, matmul, host/device ping-pong | Transfers and synchronization included; compare optimized CUDA/Futhark; kernel-only and end-to-end separately |
| Capacity guarantees | Dynamic shapes, external callee without summary, concurrent allocator/process pressure | Unknown is not zero; fallible runtime admission; no claim of global OOM exclusion |
| Lowering agreement | Differential interpreter/native runs plus supported translation validation | Traps, integer overflow, NaNs, moves, destructor/error ordering; tested equality is not a proof |

Desired performance ratios should be chosen **after** measuring relevant baselines and selecting
product workloads. They are hypotheses/gates, never facts derived from language aesthetics.

## Research sequence after the first discussion

1. Loan/effect interface calculus and hand-worked API corpus.
2. Hylo/Goose/Cogent implementation deep dives; compare extending Hylo rather than starting fresh.
3. Direct-style runtime ABI micro-experiment (stackful vs effect-lowered); include callbacks and FFI.
4. One modest verified native component with a C ABI, then evaluate developer/agent workflow.
5. Only then decide backend expansion, accelerator scope, proof automation and commercial integrations.
