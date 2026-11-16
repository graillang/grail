# The M:N scheduler: tasks and jobs on one set of workers

This is the mechanism behind `spawn`, `task_scope`, `host::sleep_ms`, the readiness waits in
`host::read_fd`/`write_fd`, and every parallel call (`parallel_map`, `parallel_for_chunks`,
`pool::join`, job handles) on every platform. The user-visible contract is
[concurrency-v1.md](concurrency-v1.md); this file states what implements it, why the pieces are
shaped the way they are, and what is verified where.

## Workers and deques

A process has one scheduler worker per CPU (`rt_os_workers`, floor two, ceiling 64). The floor is
not an optimisation: a cooperative task that spins waiting for a sibling needs a sibling *thread*
to run on, and the `meet` regression fixture does exactly that. `GRAIL_WORKERS=n` (1 to 64) sets
the count and is honoured as given; a test that needs four threads at once asks for them. These are
the only compute threads: there is no separate job pool. Thread-per-task mode (`GRAIL_TASKS=thread`)
starts the workers only when the first job is forked, because jobs are all they run there.

Each worker owns a **Chase-Lev deque** (`rt_deque_push/pop/steal`): the owner pushes and pops at the
bottom (the tail) and a thief steals at the top (the head) with a CAS. The owner's tail store is the
release that publishes the slot; the thief's CAS is what claims it, and a lost CAS means another
worker has the task. Chains of tasks are therefore LIFO for the worker that spawned them, which is
what makes a fork-join recursion run its children depth-first, and FIFO for thieves, which is what
spreads a burst.

The buffer is fixed at 131072 entries. That is deliberate: a growing Chase-Lev needs memory
reclamation for the old buffer (a thief may still be reading it), and a fixed buffer needs none.
A push that does not fit spills to the shared **injection ring**, which is also where a spawn or a
wake from a thread that is not a worker goes - the main thread, the reactor, an offload helper - and
so is the wake that a join, a channel or a reactor event produces from outside a worker. The ring is
a lock-protected ring of 8192 entries; when even that is full the pusher yields and re-tries, which
cannot deadlock because the other workers drain it.

Each worker has a second deque of the same kind for **jobs** (8192 entries), and there is a second
injection ring for jobs forked by a thread that is not a worker. A worker takes work in this order:
its own jobs, its own tasks, injected jobs, injected tasks, one steal pass for jobs and one for
tasks, each starting at a random victim (a per-worker xorshift). Only then does it park. Its own
jobs come first because some stack is inside a join waiting for them.

## Parking and waking

Every worker parks on one 64-bit sequence word in the scheduler block, with the platform's address
wait: `FUTEX_WAIT`/`FUTEX_WAKE` on Linux, `WaitOnAddress`/`WakeByAddressSingle` on Windows, and
`__ulock_wait`/`__ulock_wake` on macOS - all through runtime operation 202, so the portable code
never knows which.

The protocol has no lost wakeups:

1. The worker reads the sequence, then looks for work (`rt_worker_loop`; the read used to come
   after the look, which left a window in which a push went unnoticed until the next one).
2. If it finds none it publishes itself as parked and waits on the sequence with the value it read.
3. A pusher bumps the sequence *unconditionally* and wakes one waiter if one is parked.

A push that lands between the read and the wait changes the value the waiter is waiting on, so the
wait returns immediately; a push after the wait starts sees the parked count and wakes a thread. A
woken worker that still finds work notifies another, which is how a spawn burst reaches every worker
without a wake per task.

A finished task wakes its joiner onto the *waker's* deque, so a `join` in a task on worker B pushes
the joiner onto B's deque and the next pop is cheap. Wakeups that come from the reactor or an
offload thread go through the injection ring, because those threads have no deque.

## Jobs

A job is run-to-completion work forked by a structured call: a leaf range of `parallel_map` or
`parallel_for_chunks`, the first branch of `pool::join` (`parallel_with`), a `Job<R>` handle. It is
a 64-byte record - function, three arguments, state, result - and nothing else: no thread and no
stack of its own.

**Records are type-stable.** They are carved from mapped pages that are never unmapped and recycled
through free lists (one per worker, touched only by the thread running on that worker, plus a
locked list for threads that are not workers), so forking calls no allocator. A record is released
only by its forker, after it has seen the job done.

**A queue entry is a hint; the claim is a CAS.** The only way to run a job is to win
`CAS(state, pending -> claimed)` on its record. So:

- the forker can always take its own job back by pointer, wherever its entry went - which is how
  an unstolen fork is run inline at the join, how a forker whose task migrated still finishes, and
  the whole of "a thread that is not a worker helps with its own scope only" (it claims by pointer
  and never takes an entry from a queue);
