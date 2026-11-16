# Threads, atomics and mutexes

`parallel_map(items, context, f)` runs `f(item, context)` on real worker threads and returns the
results in order. It is structured: every worker is joined before the call returns, so a worker
can safely use shared data, here `&shared`. What crosses the boundary is classified structurally -
the item, the result, the context *and* the closure's captured environment each have to be
transferable (may move to another thread) and, where several workers share them, shareable. A
foreign handle is neither until its declaration says so, so a handle captured by a closure is
refused by name, with the capture and the path that reached it in the message. Results must hold no
borrows. The library's generic bounds are spelled `Send`, `Share` and `Owned`, and a closure
parameter states the same bounds on its type: `pool::map` takes `f: Fn<Share>(T) -> U`,
`pool::spawn` takes `f: FnMut<Send, Owned>() -> R` (see "Saying what a closure may capture" in the
closures chapter). A wrapper that takes a bare `Fn(..)` cannot pass it on to a worker: its type no
longer shows the captures the worker would reach.

{{example:concurrency}}

Behind `parallel_map` are the scheduler's worker threads, one per CPU - the same ones that run
tasks - stealing work from each other, so a call pays no thread-creation cost, a nested call uses
the same workers, and the calling thread runs leaves itself instead of sleeping. For
`T[]`-shaped work, `lib/pool.grl` wraps it: `pool::map(items, f)` is the per-element form,
`pool::run(count, f)` gives job `i` to `f(i)`, `pool::for_chunks(data, chunks, f)` consumes a vector
and hands each job one contiguous owned chunk, and `pool::join(a, b)` forks `a` for any worker to take, runs `b` on the calling thread, and returns
both owned results - if no worker took `a`, the caller runs it too, so a join costs little when
there is nobody free to help. All of them state the same rule: everything a job's closure touches it owns, and
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

### Atomics and memory orderings

`Atomic<T>` holds a `u8`, `u16`, `u32`, `u64`, `i8`, `i16`, `i32`, `i64` or `bool`. Its type comes
from the value it starts with: `Atomic::new(0)` is an `Atomic<u64>`, as it always was, and a narrow
cell starts from a value of its type, `Atomic::new(u8(0))`. Every operation is a method, and its
memory ordering is part of the name. The bare name is sequentially consistent, so the short
spelling is always the safe one:

| operation | names |
|---|---|
| load | `load`, `load_relaxed`, `load_acquire` |
| store | `store`, `store_relaxed`, `store_release` |
| read-modify-write, returns the old value | `swap`, `fetch_add`, `fetch_sub`, `fetch_and`, `fetch_or`, `fetch_xor`, `fetch_min`, `fetch_max`, each also `_relaxed`, `_acquire`, `_release`, `_acqrel` |
| compare-exchange | `compare_exchange(expected, new) -> T` returns the value it saw; `compare_exchange_weak(expected, new) -> bool` may fail spuriously and returns whether it stored; both also `_relaxed`, `_acquire`, `_release`, `_acqrel` |

