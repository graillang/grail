# Task concurrency: green by default, checked when parallel

Decision: **green tasks are the semantics on every platform.** Windows gets a scheduler thread and
cooperative switching like Linux (see `decisions-b2-b6.md`, B4). A thread-per-task mode may exist as
an explicit opt-in, and that mode is the one that gets a Send/Sync-style check. This note records why,
so the question is not reopened by accident.

## What green buys

- **No data race is possible between tasks**, because tasks never run concurrently. This is a
  structural guarantee, not a checked one: there is no window in which a wrong program can slip
  through a compiler that has not been written yet.
- **Tasks are cheap.** Thousands of `spawn`s cost no extra stacks or OS threads. `parallel_map` over
  small work items does not become an OS-thread allocator benchmark.
- **One set of semantics to test and document**, instead of one per platform.
- **Blocking is already solved** where it matters: `rt_offload` hands a blocking foreign call to a
  worker thread while the scheduler continues, which is what `host::read_file`/`write_file`/`command`
  use. A user `extern "C"` call still occupies the calling task's thread - that is the recorded B3
  contract, and it is the same on both platforms now.

## Why not Send/Sync first

With one scheduler thread a Send/Sync-style check would enforce a property that already holds, while
adding an auto-derived type property the compiler must compute through records, enums, unions,
generics, closures and every FFI handle. Grail has no traits, so this cannot be a user-implementable
bound; it has to be derived. That is real complexity for no safety gain while tasks are green.

## A failed task is a value, not a process death

A task that fails does not end the program. Inside a green task, a failed check (bounds, overflow,
division by zero, `!` on a failed `Option`/`Result`, a failed refinement or `assert`) or an explicit
`task_fail(text)` is *contained* at the task's own top frame: the failure is recorded in the task
record and control returns to the scheduler, which discards the task's stack whole - no frame is
unwound, no destructor runs, nothing crosses a C frame - exactly the B5 rule, applied to one task
instead of the process. Nothing is allocated on that path, so a trap cannot deadlock on the
allocator lock a runtime frame may hold.

The join is the only boundary. `join(handle)` keeps its meaning - "this task must have succeeded" -
and reports the recorded failure at the join, which is still fatal from the top of the program.
`try_join(handle)` contains: it returns `R |? TaskFailure`, the language's existing result-union
shape, and never aborts. `TaskFailure` is a synthesized record of `kind`, `message` and `site` (the
failing statement's location). The value must be handled - `?` it, `match` it, or write
`ignore_failure(...)` - because the compiler refuses to drop an outcome that is still owned.

Decided semantics: a failed task produces no placeholder result; its children are *not* cancelled
(they belong to the same scope, finish, and keep their own outcomes; cancellation stays cooperative
and explicit); a handle is affine so a join happens once; an abandoned handle whose task failed
re-raises at the scope exit, which the enclosing task contains or the top level dies on; `rt_abort`
sites (allocator invariants, stack overflow, the end-of-main leak check) are never contained, and
neither is the opt-in thread-per-task scheduler, which has no scheduler frame to return to.

The cost is stated, not hidden: the discarded stack's owned heap values leak (the mapping itself is
recycled), and because no exact count of them exists the end-of-main leak check *reports* rather
than aborts once a failure has been contained. Design and semantics:
[task-failure-containment.md](task-failure-containment.md); decision: B5a in
[decisions-b2-b6.md](decisions-b2-b6.md).

## What a parallel mode must check

Grail's borrow rules already forbid two exclusive references and make `&T` read-only, so the memory
race surface is mostly *interior mutability and foreign state*:

- **Handle types** (files, sockets, Vulkan/COM objects) whose methods mutate through `&self`. Sending
  `&Handle` to two tasks must be refused: handles are not shareable.
- **Records and generics**: shareability derives from the fields - a record is shareable when every
  field is.
- **OS resources**: two tasks writing one descriptor is not a data race but is a real hazard, and no
  type check catches it; it has to be documented as unsafe-by-convention or mediated by the authority
  model.
- **`unsafe module`**: the single explicit escape hatch, and the reason the check can only be as
  sound as that surface is small. It is the same condition that makes B2's ambient `host::`
  acceptable for now.

Concretely, a parallel task entry point would require its arguments to be Send (owned data) or a
shared reference to Sync data; anything else is a diagnostic naming the type and the field that makes
it unshareable.

## When this is revisited

When a thread-per-task mode is added for CPU-bound fan-out. At that point the check ships *with* the
mode: the unsafe configuration is the checked one, and the default stays green and unchecked because
it needs no check.
