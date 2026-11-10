# Real parallelism

Goal: use every core, especially for Abundance's chunked geometry, image and asset work, without
importing a trait system and without shipping a safe API that is unsound.

This note replaced an earlier plan whose central premise was wrong. It is kept honest here.

## What was wrong in the first draft

The first draft said: *a job owns its inputs and returns an owned result, so nothing can race and no
compiler change is needed.* An external review (GPT-6.1 Sol, high effort) refuted it, and it is right:

- **Ownership is not transferability.** A window/context must be created, used *and destroyed* on its
  creating thread; a Vulkan object may refer to a thread-affine command pool; a buffer may have to be
  freed on its allocating thread. Moving such a value to a worker is not a memory race but is unsound.
- **Foreign libraries hold hidden state** - process-global or per-thread scratch -, and may call
  registered callbacks from their own threads.
- **A read-only `&T` is not automatically shareable**: if `T` reaches a handle (directly, through a
  field, or through a closure capture, or as a returned reference into foreign scratch) then methods
  callable through `&T` can mutate foreign state.
- So a check over the argument type alone is insufficient. The whole **closure environment, the
  result, and the reachable foreign authority** must be classified.

## The model

Two compiler-derived properties, **not** traits and **not** bounds on every signature:

- **Transferable(T)** - a value may cross to another worker, including being destroyed there.
- **Shareable(T)** - concurrent shared access is permitted.

| Type | Transferable | Shareable |
|---|---:|---:|
| Plain data (integers, floats, bytes, records/enums/slices of them) | yes | yes |
| Unique foreign context, movable but not concurrently usable | yes | no |
| Main-thread window/context | no | no |
| Audited immutable foreign blob | maybe | maybe |

Derived structurally for Grail-defined types: a record is transferable when its fields are; shareable
when its fields are. **Unknown FFI classification defaults to denied.** A safe wrapper cannot erase a
restriction, and being declared in an `unsafe module` is not by itself the criterion - the boundary
needs an explicit foreign-resource contract.

Checked after monomorphisation, so diagnostics name the field:

```
cannot transfer job capture `decoder`:
  decoder.context is thread-affine
```

Classification metadata must survive in exported interfaces (B1) so separate compilation can check it
later, and so explicit constraints could be added without redesign.

## The safe surface: structured, not free spawn

- **Scoped jobs.** A scope guarantees borrowed inputs outlive the workers and that no worker can still
  reach frame memory after the scope ends. This is what makes shared captures sound without a trait
  system, and it is the property an unrestricted `spawn(&x)` can never give you.
- **`parallel_for_chunks(&mut [T], chunks, f: Fn(&mut [T]))`** - the compiler splits an exclusive
  slice into disjoint exclusive chunks, and the elements must be transferable. Disjointness is
  constructed, not checked. This is the Abundance workload.
- **`parallel_map(&[T], f) -> V[]`** - requires `Shareable(T)`; results returned in input order.
- **Owner actors** for externally mutable resources (asset caches, sockets, the main thread). Not a
  primitive; a consequence: thread-affine work runs on a main-thread executor and workers hand back
  CPU-side results.
- An unrestricted spawn is **not** part of the safe surface. A trusted/unsafe primitive may exist for
  the runtime itself, clearly named and documented as such.

## Lifecycle rules that must be designed in, not retrofitted

- **Fail-fast scope exit**: one job failing cancels its siblings, then joins them, and only then
  releases the inputs.
- **Cooperative cancellation** cannot let a parent reclaim memory a running child still borrows.
- **Helping scheduler**: a worker that waits on children it queued must make progress itself,
  otherwise a pool can deadlock when every worker waits. Nested parallelism reuses the pool rather
  than creating core-count pools.
- **Blocking separation**: blocking foreign calls must not run on the CPU pool. `rt_offload` already
  exists for this and now crosses a thread boundary itself, so it needs the same classification audit.
- **Allocators**: cross-worker ownership implies cross-worker destruction. Start with an allocator
  that supports that; locality is an optimisation later.
- **Determinism**: result ordering and reductions are defined independently of execution order.
  Floating-point reductions must not silently depend on which worker finished first.

## Build order

1. Bounded pool + structured scope/join, with the lifecycle rules above and tests for them.
2. `parallel_for_chunks` over plain-data element types, refused by name for anything else.
3. Structural derivation of transferable/shareable, with default-deny for unknown FFI types, and the
   audited declarations for the handles we actually use (files, sockets, Vulkan objects).
4. `parallel_map` with the shareable check.
5. Job graph with dependencies, once the lifecycle is proven.
6. Abundance: move `job_executor` and the geometry chunking onto it; main-thread executor for the RHI.

## Deferred on purpose

NUMA, elaborate priorities, a public work-stealing policy, and deterministic scheduler replay. The
one thing not deferred: an API shape that assumes all work is interchangeable forever - interactive
frame work must eventually be able to avoid starvation behind bulk asset builds, so the pool needs
room for that even if priorities are not implemented yet.

