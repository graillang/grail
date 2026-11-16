# Concurrency model: jobs, tasks and threads on one scheduler

Status: design proposal (gaps12). Nothing here is implemented; the compiler and runtime are
unchanged by this note. Claims are tagged **[V file:line]** (read in the code at 78c8c6e),
**[P n]** (probe n in `docs/design/concurrency-probes/`, output quoted in section 1.9) or
**[A]** (assumed, not verified). Probes ran on Linux x86-64, 24 logical CPUs, static (no libc) builds.

## 0. Decisions for the owner

| # | Decision | Recommendation |
|---|---|---|
| D1 | One set of worker threads, or keep the pool and the scheduler separate? | **One.** Delete the pool's threads; jobs run on scheduler workers. Today they are two sets (50 threads on 24 CPUs) and a task waiting for a pool job blocks its worker [P1, P4]. |
| D2 | May a job wait (lock, channel, I/O)? | **Legal, never the fast path.** A job that waits is promoted to a parked stack at that moment; `@no_wait` (a checked, opt-in effect like `@no_alloc`) is how a frame system proves it never does. No colouring. |
| D3 | Do dedicated OS threads exist as a public API? | **Yes, `thread::spawn` with name, stack, affinity, priority; joined by default.** Main, render and audio are threads, not workers; they reach the scheduler through scopes, channels and an executor mailbox. |
| D4 | Expose memory orderings? | **Yes, as method suffixes** (`load_relaxed`, `store_release`, ...), not an `Ordering` argument: only valid combinations exist, unsuffixed is sequentially consistent. Half of this is already in the compiler. |
| D5 | Thread-locals? | **Yes, but readable only through a `thread::Ctx` token that is neither `Send` nor `Share`**, so no task or job can hold one. Per-worker scratch is a separate `worker_local` with a callback-scoped borrow. |
| D6 | Ambient task-locals? | **No.** A scope already carries an explicit context; keep that. Revisit only for tracing ids. |
| D7 | Channel kinds | **Bounded MPMC and wait-free SPSC ring. No unbounded channel** (hidden allocation, no backpressure). `select` deferred (open question Q2). |
| D8 | Priority classes | **Three: `frame`, `normal`, `background`**, strict between classes, with a cap on workers that may run `background`. No preemption. |
| D9 | Blocking foreign calls | **Declare at the `extern`: `extern "C" blocking fn`.** The worker hands its queue to a spare thread for the call (Go's syscall handoff) instead of today's "one new OS thread per offloaded call". Undeclared calls keep the B3 contract. |
| D10 | `GRAIL_TASKS=thread` mode | **Remove once `thread::spawn` ships.** It is a second semantics with no `Send` check [V runtime.grl:3099-3106]; explicit threads replace its one use. |
| D11 | Worker count and core reservation | **`sched::start(Config)` before first use; default one worker per CPU**; an engine reserves cores for pinned threads by asking for fewer workers. |

## 1. What exists

### 1.1 Three kinds of thread, two independent schedulers

- **Scheduler workers** run green tasks. `rt_sched` creates `rt_os_workers()` threads
  (CPUs, floor 2, ceiling 64) plus one reactor thread, lazily, on the first call that needs the
  scheduler [V runtime.grl:3182-3230, os-linux.grl:345-354]. `host::workers()` itself is such a
  call: asking for the count starts every worker [V runtime.grl:3958-3964] [P1: 1 -> 26 threads].
- **Pool workers** run jobs (`parallel_map`, `parallel_for_chunks`, `parallel_spawn`, all of
  `lib/pool.grl`). `rt_pool` creates a *second* set, `max(CPUs, 4)` capped at 64 or
  `GRAIL_POOL_WORKERS`, on the first parallel call [V runtime.grl:2544-2558, 2585-2631]
  [P1: 26 -> 50 threads].
- **Plain threads**: the main thread, the reactor, one helper per offloaded blocking call. There is
  no public API to create one; `rt_thread_spawn` is runtime-internal [V runtime.grl:2324-2394].

**Pool jobs and green tasks do not share workers.** The two schedulers have separate blocks,
deques, injection rings and park words, and neither knows the other exists: `rt_pool_self`
answers 0 on a scheduler worker and `rt_worker_self` answers 0 on a pool worker
[V runtime.grl:2564-2584, 3260-3269] [P1: `host::worker_id()` is 0 inside a pool job]. Consequences,
all measured:

- A task that calls a pool operation is not a pool worker, so `rt_pool_wait` puts its *scheduler
  thread* to sleep on a futex [V runtime.grl:2845-2863]. When every scheduler worker is in that
  state no other task runs, timers included [P4: a 10 ms ticker stalls 307 ms].
- A pool job that calls `join`, sleeps, or locks is a plain OS thread to the scheduler
  (`rt_current() == 0`): it blocks its pool thread [V runtime.grl:3701-3703, 3925-3930].
- With both busy the process runs 2N compute threads on N CPUs. Throughput survives - the kernel
  time-slices them [P8: 587 ms for both at once against 341 + 347 ms apart] - but which work runs
  is decided by the kernel, not by Grail, which is what a frame loop cannot have.

### 1.2 What a job costs

| Operation | Allocations (global allocator, one spin lock [V runtime.grl:941-948]) | Measured |
|---|---|---|
| `pool::spawn` + `wait` | job record 48 B, closure box 8 B, environment [V runtime.grl:2817, 3039-3047] | 10.7 us [P2] |
| `pool::join(a, b)` | a one-element vector, result vector, descriptor 56 B, job array, job record [V lib/pool.grl:116-121, runtime.grl:2900-2931] | 12.0 us [P2] |
| `chunks_mut`, k chunks | descriptor, job array, then per chunk a job record and a 24-byte slice descriptor [V runtime.grl:2973, 3003-3013] | - |
| nested `join` recursion | as `join`, per level | `fib(32)`: 9 ms serial, **271 ms** with 28 656 joins on 24 CPUs [P2] |

A job has no stack of its own: it runs on its pool worker's thread stack, or - when a waiting
worker helps - on top of the waiter's frames [V runtime.grl:2853-2858]. Pool deques are
spin-locked rings of 1008 entries; a full ring runs the job inline [V runtime.grl:2732-2745,
2829-2837]. Every submit does a `futex` wake-all on the pool word [V runtime.grl:2838-2840].
A non-worker that waits only sleeps; it does not help [V runtime.grl:2841-2863].

### 1.3 What a task costs

`spawn` allocates a 240-byte record and pushes it on the spawner's Chase-Lev deque (131 072
entries, overflow to a locked 8192-entry injection ring) [V runtime.grl:3655-3677, 3235, 3206].
The stack is made by the first worker to run it: a 1 MiB lazy mapping with a `PROT_NONE` low page,
recycled through a per-worker free list of at most 32 [V runtime.grl:3463-3465,
os-linux.grl:505-547]. Measured: 7.7 us per sequential spawn+join, 2.0 us per task in a 200k burst
[P2]. Take order is own deque (LIFO), injection ring, one steal pass from a random victim
[V runtime.grl:3382-3410].

