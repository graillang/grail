# Parking: one way to wait

Stage 3 of [concurrency-model.md](concurrency-model.md): the parking operation; `Mutex<T>` on it with
poison; `thread::join` on it; and `lib/sync.grl` - `RwLock`, `Condition`, `Once`, `Latch`,
`Barrier`, `Semaphore` - with a deadline and cancellation for every wait.

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

## Deadlines and cancellation (`rt_park_until`)

Every wait has a deadline form (`_until(time::Instant)`) and a cancellable form. `rt_park_until`
takes a deadline on the monotonic clock and a "cancellable" flag. A task's deadline is the
scheduler's timer (the one `sleep_ms` parks on); a thread's is the kernel wait's timeout
(`rt_os_wait_ms`: a futex with a timeout on Linux, `WaitOnAddress` with one on Windows). Where no
timer can be armed for a task (Windows) it yields and looks at the clock. Cancellation reuses the
existing mechanism: the waiting task sets its "in a cancellable wait" word, which `rt_cancel` wakes;
on any wake the loop looks at the scope's token. Giving up takes the block off the queue under the
queue lock - if a waker got to it first the grant stands and the wait succeeds.

What the waiter sees:

- `_until` and `try_` forms answer `R |? time::WaitError` (`Cancelled`, `TimedOut`).
- A plain LONG wait (`Condition.wait_with`, `Latch.wait`, `Barrier.wait`, `Semaphore.acquire_with`,
  `Once.get_or_init` while another initialises, `time::sleep_ms`) that is cancelled ends its task
  with a failure of kind 16, "the wait was cancelled". `try_join` reports it as a `TaskFailure` with
  that kind; `join` re-raises it; a scope that was itself cancelled does NOT re-raise an abandoned
  child that ended Cancelled - that is what was asked for. (Before this change a cancelled task had
  no outcome of its own: only descriptor waits noticed, and answered -125.) `time::try_sleep_ms`
  answers instead of failing.
- A plain LOCK wait (`lock_with`, `read_with`, `write_with`) is not cancellable: it is bounded by its
  holder's progress, and cancelling a task that holds lock A while it waits for B would leave A
  poisoned. `sync::lock_until`, `read_until`, `write_until` are the cancellable forms.
- `join` (of a task or a thread) is not cancellable: it is how a scope winds down.
- A thread has no scope and is never cancelled; it has deadlines.
- A job (any wait inside a parallel region) does not wake for its scope's cancellation: a job runs
  inline on its forker's stack or stolen on a runner, and both must behave alike; it asks
  (`pool::cancelled()`), and a failing stack's drain is never cut short.

## The `sync` types

| type | blocks on | failure while holding | Send / Share |
|---|---|---|---|
| `Mutex<T>` (builtin) | lock | released, poisoned | as before |
| `RwLock<T>` | read / write, writer-preferring | writer: released, poisoned; reader: released | `unsafe struct ...: transferable, shareable` - each type argument must classify too, so Share needs `T: Share` |
| `Condition` | `wait_with(&m, ctx, ready, then)` | (holds the mutex only inside `then`) | transferable, shareable |
| `Latch`, `Barrier` | until zero / until a round completes (one leader) | - | transferable, shareable |
| `Semaphore` | FIFO permits | permits returned | transferable, shareable |
| `Permit` (from `try_acquire`) | - | returned | neither: it holds a private unclassified handle, so the permits stay with the execution whose failure returns them |
| `Once<T>` | until the first initialiser finishes | back to empty; the next caller initialises | transferable, shareable |

Callbacks borrow for the call only (plain `Fn` / `FnMut` parameters) and results are `R: Owned`, so
the guarded payload cannot leave a callback. Closure-bounds note 2.10: none of these types stores a
closure, behind a raw pointer or otherwise - each callback is called inside the method that
received it - so neither rule is needed; `Thread<R>` is `Owned` by construction.

Held-list entries other than a mutex are 48-byte nodes (kind 2 permits, 3 read, 4 write, 5 a Once
being initialised); `rt_held_settle` handles each kind, frees the nodes, and still never allocates
or parks.

`concurrent_map`'s shards are `RwLock`s. Measured first (`bench/shard_read.grl`, 24 tasks, one
4096-entry map, one write in 64): an RwLock shard took 1684-1796 ms where a Mutex shard took
2775-2932 ms. The price is the bound: `K, V: Send + Share` (DashMap's Send + Sync), and `V: Owned`
because `insert` and `remove` return the old value out of the shard lock. No caller in lib/, the
corpus, abundance/ or borg/ had to change.
