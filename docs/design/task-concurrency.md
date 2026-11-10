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