## As built: stage 1 landed (this section is implementation, the note above is the plan)

### The runtime: one bounded work-stealing pool

`compiler/runtime.grl` owns one process-wide pool, created by the first parallel call and never
destroyed. Reused rather than reinvented:

- `rt_thread_spawn_detached` - the same persistent-thread primitive the green scheduler and the
  blocking offload path use; workers are plain OS threads with 1 MiB stacks and a guard page.
- `rt_mutex_lock`/`rt_mutex_unlock` (futex), `rt_spin_lock`, `rt_atomic_*`, `rt_alloc`/`rt_free`,
  `raw_map` for infrastructure that must not count as user allocation, `rt_cpus`, `rt_abort`.
- `rt_offload` is untouched and remains the blocking path: a blocking foreign call never runs on a
  pool worker, so it cannot exhaust the CPU pool.

Architecture:

- **Queues.** Every worker owns a bounded ring (1008 jobs); threads that are not workers submit to a
  bounded injection ring (496). Both are bounded, so a full queue runs the job on the submitting
  thread instead of blocking or growing: submission is total, and no submitter waits for a slot.
- **Stealing.** The owner pushes and pops at the tail of its ring (LIFO, so a nested submit runs its
  children before the parent resumes); thieves take from the head (FIFO, so a stolen job is the
  oldest, and the jobs left behind are not starved by newer ones). A thief's starting victim rotates through an atomic
  cursor, so idle workers do not all pounce on one victim.
