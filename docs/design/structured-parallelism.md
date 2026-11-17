# Mutexes, maps and structured parallelism (implemented subset)

Everything here is compiled by the sole Grail compiler and executed on x86-64, ARM64 and RV64
Linux. It is a real multi-threaded runtime, not a sequential stand-in.

## `mutex<T>`

```grl
fn add<a>(total:(&mut a num),amount:num)->num{exchange(total,*total+amount);return 0;}
fn main(){m:=mutex(0);m.lock_with(42,add);}
```

`mutex(value)` owns its payload. `m.lock_with(context, callback)` locks, passes the callback an
exclusive typed reference to the payload plus the moved `context`, unlocks, and returns the result.
The exclusive reference exists only during the call. The compiler rejects callbacks whose result
contains borrows or whose context type mentions the payload reference's lifetime, so no loan of
the guarded data can escape the critical section. Only read access to the mutex itself is needed,
so `(&a mutex<T>)` may be shared between threads; `mutex<T>` is Send+Share when T is Send.

Locking uses a futex (0 unlocked / 1 locked / 2 contended): waiters sleep in the kernel.
Limitations: payloads cannot contain borrows yet; there is no try-lock, timeout, poisoning or
lock ordering check. Locking the same mutex again inside its callback deadlocks (not memory
unsafety). Panics abort the process, so no lock is left held by an unwinding thread.

## `[K: V]` maps (lib/hashmap.grl, lib/hash.grl)

Keys implement the `hash::Hash` and `hash::Equal` interfaces (`num`, sized integers, `u8[]`,
`string` provided; user records implement them). Hashing is keyed SipHash-1-3 with explicit seeds
(`hashmap::with_seed`); `hash::hasher` is SipHash-2-4, verified against all 64 reference vectors.
The map is compact and insertion-ordered (like Python's dict): keys and values are stored densely
and one open-addressed index (Robin Hood, backward-shift deletion) holds entry indices, growing at
1/2 load. `insert`/`get`/`get_mut`/`remove`/`contains`/`len`; iterate by position with
`key_at(map, i)`, `value_at(map, i)` and `value_at_mut(map, i)` for `i` in `0..len`. Removal moves the
last entry into the hole. Lookups return borrows tied to the map, so it cannot be mutated or dropped
while one is live. Not yet: an entry API and random default seeds.

## `concurrent_map::Map<K,V>` (DashMap-style)

Sixteen `mutex<[K: V]>` shards selected by an independently keyed hash. All
operations take `(&a Map)`, so many threads can insert/remove/query concurrently; only keys
on the same shard contend. Values never leave a shard lock as references (insert/remove move
values; `contains`/`len` return numbers). `len` counts shard by shard and is not a linearizable
snapshot under concurrent mutation.

## `parallel_map(items, context, callback)`

```grl
fn work<a>(id:num,shared:(&a Shared))->num{...}
results:=parallel_map(ids,borrow(shared),work);
```

The callback may be a function or a closure (closures capture only owned values and read them, so
every worker can share one). Structured fork-join: `items:T[]` is moved, each item is passed with the read-only `context`
to `callback(item, context)`, results come back in order as `R[]`, and every worker thread is
joined before the call returns. Therefore no task can outlive borrowed data. Checked rules:
T and R are Send, the context is Share and a plain value, shared reference or readonly view,
R holds no borrows, and borrowed items are references whose exclusive referents hold no borrows.

Runtime: `parallel_map` forks jobs on the scheduler's own workers (`docs/design/scheduler.md`,
"Jobs") - the same threads that run green tasks; there is no separate pool. The map splits its
items into a few contiguous owned ranges per worker and forks them by halving, the caller runs
leaves itself and takes back any fork nobody stole, and stealing balances uneven items; results
are written into their input slots, so `out` is in input order whatever order the leaves finish
in. Every fork is joined before the call returns. The worker count is one per CPU (floor two,
ceiling 64) and `GRAIL_WORKERS` overrides it.

Tests (`compiler/tests/parallel.grl`) include a barrier that only completes when four tasks run
simultaneously, 16-thread atomic and mutex contention with exact totals, and 8-way concurrent map
insertion; negative cases reject exclusive/owned contexts, borrowed results, use after move and
mutation of the shared context while it is in use.

## Task scopes, handles and cancellation

```grl
fn work(n:num,base:num)->num{return n+base;}
fn wait(n:num,base:num,token:cancel_token)->num{while token.cancelled()==0{host::sleep_ms(1);}return n;}
fn body<s>(sc:(&s scope<num>),base:num)->num{
    a:=spawn(sc,1,work);b:=spawn(sc,2,wait);
    sc.cancel();return join(a)+join(b);
}
fn main(){total:=task_scope(40,body);}
```

