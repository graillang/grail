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
