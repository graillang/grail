# The allocator, and its per-thread caches

The runtime's allocator (`compiler/runtime.grl`, `rt_alloc` / `rt_free`) is a segregated-fit
allocator: a block is a 16-byte header `{size, state}` and its payload, classes are `32 * 2^k` bytes
header included, and each class has a free list, a bump pointer into its current arena and a count
of blocks left in it. Classes of 512 KiB and more get a mapping of their own that is returned to the
OS on free. State 1 is a live block, 2 a static one that is never freed, and anything else stops the
program on free - a freed block's state word is its list link, which is how a double free is caught.
A reused block is cleared; a block from a fresh arena is already zero.

Until this note, all of that sat behind one spin lock once the process had a second thread, so a
threaded program serialised every allocation and every free. `bench/alloc_threads.grl` (jobs
that each build and drop small vectors and records, sharing nothing) went *down* with workers.

## What changed

Once the process has started a second thread, **every OS thread has a cache of free blocks of its
own** for the classes up to 256 KiB, and `rt_alloc` / `rt_free` work on it with no lock and no atomic
operation. The lock is taken only to move a batch of blocks between a cache and the shared state.

- **Where it lives.** One page from `raw_map` per thread, made by the thread's first allocation.
  Its address is word 64 of the thread record, and the record is what the hardware thread pointer
  names (`raw_tp_get`: `%fs:0` / `tpidr_el0` / `tp` on Linux, the TEB's user pointer on Windows). So
  finding the cache is two loads. The record grew from 64 to 128 bytes for it; the main thread's
  record is process-state words 128..255.
- **It belongs to the OS thread, never to a task.** A green task may resume on another worker; it
  then simply uses that worker's cache. A task leaves its worker only at a park point
  (`rt_suspend`, `rt_yield`), the allocator is not one, and there is no preemption, so nothing else
  runs on a thread while its cache is being changed. No signal handler allocates: the profiler's
  handler stores one word (`rt_prof_handler`), the stack-fault handler writes from process-state
  scratch (`rt_stack_overflow_at`), and a failure report (`rt_fail`) is an ordinary call, not an
  interruption.
- **A block freed on another thread** joins the cache of the thread that frees it. There is no
  owner word and no per-block atomic: blocks flow from the threads that free to the threads that
  allocate through the shared state, a batch at a time.
- **Bounds.** A bin holds at most 256 blocks and at most 128 KiB (256 blocks up to the 512-byte
  class, 2 at 64 KiB, and one block each for the 128 KiB and 256 KiB classes, which the byte bound
  alone would exclude). One block over, the newer half leaves as a *chain*: a list whose first block
  carries the next chain and the length in its two payload words, pushed on a per-class chain list
  (process-state words 1792..) under the lock in a few stores. An empty bin takes a whole chain the
  same way; failing that it takes blocks from the old shared free list, and failing that it reserves
  a run of never-used blocks from the class's arena, which it then carves without the lock.
- **Slow start.** A refill asks for 4 blocks the first time and twice as many each time after, up to
  half the bound, so a helper thread that lives for one blocking call does not reserve what it will
  hand straight back. A thread that never allocates never maps a cache page: a free on a thread
  with no cache goes to the shared list under the lock, and only the eighth such free makes a cache
  (a thread that only ever frees would otherwise lock every time).
- **Zeroing.** A block from a free list is cleared for the bytes that were asked for, rounded up to
  a word, not for the whole class: no caller reads past its request (a vector's capacity is the
  request - `rt_push`, `rt_reserveb`, `rt_grow` - never the class). A block from a reserved run is
  untouched memory and is not cleared again.
- **Thread exit.** `rt_thread_main` retires the cache after the thread's entry returns, which every
  thread the runtime starts passes through on Linux and Windows (scheduler workers,
  plain threads, blocking-call helpers); an adopted record of a C-created thread does it in
  `rt_release_record`. Retiring gives every bin away as a chain, turns the unused rest of each run
  into free blocks, adds the thread's live count to the process's and unmaps the page.
- **The live count.** Each cache counts its own allocations minus its own frees, as a wrapping word
  (negative on a thread that frees what others allocated). `rt_live` is the process word plus every
  registered cache's, summed under the lock so no cache joins or leaves mid-walk. It is exact when
  the other threads are idle or gone - the end of `main`, which is when `rt_leak_exit` asks - and
  approximate while they are allocating.
- **What did not change.** A process with one thread takes the path it always took: one load, one
  branch, the shared lists, no lock, no cache. `host::fork` is refused once a second thread started,
  and no cache exists before that, so a forked copy never inherits one. Classes of 512 KiB and more
  - a mapping each, made and returned on every use - still go through the lock. The double-free abort, static blocks and view records
  (`rt_view_record`, a block's address plus 8) behave as before.
- **macOS keeps the locked path.** A Mach-O build has no thread pointer of its own in this runtime
  (`raw_tp_get` is 0) and cannot start threads (`rt_thread` in `darwin.grl` reports ENOSYS), so
  there is no record to hang a cache on and nothing to contend with.

## Alignment: a promise

**A payload of 512 bytes or more starts on a 64-byte boundary; every payload starts on a 16-byte
one.** Programs may rely on it (a vector's buffer is a payload), and the corpus case
`alloc-align-64-from-512-bytes-on-every-path-and-thread` pins it.

The padding is in the arena, once, not in the block. An arena is a page-aligned mapping whose first
16 bytes are its own two words; the blocks of a class follow at multiples of the class size, and a
payload is 16 bytes into its block. For a class of 1024 bytes or more - where a request of 512 or
more lands, the header being part of the class - the first block starts at 48 instead of 16, so
every payload is `arena + 64 + i * size`. That costs 32 bytes per arena and nothing per block: no
class holds fewer blocks per arena than before, and smaller classes are untouched. Because the
alignment is fixed by the arena and no path computes a block address (a free list, a reserved run
and a chain only link or step over existing blocks), nothing can break it. One function knows the
offset (`rt_arena_first`); `rt_own_arena` finds the mapping of a block that has one to itself, and
`mremap` keeps such a block aligned when it grows. The 16-byte guarantee is what lets `rt_free`
read an address that is 8 past a multiple of 16 as a view record.

## What was not done, and why

Per-block ownership with remote-free lists (the mimalloc / snmalloc shape: a block freed elsewhere
is pushed with a CAS onto its owning thread's list) was rejected. It needs an owner word the
16-byte header does not have, an atomic on every cross-thread free, and a home for the blocks of
threads that have ended - and blocking-call helpers end constantly. The batch exchange costs one
lock per ~128 blocks instead.

## Measurements

Ryzen 9 7900X (12 cores, 24 threads), shared with another job at load 13-16 throughout, x86-64
Linux. "Before" is 78c8c6e.

`bench/alloc_threads.grl`, million allocate/free pairs per second:

| workers | before | after |
|---|---|---|
| 1 | 10.5 | 12.7 |
| 2 | 5.8 | 25.4 |
| 4 | 4.1 | 49.5 |
| 8 | 1.9 | 71.4 |
| 16 | 0.8 | 121.2 |
| 24 | 0.5 | 126.2 |

Linear to 4 workers, 9.5x at 16 and 9.9x at 24 on 12 cores that were not idle. Nothing in this
program takes the allocator lock in steady state, so what is left is the machine.

`bench/alloc_handoff.grl` (workers allocate, the main thread frees everything), million blocks per
second:

| workers | before | after |
|---|---|---|
| 1 | 7.5 | 6.3 |
| 2 | 4.5 | 8.4 |
| 4 | 2.9 | 10.1 |
| 8 | 2.1 | 10.8 |
| 16 | 1.4 | 11.2 |
| 24 | 1.2 | 10.5 |

This one cannot scale: one thread frees every block, each one last written by another core. It
stops falling and settles at what that one thread can free.

The one-thread path, `bun tools/compile-bench.mjs --quick` (best of 3; the compiler is a
one-thread program): `check syn1000` 1.38 s before and 1.39 s after in quiet runs, `check hello`
0.27 s both, `build hello --no-cache` 0.56 s both. A first version that put the cache path inside
`rt_alloc` itself cost 5% here - a larger frame on the one-thread path - which is why the threaded
path is a function of its own (`rt_alloc_shared`, `rt_free_shared`).

**Known cost, to revisit.** That split puts one extra call on every threaded allocation and free
(`rt_alloc` -> `rt_alloc_shared`). It was accepted to keep the one-thread path unmoved; when the
optimiser can inline the threaded path without growing the one-thread frame, the call should go.

## The one-thread path's cost (measured)

`grail check` on the 104k-line scaling program (the release compiler, callgrind, the main checking
process): 11.9M allocations and 13.4M frees. Before: about 96 instructions per allocation and 43 per
free - a loop doubling the class size up to the request, and an overflow check after nearly every
address addition (the runtime is compiled with checked arithmetic). After: the class of a request up
to 240 bytes is a compare chain (`rt_alloc_bin`), a block's class from its power-of-two size the
same (`rt_block_bin`), and the arithmetic on process-state and arena addresses wraps. About 50 per
allocation - of which the free-list pop or bump is about 20 and the rest is clearing a reused block
for the bytes asked for, which callers depend on - and about 25 per free. The process went from
4.88 G to 4.10 G instructions (-16%), the whole check's CPU time from 3.21 s to 2.9 s.