### 1.4 Stacks and guard pages

| Runs on | Stack | Overflow |
|---|---|---|
| main thread | the process stack (`ulimit -s`) | `error: stack overflow`, exit 134 [P6] |
| green task | 1 MiB, guard page, lazy commit [V os-linux.grl:505-522] | same report, exit 134 [P6] |
| pool job | the pool thread's: 1 MiB cloned region with a guard page in a static program; glibc's own thread stack when libc is loaded [V runtime.grl:2337-2370] | **raw SIGSEGV, exit 139, no report** [P6] - only scheduler workers and main install the fault handler [V os-linux.grl:355-358, 738] |
| offload helper | a fresh 1 MiB region per call | [A] as pool job |

Windows uses fibers (64 KiB committed in 1 MiB reserved); macOS matches Linux
[V docs/design/scheduler.md, not re-verified here].

### 1.5 Foreign calls, blocking calls, locks

- **Foreign call.** Emitted as a direct C-ABI call; the only runtime step is switching the thread
  pointer to the thread's libc TCB [V native.grl:2922-2936]. No stack switch: C called from a task
  runs on that task's 1 MiB stack and occupies its worker until it returns
  [V docs/design/decisions-b2-b6.md:148-155]. `rt_blocking_enter` only prints a one-time warning
  [V runtime.grl:4060-4071].
- **Callback from C.** On a runtime thread it finds the thread's record. On a thread C created it
  adopts one: an `mmap` and a `munmap` per outermost callback [V runtime.grl:2400-2423,
  native.grl:2944]. (`concurrency-v1.md` still says such a callback aborts; the code is newer.
  Not probed.)
- **Runtime blocking call** (`host::read_file`, `write_file`, `command`): from a task,
  `rt_offload` **spawns a new OS thread for that one call** (map 1 MiB, clone, join, unmap) and
  parks the task [V runtime.grl:4083-4133]. [P5: 100 reads take 3 ms in a task, 1 ms on main.]
- **Descriptor I/O and sleep**: non-blocking syscall, then the task parks on epoll or a `timerfd`
  [V runtime.grl:3875-3912, 3921-3945]. On a plain thread (including a pool job) they block it.
- **`Mutex`.** A plain thread uses a futex mutex. A green task **does not park: it loops
  `CAS; rt_yield()`** [V runtime.grl:3592-3610]. Correct, and expensive [P3: eight waiters burn
  3.8 s of user CPU while the holder sleeps 300 ms]. A task may hold a mutex across a wait; the
  holder resumes on any worker.
- **Allocator.** One global spin lock with no back-off once a second thread exists
  [V runtime.grl:941-948]. Every figure in 1.2 and 1.3 includes it. (Being fixed elsewhere.)

### 1.6 Cancellation

Cooperative, per scope: `rt_cancel` sets the scope's flag and wakes tasks whose record says they are
in a cancellable wait [V runtime.grl:3631-3641]. Only `rt_wait_fd` marks itself cancellable
[V runtime.grl:3898-3909]; a sleeping task is not woken and a task blocked in `join` or a mutex is
not either. Jobs have no cancellation at all.

### 1.7 Failure containment

A failing task records the failure and its stack is discarded whole; `try_join` returns
`R |? TaskFailure`, `join` re-raises [V docs/design/task-failure-containment.md] [P7]. A failing
pool job, plain thread or main thread ends the process with exit 134; one thread reports [P7].
Scope exit joins every task, fences the reactor, and frees records [V runtime.grl:3831-3866].

### 1.8 Sharing rules, atomics, fork

`Send`/`Share` are derived structurally and default-denied for foreign handles; `Scope<C>` is
neither, `Mutex<T>` is `Share` when `T` is `Send` [V docs/design/parallelism.md:53-80,
native.grl:9296]. `Atomic<u64>` is the only atomic; it is a heap word, not an inline field
[V runtime.grl:2220-2224]. The compiler already accepts `load_relaxed`, `load_acquire`,
`store_relaxed`, `store_release` beside the sequentially consistent methods
[V native.grl:29994-30033], but `fetch_add`/`swap` are CAS loops [V runtime.grl:2249-2283] and the
acquire load is not lowered on AArch64/RV64 [V runtime.grl:2849-2852]. `host::fork` refuses once
any second thread has started [V runtime.grl:5922-5927]. There are no thread-locals, channels,
condition variables or rwlocks in the language or `lib/` [V: no match for them in compiler/ or lib/].

