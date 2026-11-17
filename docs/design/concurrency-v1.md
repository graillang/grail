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
- An opaque `Atomic<T>` (T an integer of 8 to 64 bits or `bool`) owns one aligned atomic word. Every access to its contents is atomic;
  safe code cannot obtain a plain mutable reference to that word. An atomic field does not grant
  write permission to surrounding fields or make an otherwise non-shareable aggregate Share.
- Shared mutation of non-atomic values requires a typed synchronization primitive. A lock guard
  carries unique access to its payload and retains the lock's lifetime. Guards cannot escape or
  silently migrate between incompatible worker/thread ownership domains.
- Task closures/callables, explicit context, arguments and results must satisfy transfer rules.
  Generic bodies cannot assume Send/Share without a checked bound. Unknown types stay affine.

Atomic methods encode their ordering in the name (stage 7, docs/design/concurrency-stages-5-7.md):
`load`/`load_relaxed`/`load_acquire`, `store`/`store_relaxed`/`store_release`, and every
read-modify-write and compare-exchange bare or with `_relaxed`, `_acquire`, `_release` or
`_acqrel`. A release load or an acquire store has no name, so it is a "no method" error rather than
an accepted combination. The bare name is sequentially consistent. Each ordering is lowered as
itself on every target and in LLVM IR (no ordering is carried as a stronger fence), and the text
optimiser treats every atomic op as a barrier. Integer atomic fetch arithmetic is modular at the
element's width; `fetch_min`/`fetch_max` take their signedness from the element type. CAS is
strong (`compare_exchange`, returning the value seen) unless the API says weak
(`compare_exchange_weak`, returning whether it stored), and a failure ordering is derived from the
success ordering as C++ derives it.

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
  v1: a foreign call occupies its worker for its whole duration. FFI is valid on every runtime thread
  (each has its own glibc TCB when libc is loaded); a callback on a thread C created aborts by name.
  The runtime offloads only `host::read_file`,
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
  inside a C callback therefore kills the process instead of returning into C. Exactly one thread
  reports: an atomic claim decides which, and the others park until the reporter's exit ends the
  process, so two tasks failing at once print one message, not two. The main thread, an offload
  helper and a thread foreign code created raise SIGABRT on POSIX (the platform's cleanup-free exit
  then follows: `exit_group` on Linux, `TerminateProcess` on Windows, `_exit` on macOS); a scheduler
  worker (and any thread inside a parallel region) exits with status 134 directly, because a signal raised from one of several
  threads that may fail together is delivered to whichever thread the kernel picks and can race the
  exit. `exit(2)` and `ExitProcess` are never used on this path because they run atexit handlers,
  C++ destructors or DLL detach. This work does not claim panic isolation or unwinding that the
  language does not implement.

## Platform mechanism: the same task semantics, a different switch

A task is green on every platform, and it is multiplexed over **one worker per CPU** on every
platform, Windows included. What a program may rely on is the same everywhere:

- `spawn` creates a task that is queued on the spawning worker's deque and runs there - or on
  another worker that steals it - until it *yields or blocks*. Suspension parks the task, not the
  worker: the other tasks keep running.
- `sleep_ms`, `read_fd`, `write_fd` and the blocking host operations (`read_file`, `write_file`,
  `command`) park the calling task. On Linux and macOS the reactor suspends it on a descriptor or
  timer registration; on Windows it parks on the task's park word and is woken by a completion (the
  blocking call runs on a helper thread) or by a timer on the reactor's heap. The observable
  behaviour is the same; only the mechanism is.
- `join`, task-scope exit, cancellation, result publication and the abort rules behave identically.
- The interleaving *order* is not a portable guarantee, and it is not deterministic anywhere: with
  one worker per CPU two ready tasks really do run at the same time. What is guaranteed is that a
  task gives up its worker only at a yield or a block, and that a yield re-queues it.
- `host::worker_id()` and `host::workers()` expose the scheduler: the worker running the call (from
  1, or 0 off a worker) and the worker count.

Mechanically the platform module supplies the readiness source and the switch: Linux switches stacks
with `raw_switch` under an epoll reactor with one worker per CPU, Windows switches Win32 fibers
(`CreateFiberEx`/`SwitchToFiber`) with an I/O completion port as the reactor, and macOS switches with
`raw_switch` under kqueue. A task stack is a 1 MiB reservation with a guard page at its low end on
Linux and macOS (committed lazily, recycled through a per-worker free list), and a 64 KiB-committed
in 1 MiB-reserved fiber stack on Windows (grown by the OS through guard pages). Running past the
bottom is a named runtime error, `error: stack overflow`, and exit status 134 - not a silent write
into a neighbouring mapping.

A reactor that cannot be created is not fatal: the scheduler runs without it and the operations
that wanted it fall back to offload. `docs/design/scheduler.md` states the deques, the parking
protocol, the stacks, the reactors and what each platform is verified by.

### The opt-in thread-per-task scheduler

`GRAIL_TASKS=thread` in the environment selects the previous Windows scheduler on any platform, and
it is a *different* semantic rather than a faster one:

- `spawn` creates a task record and a real OS thread; `join` and scope exit wait on the task's
  finished word and then reap the thread, so its stack is unmapped only after it exited.
- Suspension (`rt_suspend`/`rt_wake`, used by `rt_offload`) parks the task's own thread on its park
  word with `WaitOnAddress`.
- `rt_wait_fd` returns immediately and `host::sleep_ms` sleeps the task's thread: readiness is the
  blocking call on the thread that owns the task. `rt_reactor_fence` is a no-op, `rt_yield` is
  `SwitchToThread`, and a mutex blocks the task's thread.
- A task that never yields still makes progress beside another one, because both own a thread. That
  is the point of the mode (CPU-bound fan-out) and the reason it is not the default: there is no
  `Send`/`Sync` check, so two tasks mutating the same memory race silently.

The mode is resolved once per process from the environment and cached in process state
(`rt_task_mode`, word 88), so entering it costs no per-task check.

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
