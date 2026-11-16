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
| D10 | `GRAIL_TASKS=thread` mode | **Remove once `thread::spawn` ships.** It is a second semantics with no `Send` check [V runtime.grl:3098-3104]; explicit threads replace its one use. |
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
  (`rt_current() == 0`): it blocks its pool thread [V runtime.grl:3703-3705, 3925-3930].
- With both busy the process runs 2N compute threads on N CPUs. Throughput survives - the kernel
  time-slices them [P8: 587 ms for both at once against 341 + 347 ms apart] - but which work runs
  is decided by the kernel, not by Grail, which is what a frame loop cannot have.

### 1.2 What a job costs

| Operation | Allocations (global allocator, one spin lock [V runtime.grl:941-948]) | Measured |
|---|---|---|
| `pool::spawn` + `wait` | job record 48 B, closure box 8 B, environment [V runtime.grl:2817, 3039-3047] | 10.7 us [P2] |
| `pool::join(a, b)` | a one-element vector, result vector, descriptor 56 B, job array, job record [V lib/pool.grl:114-119, runtime.grl:2900-2931] | 12.0 us [P2] |
| `chunks_mut`, k chunks | descriptor, job array, then per chunk a job record and a 24-byte slice descriptor [V runtime.grl:2973, 3003-3013] | - |
| nested `join` recursion | as `join`, per level | `fib(32)`: 9 ms serial, **271 ms** with 28 656 joins on 24 CPUs [P2] |

A job has no stack of its own: it runs on its pool worker's thread stack, or - when a waiting
worker helps - on top of the waiter's frames [V runtime.grl:2853-2858]. Pool deques are
spin-locked rings of 1008 entries; a full ring runs the job inline [V runtime.grl:2732-2745,
2829-2837]. Every submit does a `futex` wake-all on the pool word [V runtime.grl:2838-2840].
A non-worker that waits only sleeps; it does not help [V runtime.grl:2841-2863].

### 1.3 What a task costs

`spawn` allocates a 240-byte record and pushes it on the spawner's Chase-Lev deque (131 072
entries, overflow to a locked 8192-entry injection ring) [V runtime.grl:3655-3677, 3235, 3210].
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
