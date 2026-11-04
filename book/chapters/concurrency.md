# Threads, atomics and mutexes

`parallel_map(items, context, f)` runs `f(item, context)` on real worker threads and returns the
results in order. It is structured: every worker is joined before the call returns, so a worker
can safely use borrowed data such as `borrow(shared)`. The compiler checks that items and results
may move between threads (`Send`), that the context may be shared (`Share`), and that results
hold no borrows.

{{example:concurrency}}

Four tasks each increment an atomic counter and a mutex-protected total 1000 times. The atomic
uses `fetch_add`; the mutex is used with `lock_with(context, callback)`, which gives the callback
exclusive access to the payload only while the lock is held. The compiler rejects callbacks that
try to return or stash a reference to the guarded value, so the lock cannot be bypassed later.
Waiting threads sleep in the kernel (futex) instead of spinning.

Rust's `std::thread::scope` gives the same "joined before the scope ends" guarantee with
closures. Grail does not have capturing closures yet, so shared state is passed explicitly as the
`context` argument and callbacks are named functions. A Rust `MutexGuard` is a value you can hold;
Grail scopes the guard to a callback instead.

The library also provides `hashmap::Map` (keyed SipHash, user key types via the `hash::Hash` and
`hash::Equal` interfaces) and `concurrent_map::Map`, a sharded map usable from many threads at once.
Task handles, cancellation and suspending I/O are not implemented yet.

**Try it:** remove `shared.total.lock_with(1, add);` and compare the two totals.