- an entry that outlives its job is harmless: it names a record that is free, running, done, or
  pending again as a later job - and in that last case claiming it runs that later job exactly once,
  which is what its forker is waiting for.

**Loops split by halving.** A parallel call forks the upper half of its leaves as one job and
descends into the lower half, joining on the way back; the leaf boundaries are a function of the
element count and the requested chunks, never of who ran what.

**Joining.** A forker that reaches its join pops its own job deque (the fork is there unless it was
stolen), else claims by pointer, else the job is running elsewhere: on a worker it *helps* - runs an
injected job or one stolen from another worker - and when there is nothing to help with it parks
(a task parks as a task; a plain thread sleeps on the record's state word). Help nests on the
waiter's stack; each worker records the deepest nesting it saw, and `GRAIL_SCHED_STATS=1` prints
the maximum at exit.

**Runners.** A worker does not run a job on its scheduler stack. It enters its *runner*, a green
task whose body claims the handed job, drains the worker's job deque and goes idle. Inside a job
there is therefore always a current task, so a job that waits - a sleep, a descriptor, a join, an
offloaded call - parks exactly as a task does: the worker sees its runner leave without being
idle, forgets it, and makes a fresh runner for its next job, while the parked one is resumed by any
worker like any task, finishes its job and ends. A job that never waits pays for none of this. A
runner's stack is a task stack, so a job that overflows it gets the task's report (it was an
unexplained SIGSEGV on a pool thread).

**Failure.** A failed check inside a parallel region - in a job, or in a task that still has forks
outstanding - ends the process (status 134, one report), as a pool job's failure always did.
Containing it needs the failing stack kept alive until every stolen child that borrows its frames
has finished; that is follow-up F1 in `concurrency-model.md`.

**A hazard that comes with helping.** A stack that holds a `Mutex` across a join may, while
waiting, pick up a job that wants the same mutex; that job then waits for a lock its own stack
holds. Do not fork while holding a lock.

## Stacks

A green task's stack is not created at spawn. `spawn` allocates the record and the queue slot, and
the first worker to run the task creates the stack (`rt_worker_run` calls `rt_os_ctx_new` when word
0 is still zero). A 100k-task spawn burst therefore costs records and queue slots, not 100k stack
mappings, and only the tasks that actually run hold a stack.

On Linux and macOS a stack is a 1 MiB anonymous mapping whose lowest page is `mprotect`ed
`PROT_NONE`:

- `mmap` (through `raw_map`) is lazy, so the kernel commits pages as the task touches them and a
  task that uses 20 KiB costs five pages of physical memory;
- the guard page turns an overflow into a fault instead of a write into whatever mapping sits
  below the stack;
- a finished stack goes on the finishing worker's free list (link in the *top* word, never the
  guard page) and is reused up to 32 per worker, so a spawn/wake storm does not pay an `mmap` and an
  `mprotect` per task.

On Windows the stack is the fiber's: `CreateFiberEx(64 KiB committed, 1 MiB reserved)` has the OS
commit on demand and grow through its own guard pages, which is exactly the "commit with a
`PAGE_GUARD` page" behaviour a thread stack has. A fiber cannot be reinitialised, so `DeleteFiber`
releases it rather than recycling it.

### Stack overflow

The low guard page is the detection point. The fault is handled by the platform's fault hook and
reported through `rt_stack_overflow`, which writes `error: stack overflow` and exits 134 through the
same one-reporter claim a failed runtime check uses (below).

- Linux: `SIGSEGV` (and `SIGBUS`) with `SA_SIGINFO|SA_ONSTACK` on a per-worker `sigaltstack`, so the
  handler has 64 KiB of stack that is not the exhausted one. The handler checks that `si_addr` lies
  in the running task's guard page; anything else restores `SIG_DFL` and dies as before. x86-64
  installs an `SA_RESTORER` trampoline (`rt_sigreturn`); the other ELF targets use the generic
  `rt_sigaction` table (134/132), which the platform module maps for them. The **main thread** takes
  the same handler and its own alternate stack at startup, and recognises its overflow by the fault
  address being within a window of the interrupted stack pointer instead of by a guard page it does
  not have (`docs/design/main-stack-overflow.md`).
- macOS: the same shape with Darwin's `struct sigaction`/`stack_t` layouts, `SIGSEGV` = 11 and
  `SIGBUS` = 10, and `si_addr` at offset 24 of Darwin's `siginfo_t`.
- Windows: `AddVectoredExceptionHandler` on `STATUS_STACK_OVERFLOW` (0xC00000FD); any other code
  returns `EXCEPTION_CONTINUE_SEARCH`. Wine cannot set up an exception frame on an exhausted fiber
  stack, so that case is verified statically in `windows.mjs check` and executed on a real Windows
  host; the Linux/macOS path is executed by `task-stack-overflow-reports-and-exits-134`.