A pair that makes no sense has no name, so `load_release` is a "no method" error that lists the
loads there are. `fetch_add`/`fetch_sub` wrap at `T`'s width, and `fetch_min`/`fetch_max` compare as
`T` does: signed for `i*`, unsigned for `u*`. An `Atomic<bool>` has no arithmetic. A
compare-exchange's failure ordering is derived as C++ derives it: acquire for `_acquire` and
`_acqrel`, relaxed for `_relaxed` and `_release`. `fence()`, `fence_acquire()` and
`fence_release()` are standalone fences, and `spin_hint()` tells the CPU that a loop is waiting
(`pause`, `yield`, or RISC-V's `pause`, which is a no-op on cores without it).

```grail
mut seen = counter.load_relaxed();
while !counter.compare_exchange_weak_acqrel(seen, seen + 1) {
    seen = counter.load_relaxed();
}
```

Each method compiles to the instructions at the call site. There is no runtime call, so none of
them allocates or fails, and every one is allowed in a `@no_alloc @no_panic` function. The ops are:

- **x86-64:** acquire loads and release stores are plain `mov`s. A sequentially consistent load is
  a `mov` as well, and a sequentially consistent store is an `xchg`. A 64-bit `fetch_add` is one
  `lock xadd`. Operations that compute the new value from the old one, such as `fetch_min` or a
  narrow `fetch_add`, are a `lock cmpxchg` loop.
- **AArch64:** `ldar`/`stlr`, and exclusive-pair loops (`ldaxr`/`stlxr` and their relaxed forms) on
  the v8.0 baseline.
- **RISC-V:** AMOs (`amoadd.d.aq` and so on), LR/SC loops, and the fences of the standard mapping.
- **LLVM backend:** `load atomic ... acquire`, `atomicrmw ... acq_rel` and `cmpxchg weak`, with the
  orderings the source asked for.

Until records can hold values inline, an `Atomic<T>` is an 8-byte heap cell holding the value
widened to 64 bits.

### Litmus tests

`bun tools/test-atomics-litmus.mjs` builds three programs for x86_64, aarch64 and riscv64, with
both backends, and runs them. The two cross targets run under qemu-user:

- `tests/atomics/litmus.grl`: message passing, with relaxed data, a release flag and an acquire
  read, over 20,000 rounds. Then 24 jobs count through `compare_exchange`, through a
  `compare_exchange_weak` retry loop, through `fetch_add`, and through a 16-bit `fetch_add` that
  wraps. They also drive `fetch_min`/`fetch_max` to the i64, u8 and i8 boundaries.
- `tests/atomics/litmus_sb.grl`: store buffering with sequentially consistent stores and loads.
- `tests/atomics/widths.grl`: every width wraps at its own size, with min/max at every boundary.

qemu-user runs the guest on the host's memory model, so on this x86 machine it is mostly stronger
than the hardware it emulates. What each test can catch therefore depends on where it runs:

| test | catches a fault under qemu (x86 host) | catches it only on real hardware |
|---|---|---|
| message passing (release store, acquire load) | a missing atomic on x86-64 itself | aarch64 and riscv64: the x86 host never reorders two stores or two loads, so a dropped `stlr`/`ldar` or fence goes unseen under qemu |
| store buffering, seq_cst | x86-64 (a seq_cst store that is a plain `mov`), riscv64 (dropped fences), a lost order anywhere | aarch64: see below |
| CAS counter, weak-CAS loop, fetch_add from 24 jobs | a read-modify-write that is not atomic, on every target | a spurious store-conditional failure, which qemu's emulated exclusives rarely produce, so the weak loop's retry path is exercised for real only on hardware |
| min/max signedness, wrap at every width | every target (no ordering involved) | - |

Store buffering is the one test that runs the other way. qemu 11.1.3 puts a barrier before an `stlr`
and after an `ldar`, but none between the two, so on an x86 host the pair can pass each other, which
ARMv8 forbids. LLVM's own `stlr`/`ldar` lowering shows the same forbidden outcomes there. The program
therefore recognises the emulator by the CPU it reports, implementer `0x00` (reserved for software,
used by no silicon vendor). Under qemu it prints the count instead of asserting. A real AArch64
machine asserts, and it is the only place the aarch64 store-buffering result means anything.

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

A job that waits - sleeps, reads a descriptor, joins a task - does not hold a worker: it parks the
way a task does and another worker's job runs meanwhile. A thread waiting in a join helps only with work its own
forked job created, so joining while holding a `Mutex` is safe unless that work takes the same lock.

A failure inside a parallel call is contained the same way: the other branches finish, the
failure is raised again where the call joins, and inside a task `try_join` reports it with the
statement that failed. From `main` it still ends the program, naming that statement.

What it still does not do: there are no dependency edges between jobs, and a graph of asset jobs can still starve interactive
work because there is one queue class.
`docs/design/parallelism.md` states each of those with the reason.

**Try it:** remove `shared.total.lock_with(1, add);` and compare the two totals.
