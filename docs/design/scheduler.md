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

The head lives a line away from the tail, the buffer and the mask (`rt_deque_head`, deque + 1024),
and the owner keeps the head it read last beside it: a push reads the shared head only when that
bound says full. On one line, every steal's CAS cost a burst's pusher a miss per push.

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

A parked worker sleeps on its own **wake word** (worker block word 384) with the platform's address
wait: `FUTEX_WAIT`/`FUTEX_WAKE` on Linux, `WaitOnAddress`/`WakeByAddressSingle` on Windows, and
`__ulock_wait`/`__ulock_wake` on macOS - all through runtime operation 202, so the portable code
never knows which. The parked workers are an **idle list**: a bit mask in the scheduler block (word
272, bit i for worker i - there are at most 64), guarded by a small lock (word 264) that is taken
only when a worker parks, leaves the list, or is taken off it by a waker. Beside them, on the same
line, is the **idle word** (256): parked workers in the high half - always the number of bits in the
mask - and searching workers in the low half. A push reads only the idle word.

A waker does not wake "some" worker: it takes one specific worker off the list and counts it as
searching in the same step, under the lock (`rt_idle_wake`), sets that worker's wake word to 2, and
only then makes the system call. A wake takes microseconds to land; because the woken worker already
counts as searching, every push meanwhile sees a searcher on its way and wakes nobody. (Counted only
once it ran, each fork of a nested join saw "parked, nobody searching" in that window and woke
another: about 6,000 to 28,000 wakes per `bench/sched.grl` run, and `rt_notify` a quarter of all
parallel CPU. Now a run issues one or two hundred.) A woken worker goes straight to searching. A
woken worker that finds work and was the last searcher wakes another (below), which is how a spawn
burst reaches every worker without a wake per task.

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

