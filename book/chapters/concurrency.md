# Threads, atomics and mutexes

`parallel_map(items, context, f)` runs `f(item, context)` on real worker threads and returns the
results in order. It is structured: every worker is joined before the call returns, so a worker
can safely use shared data, here `&shared`. The compiler checks that items and results
may move between threads (`Send`), that the context may be shared (`Share`), and that results
hold no borrows.

{{example:concurrency}}

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