- **Park/wake.** Idle workers sleep in the kernel on one futex word (the pool's wake sequence). A
  worker reads the sequence *before* it scans for work, so a submit that lands after that read
  either appears in the scan or changes the word the worker is about to wait on - no wakeup can be
  lost, and nothing spins for work. Ring locks are short spin locks; the locks are held for a few
  instructions and never across a job.
- **Jobs and results.** A job record holds a callback, one environment word, one argument word, one
  result word and a futex state word. The worker builds the result and publishes it with a release
  store before waking; the thread that waits for the job reads the result and frees the record, and
  the worker never touches the record again. Every allocation therefore has exactly one releasing
  thread.
- **Helping.** A worker that waits on a job it queued runs queued work itself (its own ring, then the
  injection ring, then a steal pass), so a pool whose every worker is waiting still makes progress.
  A thread that is not a worker only sleeps: helping from a non-worker could run an unrelated long
  job in front of the one it is waiting for.
- `rt_parallel_map` is now a client of the pool: it splits its items into a few contiguous ranges
  (four jobs per worker, capped at the item count), submits one job per range, and waits for every
  job. It no longer creates and joins threads per call, and the pool's own workers mean a nested
  `parallel_map` reuses the pool instead of creating a second one.

### The safe surface: `lib/pool.grl`

`pool::map(items, f)`, `pool::run(count, f)`, `pool::for_chunks(data, chunks, f)` and `pool::join(a,
b)`, all built on `parallel_map` because a safe module cannot call the runtime directly. The
ownership rule is stated at the top of the file: **everything a job's closure touches it owns** - a
job's inputs are moved into it and its result is owned, and no reference crosses a job boundary.

`for_chunks` is the Abundance shape and is sound for plain data today without a compiler change: it
consumes the vector, hands each job one contiguous **owned** chunk, and concatenates the results in
chunk order. It is the same shape stage 2's `&mut [T]` chunks will produce, minus the compiler
split - and that is its cost: splitting by popping moves every element twice, about 46-48 ms for
3M u64 elements against ~10 ms to build the same vector (~15 ns per element, against ~3 ns). `parallel_for_chunks(&mut [T], ...)`
removes that copy entirely, which is one more reason stage 2 is where the compiler earns its keep.

### The pool's share of the process state, and why the merge broke

`rt_state` is 4096 bytes shared by every long-lived subsystem, and a claim on one of its words is
now a row in a single table at the top of the pool section of `compiler/runtime.grl` - word, owner,
accessor and who claimed it - with the offsets appearing exactly once, inside the accessor named by
that row (`rt_state_pool()` and `rt_state_pool_cas()` for the pool). A comment would depend on
people reading it; the table is the place a new claimant has to edit, next to everyone else's claim.

Stage 1 first put the pool pointer in `raw_state() + 88` and the creation CAS in `+96`, because both
were free at the time. Then the Windows green scheduler landed `rt_task_mode()`, which caches the
resolved task mode in **88**. Merged, a program that ran a `task_scope` first (mode word = 1) and
then `parallel_map` had `rt_pool()` read 1 as the pool pointer and `rt_parallel_map` dereference
1 + 8: a fault at address 0x9, with the program's correct output already printed. The pool now sits
at 3200/3208, which the table shows free in every platform module.

The pool also used to borrow **word 48 of the thread record** as "which worker am I". That word is
free on Linux but is the Windows address wait's per-thread expected-value slot, so the borrowing was
a latent Windows bug on the unmerged branch too. A worker now publishes its own thread record in its
worker block at startup and `rt_pool_self` finds it by scanning the worker array; no thread-record
word is touched. `tests/pool/from_task.grl` (`pool-from-green-task`) pins the interaction: parallel
work entered from a task scope and from spawned tasks, which is the combination neither branch
tested alone.

### Determinism

Results land in their input slots, so `pool::map` returns input order whatever order the jobs finish
in, and `for_chunks` returns chunk order. The runtime also asserts an exactness invariant of its own:
the per-job counts must sum to the item count, so an item written twice or not at all aborts instead
of returning a plausible wrong answer.

### The gap this stage does not close

`parallel_map` - and therefore everything above - capability-checks the item, the result and the
context structurally: a `handle` is neither `Send` nor `Share` (type kind 14, `transfer_capability`
returns false), so `H[]`, `Holder{file: H}[]` and a handle as the context are all refused with a
diagnostic. What is **not** checked is the closure environment: `|x: u64, u: u64| -> u64 touch(&held,
x)` with `held` a record holding a handle compiles and reaches that handle read-only from every
worker. That hole is pre-existing in `parallel_map`, not introduced here, and it is closed where the
classification lives - the closure-capture capability check in `compiler/native.grl`. Until it
lands, the module doc says plainly: treat a closure passed to `pool` as trusted, capture plain data,
keep handles out of the capture.

### Lifecycle properties: tested vs designed

Tested by native cases (`tests/native-cases.json`, fixtures in `tests/pool/`):

- nested parallel work completes on a **one-worker** pool (`pool-nested-one-worker`,
  `GRAIL_POOL_WORKERS=1`) - the helping scheduler is the only thing that makes that non-deadlocking;
- one long job among trivial ones does not deadlock and its result lands in its own slot
  (`pool-uneven-work-no-deadlock`);
- results are independent of completion order (`pool-map-input-order`: job 0 sleeps longest);
- a failing job ends the process promptly instead of hanging pool or waiter (`pool-abort-in-job`).
  The failure policy is the runtime's abort policy (B5): no unwinding, so there is no half-dead
  sibling to cancel and nothing a live thread could still reach. Raised on a pool worker the abort
  surfaces as the runtime's abort exit status (134, i.e. 128 + SIGABRT), which is exactly what
  `abort-in-green-task-ends-process` already records for an abort raised on a runtime thread; raised
  on the main thread it is still SIGABRT. Both are a process abort with no hang and no code after
  the abort, which is the property that matters. **Do not "fix" the difference by making `rt_abort`
  wait for the signal** (yielding or `tgkill` to self): the process-directed `SIGABRT` is delivered
  to whichever thread does not block it, so the aborting thread's `exit_group(134)` can win the
  race, and 134 is the status the recorded B5 contract and `abort-in-green-task-ends-process` both
  expect. The exit status for a thread-side abort is 134 = 128 + SIGABRT, by design;
- the chunk split does not change the answer (`pool-chunks-owned`) and four jobs are materially
  faster than one (`pool-speedup-four-workers`, which skips its assertion below four cores).

Designed but not observable in safe code yet:

- **Fail-fast scope exit** reduces to the abort policy: `rt_abort` hard-exits (SIGABRT, no unwinding,
  no thread left running), so there is no half-dead sibling to cancel and no memory a live thread
  could still reach. A future non-abort failure path needs an error value to cross a job boundary,
  which the language does not have yet.
- **Cooperative cancellation** has no meaning while failure is abort, and adding a flag nothing sets
  would be dead code; it arrives with that typed-error path.
- **Priorities**: interactive frame work avoiding starvation behind asset builds needs a second queue
  class. The pool has room for it (per-worker rings plus injection ring) but no policy.

### Measured (24 reported cores, 3M CPU-bound u64 elements, 1 job vs 4 jobs, best of two rounds)

| `GRAIL_POOL_WORKERS` | one job | four jobs | speedup |
|---:|---:|---:|---:|
| 1 | 27 ms | 28 ms | 0.96x (assertion fails, as it must) |
| 2 | 28 ms | 15 ms | 1.9x |
| 4 | 28 ms | 12 ms | 2.3x |
| 8 | 30 ms | 8 ms | 3.8x |
| default (24) | 27 ms | 8 ms | 3.4x |

### What stage 2 needs from the compiler

1. **Closure-capture classification** in `native.grl` (`require_capability` over the closure type's
   captures), so the safe surface stops being trusted-only.
2. `parallel_for_chunks(&mut [T], chunks, f: Fn(&mut [T]))`: split the exclusive slice into disjoint
   exclusive chunks and check the element type by name, which removes the copy the owned-chunk shape
   pays today.
3. A user-visible job handle, or the scoped equivalent, so `spawn`-then-`wait` can be expressed
   outside a structured call; the runtime already supports it (`rt_pool_submit` / `rt_pool_wait`),
   and only the builtin bridge is missing.
4. The audited transferable/shareable declarations for the handles actually used (files, sockets,
   Vulkan objects), with default-deny for unknown FFI types, surviving in exported interfaces.
