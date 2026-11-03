# V1 concurrency contract (implementation in progress)

This is the contract being built, not a claim that these APIs already ship. Grail's compiler and
runtime remain the only implementation; parallel APIs must not execute sequentially under a
parallel name. The initial platform set is Linux x86-64, AArch64 and RV64 with atomic instructions.

## Type obligations

- **Send**: an owned value may transfer to another worker. Moving it makes the original binding
  unavailable. **Share**: an immutable reference may be used concurrently. Neither means that
  arbitrary writes are allowed. These are checked structural capabilities, not user promises.
- Numeric/unit values qualify; collections and aggregates require the corresponding capability
  for every contained value. A shared reference requires a Share referent. Exclusive references
  can transfer only with exclusive authority and a lifetime that outlasts the joined task.
- An opaque `atomic<num>` owns one aligned atomic word. Every access to its contents is atomic;
  safe code cannot obtain a plain mutable reference to that word. An atomic field does not grant
  write permission to surrounding fields or make an otherwise non-shareable aggregate Share.
- Shared mutation of non-atomic values requires a typed synchronization primitive. A lock guard
  carries unique access to its payload and retains the lock's lifetime. Guards cannot escape or
  silently migrate between incompatible worker/thread ownership domains.
- Task closures/callables, explicit context, arguments and results must satisfy transfer rules.
  Generic bodies cannot assume Send/Share without a checked bound. Unknown types stay affine.

Atomic methods will encode permissible ordering (e.g. acquire loads and release stores), so a
release-load/acquire-store is not an accidentally accepted ordering combination. Sequentially
consistent load/store/CAS are the initial baseline; stronger-than-requested lowering is valid but
must not be sold as an optimized weak-order implementation. Integer atomic fetch arithmetic is
explicitly modular. CAS is strong unless an API explicitly says weak.

## Structured task lifetime

A scope owns all work started in it. A task handle is affine; joining transfers its result exactly
once, and an explicit structured scope exit joins undisposed work rather than detaching it. Task-handle
destruction must not hide blocking or suspension; the scope boundary advertises and checks that
effect. Borrowed
captures retain their originating loans until all uses finish. A task or result borrowing a local
cannot outlive that local, including through generic returns, containers and early exits.

CPU parallel collection operations consume/move elements into workers or borrow only with proven
permissions. They do not invent disjoint mutable slices or clone arbitrary affine captures.
First-class callables and checked captures are prerequisites, not an excuse to expose numeric
function pointers or unchecked context records to safe applications.

## Colourless suspension

A task may suspend inside ordinary I/O calls without turning every caller into an async function
or exposing Future state machines. This does **not** erase scheduling semantics:

- Stackful tasks use a real readiness reactor and resume owned frames, rather than polling/blocking
  the same worker under an async-looking interface.
- CPU workers use bounded scheduling/work stealing; blocking foreign calls are explicitly isolated.
- Worker-affine state/guards require pinning or a checked non-migration boundary. A suspended task
  must not resume on another worker while violating a live guard's contract.
- Cancellation is cooperative. A request wakes cancellable waits and is observable; it does not
  abandon a live stack or pretend that dropping raw stack memory runs generated destructors.
  Normal error propagation/return and explicit scope joining preserve cleanup. Non-cooperative code may
  delay cancellation; no unsupported hard-cancellation guarantee is advertised.
- Panics currently abort the process, as elsewhere in Grail. This work does not claim panic
  isolation/unwinding that the language does not implement.

## Runtime and verification prerequisites

The allocator, live counter and slab lists now use a serialized atomic lock; concurrent allocation
stress tests are still pending. Process PATH construction happens before fork so its child never
acquires an inherited allocator lock. Other runtime globals must be audited before workers start. Thread startup/join, task result publication,
queues and I/O registrations need explicit acquire/release or stronger synchronization. No live
worker may access unmapped stacks, task records or shutdown arenas.

Tests must include actual multi-threaded execution and overlap, structural rejection of unsafe
captures/results, scope/return escapes, atomic contention and ordering, bounds/UTF-8/overflow
invariants, cancellation/cleanup, blocking-call isolation, starvation/backpressure behavior and
cross-target execution. Passing single-thread smoke tests is not sufficient. Platform/feature
limits remain documented until implemented and verified.
