# Original design versus the authoritative implementation

Audit baseline: the sole Grail-written compiler/runtime, `compiler/NATIVE.md`, the native regression
corpus and executable book. Rust/C prototypes and research models are not implementation evidence.
The original [surface sketch](surface-sketch.md) explicitly says it is **not a specification or
agreed syntax**; the [decision ledger](decisions.md) separates human directions from recommendations.
This table therefore distinguishes missing implementation from an unapproved research proposal.

## Major feature map

| Area / original intent | Status | Evidence and remaining gap |
| --- | --- | --- |
| Ordinary CPU language, deterministic owned cleanup, no tracing GC/mandatory RC | Implemented core, not a soundness proof | `compiler/native.grl`, `ownership.grl`, `runtime.grl`; runtime/ownership/cleanup audits and negative corpus. Abort paths do not unwind. |
| Native targets | Implemented Linux CPU ports | x86-64, AArch64 and RV64 execute/self-host; bootstrap manifest records provenance. macOS/Windows, device targets and other ABIs are separate missing ports. |
| Primitive numeric family and Bool | Missing beyond bootstrap num | `parse_type` supports num (u64), unit and aggregate/view/reference types. true/false are numeric truth literals. No standalone u8/i64/usize/float/bool; byte storage is not a primitive u8 type. See `numeric-types.md`. |
| Checked arithmetic with explicit alternatives | Implemented | Default overflow guards, local wrapping operations, explicit user `--overflow=wrap`; runtime guards and bounds remain checked. |
| Moves, borrowed aggregates, captured lifetimes, reborrows | Implemented with conservative limits | Records/enums/vectors and external loans are checked. Weak updates/whole-frame guards can reject valid programs; opaque invariant writes without a retained witness are rejected. |
| Trusted disjoint iteration / split authority | Missing general library/contract support | Known-disjoint fields work, but this is not proof of disjoint arbitrary indices or a general IterMut/lending-iterator contract. Do not infer target transfer from lifetime/arity alone (`authority-boundary.md`, `target-coverage.md`). |
| Little lifetime bookkeeping / inferred published origins | Partial | Written lifetime parameters and origin/guard checking exist. General lifetime elision, principal inferred public summaries and a separate compiled-interface contract are not implemented. |
| Higher-order functions and checked closures | Partial / capture-free values implemented | Typed function parameters/results, generic callbacks, explicit generic items and indirect ABI work. Lifetime/return-origin contracts are checked. Owned/shared/exclusive capturing closures remain missing; retired seed behavior does not count. |
| Static generics, record/enum layouts, universal template checking | Implemented subset | Generic layouts, inference, specialization, affine unknown types and unused-body checks exist. Structural Send/Share and explicit static user-defined interfaces/bounds are implemented. Generic interfaces, associated types, blanket implementations, effect-polymorphic callbacks and specialization-cache policies remain missing (`interfaces.md`). |
| Separate compilation with checked library contracts | Missing build/interface layer | The compiler checks named signatures but currently reads every module source and emits whole-program assembly. No opaque-provider compiled module format, transitive ABI invalidation or frozen exported origin/effect artifact is delivered. Old seed artifact machinery was removed. |
| Postfix collection transformations / iterators | Partial | Literals, push/pop/len/copy/text, byte slices and vector indexing work. Higher-order map/filter/folds, iterator/lending protocols and fusion are not implemented by postfix spelling alone. |
| Result and typed errors | Implemented core, partial standard policy | Nominal Result/Option and ? propagation exist. No !T/default closed-error shorthand; ! currently unwraps/aborts. Host read aborts and write returns numeric errno; recoverable typed OS errors are not a complete library yet. |
| Explicit authority / capabilities | Missing public capability model | host::print/read_file/command are ambient prototype APIs, not Console/Dir/Net/Allocator capabilities supplied at boundaries. No lexical typed context passing or authority-effect contracts. |
| Suspension effects and non-suspending cleanup | Missing | No published/inferred suspension summaries, checked nosuspend contexts, or user cleanup/release contract. This is a prerequisite for honest colourless concurrency, not solved by omitting async syntax. |
| Structured CPU parallelism, tasks and colourless readiness I/O | In progress / missing scheduler | Current v1 work includes type rules, atomics, safe allocation, scoped lifetimes, cancellation, worker scheduling and blocking boundaries. No claim that a sequential helper or thread-shaped API is a scheduler. |
| Atomicity / synchronization / cross-thread capabilities | In progress | Opaque word-atomic operations and structural transfer/sharing bounds are implemented. Allocation is serialized. Contention and multi-thread tests are still required before claiming a thread-safe scheduler. An atomic field grants no permission to mutate other fields. |
| Containers / arenas / networking / channels | Partial basic library | bytes, strings, vec, Pair/Option/Result exist. Generational arena IDs, maps, network resources, timers/channels and capacity/backpressure policies are not a complete v1 library. |
| User FFI boundary | Missing | No general extern C declarations, checked pointer exposure, foreign effect/retention contracts or unwinding policy. Current raw intrinsics are a restricted trusted runtime boundary, not a safe FFI feature. |
| Staging / comptime | Missing; original proposal | No general stage evaluator, finite stage budgets or explicit build-time authority policy. Generic specialization is not arbitrary compile-time execution. |
| Contracts / proof / verification lane | Research only | No requires/ensures/proof elaborator, erased total logic or compiler-linked proof certificates. Research models/Lean lemmas are not proofs of the native compiler. Ordinary builds must not depend on proof search. |
| Optimizing/build-performance lanes | Missing beyond caches and direct emission | No optimizing middle end/register allocator, separate library object cache or shared elaborated proof/fast lane. Compiler build caching is not incremental application compilation. Performance claims need workload measurements. |
| Device resources / GPU kernels | Research only, not agreed v1 implementation | No typed device buffers, transfers, kernel checker, convergence/admission rules or backend. CPU support does not imply GPU support. |

## Immediate consequences for the approved work

1. Build general callables, structural transfer/sharing and synchronized allocation before workers.
2. Colourless functions still need visible/checkable suspension effects. In particular, the original
   ledger rejects **hidden blocking destructors**: joining belongs to an explicit structured scope
   operation/exit contract, not an unadvertised arbitrary task-handle destructor.
3. Cancellation must not abandon owned stacks. Scope error/exit must retain borrowed storage while
   requesting cancellation and joining; ordinary resource release must be non-suspending.
4. Lock guards and foreign blocking calls need explicit suspension/migration rules. A runtime cannot
   silently move a guarded task to another worker and call that colourless safety.
5. Keep capture lifetime, address/target authority and referent writeback distinct; the original
   call-activation/target-coverage counterexamples remain acceptance gates for higher-order calls.

## V1 decisions to prioritize, not silently assume

Beyond the already approved concurrency/HOF work, the largest ordinary-language gaps are numeric
widths/signedness/Bool, a small interface/constraint mechanism, typed fallible OS/capability APIs,
checked module interfaces/incremental builds, iteration/adapters and a documented FFI boundary.
These need a release decision and acceptance tests. Proof/staging/device sketches are longer-term
proposals unless explicitly promoted; copying Rust's complete feature list is not the plan.
