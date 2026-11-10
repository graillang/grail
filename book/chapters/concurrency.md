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
General `async`/`await` syntax is not provided; the scope and task APIs are the current surface.

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
- **Classification instead of a guess.** Transferable and shareable are derived from a type's
  structure, default-denied for foreign handles, and they reach a closure's captures, which are now
  part of the closure's type. The practical effect is that a reference to thread-affine foreign state
  cannot ride into a job inside what looks like plain data, and the diagnostic names the capture that
  denied it.

What it still does not do: a job's failure is still a process abort (there is no error value to cross
a boundary), there are no dependency edges between jobs, and a graph of asset jobs can still starve
interactive work because the pool has one queue class. `docs/design/parallelism.md` states each of
those with the reason.

**Try it:** remove `shared.total.lock_with(1, add);` and compare the two totals.