### 1.9 Probe output

```
P1  start: threads=1
    host::workers()=24 -> threads=26
    task worker_id=1 -> threads=26
    pool job worker_id=0 -> threads=50
    pool jobs submitted from a task: sum of worker_id=0 -> threads=50
P2  pool spawn+wait x200000: 2139 ms = 10695 ns each
    pool::join x200000: 2391 ms = 11955 ns each
    task spawn+join (sequential) x200000: 1544 ms = 7720 ns each
    task spawn burst then join x200000: 403 ms = 2015 ns each
    fib(32) serial 9 ms; nested pool::join cutoff 12 (28656 joins) 271 ms; equal=true
P3  holder sleeps 300 ms inside lock_with, 8 tasks wait for the lock: wall 301 ms
    real 0m0.302s  user 0m3.808s  sys 0m0.628s
P4  workers=24: a 10 ms ticker task beside 24 tasks that each wait for a 300 ms pool job: worst tick gap 307 ms
    workers=2 (taskset -c 0,1): ... worst tick gap 310 ms
P5  100 host::read_file in a task: 3 ms; on the main thread: 1 ms
P6  deep recursion on main: "error: stack overflow", exit 134
    in a pool job: Segmentation fault, exit 139, no message
    in a task: "error: stack overflow", exit 134
P7  task failure contained: index 5 out of bounds for length 1
    then the same failure in a pool job: "error: index 5 out of bounds for length 1", exit 134
P8  24 cpus: 24 spinning tasks 341 ms; 24 spinning pool jobs 347 ms; both at once 587 ms
P9  main worker_id=0 task_scope body worker_id=0
```

## 2. The model

One sentence: **N workers run two kinds of work - jobs, which borrow a stack, and tasks, which
own one - and everything that must be a particular OS thread is a `thread`, which is not a
worker.** Every waiting primitive is built on one parking operation that parks a task if there is
one and blocks the OS thread otherwise. Nothing is coloured: any function may be called from a job,
a task or a thread.

```
            thread (main)      thread (render, pinned)     thread (audio, C-created)
                 |  scopes, channels, executor mailbox  |        | SPSC ring, atomics only
   +-------------v--------------------------------------v--------v------------------+
   | scheduler: N workers, each { job deque x3 classes, task deque x3 classes }     |
   |   take order: own jobs (LIFO) > own tasks > injected > steal jobs > steal tasks|
   |   reactor (epoll/kqueue/IOCP) and timer wheel wake tasks; spare threads cover  |
   |   workers inside `blocking` foreign calls                                      |
   +---------------------------------------------------------------------------------+
```

### 2.1 Jobs

A job is a run-to-completion closure created by a structured call. Its record
`{fn, env, state, link}` lives **in the forking frame** (`join`, loops) or in the scope's bump
block (`scope.spawn`), so spawning allocates nothing. The forker cannot return before the job is
done, which is what makes a frame-held record and borrowed captures sound - the same argument
`chunks_mut` already relies on [V lib/pool.grl:93-109].

Mechanics (replaces `rt_pool_*`):

- `join(a, b)`: push `b`'s record on the current worker's job deque, run `a` inline, pop. If `b`
  is still there (the common case) run it inline: cost is a push, a pop and two calls, no atomics
  beyond the deque's. If it was stolen, **help**: run other jobs until `b`'s state word flips,
  then park.
- A stolen job runs on the thief's *current stack*. Every worker's idle loop runs on a recycled
  task-sized stack with a guard page (the existing free list), not on the bare thread stack, so
  **a job that waits is promoted, not forbidden**: the park switches away from that stack exactly
  as for a task, and the worker takes a fresh one. The non-waiting path pays nothing for this.
  It also gives every job the overflow report tasks have (today: SIGSEGV [P6]).
- A thread that is not a worker (main, render) may fork jobs. It pushes to the injection queue of
  the scope's class and **helps with jobs of its own scope only** - never an unrelated job, the
  reason the pool gives for not helping at all [V runtime.grl:2841-2844].
- A parallel loop is recursive halving down to a grain: `log2(n/grain)` steal-able records, no
  job array, no descriptor allocation. The grain and the split are functions of `n` and `grain`
  only, never of the worker count (2.9).

The known cost of helping: a helper that picks up a job which then *waits* parks the joins beneath
it on the same stack. That is why waiting in a job is legal but discouraged, and why the proof
exists:

```grail
@no_wait                       // checked like @no_alloc: no path reaches a parking runtime entry
fn integrate(bodies: (&mut [Body]), dt: f64) -> unit { ... }
```

`@no_wait` rides on the effect analysis that exists [V docs/design/effects.md]; an indirect call is
"may wait" exactly as it is "may allocate" today. It is a claim on the function that wants it, so
callers are not coloured.

