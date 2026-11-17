# Dedicated threads (`lib/thread.grl`)

Stage 2 of [concurrency-model.md](concurrency-model.md) (sections 2.3, 2.7, 2.8). A dedicated thread
is an OS thread that runs one closure and is nothing else: not a scheduler worker, not a task. This
note records how it is built, what it guarantees, and what it does not do yet.

## The one mechanism: the closure runs on a stack the runtime switched onto

`thread::spawn` starts an OS thread through `rt_thread_start`, the primitive every runtime thread
uses. The thread's entry (`rt_uthread_main`, `compiler/runtime.grl`) does not call the closure on
the OS stack. It maps a stack of the size the program asked for (1 MiB by default, lowest page
`PROT_NONE`; a fiber on Windows) and switches onto it, exactly as a scheduler worker enters a task.
The thread has a record with a task record's layout for the words that matter - saved stack pointer,
stack base and size, failure words - kept in thread-record word 80, **not** word 16, so
`rt_current()` stays 0: the thread is not a task, every wait blocks it in the kernel, nothing
offloads, `host::worker_id()` is 0.

Three things follow from that one decision:

- **The stack size is honoured the same way with and without libc.** In a process that loaded libc
  the thread is created by glibc and has glibc's stack; that stack only carries the entry. The
  closure's stack is the runtime's mapping either way.
- **Running off the stack is the task overflow report.** `rt_os_stack_guard_hit` looks at word 80
  as well as word 16, and the thread installs an alternate signal stack of its own
  (`rt_os_thread_guard`; scheduler workers and the main thread already had one). `error: stack
  overflow`, status 134.
- **A failed check is contained the way a task's is**
  ([task-failure-containment.md](task-failure-containment.md)). `rt_containable` answers with the thread's record; `rt_fail`
  writes the failure into it as numbers and leaves the stack by a switch. The entry is then back on
  the OS stack: it frees the closure's stack, drops the thread's locals, publishes "finished" and
  *returns* - so the thread ends normally, its allocator cache is retired, and glibc tears its own
  thread down. Nothing is unwound. What the discarded stack owned is leaked and counted
  (`rt_contained`), so the end-of-main leak check prints its note instead of aborting, as for a
  task. The allocator cache is never mid-update at a failure: the allocator's own failures are
  `rt_abort`, not `rt_fail`.

What a contained failure does *not* do, stated because it is the cost of not unwinding:

- **A `Mutex` held inside `lock_with` stays locked.** The unlock was in a frame that no longer
  exists; the next locker waits for good. A failing task does the same today (verified), and the
  corpus case `thread-failure-holding-mutex-leaves-it-locked` pins it for a thread.
- **A failure inside a callback C called is contained too**, and the C frames between the callback
  and the closure are discarded with the stack - never returned into, exactly as an abort never
  returns into them. Whatever C held when it made the call is not released. (`tests/ffi/
  thread_callback_fail.grl`.)
- On the **main thread** there is no such stack and no record: a failure ends the process.

## `Thread<R>`

A library type, no compiler kind: `pub unsafe struct Thread<R>: transferable { result: *mut R }`,
a pointer to the result word of the thread's record (the record is `rt_alloc`ed; its layout is the
comment above `rt_uthread_new`). `impl Drop` joins: wait for the finished word, drop the result or
the failure, reap the OS thread, free the record - the rule `Job<R>` has. `join` and `try_join`
empty the handle first. A wait made by a green task goes through `rt_blocking_call`, so the task
parks and its worker keeps running other tasks (`thread-join-from-task-keeps-worker-running`);
any other caller blocks in the kernel.

The result is written by library code, which knows its type: `spawn` wraps the program's closure in
one that calls it and stores what it returned into the record. That wrapper is also what makes
`detach` sound without the runtime knowing how to drop an `R`: when it has a result it asks the
runtime, in one compare-and-swap, whether a joiner may still come (`host::thread_keep`); a detached
thread's result is dropped by the wrapper, on the thread.

**`detach` and the end of the process.** A detached thread frees its own record when it ends. One
that is still running when `main` returns does not keep the process alive: the process exits
without waiting, as in C and Rust. While such a thread exists (a count in process-state word 56)
the end of `main` does not make the leak check and does not unmap the arenas - the thread's
allocations are its own and it is still using them.

## `Ctx`: unforgeable, neither `Send` nor `Share`

`handle CtxToken;` is private to the module, and `pub struct Ctx { token: CtxToken, record: u64 }`.
A foreign handle nothing has classified is thread-affine, and a struct is classified through its
fields, so `Ctx` is neither transferable nor shareable by the rules that already exist - the same
structural denial that keeps a `Scope<C>` on its thread - and no other module can name the token to
build one. `spawn` lends a `Ctx` to the closure; `with_current` lends the caller's and answers
`None` when the caller is a task or a runtime worker.

## `thread::Local<T>`

