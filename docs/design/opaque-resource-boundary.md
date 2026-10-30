# Opaque T, destruction and outstanding work

2026-10-30. [Cases and runner](../../research/experiments/resources15/README.md),
[evidence](../../research/evidence/resources15-20261030/),
[pinned standard-library sources](../../research/experiments/resources15/std-provenance.json).
No Grail source checker, universal resource theorem or performance comparison is implemented here.

## Question

The pure shared-data proofs preserve dependency support. The [referent study](mutable-referent-state.md)
then needs authority/current-state transfer. What changes when generic T contains a unique cursor,
a destructor or a user handle for scope-owned work?

An output root set is not a complete resource/effect contract. Consuming T does not uniformly mean
"its destructor ran", "its borrow ended", "all work stopped" or "scope exit is bounded".

## Seven version-pinned Rust observations

Rust 1.98.0, compiler commit `88d9e12ae178fab0fb5cc050a94da85685d449ea`:

| Case | Observed result |
| --- | --- |
| Generic pack then forget a Vec containing a unique cursor | compile/run; parent reused |
| Generic forward of that container, then conflicting parent write | reject E0506 |
| Generic duplication of arbitrary owned T | reject E0382 |
| Generic erase versus generic drop on a custom destructor | compile/run; erase skips it, drop mutates target and increments counter |
| Generic drop of a scoped-thread handle | compile/run; released child finishes and scope returns |
| Generic forget of a scoped-thread handle | compile; both body/child completion markers, then no scope return within 8s |
| Forget scoped handle then use borrowed data inside scope | reject E0502 |

Only intended positive/bounded-observation cases execute. Compile-reject fixtures never execute,
even if a future compiler unexpectedly accepts them. The runner requires the inspected compiler
commit rather than silently changing version-specific expectations.

### Forgetting an ordinary owned container

The Vec allocation is intentionally leaked. Its cursor/pointer bytes need not be physically zeroed
or destroyed for the parent to become accessible: no safe live owner can access that forgotten
container afterward. Logical loan ending is not necessarily a runtime destructor event. This is an
affine/leak-tolerant observation, not a recommendation that Grail provide `forget` or allow every leak.

Forwarding the same T instead keeps its access live; a conflicting parent write is rejected. T's
ownership/access structure matters even when a generic callee does not inspect its fields. Root
support alone is idempotent and cannot justify duplicating an arbitrary T; copy/move validity is a
separate typing invariant. These cases do not resolve the changing external-referent state tested
in referents14: this cursor points to an integer, not a mutable slot containing borrowed views.

### Destruction has observable behavior

The custom cursor destructor writes through its exclusive access and updates an atomic counter.
Generic `drop(T)` executes it; generic `forget(T)` does not. Neither function returns a borrowed
value, yet their value effects differ. Empty result captures therefore do not imply purity,
no mutation or universally trivial destruction. Generic effect checking needs an account of T's
destruction where it can run, not only a function's ordinary call/return dependency routes.

This probe measures no suspension. Arbitrary destructors can have other effects; NoSuspend,
NoBlock, bounded cleanup and memory safety remain different properties. No new effect-row syntax
or mandatory normal-build prover is adopted by this finding.

## The unexpected scoped-thread stall

The initial hypothesis that scope would return after the forgotten handle's worker finished was
falsified by a 15s timeout. The instrumented control records a later **8s bounded observation**, not
"successful completion":

- A readiness/release rendezvous ensures the child cannot write before the parent forgets/drops
  the user handle and explicitly releases it.
- Both variants emit `scope_body_done` and `child_done` (order is not asserted).
- The normal-drop variant also emits `scope_returned` and verifies the written value afterward.
- The forget variant does not return before timeout; the runner terminates it and checks that no
  owned test process remains. A timeout alone is not a proof of infinite execution.

Pinned source explains this version's behavior. `std/thread/lifecycle.rs` stores the result packet
in an Arc shared by thread and join handle. Its comment states completion accounting is signaled
when the **last** packet Arc is dropped; `Packet::drop` decrements the scope counter. Forgetting the
handle leaks its Arc, so dropping the thread's packet reference does not run that final destructor.
`std/thread/scoped.rs` waits while the counter is nonzero. For this program there is no later handle
operation that would release the leaked reference. Memory safety is preserved by retaining the scope,
not by reclaiming the borrowed stack slot early.

The three inspected installed source files were compared byte-for-byte with the public compiler
commit; URLs and hashes are retained. This is selected implementation inspection plus execution,
not an audit of Rust/std, a formal nontermination proof or a guarantee for all future versions.
The core `mem::forget` safety documentation explicitly says destructors are not guaranteed to run
and unsafe abstractions must tolerate the caller not running them.

The standard library's internal Arc is an observed implementation choice, **not a mandatory RC
requirement for Grail**. A different registry can track final work access separately from forgotten
user handles. The [cleanup study](cleanup-boundary.md) states the relevant operation/acknowledgment
boundary; it does not inherit native-runtime verification from this source inspection.

## Information the architecture must preserve

| Fact | Why it cannot be inferred from output captures alone |
| --- | --- |
| Ownership/copy permission | Same roots do not make duplication of unique T legal |
| Access/frame transfer and current referent state | Forwarding T keeps an access; making it unreachable may permit logical handoff |
| Destruction/value effects | Drop and forget have different observable behavior |
| Scope-owned pending uses/results | Losing a user handle does not discharge an independently retained scope obligation |
| Progress conditions | Retaining storage safely may still stall forever after leaked accounting |

These are semantic obligations, not five required user annotations/public qualifier slots. A
well-formed type constructor, private affine context, inferred effect summary and structured scope
can supply different pieces. Root-set forwarding remains useful but cannot stand in for all of them.

For opaque T, a general proof needs parametric ownership/resource transfer, correct current-state
handoff when accesses end, and appropriate destruction semantics. The earlier `deps(x, root)` and
suffix-substitution theorems prove none of that automatically. Their restricted value/shape models
do not certify arbitrary T containing exclusive handles or externally registered operations.

If Grail chooses stronger linear disposal or omits safe forget, state exactly how unreachable
owners, cycles/FFI, divergence and every scope exit interact with safety. If it permits leaks, do
not rely solely on arbitrary user-value destructors for borrowed-work safety. Structured operation
ownership must survive all supported abandonment paths; successful acknowledgment must mean no
further relevant access. Results with their own borrowed payloads need separate lifetime tracking.

The next useful gate is an ownership-parametric transfer invariant for opaque values and loan
frames, composed with—rather than substituted for—the root-support and ambient-work invariants.
Keep the design provisional until its inference/interface and erasure story are concrete.