```grail
module pool;   // signatures that stay are unchanged; the implementation moves to the scheduler

pub fn join<A:Send,B:Send>(first: Fn()->A, second: FnMut()->B) -> Pair<A,B>;
pub fn chunks_mut<T:Send>(data: (&mut [T]), grain: u64, f: Fn((&mut [T]))->unit) -> unit;
pub fn range<C:Share>(n: u64, grain: u64, ctx: (&C), f: Fn(u64, u64, (&C))->unit) -> unit; // [lo, hi)
pub fn map<T:Send,U:Send>(items: T[], f: Fn(T)->U) -> U[];
pub fn reduce<C:Share,R:Send>(n: u64, grain: u64, ctx: (&C), zero: R,
                              leaf: Fn(u64, u64, (&C))->R, merge: Fn(R, R)->R) -> R;

// N heterogeneous jobs that may borrow the caller's frame ("the systems of one frame").
pub fn scope<s,C,R>(class: Class, ctx: C, body: Fn((&s Jobs<C>), C)->R) -> R;
impl Jobs<C> { pub fn spawn(self: (&Self), f: Fn()->unit) -> unit; }   // record from the scope's block
pub enum Class { Frame, Normal, Background }
```

`chunks_mut` today takes a chunk *count*; a grain (elements per leaf) is what makes the split
independent of the machine. Whether to rename or add is Q5. `pool::spawn`/`Job<R>` (a handle that
outlives its frame) stays, as a task-like heap record: it is the one job form that allocates.

The typed, checked parallel loop over records (`for x in par data { ... }`, disjointness proved by
the compiler) belongs to the SIMD/layout note; it should lower to `chunks_mut`/`range` here and
needs nothing else from this design. **Depends on:** unboxed records (a `&mut [Body]` chunk is only
cache-efficient if `Body` is stored inline) and the allocator work (`map`'s result vector and any
allocation inside a leaf).

### 2.2 Tasks

Unchanged in shape: `task_scope`, `spawn`, `join`/`try_join`, a 1 MiB guarded lazy stack,
cooperative, migrating between workers at parks. Changes:

- A task that forks jobs **is on a worker**, so it helps instead of sleeping its thread (fixes P4).
- `spawn_with(scope, TaskConfig { stack_bytes, class, name }, ctx, f)` for the task that needs a
  deep stack (a recursive importer, C with large frames).
- Records come from a per-worker slab; a finished stack returns to the free list as today.
  `sched::Config.warm_stacks` pre-maps them so a frame never calls `mmap`.
- Cancellation reaches every wait: the parking operation (2.5) registers the scope's token, so a
  cancelled task wakes from sleep, a channel, a lock or a join with `Cancelled`, not only from
  descriptor waits (1.6). Jobs observe the enclosing scope's token (`pool::cancelled()`); a
  parallel loop checks it between leaves.
- Failure: a job that fails *inside a task* fails that task (the join re-raises into the forker,
  whose task is then contained as today). A job failing with no task above it - forked from a
  thread - fails that thread (2.3). A leaf's siblings finish or observe cancellation; no frame is
  unwound, as now.

### 2.3 Dedicated threads

```grail
module thread;

pub struct Config {
    name: string,                 // shown by the OS (prctl / SetThreadDescription / pthread_setname_np)
    stack_bytes: u64,             // 0: platform default; always guard-paged
    affinity: CpuSet?,            // None: unpinned
    priority: Priority
}
pub enum Priority { Background, Normal, High, Realtime(u8) }   // Realtime: SCHED_FIFO / time-critical / QoS user-interactive

pub fn spawn<R:Send>(cfg: Config, f: FnMut((&Ctx))->R) -> Thread<R>;   // captures moved, must be Send
pub fn join<R:Send>(t: Thread<R>) -> R;                                // re-raises a failure, like task join
pub fn try_join<R:Send>(t: Thread<R>) -> R |? TaskFailure;
pub fn scope<s,C,R>(ctx: C, body: Fn((&s Threads<C>), C)->R) -> R;     // threads that borrow; joined at exit
pub fn with_current<R>(f: Fn((&Ctx))->R) -> R?;                        // None on a worker (task or job)
pub fn sleep_until(deadline: time::Instant) -> unit;                   // absolute OS sleep, for frame pacing
```

- `Thread<R>` is move-only and **its drop joins**, the rule `Job<R>` already has
  [V lib/pool.grl:122-128]. `thread::detach(t)` is the explicit opt-out and requires captures with
  no borrows. The main thread is a thread: `main` may call `thread::with_current`.
- A thread is never a worker: `host::worker_id()` is 0, nothing is stolen onto it, and a wait
  blocks it in the kernel. That is the point - latency on it is the OS's and the program's, not
  the scheduler's.
- A failure on a spawned thread is contained at its top frame like a task's (stack discarded,
  `try_join` returns it). On the main thread it ends the process, as today.
- **Reaching the scheduler from a thread:** open a `task_scope` or `pool::scope` (works today for
  main [P9]; the thread helps with its own jobs, 2.1); send on a channel; or fork-and-wait.
- **Reaching a thread from a task** (the GL context, the window, a thread-affine C library): an
  executor mailbox, which is a bounded channel of closures the thread drains where it chooses.

```grail
pub fn executor(ctx: (&Ctx), capacity: u64) -> Executor;               // Executor: Send + Share
impl Executor {
    pub fn call<R:Send>(self: (&Self), f: Fn((&Ctx))->R) -> R;         // parks the caller until the thread ran f
    pub fn post(self: (&Self), f: Fn((&Ctx))->unit) -> bool;           // false when full; never waits
}
impl Ctx { pub fn run_pending(self: (&Self), budget: u64) -> u64; }    // the thread's side, e.g. once per frame
```

`sched::start(sched::Config { workers, pin_workers, idle_spin_us, warm_stacks, background_cap,
seed })` must run before anything starts the scheduler; later it is an error value. Default
`workers` is the CPU count; a game asks for `cpus - 2` and pins render and audio to the cores left.

### 2.4 Calling C

