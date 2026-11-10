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

## Stage 3 as built

The derivation is one structural walk in `compiler/native.grl`,
`transfer_capability(c, ty, shared, trail, depth)`. `shared` selects the question - 0 asks
`transferable`, 1 asks `shareable` - so both properties come from one recursion that has the same
shape; only the leaf rule and the borrow rule differ. It is not a trait: nothing is added to any
signature, no user type can opt in (an opt-in would be a way to erase a restriction), and a type
nothing knows about is denied.

| Type kind | transferable | shareable |
|---|---|---|
| scalars: u64, unit, bytes, string, char, bool, sized int, Atomic, f64; capture-free fn pointer; CancelToken | yes | yes |
| record / enum / union (8) | every field | every field |
| vector (6) | element | element |
| typed slice (27) | element | element, and only a read-only slice |
| byte view (5) | yes | read-only only |
| `&T` (7) | shareable(T) | shareable(T) |
| `&mut T` (7, exclusive) | transferable(T) | no |
| `Mutex<T>` (13) | transferable(T) | transferable(T) |
| `Task<R>` (16) | transferable(R) | no |
| `Scope<C>` (14) | no | no |
| `byval(R)` (28) | R | R |
| closure (20) | every capture | every capture |
| handle (23) | declared `transferable` | declared `shareable` |
| CStr (24), CPtr/CMutPtr (26), cfn (25) | no | no |
| capability proof (9) | its transferable bit | its shareable bit |

Three rules carry the review's corrections:

- **A shared reference is only shareable when its referent is.** `&T` hands the holder every method
  callable through `T`, so if `T` reaches a handle then `&T` is not shareable even though nothing can
  be written through it. This is why a `&File` capture is refused.
- **A slice reaches its elements.** The old walk treated a slice as bytes; `&[T]` now classifies as
  `T`, for the same reason.
- **A closure's environment is part of its type.** See below.

The walk records which leaf denied (`cap_denial`) and the dotted path that reached it (`cap_segs`),
so a rejection names a field rather than repeating the whole type.

### The closure environment, and the hole it closed

A closure type (kind 20) carried only its signature, and `parallel_map` checked the item, the result
and the context but never the closure. So this compiled, and every worker could reach the handle
through the environment:

```grail
g := |x: u64, u: u64| -> u64 touch(&h, x);   // plain-data signature, thread-affine capture
parallel_map(items, 0, g);
```

Fixed by making the environment part of the closure's identity: `Ty.env` holds the environment
record (kind 8) the closure is lowered into, interned into the type key, so two closures with one
signature and different captures are different types - which they already were as layouts. The walk
classifies every environment field (`__code` and `__drop` too, both plain words) and pushes a
capture's name onto the path exactly like a record field. A closure that has escaped a job is
covered by the same rule, because a closure in a result position is just a type of kind 20: what
crosses is the whole environment, and it must be transferable. A closure that *borrows* its
environment cannot escape at all, because a borrowed capture puts the lifetimes into the type and
the existing `contains_borrow` result check refuses it.

`parallel_map` also refuses an `FnMut` callback now: every worker shares one closure object, so a
callback that writes a capture would have its workers race on the environment.

### Diagnostics

```
cannot share closure capture `a`: a.file is thread-affine (a foreign handle with no audited classification)
cannot share closure capture `f`: f is thread-affine (declared transferable, not shareable)
cannot share parallel_map context: file is thread-affine (a foreign handle with no audited classification)
cannot share parallel_map context: an exclusive borrow cannot be shared
cannot transfer spawned result: thread-affine (a foreign handle with no audited classification)
```

### The audit

A handle states its contract where it is declared - `handle File: transferable;`,
`handle PhysicalDevice: transferable, shareable;`, `handle Window;` - and nothing declared is
neither. `shareable` alone is an error, because a value usable on another thread may also be moved
to it. Default-deny is the point: adding a foreign type to the compiler can never widen what a
worker may reach.

| Handle | Classification | Why |
|---|---|---|
| `sys_grail::File` | transferable | an fd/HANDLE with no wrapper-side state: it may be moved to a worker and closed there. Nothing serializes two users of one, so `close` under another worker's read is a race. |
| `sys_grail::Socket` | transferable | the same, and the accept-loop-to-worker handoff is the intended use. |
| `sys_grail::Process` | transferable | wait/kill/close are per-call syscalls on an owned child handle; nothing serializes concurrent calls. |
| `sys_grail::Thread` | neither | its one correct disposal (join or detach, exactly once) is the creating thread's bookkeeping, and the shim hands every handle out through a `_Thread_local` slot, so acquisition itself is thread-local. |
| `rhi_vulkan::Instance` | neither | created and destroyed on the thread that owns the display connection - on Linux the surface extension binds an Xlib display, thread-affine without `XInitThreads` - and Vulkan requires every child dead before it. |
| `rhi_vulkan::PhysicalDevice` | transferable, shareable | owns nothing, has no destructor, and every operation is a query; sharing it puts capability and queue-family queries off the main thread. |

