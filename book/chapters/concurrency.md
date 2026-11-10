# Threads, atomics and mutexes

`parallel_map(items, context, f)` runs `f(item, context)` on real worker threads and returns the
results in order. It is structured: every worker is joined before the call returns, so a worker
can safely use shared data, here `&shared`. The compiler checks that items and results
may move between threads (`Send`), that the context may be shared (`Share`), and that results
hold no borrows.

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
through `for_chunks` costs ~44 ms here, as one job. The `&mut` slice is the whole vector's loan, so
no capture in the callback can reach that data, and the slice a callback holds has its own length,
so an index past the chunk is a bounds check rather than a write into a neighbour.
`pool::chunks_mut(data, chunks, f)` wraps it for the case where `f` is a named function.

`parallel_spawn(f)` returns a `Job<R>` you can wait on later with `parallel_join(job)`, or
`pool::spawn`/`pool::wait`. A handle may outlive the statement that made it, and even the frame: its
captures were moved into the job and its result comes back owned, so nothing it holds is frame
memory. The compiler refuses a callback that captured a *borrow* (the handle's type records no such
lifetime), a job that would return another handle (two waits on one record), and sharing a handle
between threads. Dropping a handle without waiting on it waits and discards the result, so a job is
never left running with no owner.

Four tasks each increment an `Atomic` counter and a `Mutex`-protected total 1000 times. The `Atomic`
uses `fetch_add`; the `Mutex` is used with `lock_with(context, callback)`, which gives the callback
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
`CancelToken` parameter lets a task observe cancellation. Blocking host reads inside a green
task suspend that task and are resumed by the reactor, so other tasks keep running. General
`async`/`await` syntax is not provided; the scope and task APIs are the current surface.

**Try it:** remove `shared.total.lock_with(1, add);` and compare the two totals.
