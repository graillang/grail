# Pending-work ownership and error cleanup

2026-10-30. Investigation of a missing semantic rule, **not a bug report against an existing Grail
implementation**. [Finite model](../../research/experiments/cleanup06/README.md),
[raw reachability/counterexamples](../../research/evidence/cleanup06-20261030/reachability.json).
The [state-transformer experiment](experiment-results-05.md) covers normal returns and excludes these
resources; its clear/drop rules must not silently be generalized to pending operations.

## The user handle is not the underlying work

```text
scope {
    op = upload(buffer)
    fallible_operation()?  // error before explicit finish
}
```

If error abandonment merely requests cancellation and forgets op, some other owner must retain both
work and borrowed storage until all relevant users stop. A non-suspending handle destructor can
coexist with a scope that joins on error; those are different operations with different effects.

The finite model separates user handles from a registry owned by the enclosing scope. Operations
share one **read-only** buffer, so multiple pending operations are legitimate. All policies consume
handles before exit: normal paths finish them explicitly, error paths abandon them. Only the registry
policy decides whether the buffer's lifetime survives outstanding work.

| Policy | N=1 states / violations | N=2 states / violations | N=3 states / violations |
| --- | ---: | ---: | ---: |
| Scope retains each operation until its acknowledgment | 13 / 0 | 37 / 0 | 115 / 0 |
| Dropping handles on error clears registry | 14 / 1 | 42 / 5 | 134 / 19 |
| Any acknowledgment clears entire registry | 13 / 0 | 45 / 2 | 187 / 12 |

These are complete reachable-state graphs of these nine finite instances, not sampled traces or a
proof about arbitrary operation counts, source programs or a runtime implementation. Violations mean
an operation still *may* access a released buffer; no actual DMA/read occurs in this experiment.

Minimal error trace for the handle-only policy:

```text
submit(0) -> error/abandon/request_cancel -> release_buffer
```

The operation is still cancel_requested after release. User handles are empty, but memory lifetime
is wrong. A counterexample to the all-on-one-ack policy is:

```text
submit(0) -> submit(1) -> acknowledge(0) -> error/abandon -> release_buffer
```

Operation 1 remains active. A one-operation test misses this bug by construction.

## Invariant and progress boundary

The scope-owned policy maintains active IDs ⊆ registered IDs. Submission adds to both; acknowledgment
removes that operation from both; error abandonment changes handles/cancel requests, not membership.
The exit guard requires the registry empty. Thus the intended invariant excludes active work when
buffer_alive becomes false. This is a short inductive argument for the abstract rules, **not a
mechanized proof**, a source-type preservation theorem, or proof that a real acknowledgment is honest.

Every case also has a reachable pending-error state with a stall self-loop. Consequently safety does
not establish eventual acknowledgment or a bounded cleanup time. A timeout can initiate cancellation
without guaranteeing that borrowed storage is reclaimable at the timeout. Aborting the process,
transferring owned storage, restricting operations or intentionally retaining storage are different
policies with real costs; none is adopted here.

The model assumes stable addresses and read-only sharing. It does not replace the earlier
[reallocation counterexample](quint-lessons.md): storage can remain alive while a saved pointer's
address/generation is invalidated. It also excludes stale/reused operation IDs, multishot completion,
cleanup failures, nested scopes and completion callbacks that access storage after the event claimed
as acknowledgment. Those require additional contracts or modeling.

## Dependency contracts need identity when removing obligations

Two operations borrowing the same buffer contribute the same root to a union of dependencies.
Completing one cannot simply subtract that root: the other may still need it. Keep operation/loan
identity, conservatively retain the union until a join-all barrier, or justify a richer update rule.
A root set alone is not a count of outstanding obligations.

This does not mandate reference counting for ordinary Grail values. A structured scope already needs
an explicit protocol for tracking/joining its operations. Runtime work registration and static
borrow/dependency summaries are different mechanisms; neither is a tracing collector. The exact
representation, cost and ownership proof remain open.

A scope owning pending work also carries a **latent cleanup effect**. If joining may suspend, a
function can suspend on an error exit even if no explicit wait in its body was reached. Effect
inference must include cleanup paths, not just normal calls. Alternatively an API can synchronously
stop work, move ownership out of the frame, or reject an unsupported combination. Nonsuspending
alone does not imply nonblocking, bounded, allocation-free or panic-free.

## Backend mapping: liburing is more specific than "cancel is asynchronous"

Primary documentation inspected at
[liburing c6da6135](https://github.com/axboe/liburing/tree/c6da6135fd7366fd3b18cec04f2df219f3a73979/man),
with [source provenance](../../research/evidence/cleanup06-20261030/precedent-sources.json):

- [io_uring_cancelation(7)](https://github.com/axboe/liburing/blob/c6da6135fd7366fd3b18cec04f2df219f3a73979/man/io_uring_cancelation.7)
  distinguishes target-request and cancel-request CQEs. Their observation order is not guaranteed;
  normal target completion races cancellation. A multishot request has a terminal CQE without F_MORE.
- [io_uring_prep_cancel(3)](https://github.com/axboe/liburing/blob/c6da6135fd7366fd3b18cec04f2df219f3a73979/man/io_uring_prep_cancel.3)
  explicitly says kernel-side cancellation runs synchronously despite async request syntax. On
  successful cancellation, the target completion has been posted by submission return. For
  **-EALREADY**, the caller must wait for the target request's completion event.
- The overview also documents a synchronous cancellation API that blocks until cancellation or
  timeout. Blocking can satisfy a nonsuspending surface effect but is not thereby bounded/successful.

Therefore do not translate every cancel submission, every cancel CQE or an unrelated completion into
acknowledge. Conversely, do not claim successful cancellation can never supply a stronger guarantee:
the mapping depends on status and the backend contract. Request identities, terminal events and
remaining users of completion metadata must be accounted for separately. This was documentation
inspection, not a kernel audit, runtime experiment or proof for every Linux version/device.

## Revised research direction

Keep finish-on-normal/abandon-on-error resource discipline separate from memory safety. If borrowed
pending values are allowed, specify who owns work after handle abandonment, what acknowledgment
means, and where cleanup effects appear. Then test the same rules for containers of pending values
and cancellation of a waiter. A join-all primitive must not skip remaining operations when one
completion reports an error: a short-circuiting `wait()?` loop needs an enclosing cleanup guarantee.
The model abstracts stopped operations' result payloads and does not implement error aggregation.
Do not add an unrestricted abandonable in-flight value merely because its destructor can be labeled
nonsuspending.