| Caller | Stack C runs on | If C blocks | C calls back into Grail |
|---|---|---|---|
| thread | the thread's (`Config.stack_bytes`) | only that thread | fine; the callback is on the thread, `Ctx` is reachable |
| task | the task's (1 MiB, or `TaskConfig.stack_bytes`); overflow is the guarded report | undeclared: occupies the worker (B3, with today's warning). `blocking`: worker handoff, below | fine; runs as part of the task, may wait |
| job | whatever stack the job borrowed (a worker stack or its forker's) - same size rule as a task | as task | fine, but a callback that waits promotes the job (2.1) |
| C-created thread (audio callback) | C's | n/a | adopted as a foreign thread: atomics, `try_` channel operations and `Executor.post` only; any parking call blocks C's thread; scopes are refused at run time |

- Cost of an ordinary foreign call stays what it is: a thread-pointer swap, no stack switch
  [V native.grl:2922-2936]. No "always switch to a big stack" tax (Go's cgo); a caller that needs
  depth asks for it once at spawn.
- `extern "C" blocking lib "c" fn fsync(fd: i32) -> i32;` is a property of the *foreign*
  declaration. The call site becomes enter/leave: `enter` marks the worker as blocked and, if its
  deques are non-empty or other workers are parked with work pending, wakes a **spare thread** that
  takes over the worker slot; `leave` re-takes a free slot or, if none, queues the task and the
  thread becomes a spare. Two atomic operations when nothing else is runnable. Spares are cached
  and capped; the same spares replace `rt_offload`'s thread-per-call [V runtime.grl:4119-4133].
- The record a C-created thread adopts is cached per thread instead of mapped and unmapped per
  callback [V runtime.grl:2400-2423]: an audio callback must not call `mmap`.
- A library that is thread-affine is called from a `thread` through an `Executor`; `handle`
  declarations without `transferable` already keep its values off workers
  [V lib/pool.grl:13-22].

### 2.5 Coordination

One runtime operation underlies all of it: **park the current execution on a wait node**. The
node `{who, next, token}` is in the waiter's frame (no allocation). `who` is a task - parked with
the existing `rt_suspend`/`rt_wake` protocol, which already tolerates wake-before-park
[V runtime.grl:3536-3577] - or a thread record, parked on its own futex word. A waker never needs
to know which. Lists are guarded by a word lock held for a few instructions.

| Primitive | API (module `sync` / `chan`) | Task (or job) that must wait | Thread that must wait |
|---|---|---|---|
| `Mutex<T>` | `lock_with(ctx, f)` (unchanged), `try_lock_with` | brief spin, then parks; unlock hands off to the first waiter. Replaces spin-yield [P3] | brief spin, futex |
| `RwLock<T>` | `read_with(ctx, f)`, `write_with(ctx, f)` | parks; writer-preferring so a frame's writer is not starved | futex |
| `Condition` | `wait_with(&mutex, ctx, ready: Fn((&T), C)->bool, then: Fn((&mut T), C)->R) -> R`; `notify_one`, `notify_all` | parks with the mutex released, re-acquires, re-tests `ready` | futex |
| `Once<T>` | `get_or_init(f: Fn()->T) -> (&T)` | parks until the initialiser finishes | futex |
| `Latch` | `Latch::new(n)`, `count_down()`, `wait()` | parks until zero | futex |
| `Barrier` | `Barrier::new(n)`, `wait() -> bool` (true for one leader) | parks until `n` arrive | futex |
| `Semaphore` | `acquire_with(n, ctx, f)`, `try_acquire(n) -> Permit?` | parks FIFO | futex |
| `chan::bounded<T>(cap)` | `send(v) -> bool`, `recv() -> T?`, `try_send`, `try_recv`, `recv_until(deadline)`; `Sender<T>` clonable, closes when the last one drops | sender parks when full, receiver when empty | futex |
| `chan::spsc<T>(cap)` | `try_send(v) -> T?` (gives the value back when full), `try_recv() -> T?`; optional `recv()` | wait-free; `recv()` parks | wait-free; `recv()` futex |

- Guards stay callback-scoped, as `lock_with` is today: a guard value that could be held across
  a migration is the worker-affine-guard problem `concurrency-v1.md` leaves open; a callback makes
  it unrepresentable. `Condition` follows the same shape, which also removes the "forgot to re-test
  the predicate" bug.
- Channels allocate once, at creation. A `bounded(0)` channel is a rendezvous. A task's result is
  already the one-shot channel (`Task<R>`, `Job<R>`, `Thread<R>`), so there is no separate oneshot.
- Every parking wait takes the enclosing scope's cancel token and has an `_until(deadline)` form.
- Holding a mutex while waiting is allowed and no longer burns CPU; `@no_wait` on the callback is
  the way to forbid it where it matters.

### 2.6 Atomics

- Family: `Atomic<T>` for `u8 u16 u32 u64 i8 i16 i32 i64 bool` and plain C-like enums of at most 8
  bytes. No atomic references or pointers in safe code. **Depends on unboxed records** for the
  part that matters: an `Atomic` should be an inline field, not today's heap word
  [V runtime.grl:2220-2224]; `CachePadded<T>` depends on the layout note.
- Orderings are exposed as names: `load`, `load_relaxed`, `load_acquire`; `store`,
  `store_relaxed`, `store_release`; `swap`, `fetch_add/sub/and/or/xor/min/max` each with
  `_relaxed`; `compare_exchange(expected, new) -> T` (strong, returns the observed value, as now)
  and `compare_exchange_weak`, each with `_acqrel` and `_relaxed`. An invalid pair (a release
  load) has no name. Unsuffixed is sequentially consistent, so the short spelling is the safe one.
- Implementation debts found while reading: `fetch_add`/`swap` are CAS loops and should be
  `lock xadd`/`xchg` (LSE/`amoadd` elsewhere); weak orderings are not lowered off x86, where the
  honest answer until they are is to map them to the strong form [V runtime.grl:2249-2283, 2849].
- `sync::spin_hint()` (`pause`/`yield`).

### 2.7 Locals

- **Thread-local**: `thread::Local<T>`, declared at module level, read with
  `local.with(ctx: (&thread::Ctx), f: Fn((&mut T))->R) -> R`. **The compile-time rule is the type
  of `Ctx`: neither `Send` nor `Share`.** A task or job closure must have `Send` captures
  (already enforced [V docs/design/parallelism.md:53-80]), so it cannot capture a `Ctx`; a `Ctx`
  only comes from a thread's entry argument or `thread::with_current`, which returns `None` on a
  worker. No code that can migrate can name the value it needs to read a thread-local. C's own
  `__thread` data is behind the TCB switch and unaffected.
- **Worker-local** (per-worker scratch arenas, counters): `pool::WorkerLocal<T>` with
  `with(f: Fn((&mut T))->R) -> R`. The borrow cannot escape the callback (compile time); parking
  inside the callback is `error: wait inside worker_local` (a per-worker depth counter, run time)
  and is provable absent with `@no_wait`. Stated plainly: this half of the rule is a run-time
  check unless the callback carries the proof.
- **Task-local**: none (D6). The scope context is the explicit form
  [V runtime.grl:3615-3620, book/chapters/concurrency.md].

### 2.8 `Send`, `Share`, scopes and borrows

| Construct | Closure captures | May borrow the caller's frame | Result | Handle |
|---|---|---|---|---|
| `join`, loops, `pool::scope` jobs | `Send`; shared context `Share`; `first` is `Fn`, the inline branch `FnMut` | yes - the call does not return first | `Send`, owned | none |
| `pool::spawn` -> `Job<R>` | `Send`, no borrows | no | `Send`, owned | move-only, drop waits |
| task in `task_scope` | `Send`; context `Share` or moved | only what outlives the scope (`&s`) | `Send` | `Task<R>`, scope exit joins |
| `thread::spawn` -> `Thread<R>` | `Send`, no borrows | no | `Send` | move-only, drop joins |
| thread in `thread::scope` | `Send` | what outlives the scope | `Send` | scope exit joins |
| `Sender<T>`/`Receiver<T>` | `T: Send`; endpoints `Send`; `Sender` also `Share` | - | - | close on last drop |
| `Mutex<T>`, `RwLock<T>` | `Share` when `T: Send` (`RwLock` readers need `T: Share`) | - | - | - |
| `thread::Ctx`, `Jobs<C>`, `Scope<C>` | neither `Send` nor `Share` | - | - | - |

Structured is the default everywhere: every spawn form either cannot return before its work ends
or yields a handle whose drop waits. The only detach is `thread::detach`, and it is spelled.

### 2.9 Frame loops: determinism and latency

- **Deterministic results.** Loop splits depend on `(n, grain)` only and results are combined in
  index order, so `reduce` over floats is bit-identical on 4 and 64 cores. (`parallel_map` today
  sizes chunks from the worker count [V runtime.grl:2914]; harmless for `map`, wrong for a
  reduction.) Scheduling order is not deterministic and is not promised; `sched::Config.seed`
  fixes the steal victims and `workers: 1` gives a reproducible interleaving for tests.
- **Priorities.** `Frame` work is taken before `Normal`, `Normal` before `Background`, on every
  worker; at most `background_cap` workers run `Background` at once, so an asset import cannot
  occupy the machine when the next frame's jobs arrive (the starvation
  `book/chapters/concurrency.md` admits today). A job inherits its scope's class. No priority
  inheritance: `Frame` code must not take a lock `Background` code holds across a wait, and
  `@no_wait` on the background callback proves it.
- **Fairness.** Owner LIFO, thief FIFO, as now. Every 61st take checks the injection queue first so
  a self-feeding worker cannot starve injected work. No preemption: a compute loop that must not
  hog a worker is a parallel loop, which splits.
- **Wake latency.** A parked worker costs a futex round trip to wake. `idle_spin_us` lets workers
  spin briefly before parking, the standard job-system trade of CPU for frame-time variance.
  `pin_workers` removes migration by the OS.
- **No hidden allocation** on the frame path: job records in frames or the scope block, wait nodes
  in frames, channels pre-sized, stacks warmed. Task `spawn` is one slab record. `@no_alloc`
  already proves the rest per function.
- **Timers.** A task sleep is a `timerfd` per sleep [V os-linux.grl:463-483]; frame pacing uses
  `thread::sleep_until` on the thread that owns the frame. A timer wheel in the reactor replaces
  the per-sleep descriptor (stage 6).

## 3. Comparisons that changed a decision

- **Rust `std::thread::scope` + rayon + crossbeam.** Rayon's `join` with a stack-held job is the
  model for 2.1; it is why a join can cost nanoseconds rather than today's 12 us. Rayon's flaw is
  that it is a *separate* pool from the async runtime - exactly Grail's current state - and
  blocking inside it deadlocks or stalls; hence one scheduler and promotion on wait. Crossbeam's
  split into bounded MPMC and SPSC is adopted; its unbounded channel is not.
- **Tokio.** Its costs are colouring, a heap-allocated future per task, and `spawn_blocking` as a
  second pool. Stackful tasks avoid the first two; the worker handoff avoids the third. What it
  gets right and is copied: every wait is cancellable and has a deadline.
- **Go.** Syscall handoff (D9) and the 61-tick fairness check are Go's. Not copied: cgo's stack
  switch on every foreign call, growable stacks (they need precise stack maps and forbid interior
  pointers into stacks), unstructured `go`, unbounded-by-default patterns, signal preemption.
- **Zig.** Removed its async and is rebuilding I/O as an interface passed explicitly. The lesson
  taken is the negative one: do not put suspension in the type system. Grail's stackful tasks
  already give direct-style code without it.
- **C++ job systems and fiber engines** (enkiTS, Unreal's task graph, Naughty Dog's fibers). They
  confirm the split in D3: a small set of named pinned threads beside a job pool, priority classes,
  spin-before-park. Naughty Dog runs *every* job on a fiber so any job may wait; 2.1 gets the same
  property lazily, paying for a stack only when a job actually waits.

## 4. Alternatives rejected

| Alternative | Why not |
|---|---|
| Keep two thread sets, add a bridge (task waits for pool job by parking) | Fixes P4 only. Still 2N threads, two queues the priorities cannot span, two sets of code. |
| Every job gets a task stack (jobs are tasks) | 240-byte record, stack acquisition and two context switches per job; nested `join` cannot be cheap. P2 shows task spawn+join at 7.7 us. |
| Forbid waiting in jobs by a compile-time effect on all code | That is function colouring by inference: a library function that locks could not be called from a loop body. Opt-in `@no_wait` gives the proof to those who need it. |
| async/await, or stackless coroutines under the hood | Excluded by the brief; also needs state-machine lowering and pinning rules the compiler does not have. |
| Thread-per-task as the answer for blocking (keep `GRAIL_TASKS=thread`) | A second semantics without `Send` checking [V runtime.grl:3099-3106]; explicit threads cover the legitimate use. |
| An `Ordering` enum argument on atomics | Admits invalid combinations and a run-time or compile-time check for them; suffixes make them unspellable and are half built. |
| Unbounded channels by default | Allocation on send under the global allocator and no backpressure; a slow consumer becomes a memory leak mid-frame. |
| `MutexGuard` values (Rust style) | A guard held across a park migrates between workers; the callback form already prevents it and is what `lib/` uses. |
| Ambient task-locals inherited at spawn | Hidden data flow and a per-spawn copy; the scope context is explicit and already there. |
| Preempting compute tasks with signals | Unsafe points everywhere in a runtime with no stack maps; breaks foreign code; jobs are meant to be short. |
| Growable or segmented stacks | Need relocation of frames or hot-split checks; 1 MiB lazy reservations cost only address space. |

## 5. Staged plan

Ordered by what an engine needs first. Each stage ships alone and leaves the corpus green.

**The benchmark all stages report** (`bench/frame.grl`, added in stage 1): 600 frames; each frame
runs 32 systems as jobs in a `Frame` scope (a third of them fork a parallel-for), one parallel-for
over 1M elements (`chunks_mut`, grain 4096), an I/O task that reads a file and sends the bytes
over a channel every 10th frame, a background task importing "assets" (compute plus allocation)
throughout, and a pinned render thread that receives a per-frame command buffer over an SPSC ring
and replies with a latch. Reported: frame time median, p99 and max; allocations per frame; thread
count; CPU seconds. Until a stage provides a piece, the benchmark uses what exists (main for
render, `pool::run` for systems) so the trend is one series. Micro-benchmarks: `fib(32)` by nested
join (today 271 ms against 9 ms serial [P2]), spawn+join, mutex handoff, channel throughput.

| Stage | Ships | Files | Risks | Corpus cases | Gate on the benchmark |
|---|---|---|---|---|---|
| 1. One scheduler | Jobs on scheduler workers, frame-held records, help-on-wait, promotion on park, non-worker helping; `rt_pool_*` threads deleted; overflow report for jobs | `compiler/runtime.grl`, `os-linux.grl`, `os-windows.grl`, `darwin.grl`, `native.grl` (lowering of `parallel_map`/`parallel_for_chunks`/`parallel_spawn`), `lib/pool.grl`, `docs/design/scheduler.md`, `parallelism.md` | Windows fibers: a worker's idle loop must itself be a fiber; record lifetime when a forker fails mid-join (must still wait for stolen children before its stack is discarded); `GRAIL_POOL_WORKERS` tests | `job-in-task-does-not-block-worker` (P4 as a test: tick gap under 50 ms), `job-wait-promotes`, `job-stack-overflow-reports-134`, `join-nested-fib`, `threads-equal-cpus-plus-reactor`, existing `tests/pool/*` unchanged | threads = CPUs + 2; `fib(32)` join under 3x serial on one worker; frame p99 no worse |
| 2. Threads | `lib/thread.grl`: spawn/join/try_join/scope/detach, `Config`, `Ctx`, `with_current`, `sleep_until`; `sched::start`; `thread::Local`; `GRAIL_TASKS=thread` removed (D10) | `runtime.grl` (public surface over `rt_thread_start`, stack size, name, affinity, priority), the three OS modules, `native.grl` (`Thread<R>` kind and its `Send`/`Share` rows, `Ctx` not transferable), `lib/thread.grl`, book chapter | priority and affinity need privileges or differ per OS (macOS has QoS, no hard affinity): each setter returns a result, never aborts; libc-loaded processes must create through the glibc bridge with attributes | `thread-join-result`, `thread-drop-joins`, `thread-scope-borrows`, `thread-ctx-not-sendable` (compile error), `thread-local-per-thread`, `thread-failure-is-value`, `thread-stack-size-honoured`, `sched-start-twice-is-error` | render moves to a pinned thread; frame max improves or holds |
| 3. Parking and `sync` | Wait nodes; `Mutex` parks; `Condition`, `Latch`, `Barrier`, `Semaphore`, `Once`, `RwLock`; cancellable, deadline-able waits | `runtime.grl` (park/unpark, mutex), `native.grl` (builtin kinds or plain library types - Q4), `lib/sync.grl`, `lib/concurrent_map.grl` (may move to `RwLock`) | lost-wakeup and ABA bugs in the wait list; mutex handoff fairness against throughput (allow barging after a short spin) | `mutex-waiters-park` (P3 as a test: user CPU under 2x wall), `condition-ping-pong`, `rwlock-readers-overlap`, `once-runs-once-under-race`, `latch-many-waiters`, `wait-cancelled-by-scope`, `wait-deadline` | mutex handoff under 1 us uncontended-to-contended; CPU seconds drop |
| 4. Channels and executor | `chan::bounded`, `chan::spsc`, `thread::Executor` | `lib/chan.grl`, `lib/thread.grl`, small runtime help for the SPSC cache-line layout | SPSC needs inline atomics and padding to be wait-free in practice - **depends on unboxed records / layout**; until then it works through heap words and is slower | `chan-bounded-backpressure`, `chan-close-on-last-sender`, `chan-mpmc-checksum`, `spsc-order-and-count`, `executor-call-from-task`, `chan-send-non-send-refused` (compile error) | render command stream on SPSC; zero allocations per frame on that path |
| 5. Classes and latency | `Frame`/`Normal`/`Background` deques, `background_cap`, `idle_spin_us`, `pin_workers`, `warm_stacks`, `seed`, 61-tick fairness, `(n, grain)` splits, `reduce` | `runtime.grl`, `lib/pool.grl`, `lib/sched.grl` | three deques per worker triples steal scans; starvation of `Background` must be bounded (age promotion or guaranteed share - Q3) | `frame-not-starved-by-background`, `reduce-bit-identical-across-worker-counts`, `seeded-run-reproduces`, `injected-work-not-starved` | frame p99 with the background importer within 10% of without |
| 6. Blocking and foreign | `extern "C" blocking`, worker handoff with cached spares, spares replace thread-per-offload, cached adopted records for C threads, timer wheel, `@no_wait` | `native.grl` (extern attribute, effect), `runtime.grl`, OS modules, `docs/ffi.md`, `decisions-b2-b6.md` (B3 amended) | handoff races (a returning thread and its replacement both own the slot); spare-thread cap behaviour under a storm; `@no_wait` precision through closures | `blocking-ffi-does-not-stall-tasks` (the existing `tests/concurrency/blocking_call.grl` inverted), `offload-reuses-threads`, `c-thread-callback-no-mmap`, `no-wait-refuses-lock`, `audio-callback-spsc` | I/O task latency flat while 24 tasks sit in `blocking` calls; P5 ratio near 1 |
| 7. Atomics | The `Atomic<T>` family, the ordering suffixes on every target, native `xadd`/`xchg` | `native.grl`, back ends, `runtime.grl` | **blocked on unboxed records** for inline atomics; weak orderings need per-target lowering and a litmus test each | `atomic-family-widths`, `atomic-wrap-is-modular`, `atomic-orderings-litmus` (store buffering, message passing), `atomic-inline-field-size` | fetch_add throughput; no frame gate |

Stages 1-3 are the engine minimum. Stage 4's SPSC and stage 7 wait on the unboxed-records note;
everything is faster after the allocator work but nothing waits for it.

## 6. Open questions

- **Q1.** Does a job failure inside a `pool::scope` with several spawned jobs cancel the siblings,
  or let them finish? Tasks let siblings run (failure is not cancellation). Recommended: same rule,
  first failure re-raised at scope exit.
- **Q2.** `select` over several channels. Needed eventually (a task waiting on "a message or a
  timer or cancellation"); deadlines and cancel tokens cover the common two. A general `select`
  wants either a builtin statement or a variadic-free API (`chan::select2`, `select3`); which?
- **Q3.** `Background` under sustained `Frame` load: strict priority starves it. Guaranteed share
  (one worker), or age promotion?
- **Q4.** Are `RwLock`, `Condition`, `Latch`, channels compiler builtins like `Mutex`
  (kind 13) or library types over an unsafe core? Library is smaller and is what `rc.grl` does, but
  the callback-scoped borrow of the payload must be expressible to the checker without a builtin.
- **Q5.** `chunks_mut(data, chunks, f)` takes a count today. Change the meaning to a grain
  (breaking, deterministic), or add `chunks_mut_by(data, grain, f)` and keep both?
- **Q6.** Should `thread::spawn` in a process that loaded libc refuse a `stack_bytes` glibc
  cannot honour, or fall back silently? (Recommended: return the error.)
- **Q7.** Is `host::fork` after the scheduler started worth supporting (fork then exec only)? It
  refuses today [V runtime.grl:5922-5927]; `process::spawn` covers exec. Recommended: keep refusing.
- **Q8.** The one-reporter abort rule exits 134 from workers without raising `SIGABRT`
  [V docs/design/scheduler.md]. With user threads, which side is a `thread`: raises (like main) or
  exits? Recommended: contained like a task, so neither.
- **Q9.** Not verified here: Windows and macOS behaviour (read from `scheduler.md` only), the
  libc-loaded stack sizes of runtime threads, and whether a C-created thread's callback works
  today as `runtime.grl:2400-2423` describes (`concurrency-v1.md` says it aborts).
