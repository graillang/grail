# Real parallelism

Goal: use every core, especially for Abundance's chunked geometry, image and asset work, without
importing a trait system and without shipping a safe API that is unsound.

This note replaced an earlier plan whose central premise was wrong. It is kept honest here.

## What was wrong in the first draft

The first draft said: *a job owns its inputs and returns an owned result, so nothing can race and no
compiler change is needed.* An external review (GPT-6.1 Sol, high effort) refuted it, and it is right:

- **Ownership is not transferability.** A window/context must be created, used *and destroyed* on its
  creating thread; a Vulkan object may refer to a thread-affine command pool; a buffer may have to be
  freed on its allocating thread. Moving such a value to a worker is not a memory race but is unsound.
- **Foreign libraries hold hidden state** - process-global or per-thread scratch -, and may call
  registered callbacks from their own threads.
- **A read-only `&T` is not automatically shareable**: if `T` reaches a handle (directly, through a
  field, or through a closure capture, or as a returned reference into foreign scratch) then methods
  callable through `&T` can mutate foreign state.
- So a check over the argument type alone is insufficient. The whole **closure environment, the
  result, and the reachable foreign authority** must be classified.

## The model

Two compiler-derived properties, **not** traits and **not** bounds on every signature:

- **Transferable(T)** - a value may cross to another worker, including being destroyed there.
- **Shareable(T)** - concurrent shared access is permitted.

| Type | Transferable | Shareable |
|---|---:|---:|
| Plain data (integers, floats, bytes, records/enums/slices of them) | yes | yes |
| Unique foreign context, movable but not concurrently usable | yes | no |
| Main-thread window/context | no | no |
| Audited immutable foreign blob | maybe | maybe |

Derived structurally for Grail-defined types: a record is transferable when its fields are; shareable
when its fields are. **Unknown FFI classification defaults to denied.** A safe wrapper cannot erase a
restriction, and being declared in an `unsafe module` is not by itself the criterion - the boundary
needs an explicit foreign-resource contract.

Checked after monomorphisation, so diagnostics name the field:

```
cannot transfer job capture `decoder`:
  decoder.context is thread-affine
```

Classification metadata must survive in exported interfaces (B1) so separate compilation can check it
later, and so explicit constraints could be added without redesign.

## Stage 3 as built

The derivation is one structural walk in `compiler/native.grl`,
`transfer_capability(c, ty, shared, trail, depth)`. `shared` selects the question - 0 asks
`transferable`, 1 asks `shareable` - so both properties come from one recursion that has the same
shape; only the leaf rule and the borrow rule differ. It is not a trait: nothing is added to any
signature, no user type can opt in (an opt-in would be a way to erase a restriction), and a type
nothing knows about is denied.

| Type kind | transferable | shareable |
|---|---|---|
| scalars: u64, unit, bytes, string, char, bool, sized int, Atomic, f64; capture-free fn pointer; CancelToken | yes | yes |
| record / enum / union (8) | every field | every field |
| vector (6) | element | element |
| typed slice (27) | element | element, and only a read-only slice |
| byte view (5) | yes | read-only only |
| `&T` (7) | shareable(T) | shareable(T) |
| `&mut T` (7, exclusive) | transferable(T) | no |
| `Mutex<T>` (13) | transferable(T) | transferable(T) |
| `Task<R>` (16) | transferable(R) | no |
| `Scope<C>` (14) | no | no |
| `byval(R)` (28) | R | R |
| closure (20) | every capture | every capture |
| handle (23) | declared `transferable` | declared `shareable` |
| CStr (24), CPtr/CMutPtr (26), cfn (25) | no | no |
| capability proof (9) | its transferable bit | its shareable bit |

Three rules carry the review's corrections:

- **A shared reference is only shareable when its referent is.** `&T` hands the holder every method
  callable through `T`, so if `T` reaches a handle then `&T` is not shareable even though nothing can
  be written through it. This is why a `&File` capture is refused.
- **A slice reaches its elements.** The old walk treated a slice as bytes; `&[T]` now classifies as
  `T`, for the same reason.
- **A closure's environment is part of its type.** See below.

