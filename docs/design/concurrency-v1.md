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
- CPU workers use bounded scheduling/work stealing. Blocking foreign calls are **not** isolated in
  v1: a foreign call occupies its worker for its whole duration, and FFI is valid on the main thread
  only because the host TLS base is process-wide. The runtime offloads only `host::read_file`,
  `host::write_file` and `host::command` when they run in a green task
  ([B3](decisions-b2-b6.md#b3-foreign-calls-block-the-executing-thread)).
- Worker-affine state/guards require pinning or a checked non-migration boundary. A suspended task
  must not resume on another worker while violating a live guard's contract.
- Cancellation is cooperative. A request wakes cancellable waits and is observable; it does not
  abandon a live stack or pretend that dropping raw stack memory runs generated destructors.
  Normal error propagation/return and explicit scope joining preserve cleanup. Non-cooperative code may
  delay cancellation; no unsupported hard-cancellation guarantee is advertised.
- Abort (a checked-arithmetic failure, an index bound, a failed `!`, `assert`, or an explicit
  abort) terminates the whole process immediately: it never unwinds, never returns to its caller,
  and runs no foreign cleanup. A blocking foreign call still blocks its thread (see below); an abort
  inside a C callback therefore kills the process instead of returning into C. `rt_abort` sends
  SIGABRT on POSIX and then calls the platform's cleanup-free exit (`exit_group` on Linux,
  `TerminateProcess` on Windows, `_exit` on macOS); `exit(2)` and `ExitProcess` are never used on
  this path because they run atexit handlers, C++ destructors or DLL detach. This work does not
  claim panic isolation or unwinding that the language does not implement.

## Platform divergence: on Windows a task is an OS thread

Linux runs stackful green tasks over a worker pool with an epoll reactor: many tasks share a worker,
suspension switches the stack away, and a blocking foreign call occupies a worker. Windows has no
epoll, eventfd or timerfd, and the runtime has no stack switching there, so `rt_threaded()` selects
a thread-per-task scheduler instead. The task API and its type rules are identical on both platforms;
the observable scheduling is not:

- `spawn` creates the task record and a real OS thread; `join` and scope exit wait on the task's
  finished word and then reap the thread, so its stack is unmapped only after it exited.
- Suspension (`rt_suspend`/`rt_wake`, used by `rt_offload`) parks the task's own thread on its park
  word with `WaitOnAddress`. There is no handoff and no stack switch.
- `rt_wait_fd` returns immediately and `host::sleep_ms` sleeps the task's thread: readiness is the
  blocking call on the thread that owns the task, which is the documented thread-per-blocking-call
  policy. With no readiness reactor, a task blocked in a blocking call observes cancellation only
  when that call returns.
- `rt_reactor_fence` is a no-op, `rt_yield` is `SwitchToThread`, and a mutex blocks the task's thread.
- Each task costs one OS thread and its stack, so the task count is bounded by threads and memory
  rather than by the worker pool. A blocking foreign call blocks only the task that made it, so B3's
  handoff is unnecessary there.
- `rt_sched` never creates a reactor on Windows, so the old fatal `epoll_create` abort cannot happen:
  `spawn`, `task_scope` and `parallel_map` work and are executed under Wine.

This is thread-per-blocking-call, not IOCP: overlapped I/O and completion ports are still
unimplemented, and there is no readiness-based fairness because every task already has its own
thread.

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
