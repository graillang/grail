# Threads, atomics and mutexes

`parallel_map(items, context, f)` runs `f(item, context)` on real worker threads and returns the
results in order. It is structured: every worker is joined before the call returns, so a worker
can safely use shared data, here `&shared`. What crosses the boundary is classified structurally -
the item, the result, the context *and* the closure's captured environment each have to be
transferable (may move to another thread) and, where several workers share them, shareable. A
foreign handle is neither until its declaration says so, so a handle captured by a closure is
refused by name, with the capture and the path that reached it in the message. Results must hold no
borrows. The library's opt-in generic bounds are still spelled `Send`/`Share`.

{{example:concurrency}}

Behind `parallel_map` sits one process-wide pool of worker threads that steal work from each
other, so a second call pays no thread-creation cost and a nested call reuses the same pool. For
`T[]`-shaped work, `lib/pool.grl` wraps it: `pool::map(items, f)` is the per-element form,
`pool::run(count, f)` gives job `i` to `f(i)`, `pool::for_chunks(data, chunks, f)` consumes a vector
and hands each job one contiguous owned chunk, and `pool::join(a, b)` runs two branches and returns
both owned results. All of them state the same rule: everything a job's closure touches it owns, and
results come back in input order whatever order the jobs finish in. See
`docs/design/parallelism.md`.

`parallel_for_chunks(&mut data[a: b], chunks, f)` is the in-place form of the chunked one: the
compiler splits an exclusive slice into disjoint exclusive chunks and hands each job `&mut [T]` over
its own elements, so nothing is moved or copied - the same 3M-element pass that costs ~100 ms
through `for_chunks` costs ~44 ms here, as one job. The split is `size = ceil(n/chunks)`, chunk `k`
being `[k*size, min(n, k*size+size))`, so disjointness and coverage are arithmetic rather than a
checked property. The `&mut` slice is the whole vector's loan, so no capture in the callback can
reach that data, and the slice a callback holds has its own length, so an index past the chunk is a
bounds check rather than a write into a neighbour. `pool::chunks_mut(data, chunks, f)` wraps it.

{{example:pool-chunks-mut}}

`parallel_spawn(f)` returns a `Job<R>` you can wait on later with `parallel_join(job)`, or
`pool::spawn`/`pool::wait`. A handle may outlive the statement that made it, and even the frame: its
captures were moved into the job and its result comes back owned, so nothing it holds is frame
memory. The compiler refuses a callback that captured a *borrow* (the handle's type records no such
lifetime), a job that would return another handle (two waits on one record), and sharing a handle
between threads. Dropping a handle without waiting on it waits and discards the result, so a job is
never left running with no owner.

{{example:pool-job-handle}}

In the `concurrency` example above, four tasks each increment an `Atomic` counter and a
`Mutex`-protected total 1000 times. The `Atomic` uses `fetch_add`; the `Mutex` is used with
`lock_with(context, callback)`, which gives the callback
exclusive access to the payload only while the lock is held. The compiler rejects callbacks that
try to return or stash a reference to the guarded value, so the lock cannot be bypassed later.
Waiting threads sleep in the kernel (futex) instead of spinning.

Rust's `std::thread::scope` gives the same "joined before the scope ends" guarantee with
closures. Grail closures capture by value, so shared state is passed explicitly as the `context`
argument; callbacks may be named functions or value-capturing closures. A Rust `MutexGuard` is a value you can hold;
Grail scopes the guard to a callback instead.

The library also provides `[K: V]` maps (keyed SipHash, user key types via the `Hash` and
`Equal` interfaces, imported with `use hash::Hash;` and `use hash::Equal;`) and a sharded `concurrent_map::Map` usable from many threads at once.

`task_scope(context, body)` starts structured tasks. Inside the body, `spawn(scope, context, f)`
returns a `Task<R>` handle and `join(handle)` waits for its result; every task is joined or
cancelled before the scope ends. `scope.cancel()` cancels the scope, and an optional
`CancelToken` parameter lets a task observe cancellation. `host::read_file`, `host::write_file`
and `host::command` inside a green task hand the blocking work to a dedicated OS thread and suspend
the task until it finishes, so other tasks keep running. A foreign (`extern "C"`) call does not get
that treatment: it occupies the thread that makes it, and foreign calls stay on the main thread.
Each `spawn` puts the task on the current worker's deque, and idle workers steal from each other's
deques; there is one worker per CPU on every platform, Windows included. `host::worker_id()` returns
the worker a task is running on (from 1, or 0 off a worker) and `host::workers()` the worker count,
which is how a program can check that its work really spread.

What is guaranteed is that a task runs until it yields or blocks and that a yield re-queues it. The
*order* is not: with one worker per CPU two tasks can be running at the same time, so two tasks that
print see whatever interleaving the host produced. A task's stack is a 1 MiB reservation that commits
only the pages it touches, and recursing past the bottom of it is a named runtime error,
`error: stack overflow`, with exit status 134 rather than a write into the neighbouring mapping.

### A failed task is a value

`join(handle)` is "this task must have succeeded": a task that fails a check - a bounds index, a
checked overflow, a division by zero, `!` on a failed `Option`/`Result`, `assert` - or that calls
`task_fail(text)` explicitly reports that failure at the join, and the process ends there as it
always has. `try_join(handle)` is the containing form: it never aborts, and it returns the
language's own result shape rather than a special error type.

{{example:task-failure}}