The walk records which leaf denied (`cap_denial`) and the dotted path that reached it (`cap_segs`),
so a rejection names a field rather than repeating the whole type.

### The closure environment, and the hole it closed

A closure type (kind 20) carried only its signature, and `parallel_map` checked the item, the result
and the context but never the closure. So this compiled, and every worker could reach the handle
through the environment:

```grail
g := |x: u64, u: u64| -> u64 touch(&h, x);   // plain-data signature, thread-affine capture
parallel_map(items, 0, g);
```

Fixed by making the environment part of the closure's identity: `Ty.env` holds the environment
record (kind 8) the closure is lowered into, interned into the type key, so two closures with one
signature and different captures are different types - which they already were as layouts. The walk
classifies every environment field (`__code` and `__drop` too, both plain words) and pushes a
capture's name onto the path exactly like a record field. A closure that has escaped a job is
covered by the same rule, because a closure in a result position is just a type of kind 20: what
crosses is the whole environment, and it must be transferable. A closure that *borrows* its
environment cannot escape at all, because a borrowed capture puts the lifetimes into the type and
the existing `contains_borrow` result check refuses it.

`parallel_map` also refuses an `FnMut` callback now: every worker shares one closure object, so a
callback that writes a capture would have its workers race on the environment.

### Diagnostics

```
cannot share closure capture `a`: a.file is thread-affine (a foreign handle with no audited classification)
cannot share closure capture `f`: f is thread-affine (declared transferable, not shareable)
cannot share parallel_map context: file is thread-affine (a foreign handle with no audited classification)
cannot share parallel_map context: an exclusive borrow cannot be shared
cannot transfer spawned result: thread-affine (a foreign handle with no audited classification)
```

### The audit

A handle states its contract where it is declared - `handle File: transferable;`,
`handle PhysicalDevice: transferable, shareable;`, `handle Window;` - and nothing declared is
neither. `shareable` alone is an error, because a value usable on another thread may also be moved
to it. Default-deny is the point: adding a foreign type to the compiler can never widen what a
worker may reach.

| Handle | Classification | Why |
|---|---|---|
| `sys_grail::File` | transferable | an fd/HANDLE with no wrapper-side state: it may be moved to a worker and closed there. Nothing serializes two users of one, so `close` under another worker's read is a race. |
| `sys_grail::Socket` | transferable | the same, and the accept-loop-to-worker handoff is the intended use. |
| `sys_grail::Process` | transferable | wait/kill/close are per-call syscalls on an owned child handle; nothing serializes concurrent calls. |
| `sys_grail::Thread` | neither | its one correct disposal (join or detach, exactly once) is the creating thread's bookkeeping, and the shim hands every handle out through a `_Thread_local` slot, so acquisition itself is thread-local. |
| `rhi_vulkan::Instance` | neither | created and destroyed on the thread that owns the display connection - on Linux the surface extension binds an Xlib display, thread-affine without `XInitThreads` - and Vulkan requires every child dead before it. |
| `rhi_vulkan::PhysicalDevice` | transferable, shareable | owns nothing, has no destructor, and every operation is a query; sharing it puts capability and queue-family queries off the main thread. |

`Device` is not a handle this module has yet. When it becomes one it should be
**transferable-only**: a `VkDevice` is not thread-bound by the specification, but the queue and
command pool this wrapper selects with it are main-thread state and Vulkan requires external
synchronisation around them.

### What a scoped parallel primitive must call

`parallel_map` calls, in order: the callback shape; `require_parallel_closure(c, fty, 1,
view("closure capture"))`; then `require_capability_named` on the item (0), the result (0) and the
context (1). A scoped job primitive calls the same two predicates:

```grail
require_capability_named(&mut c, input_ty, 0, view("job input"));
require_parallel_closure(&mut c, fty, 1, view("job capture"));  // environment shared by workers
require_parallel_closure(&mut c, fty, 0, view("job capture"));  // environment moves to one worker
require_capability_named(&mut c, result_ty, 0, view("job result"));
```

