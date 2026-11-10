# Real parallelism

Goal: use every core, especially for Abundance's chunked geometry and asset work, without importing
a general Send/Sync trait system.

## What Grail already has

- Ownership and exclusivity: two exclusive references cannot exist, `&T` is read-only.
- **Typed slices** (`&mut [T]`), which express disjoint mutation at the type level.
- No interior mutability in Grail's own types. The only `!Sync` things are **opaque handles**
  (files, sockets, Vulkan/COM objects) whose methods mutate through `&self`, and `unsafe module` code.
- Green tasks, so no data race is possible *between tasks* today; `rt_offload` already hands blocking
  foreign calls to a worker thread.

## The property actually needed

Not Send/Sync. A Send/Sync check exists in Rust because arbitrary `&T` may be shared and `T` may have
interior mutability. In Grail that surface is one bit:

- **`shareable(T)`** — "contains no handle" (and no `unsafe`-module type). Derived structurally over
  records, enums and generics; false only for handles. No traits, no variance questions, no user
  annotations.

Disjoint mutation needs no check at all, because a parallel primitive hands each job its own
exclusive slice — two jobs cannot address the same memory.

## Staged plan

**Stage 1 (no language change): pool of owned jobs.** A work-stealing pool with N = cores workers.
A job owns its inputs and returns an owned result; a handle to the job's completion transfers
ownership back. No reference crosses a job boundary, so no check is needed and nothing can race. This
is exactly Abundance's `job_executor` shape and is implementable in the runtime plus `lib/`.

**Stage 2: disjoint slice parallelism.** `parallel_for_chunks(&mut [T], chunks, f)` where
`f: Fn(&mut [T])`. The compiler splits the exclusive slice into disjoint exclusive chunks; inside a
chunk, ordinary Grail rules apply, so element writes are safe by construction. This is where the
compiler earns its keep, and it needs no new type property.

**Stage 3: read-only sharing.** `parallel_map(&[T], f) -> V[]` requires `shareable(T)` — refused for
anything holding a handle, with a diagnostic naming the field that makes it unshareable.

**Stage 4: job graph.** Dependencies between jobs, each producing an owned value its dependents take
by move. Covers Abundance's build DAG.

## Why not Send/Sync

A language-wide auto-derived trait would have to be computed through records, enums, unions, generics,
closures and every FFI type, and Grail has no traits to hang it on. It buys nothing that stages 1–4
do not, and it would push a `Send + Sync` bound into every signature that ever touches a task. If
shared mutable state across jobs is ever needed (a shared allocator, a global cache), it should be an
explicit audited facility — a handle-shaped object that opts in — rather than a language-wide trait.

## Non-goals / honest limits

- Two jobs writing the same OS descriptor is not a data race and no type check catches it; it stays a
  documented hazard, mediated where possible by the authority model.
- `unsafe module` is the escape hatch, and the soundness of stages 3–4 is only as good as that surface
  staying small.
- Green tasks remain the default for *task* code; this pool is for data-parallel work. Which is right
  for Abundance because its parallelism is over buffers, not over interleaved state machines.
