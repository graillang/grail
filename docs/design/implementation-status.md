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
| Primitive numeric family, Bool and char | Implemented integers, bool, f64, f32, char | `u8`..`u32`, `i8`..`i64` (`u64`/`usize` = `num`), checked/wrapping conversions, signed arithmetic and printing, `bool` with short-circuit `&&`/`||`/`!`, `f64` and `f32` (each result rounded to binary32, shortest round-trip printing), `char` Unicode scalar values with `chars()`/`push_char` (`integers.md`). Unsuffixed literal bindings take their type from later use (`bindings.md`). Byte sequences are packed (one byte per element); char classification/case mapping covers Latin-1, Latin Extended-A, Greek, Cyrillic (plus CJK letters). |
| Checked arithmetic with explicit alternatives | Implemented | Default overflow guards, local wrapping operations, explicit user `--overflow=wrap`; runtime guards and bounds remain checked. |
| Moves, borrowed aggregates, captured lifetimes, reborrows | Implemented with conservative limits | Records/enums/vectors and external loans are checked. Weak updates/whole-frame guards can reject valid programs; opaque invariant writes without a retained witness are rejected. |
| Trusted disjoint iteration / split authority | Missing general library/contract support | Known-disjoint fields work, but this is not proof of disjoint arbitrary indices or a general IterMut/lending-iterator contract. Do not infer target transfer from lifetime/arity alone (`authority-boundary.md`, `target-coverage.md`). |
| Little lifetime bookkeeping / inferred published origins | Partial | Written lifetime parameters and origin/guard checking exist. General lifetime elision, principal inferred public summaries and a separate compiled-interface contract are not implemented. |
| Higher-order functions and checked closures | Implemented: fn values and capturing (copy/move) closures; borrowing/FnMut missing | Typed fn values, generic callbacks, return-origin checks; `Fn(T)->R` closures copying scalars and moving owned captures, read-only in the body (`closures.md`). Borrowed/mutable captures and closures in generic functions remain missing. |
| Static generics, record/enum layouts, universal template checking | Implemented subset | Generic layouts, inference, specialization, affine unknown types and unused-body checks exist. Structural Send/Share and explicit static user-defined interfaces/bounds are implemented. Generic interfaces, associated types, blanket implementations, effect-polymorphic callbacks and specialization-cache policies remain missing (`interfaces.md`). |
| Separate compilation with checked library contracts | Missing build/interface layer | The compiler checks named signatures but currently reads every module source and emits whole-program assembly. No opaque-provider compiled module format, transitive ABI invalidation or frozen exported origin/effect artifact is delivered. Old seed artifact machinery was removed. |
| Postfix collection transformations / iterators | Partial | Literals, push/pop/len/copy/text, byte slices and vector indexing work. Higher-order map/filter/folds, iterator/lending protocols and fusion are not implemented by postfix spelling alone. |
| Result and typed errors | Implemented core, partial standard policy | Optional `T?` values and structural `T | E` unions support implicit member upcasts, exhaustive type-based matching, `?` propagation and generic member inference; `!` unwraps/aborts. Host read aborts and write returns numeric errno; recoverable typed OS errors are not a complete library yet. |
| Explicit authority / capabilities | Missing public capability model | host::print/read_file/command are ambient prototype APIs, not Console/Dir/Net/Allocator capabilities supplied at boundaries. No lexical typed context passing or authority-effect contracts. |
| Suspension effects and non-suspending cleanup | Missing (runtime suspension exists; no static effect contract) | No published/inferred suspension summaries, checked nosuspend contexts, or user cleanup/release contract. This is a prerequisite for honest colourless concurrency, not solved by omitting async syntax. |
| Structured CPU parallelism, tasks and colourless readiness I/O | Implemented core: fork-join, task scopes, green tasks, epoll reactor, offload; closures/effects missing | Current v1 work includes type rules, atomics, safe allocation, scoped lifetimes, cancellation, worker scheduling and blocking boundaries. No claim that a sequential helper or thread-shaped API is a scheduler. |
| Atomicity / synchronization / cross-thread capabilities | In progress | Opaque word-atomic operations and structural transfer/sharing bounds are implemented. Allocation is serialized. Contention and multi-thread tests are still required before claiming a thread-safe scheduler. An atomic field grants no permission to mutate other fields. |
| Containers / arenas / networking / channels | Partial: hash map, sharded concurrent map, mutex added | `u8[]` byte vectors, strings, `T[]` vectors, `[K: V]` maps, optional values and structural unions exist; tuples are removed. Generational arena IDs, network resources, timers/channels and capacity/backpressure policies are not a complete v1 library. |
| User FFI boundary | Missing | No general extern C declarations, checked pointer exposure, foreign effect/retention contracts or unwinding policy. Current raw intrinsics are a restricted trusted runtime boundary, not a safe FFI feature. |
| Staging / comptime | Missing; original proposal | No general stage evaluator, finite stage budgets or explicit build-time authority policy. Generic specialization is not arbitrary compile-time execution. |
| Contracts / proof / verification lane | Research only | No requires/ensures/proof elaborator, erased total logic or compiler-linked proof certificates. Research models/Lean lemmas are not proofs of the native compiler. Ordinary builds must not depend on proof search. |
| Optimizing/build-performance lanes | Partial: per-function word-stream optimizer | `optimize.grl` forwards slots, removes dead code, promotes hot slots to callee-saved registers, fuses branches, inlines leaf runtime accessors, the `push` fast path and small leaf functions; the compiler emits sized-integer arithmetic inline and drops loop-proven bounds checks (`NATIVE.md`). Measured on x86-64 (best of 5, loaded machine): a 5M sieve 689 → 83 ms (Rust -O 46–54 ms), a 20M-step i32 loop 4.7 s → 0.17 s (Rust 0.10 s), Collatz 620 → ~215 ms (Rust 85 ms); self-compilation peak memory 1.5 GB → 0.18 GB. No general register allocator, loop optimization, separate library object cache or shared elaborated proof/fast lane. |
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
