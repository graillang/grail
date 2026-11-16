# Parking: one way to wait

Stage 3 of [concurrency-model.md](concurrency-model.md), push A: the parking operation, `Mutex<T>`
on it, poison, and `thread::join` on it. Push B (`lib/sync.grl`'s `RwLock`, `Condition`, `Once`,
`Latch`, `Barrier`, `Semaphore`; cancellation and deadlines for every wait) is not done yet.

## The waiter block and the queue

Everything that waits - a task, a job in its runner task, a thread - links its **waiter block** on
the queue of what it waits for and sleeps until a waker sets the block's state. One execution waits
for one thing at a time, so the block belongs to the waiter's record and nothing is allocated to
wait: a task's is the tail of its record (`rt_task_record_size()`, used by `rt_task_spawn` and
`rt_runner_new`), a thread's hangs off thread-record word 96 (one `rt_alloc` the first time it
waits or locks, freed when the thread ends), the main thread's is in process state
(`rt_main_waiter`, rounded to 16 because process state is only 8-byte aligned).

Block: `{next, state (0 waiting / 1 woken / 2 granted), request, last-in-queue, held list, owner
task (0 for a thread)}`. A queue is one word: four flag bits (bit 1 is the queue's lock) and the
first block.

**Protocol.** Wait: take the queue lock, look at the condition again (a release may have happened
while deciding to wait), link the block, drop the lock, sleep until the state is non-zero - a task
in `rt_suspend` (which does not lose a wake that came first), a thread on the state word with the
kernel checking it is still 0. Wake: under the queue lock, unlink, set the state, `rt_wake` the task
or futex-wake the thread. **Handshake:** the waiter then takes and drops the queue lock once before it
returns; the waker did its wake under that lock, so afterwards no waker can be touching the block or
the task record (a finished task is freed at scope exit; an idle runner must never be woken). Then
the waiter clears a wake still pending on its task (`CAS(task + 24, 3, 0)`, as `rt_job_park` does),
so its next sleep does not return early. A task that migrates while it waits is no different: the
block names the task record, never a thread. `rt_task_wait` (a task joining a task) is not on the
parking operation and keeps its single-joiner word; it was not changed.

The queue lock is a spin lock an OS-preempted thread can hold, so nobody spins on it without bound:
64 tries, then the OS thread is yielded each time round (`rt_q_lock`).

## `Mutex<T>`

Block `{word, payload, next held, poison site}`. Uncontended lock and unlock are one CAS each. A held
lock is tried 40 times more, then the caller parks - no yield loop, so eight tasks waiting through a
300 ms hold use under 100 ms of CPU between them (`mutex-waiters-park-burn-no-cpu`).

Unlock is **barging with a bound**: it frees the lock and wakes the first waiter, which competes; a
waiter that is woken and loses queues at the front and sets "owed" (bit 3), and the next unlock
hands the lock to it directly. A waiter loses at most once. Strict hand-off - the lock idle from the
unlock until the woken waiter actually runs - measured worse (`bench/mutex.grl`, 20000 short holds
per contender, Ryzen 7900X under load, best of two):

| contenders | barging with a bound | strict hand-off |
|---|---|---|
| 2 | 7 ms | 76 ms |
| 8 | 735 ms | 954 ms |
| 24 | 2344 ms | 2593 ms |

The CPU column of that benchmark (2.7 s for 735 ms at 8 contenders) is the 40-try spin plus the
queue lock under a lock that is held for a few hundred nanoseconds and taken 160000 times; it is a
pathological row on purpose, and tuning the spin is left for measurements on a frame workload.

The `lock_with` lowering is unchanged (lock, call, unlock); the runtime calls changed meaning.
`lib/sync.grl` adds `try_lock_with`, `recover_with` and `is_poisoned`. (`lock_until` comes with
deadlines in push B.)

## Failure while holding: release and poison

A failed check discards its stack whole, so no unlock in it runs. Each execution keeps a **held
list** (block word 32; a mutex's link is word 16 of its own block - one holder, no allocation).
`rt_contain_tail`, the one place a failing task or thread leaves its stack, calls
`rt_held_settle(block, site)`: every mutex on the list is released and **poisoned** with the failing
statement's site. The next `lock_with` or `try_lock_with` fails its caller - contained like any
failure - with `mutex poisoned: its holder failed at FILE:LINE:COL`; a waiter that was parked when the
holder failed is woken and fails the same way. `sync::recover_with` gives access anyway and clears
the poison when its callback returns.

`rt_held_settle` never allocates and never parks: it unlinks, flags, and releases, and a release
takes the queue lock (bounded spin) and wakes a waiter. It is therefore safe from a stack that is
about to park; the scheduler's job-failure drain (F1) calls it first. Until F1 lands a job's failure
is fatal, so `mutex-job-fails-holding-lock-poisons` is pending on it.

`rt_holds_any()` answers whether the current execution holds any lock; the scheduler's help decision
asks it (an execution that holds a lock parks instead of helping).

## `thread::join`

A joiner parks on the thread record's queue (word 136); the thread publishes "finished" and wakes
every joiner under that queue's lock. No offload helper thread per join any more
(`thread-join-parks-without-helper-threads`).