`task_scope(context, body)` runs `body(ref scope, context)` on the calling thread. Inside, `spawn(scope,
item, f)` starts `f(item, context)` (or `f(item, context, cancel_token)`) as a task and returns an
affine `task<R>`; `join(handle)` consumes it and returns R exactly once. `task_scope` returns only
after **every** task has finished, including tasks whose handle was dropped: dropping a handle
never blocks, the scope exit joins it and destroys its result. Checked rules: the context is a
plain value or shared reference that satisfies Share; items/results are owned Send values with no
borrows and no task handles; the body result and mutex payloads cannot contain handles, so a
handle cannot outlive its scope; scope references are neither Send nor Share.

A task that fails - a failed check inside it, or an explicit `task_fail(text)` - is contained at its
own top frame and delivered to the join as a value: `try_join(handle)` returns `R |? TaskFailure`
instead of ending the process, while `join(handle)` keeps "must have succeeded" and reports the
failure at the join. The value cannot be dropped unhandled. Nothing is unwound and nothing is
allocated on the failure path; the discarded stack's owners are the accepted leak. See
[task-failure-containment.md](task-failure-containment.md).

Cancellation is cooperative and observable: `sc.cancel()` sets the scope flag, `sc.cancelled()` /
`token.cancelled()` read it, and tasks waiting in cancellable operations (pipe reads/writes,
`host::sleep_ms`) are woken and return early. Cancellation never abandons a stack: the task
returns normally and its owned values are cleaned up as usual. It does not yet propagate into
nested scopes, and code that never checks the token is not interrupted.

## Colourless suspension

Spawned tasks are stackful green threads (256 KiB stacks with a guard page) multiplexed on a
worker pool of max(4, CPUs) OS threads (at most 64), started on first use. There is no `async`
keyword and no future type: ordinary functions call `host::read_fd`, `host::write_fd` or
`host::sleep_ms`, and inside a task these suspend only that task. Non-blocking pipe descriptors
are registered with an epoll reactor thread (one-shot readiness); sleeps use timerfds. The same
functions block normally on plain OS threads (main thread, `parallel_map` workers).
A per-target stack-switch intrinsic saves callee-saved registers on x86-64, AArch64 and RV64;
each OS thread finds its worker record through the thread pointer (FS base, tpidr_el0, tp).
A wake that races with suspension is never lost (park-state handshake), and a finished task's
stack is released only after its worker has switched away from it.

**Blocking-call boundary:** `host::command`, `host::read_file` and `host::write_file` are handed
to a dedicated offload thread when called from a task; the task suspends and its worker keeps
running other tasks. Mutex acquisition from a task yields instead of sleeping on the futex, so a
lock holder that suspended for I/O can always resume. Mutex guards are not thread-affine (the
futex word has no owner), so resuming on another worker while holding one is allowed.

Tests (`compiler/tests/tasks.grl`, `compiler/tests/async_io.grl`): heterogeneous tasks, a two-task
barrier, cancellation of a busy task and of a pipe read that would otherwise wait forever,
abandoned results, nested scopes, 100 suspended pipe readers (more than the maximum worker
count) fed by one writer task, 300 concurrent sleeps, and 100 tasks blocked in FIFO opens through
the offload boundary while another task releases them. Negative cases reject handle escape,
double join, borrowed items/results, exclusive or owned contexts, handles in mutexes, sharing a
scope with other threads and malformed callbacks.

## TCP

`host::tcp_listen(port)` (0 picks a free port; `host::tcp_port(fd)` reports it),
`host::tcp_accept(listener)` and `host::tcp_connect("a.b.c.d", port)` create non-blocking sockets;
`host::read_fd`/`write_fd`/`close` work on them. In a task, accept/connect/read/write suspend only
that task on the reactor. `tcp_connect` returns a negative errno value (e.g. 111, connection
refused, as `wrapping_sub(0, fd)`) instead of aborting; listen/accept failures still abort until
typed I/O errors exist. `compiler/tests/tcp.grl` serves 100 concurrent client tasks from one
server task.

## Still missing (not claimed)

Checked suspension effects (a static "does not suspend" contract);
cancellation propagation into nested scopes; timeouts on joins; DNS/IPv6 (TCP over IPv4 addresses only);
channels; lifetime-carrying mutex payloads; read-write locks. `parallel_map` called from a
task still blocks that worker while its threads run.