**Classes.** Each worker has a job deque per class (Frame, Normal, Background) and there is a job
ring per class. A worker takes injected tasks (the reactor's wakes, spawns from other threads), then Frame
work, then Normal work, then its own and stolen tasks, then Background work, and
reserves one of the Background cap's slots (a CAS) before it takes a Background job; the job gives
it back when it finishes. A job's class is its parent's; a root fork takes the class its stack was
given by `pool::with_class` (record word 112). An entry found in a class's queue whose record now
has another class is a stale entry naming a later job, and is skipped rather than claimed. The
injected tasks come first on every step, not every 61st as before: behind the jobs, a woken I/O
task waited in the ring while the workers kept finding frame jobs (bench/frame.grl's I/O task woke
up to a millisecond late in the development build).

**Loops split by halving.** A parallel call forks the upper half of its leaves as one job and
descends into the lower half, joining on the way back. The leaves are a function of the element
count and the grain (`parallel_split`), or of the count alone (`parallel_map`: at most 256), never
of the worker count or of who ran what.

**Joining.** A forker that reaches its join claims its job by pointer if it is still pending and
runs it. If somebody else has it, a waiter on a worker *leapfrogs*: it takes only work forked by
that job or its descendants (each record names its parent; the claim word names the worker whose
deque holds the job's forks), so nothing is stacked on it that a sequential run would not have
stacked there. `rt_job_may_help` is the one place that decides whether to help at all: not off a
worker, not with less than an eighth of the stack left. With nothing to take, it parks (a task
parks as a task; a plain thread sleeps on the record's state word). Each worker records the deepest
help nesting it saw, and `GRAIL_SCHED_STATS=1` prints the maximum at exit.

**Runners.** A worker does not run a job on its scheduler stack. It enters its *runner*, a green
task whose body claims the handed job, drains the worker's job deque and goes idle. Inside a job
there is therefore always a current task, so a job that waits - a sleep, a descriptor, a join, an
offloaded call - parks exactly as a task does: the worker sees its runner leave without being
idle, forgets it, and makes a fresh runner for its next job, while the parked one is resumed by any
worker like any task, finishes its job and ends. A job that never waits pays for none of this. A
runner's stack is a task stack, so a job that overflows it gets the task's report (it was an
unexplained SIGSEGV on a pool thread).

**Failure.** A failed check inside a parallel region is contained: the failing stack releases its
locks (once gaps12-sync is merged), waits - not cancellably - for every fork it has not joined,
publishes the failure to every job it was running, and is discarded; each forker re-raises at its
join, and where the failure leaves the region it is contained by the task or ends the process with
one report naming the original statement and the join. A stack overflow stays fatal. The mechanism
is `concurrency-model.md`, "F1".

**Locks.** Because help is limited to the waiter's own job's descendants, a join while holding a
`Mutex` can deadlock only where the sequential program would. When locks are tracked per record a
waiter that holds one will not help at all.

## The external slot: main joins like a worker

The worker array has one block more than there are workers. A thread that is not a worker - main,
a render thread - takes it with a CAS when it enters its outermost parallel region and gives it back
when it leaves (`rt_external_take`/`rt_external_give`, thread-record word 104). While it holds the
slot its forks go on the slot's own deques and free list instead of the locked injection ring, the
workers steal from it like from any worker, and its join takes its own fork back from its own
deque. It still helps with nothing (it is not a green stack). A second such thread that finds the
slot taken uses the ring as before. Join from main went from 6,146 to 3,205 instructions and from
about 1.8 us to about 450 ns.

## Waking: only when nobody is searching

A worker that runs out of work *searches* first - 64 more looks, yielding every sixteenth - and only
then parks; a fork wakes a parked worker only when one is parked and none is searching
(`rt_notify`). In a join the forker nearly always takes its own fork back before anyone could, so a
wake would only start a worker that finds nothing and parks again. The fast path of `rt_notify` is a
full barrier and one load of the idle word; the idle word itself changes only on real transitions
(a worker starts or stops searching, parks, or is taken by a waker).

**No wakeup is lost** - the invariant is that queued work is never left while every worker is
parked. Two pairs of accesses, each a store then a load, with a full barrier between, on both sides
(Dekker):

- the pusher: publish the work (the deque's tail store or the ring's), full barrier
  (`rt_full_fence`), load the idle word; if it shows a parked worker and no searcher, take the idle
  lock, re-read the word, and if that still holds take a worker (`rt_idle_wake`);
- a parking worker, still counted as searching: one atomic update of the idle word under the idle
  lock that puts it on the list and moves it from searching to parked (`rt_idle_park`), its wake word
  set to 1, a full barrier, one more look at every queue - which runs what it finds - and only then a
  wait on its wake word for as long as the word is 1.

In the single total order of the barriers, either the pusher's load comes after the worker's update
- then it sees a parked worker and, unless one is searching, takes one off the list and wakes it - or
the worker's last look comes after the publication and finds the work. A searcher the pusher saw
ends its search after that load, in one of three ways: it parks, and its last look comes later
still, so it finds the work; it finds other work and others are still searching, which defers to
them in the same way; or it finds other work as the *last* searcher, and then it notifies itself
(`rt_worker_run`) - a load of the idle word that comes after the publication and acts on it as the
pusher's would have. A worker taken by a waker counts as searching from that moment, and every look
it makes comes after its wake. A wake whose system call lands before the worker waits cannot be
missed: the waker set the wake word to 2 under the lock first, and the wait sleeps only while the
word is 1.

Two cases need care. The last look may *find* work while the worker is on the list: `rt_worker_run`
sees word 280 = 2 and takes the worker off the list under the lock before running anything
(`rt_idle_leave`); if a waker took it meanwhile, it was counted as searching, and that count ends
here as any searcher's does (so the last-searcher rule applies to it too). A stale system call from
that waker may land on a later park: the worker re-checks its word and waits again. And a worker
stops counting as searching *before* it runs what it found (word 280): counted while running, its
own forks would see "someone is searching" and wake nobody - which happened, and is what
`sched-fork-reaches-a-thief` pins.

Two hangs had exactly the shape the invariant forbids, and both rules stay: a push into a non-empty
deque still notifies (skipping it hung `task-scopes-join-cancel-abandon`, because a task can spin
until another task runs), and the last searcher to find work wakes another for what may be queued
behind it. `sched-wake-not-lost-under-constant-parking` would hang if any of this were wrong; it
runs on x86-64, AArch64 and RV64 (qemu, which is not a weak machine: real ARM hardware is still
owed).

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