`R |? TaskFailure` is the same structural union as `string |? Error`, so `?` and `match` work on it
unchanged, and `TaskFailure` carries the check's `kind`, its `message` and the `site` of the
statement that failed. The failure never unwinds a frame - the task's stack is discarded whole, the
same rule as an abort, bounded to one task - so what the dead frames owned is not released: that
leak is the accepted cost, and the exit-time allocation check reports it instead of aborting. Because
an outcome you never looked at is the failure path no one chose, the compiler refuses to drop one:
`ignore_failure(try_join(t))` is the explicit opt-out. A failure belongs to the task, not to the
scope - the siblings keep running and their joins return their values, and cancellation is still
something a program asks for with `scope.cancel()` rather than a side effect of a failure.

General `async`/`await` syntax is not provided; the scope and task APIs are the current surface.

### Threads of your own

A task runs on whichever scheduler worker picks it up. Some work must not: the thread that owns a
window or a GL context, an audio callback's thread, a frame loop that has to wake on time. For that
there is `thread::spawn(config, closure)`, an OS thread that runs one closure and is nothing else.

{{example:threads}}

A thread is **not a worker**. Nothing is stolen onto it, `host::worker_id()` is 0 on it, and a wait -
a lock, a sleep, a read - blocks it in the kernel instead of parking a task. That is the point: its
latency is the operating system's and yours, not the scheduler's. It reaches the scheduler the way
`main` does, by opening a `task_scope` or calling into `pool`.

- **Joined by default.** `Thread<R>` is move-only and its drop joins, as a `pool::Job<R>`'s drop
  waits. `thread::join(t)` takes the owned result; `thread::detach(t)` is the one way to let a
  thread outlive its handle, and a detached thread still running when `main` returns does not keep
  the process alive (the exit-time allocation check is not made in that case - the thread's
  allocations are still its own).
- **A failure is contained**, exactly like a task's: the thread's stack is discarded whole, the
  thread ends, `try_join` returns the `TaskFailure` and `join` re-raises it. What the dead frames
  held stays held - a `Mutex` locked inside `lock_with` on that stack is never unlocked, for a
  thread as for a task - so contain failures you expect, do not rely on them. On the main thread a
  failure still ends the process.
- **`Config`** asks the OS for a stack size, a set of processors and a priority, and those are
  contracts: when the OS refuses one, `spawn` returns a `thread::Error` saying which and why, and
  the closure does not run. The name is a label: the OS shows what it can (15 bytes on Linux) and
  the rest is cut. The closure always runs on a guard-paged stack of the size asked for (1 MiB by
  default), and running off its end is the same named `stack overflow` a task reports.
- **`thread::Ctx`** is lent to the thread's closure, and `thread::with_current` lends the calling
  thread's (the main thread has one; a task or a pool job gets `None`). It can be neither sent nor
  shared, so no code that might run on another thread can hold one - which is what makes
  `thread::Local<T>` safe: `local.with(ctx, |value| ...)` reads this thread's own value, made the
  first time and dropped when the thread ends.
- **`thread::sleep_until(instant)`** sleeps to a point on the monotonic clock rather than for a
  duration, so a loop that sleeps to the next frame does not drift by the time the frame took.

Not here yet: threads that borrow from the caller's frame (`thread::scope`), and the compiler does
not yet refuse a `spawn` closure that captures a borrow or a thread-affine value - both wait for
bounds on closure types. On macOS `spawn` returns `Unsupported`: this runtime cannot start threads
there.

## What this month added

Three things, and one of them removed work rather than adding it.

- **In-place chunks.** `parallel_for_chunks(&mut [T], chunks, f)` splits the caller's own slice and
  gives each job an exclusive `&mut [T]` over its own elements, so the job that used to move every
  element into a chunk now writes the elements where they are. Measured on 3M `u64` with one job:
  about 100 ms through `pool::for_chunks`, about 44 ms in place; with eight chunks on eight workers,
  about 67 ms against 11 ms. The pass has no copy to pay for, which is where the difference comes
  from - it is not a scheduling improvement.
- **A job handle.** `parallel_spawn(f) -> Job<R>` and `parallel_join(h) -> R` are spawn-then-wait as
  two statements, with the pool's submit and wait underneath. The handle is move-only, its captures
  move into the job, its result is owned, and its drop waits - so dropping a handle is a
  wait-and-discard, not a leak and not a double free.
- **One worker per CPU, on Windows too, with guarded stacks.** Windows used to multiplex every task
  on one scheduler thread because it had no reactor; it now runs one worker per core with Win32
  fibers and an I/O completion port, so a `spawn`ned CPU-bound task really runs beside another one.
  Task stacks are reservations with a guard page (recycled on Linux and macOS), and running past the
  bottom is `error: stack overflow` with exit 134. `host::worker_id()` and `host::workers()` expose
  the scheduler; `docs/design/scheduler.md` is the mechanism.
- **Classification instead of a guess.** Transferable and shareable are derived from a type's
  structure, default-denied for foreign handles, and they reach a closure's captures, which are now
  part of the closure's type. The practical effect is that a reference to thread-affine foreign state
  cannot ride into a job inside what looks like plain data, and the diagnostic names the capture that
  denied it.

- **A task's failure became a value.** A green task that fails a check, or calls `task_fail(text)`,
  is contained at its own top frame: the stack is discarded whole, no frame is unwound, and
  `try_join` returns `R |? TaskFailure` with the failure's kind, message and site. `join` keeps
  "must have succeeded", `ignore_failure` is the explicit opt-out from handling, and the compiler
  refuses to drop an outcome that was never looked at. `docs/design/task-failure-containment.md`,
  decision B5a.

What it still does not do: a *pool job*'s failure is still a process abort (a job has no scheduler
frame to return to and no scope to report into), there are no dependency edges between jobs, and a
graph of asset jobs can still starve interactive work because the pool has one queue class.
`docs/design/parallelism.md` states each of those with the reason.

**Try it:** remove `shared.total.lock_with(1, add);` and compare the two totals.