`thread::local(make)` is a key (a process-wide counter, state word 48) and a function value that
makes a thread's first value. Each thread's values live in a table hanging off its thread record
(word 88): one `{boxed value, dropper}` pair per key it has touched. `local.with(ctx, f)` takes the
`Ctx` as proof of which thread this is. The table is dropped by the thread itself when its closure
has ended - also after a contained failure, since the table is not on the discarded stack - and
before its allocator cache is retired; the main thread's is dropped at the end of `main`, before
the leak check, so that check stays exact.

A `Local` is plain data (`same()` hands out another handle on the same key) because **Grail has no
module-level value to declare one in**. That is a language gap, written down here rather than worked
around: a `thread::Local` wants to be `static COUNTER: thread::Local<Tally> = ...` at module level.
What that needs: (1) module-level bindings of non-`const` type, with an initialiser the compiler
can run before `main` or lazily on first use; (2) a rule for what such a binding may hold - it is
reachable from every thread, so its type must be shareable, which `Local` is; (3) drop order at
exit, or the statement that statics are not dropped. Until then the handle is passed or copied into
each closure.

## What the program asks of the OS

Applied by the new thread itself, before the closure runs. `spawn` waits on a start latch; a refusal
comes back as `thread::Error { what, code }` (`code` is the OS's error number) and **the closure
does not run** - no silent fallback.

| | Linux | Windows | macOS |
|---|---|---|---|
| `name` (a label: cut, never refused) | `prctl(PR_SET_NAME)`, 15 bytes | `SetThreadDescription` | - |
| `stack_bytes` | the runtime's mapping, guard page | fiber reserve | - |
| `affinity` | `sched_setaffinity` | `SetThreadAffinityMask`, first 64 processors | - |
| `Background` / `High` / `Realtime(p)` | `SCHED_IDLE` / nice -10 / `SCHED_FIFO` p | idle / highest / time-critical | - |
| `sleep_until` | `clock_nanosleep(TIMER_ABSTIME)` | `Sleep` for the time left | time left |

macOS: this runtime cannot start a thread in a Mach-O build (`rt_thread` in `darwin.grl` reports
ENOSYS), so `spawn` returns `Refused::Unsupported` instead of the abort the runtime's own callers
get.

## Not enforced yet: the closure's captures

`spawn`'s closure crosses to another thread, so its captures must be transferable and hold no
borrow. **Today that is not checked.** A closure handed to a library function arrives as a
parameter, and a parameter's closure type has no environment, so the checks `thread_spawn_raw`
makes (the ones `parallel_spawn` makes of a job) pass vacuously - the same hole `pool::spawn` has.
The fix is bounds on the closure type, checked where a closure with a known environment converts to
it (`docs/design/closure-bounds.md`, branch `gaps12-closures`); `spawn` becomes

    pub fn spawn<R: Send + Owned>(cfg: Config, f: FnMut<Send, Owned>((&Ctx)) -> R) -> Thread<R> |? Error

and `thread_spawn_raw` keeps no check and becomes callable from an `unsafe module` only. The corpus
cases `thread-spawn-borrow-refused` and `thread-spawn-affine-capture-refused` state the required
refusals and are marked `pending` on that work. This branch is not merged before it.

## Follow-ups, by name

- **`thread::scope`**: built (below).
- **`thread::Executor`** (stage 4), **`sched::start`** and the removal of `GRAIL_TASKS=thread`
  (stage 1/2 of the scheduler work, not this branch).
- Module-level `Local` (the language gap above).
- A compiler bug found on the way and fixed here: an `extern "C"` call that took its function's
  first stack slot never restored the thread pointer (slot 0 was read as "no slot saved"), so in a
  libc-linked program everything after a no-argument foreign call that opened a function ran on
  libc's thread pointer.

## `thread::scope`

    thread::scope(|t| -> u64 {
        a := t.spawn(|| -> u64 left.len());
        b := t.spawn(|| -> u64 { right[0] = 9; return 1; });
        return a.join() + b.join();
    })

`scope<s, R: Owned>(body: FnMut<s>((&mut Threads<s>)) -> R) -> R`, `Threads<s>::spawn<U: Send +
Owned>(self: (&mut Self), f: FnMut<Send, s>() -> U) -> ScopedThread<s, U>`, and `h.join()` - a
method, because `thread::join` already names the join of a `Thread<R>` and Grail has no
overloading. The shapes are the closure-bounds checker's (docs/design/closure-bounds.md 7.1): the
`&mut` receiver keeps each spawn's loans alive until the scope ends and makes two spawns of one
`&mut x` conflict, and `s` in `ScopedThread<s, U>` keeps a handle inside the body. Neither type is
transferable or shareable.

The threads start through the same raw entry as `thread::spawn` (`thread_spawn_raw`, which checks
nothing). The scope owns every thread record: after the body returns it waits for each thread in
order, keeps the first failure no handle took, releases every record, and only then re-raises that
failure - siblings always finish (director Q1). A handle's `join` waits, takes the result and marks
the record taken (a failure is raised at the join instead, and not again at scope exit); a handle
dropped without a join waits and drops the result. Because the scope, not the handle, frees the
record, a handle that is never dropped (an Rc cycle) still leaves no thread running past the scope.
Such a handle's result is not dropped - its type is not known to the scope - which is a leak, not a
dangling borrow.