## Reactors

The portable scheduler owns task states; the platform module owns the descriptors. The hooks are
`rt_os_reactor_open`, `rt_os_reactor_loop`, `rt_os_reactor_fence`, `rt_os_ready`,
`rt_os_wait_fd`/`rt_os_wait_done`, `rt_os_timer`/`rt_os_timer_done` and `rt_os_complete`.

`rt_os_ready` is separate from "has a reactor" on purpose: Windows has a reactor (a completion port)
but no descriptor readiness, so `rt_wait_fd` reports ready there and `rt_io` keeps handing blocking
operations to an offload thread. A reactor that cannot be created is **not fatal** - the scheduler
runs without it and the operations that wanted it fall back to offload. That is the fix for the
original Windows bug, where the portable scheduler asked for epoll, got a syscall error, and aborted
the process (status 134 with no output).

- **Linux** - epoll, an `eventfd` for the fence, `timerfd` per sleep. Every registration is
  `EPOLLONESHOT` and carries the task pointer in its data word; the reactor thread wakes that task.
- **Windows** - one I/O completion port created with one thread per worker. The reactor thread
  blocks in `GetQueuedCompletionStatus`; a completion key is the task to wake, 0 is the fence and 1
  says the timer heap changed. A helper thread that finished a blocking operation posts its task to
  the port (`rt_os_complete`) instead of waking it directly. Sleeps live on a small timer heap in
  the scheduler block; the reactor waits for at most the time until the earliest deadline and fires
  what is due, so `host::sleep_ms` has no timer fd and no helper thread.
- **macOS** - kqueue: `EVFILT_READ`/`EVFILT_WRITE` one-shots with the task in `udata`,
  `EVFILT_TIMER` one-shots for sleeps, and an `EVFILT_USER` event (ident 1, `NOTE_TRIGGER`) for the
  fence.

`rt_reactor_fence` asks the reactor to complete a batch and waits for the batch epoch to advance.
Task-scope exit uses it so a cancelled task whose event was already read cannot be freed while the
reactor still holds its pointer.

## One reporter per failure

`rt_abort` and `rt_fail` claim one atomic word in process state. The first failing thread reports
and exits; every other failing thread parks on that word forever and is ended by the reporter's
`exit_group`/`TerminateProcess`. Two parallel chunks writing one past their own slice used to print
two messages and race their own `SIGABRT` against the exit, which sometimes killed the process by
signal instead of exiting 134.

A scheduler worker does not raise `SIGABRT` at all, and neither does any other thread while it is
inside a parallel region (it runs leaves beside the workers): it exits 134 directly. A signal sent to a multi-threaded process is delivered to whichever thread the kernel
picks - often a parked sibling returning to user space - so raising it from one of several threads
that may fail together is exactly the race above. The main thread, an offload helper and a thread
foreign code created keep `SIGABRT`, which is what a parent process observes for an ordinary abort.

## What programs can see

`host::worker_id()` returns the worker running the call, numbered from 1, or 0 off a worker;
`host::workers()` returns the worker count (0 in thread-per-task mode). They exist for tests that
have to prove work actually spreads - `task-fib-spreads-across-workers` records the id of every task
and asserts more than one was seen whenever there is more than one worker - and they are cheap
enough for user code to use for its own accounting.

## Verified

| What | Where |
| --- | --- |
| 100k spawn/join burst, checksum | `task-100k-spawn-join-checksum` (x86-64, aarch64, riscv64) |
| work spreads across workers | `task-fib-spreads-across-workers` (start barrier forces two workers) |
| deque push/pop/steal race | `task-steal-stress-tree` (2048 stolen leaves, checksummed) |
| timers, sleep overlap | `task-sleep-timers-overlap`, `tasks-sleep-overlap` (Windows) |
| stack overflow report + status 134 | `task-stack-overflow-reports-and-exits-134`; Windows case static |
| one report per race of failures | `pool-abort-eight-chunks-reports-once`, `pool-chunk-write-outside-aborts` |
| nested joins under steal, from a thread and from tasks | `sched-nested-join-under-steal` (x86-64, aarch64, riscv64) |
| tasks fork jobs while timers tick | `sched-task-forks-jobs-while-timers-tick` |
| a job that waits holds no worker | `sched-job-wait-does-not-hold-a-worker` |
| a job's stack overflow is reported | `sched-job-stack-overflow-reports-and-exits-134` |
| nested parallel work with one worker | `pool-nested-one-worker` (`GRAIL_WORKERS=1`) |
| Windows fibers across workers, completion port, timers | `windows.mjs check` (Wine: 42 executed) |
| macOS kqueue/ulock/guard pages | static: both Mach-O targets assemble and link (`bun tools/test-macos.mjs` is blocked by a pre-existing assembler failure, see the note there) |