`Device` is not a handle this module has yet. When it becomes one it should be
**transferable-only**: a `VkDevice` is not thread-bound by the specification, but the queue and
command pool this wrapper selects with it are main-thread state and Vulkan requires external
synchronisation around them.

### What a scoped parallel primitive must call

`parallel_map` calls, in order: the callback shape; `require_parallel_closure(c, fty, 1,
view("closure capture"))`; then `require_capability_named` on the item (0), the result (0) and the
context (1). A scoped job primitive calls the same two predicates:

```grail
require_capability_named(&mut c, input_ty, 0, view("job input"));
require_parallel_closure(&mut c, fty, 1, view("job capture"));  // environment shared by workers
require_parallel_closure(&mut c, fty, 0, view("job capture"));  // environment moves to one worker
require_capability_named(&mut c, result_ty, 0, view("job result"));
```

`shared` is 1 when several workers may call the environment at once (`parallel_map`,
`parallel_for_chunks`) and 0 when the closure moves to exactly one worker (a single job).
`require_parallel_closure` is one call so a surface cannot do half the job: it refuses an `FnMut`
environment when it is shared (concurrent workers would race on it) and then classifies every
capture. Both predicates reset the diagnostic state themselves and fail at the call site, naming the
field.

### Deliberately not classified

`CStr` (24), `CPtr`/`CMutPtr` (26) and `CFn` (25) stay denied: each reaches foreign memory or code
nobody has audited, and none of the handles we use needs them to cross a boundary. `CPtr` over
Grail-owned bytes is the one that plausibly could, but its origin is a call-scoped borrow, so
whoever audits it must also say what the pointee's lifetime is. The opt-in `Send`/`Share` generic
bounds are the same walk under their old names; renaming them to `transferable`/`shareable` is a
language change of its own and is not part of this stage.

### B1

Classification has to survive an exported interface or separate compilation re-derives the safe
answer for the wrong reason: a module importing `sys_grail::File` would see an opaque declaration
with `transfer = share = 0` and refuse a move the audit allowed. Nothing is lost today because the
whole program is one declaration table, and B1 stage 1 emits per-module assembly only. When
interface files land they must carry `Decl.transfer` and `Decl.share` for every handle, and
`Ty.env` - the closure environment record, with its field names and types - for every closure type
that appears in a signature.

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

### What is checked, and what is not

Both the values that cross a job boundary and the closure's environment are now classified. The
compiler's structural walk (`transfer_capability`) is the single derivation engine, reached through
`require_parallel_closure` for a callback, and it names the field that denies:

    a handle captured by the closure
      cannot share closure capture `h`: h.file is thread-affine (a foreign handle with no audited classification)
    a handle as the item, or a record holding one
      cannot transfer parallel_map item: thread-affine (a foreign handle with no audited classification)
      cannot transfer parallel_map item: file is thread-affine (a foreign handle with no audited classification)
    unclassified FFI authority (`CStr`, `CPtr`, `CMutPtr`)
      cannot transfer parallel_map item: unclassified foreign authority

Also refused: an `FnMut` closure shared with concurrent workers ("an FnMut closure would race on its
own environment"), a `Task` handle, an exclusive borrow, a mutable slice or view, and a type
parameter with no capability proof. A type declared transferable but not shareable is accepted for an
item and refused as a shared context, which is the distinction the design note's table draws.

What this does **not** buy, and must not be read as buying:

- **The foreign library's behaviour.** A classification says a value may move or be shared; it does
  not say the library behind it tolerates that. That is what an audited declaration asserts, and the
  declarations for the handles actually used (files, sockets, Vulkan objects) are still to come.
- **The FFI surface is default-denied, not audited.** `CStr`, `CPtr`, `CMutPtr` and `cfn` are
  deliberately unclassified, so they are refused as "unclassified foreign authority" or "an
  unclassified C function pointer" today. Conservative and correct, and it means a legitimate
  foreign blob cannot cross a job boundary until its declaration exists.
- **`unsafe module` code.** It can construct or convert anything, so the classification is exactly
  as strong as the safe surface above it.
- **Shared OS resources.** Two jobs writing the same descriptor is not a data race and no type
  catches it; it stays a documented hazard, mediated by the authority model and by owner actors.

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