`shared` is 1 when several workers may call the environment at once (`parallel_map`,
`parallel_for_chunks`) and 0 when the closure moves to exactly one worker (a single job).
`require_parallel_closure` is one call so a surface cannot do half the job: it refuses an `FnMut`
environment when it is shared (concurrent workers would race on it) and then classifies every
capture. Both predicates reset the diagnostic state themselves and fail at the call site, naming the
field.

### Deliberately not classified

`CStr` (24), `CPtr`/`CMutPtr` (26) and `CFn` (25) stay denied: each reaches foreign memory or code
nobody has audited, and none of the handles we use needs them to cross a boundary. `CPtr` over
Grail-owned bytes is the one that plausibly could, but its origin is a call-scoped borrow, so
whoever audits it must also say what the pointee's lifetime is. The opt-in `Send`/`Share` generic
bounds are the same walk under their old names; renaming them to `transferable`/`shareable` is a
language change of its own and is not part of this stage.

### B1

Classification has to survive an exported interface or separate compilation re-derives the safe
answer for the wrong reason: a module importing `sys_grail::File` would see an opaque declaration
with `transfer = share = 0` and refuse a move the audit allowed. Nothing is lost today because the
whole program is one declaration table, and B1 stage 1 emits per-module assembly only. When
interface files land they must carry `Decl.transfer` and `Decl.share` for every handle, and
`Ty.env` - the closure environment record, with its field names and types - for every closure type
that appears in a signature.

## The safe surface: structured, not free spawn

- **Scoped jobs.** A scope guarantees borrowed inputs outlive the workers and that no worker can still
  reach frame memory after the scope ends. This is what makes shared captures sound without a trait
  system, and it is the property an unrestricted `spawn(&x)` can never give you.
- **`parallel_for_chunks(&mut [T], chunks, f: Fn(&mut [T]))`** - the compiler splits an exclusive
  slice into disjoint exclusive chunks, and the elements must be transferable. Disjointness is
  constructed, not checked. This is the Abundance workload.
- **`parallel_map(&[T], f) -> V[]`** - requires `Shareable(T)`; results returned in input order.
- **Owner actors** for externally mutable resources (asset caches, sockets, the main thread). Not a
  primitive; a consequence: thread-affine work runs on a main-thread executor and workers hand back
  CPU-side results.
- An unrestricted spawn is **not** part of the safe surface. A trusted/unsafe primitive may exist for
  the runtime itself, clearly named and documented as such.

## Lifecycle rules that must be designed in, not retrofitted

- **Fail-fast scope exit**: one job failing cancels its siblings, then joins them, and only then
  releases the inputs.
- **Cooperative cancellation** cannot let a parent reclaim memory a running child still borrows.
- **Helping scheduler**: a worker that waits on children it queued must make progress itself,
  otherwise a pool can deadlock when every worker waits. Nested parallelism reuses the pool rather
  than creating core-count pools.
- **Blocking separation**: blocking foreign calls must not run on the CPU pool. `rt_offload` already
  exists for this and now crosses a thread boundary itself, so it needs the same classification audit.
- **Allocators**: cross-worker ownership implies cross-worker destruction. Start with an allocator
  that supports that; locality is an optimisation later.
- **Determinism**: result ordering and reductions are defined independently of execution order.
  Floating-point reductions must not silently depend on which worker finished first.

## Build order

1. Bounded pool + structured scope/join, with the lifecycle rules above and tests for them.
2. `parallel_for_chunks` over plain-data element types, refused by name for anything else.
3. Structural derivation of transferable/shareable, with default-deny for unknown FFI types, and the
   audited declarations for the handles we actually use (files, sockets, Vulkan objects).
4. `parallel_map` with the shareable check.
5. Job graph with dependencies, once the lifecycle is proven.
6. Abundance: move `job_executor` and the geometry chunking onto it; main-thread executor for the RHI.

## Deferred on purpose

NUMA, elaborate priorities, a public work-stealing policy, and deterministic scheduler replay. The
one thing not deferred: an API shape that assumes all work is interchangeable forever - interactive
frame work must eventually be able to avoid starvation behind bulk asset builds, so the pool needs
room for that even if priorities are not implemented yet.
