# Concurrency stages 5, 6 and 7: proposals

Status: proposals for the director, written on `gaps12-sched` after stage 1, the help bound and F1.
Nothing here is implemented. Claims about today's code are tagged **[V file:line]** (read at the
commit that adds this file) or **[A]** (assumed). Each stage ends with the decisions it needs.

## Stage 7: the atomics family

### What exists

- **The type.** `Atomic<T>` is type kind 11, and the checker refuses every `T` but `u64`:
  "Atomic currently requires u64 (one aligned 64-bit word)" [V native.grl:13034-13040].
  `Atomic::new` allocates one 8-byte heap word (`rt_atomic_new`, an `rt_alloc(8)`
  [V runtime.grl `rt_atomic_new`]), so an atomic is never inline in a record. It is `Send` and
  `Share` [V docs/design/parallelism.md, table].
- **The methods.** `load`, `load_relaxed`, `load_acquire`, `store`, `store_relaxed`,
  `store_release`, `fetch_add`, `fetch_sub`, `swap` and `compare_exchange` are accepted. Each is a
  call to a runtime function [V native.grl `atomic_method`, about :30480-30540]. `fetch_add`,
  `fetch_sub` and `swap` are compare-and-swap loops in the runtime [V runtime.grl
  `rt_atomic_fetch_add`/`_sub`/`_swap`], so every RMW is a call plus a loop.
- **The intrinsics underneath** (runtime-only, ids 110-116) [V native.grl:24715-24735, :25190-25210].
  x86-64 is the instruction stream itself; AArch64 and RV64 are produced from it by
  `compiler/machine.grl` [V machine.grl:682-760]:

  | intrinsic | x86-64 | AArch64 (machine.grl) | RV64 (machine.grl) | LLVM (llvm.grl) |
  |---|---|---|---|---|
  | load (SC) | `mov; mfence` | `ldr; dmb ish` | `ld; fence rw,rw` | `fence seq_cst` after a plain load |
  | load_acquire | `mov; lfence` | `ldr; dmb ishld` | `ld; fence r,rw` [A] | `fence seq_cst` |
  | load_relaxed | `mov` | `ldr` | `ld` | plain load |
  | store (SC) | `xchg` | `ldaxr/stlxr` loop + `dmb ish` both sides | `fence; amoswap.d.aqrl; fence` | `atomicrmw xchg seq_cst` |
  | store_release | `sfence; mov` | `dmb ish; str` [A] | `fence rw,w; sd` | `fence seq_cst` + store |
  | cas | `lock cmpxchg` | `ldaxr/stlxr` loop + `dmb ish` both sides | `lr.d.aq/sc.d.rl` loop + fences | `cmpxchg seq_cst seq_cst` |

  Two consequences. First, the comment in `rt_pool_wait` that the acquire load "is not lowered on
  AArch64/RV64" is stale: it is lowered, as a load and a barrier. Second, every ordering reaches
  LLVM as a `seq_cst` fence. That is correct, but it is the strongest possible lowering, and on x86
  the SC load pays an `mfence` it does not need (an x86 SC load is a plain `mov` when SC stores
  are `xchg`).

### Proposal

**Types.** `Atomic<T>` for `T` in `u8 u16 u32 u64 i8 i16 i32 i64 bool`. Plain C-like enums
come later, behind unboxed records. No atomic references or pointers in safe code.
- Until unboxed records land, an `Atomic<T>` stays a heap cell of 8 bytes and all widths use
  64-bit operations on it, with the value kept in the low bits, sign- or zero-extended. That is
  exact for every operation: arithmetic wraps at `T`'s width because the result is truncated
  before it is stored, which for RMWs means a CAS loop for the narrow widths. Store narrow
  `fetch_add` results the same way.
- When unboxed records give `Atomic<T>` an inline layout (the unboxed-records note), narrow widths
  become real 1/2/4-byte cells. The methods do not change, only the lowering: x86 has every
  width; AArch64 has `ldaxrb/h`, `ldarb/h` and so on; RV64 has 32/64-bit AMOs and LR/SC, so 8 and
  16 bits are a masked LR/SC loop on the containing aligned word.
**Methods** (orderings as suffixes, decided in D4; the unsuffixed name is sequentially consistent):
- `load`, `load_relaxed`, `load_acquire`
- `store`, `store_relaxed`, `store_release`
- `swap`, `fetch_add`, `fetch_sub`, `fetch_and`, `fetch_or`, `fetch_xor`, `fetch_min`,
  `fetch_max`, each also with `_relaxed`, `_acquire`, `_release` and `_acqrel`. `fetch_add/sub`
  wrap (modular), as `concurrency-v1.md` already promises; `bool` has only `swap`, `fetch_and`,
  `fetch_or` and `fetch_xor`.
- `compare_exchange(expected, new) -> T` (strong; returns the value seen, as now) and
  `compare_exchange_weak` (may fail spuriously; for loops), each also with `_relaxed`, `_acquire`,
  `_release` and `_acqrel`. The failure ordering is not spelled: it is `acquire` for `_acquire`
  and `_acqrel`, `relaxed` for `_relaxed` and `_release`, SC for the unsuffixed form. That is the
  C++ rule for a derived failure order, and it removes the invalid pairs.
- Free functions in `lib/sync.grl` (or builtins): `sync::fence()`, `fence_acquire()`,
  `fence_release()`, and `sync::spin_hint()` (`pause` / `yield` / `pause` hint on RV64 with
  Zihintpause, else `nop`).
- An invalid combination has no name, so it is a "no method" error naming the valid ones.

**Lowering: new instruction-stream ops, not fences.** Today an ordering exists only as an x86
fence that the later stages translate, and LLVM can only see `fence seq_cst`. The proposal is four
pseudo-ops in the word-machine stream that `native.grl` emits and `machine.grl` / `llvm.grl` lower
per target, each carrying `{op, ordering, width}`:
`atom.load O W`, `atom.store O W`, `atom.rmw OP O W` and `atom.cas O W` (strong, or `weak`).

| ordering | x86-64 | AArch64 (v8.0 baseline) | RV64 | LLVM |
|---|---|---|---|---|
| load relaxed | `mov` | `ldr` | `ld` | `load atomic ... monotonic` |
| load acquire | `mov` | `ldar` | `ld; fence r,rw` | `load atomic ... acquire` |
| load SC | `mov` | `ldar` | `fence rw,rw; ld; fence r,rw` | `load atomic ... seq_cst` |
| store relaxed | `mov` | `str` | `sd` | `store atomic ... monotonic` |
| store release | `mov` | `stlr` | `fence rw,w; sd` | `store atomic ... release` |
| store SC | `xchg` | `stlr` | `fence rw,w; sd` | `store atomic ... seq_cst` |
| RMW (any order) | `lock xadd` / `xchg` / `lock and/or/xor` (result unused) / `lock cmpxchg` loop (and/or/xor with result, min/max) | `ldxr/stxr` loop with `a`/`l` per order (`ldaxr`/`stlxr` for acqrel and SC) | `amoadd.d` / `amoswap.d` / `amoand.d` / `amoor.d` / `amoxor.d` / `amomin(u).d` / `amomax(u).d` with `.aq`/`.rl`/`.aqrl` | `atomicrmw OP ... ORDER` |
| CAS | `lock cmpxchg` | `ldxr/stxr` loop, acquire/release variants | `lr.d`/`sc.d` loop with `.aq`/`.rl` | `cmpxchg [weak] ... SUCC FAIL` |

These follow the standard C/C++11 mappings (x86 TSO, ARMv8 with `ldar`/`stlr` for SC, RISC-V
table A.6 of the unprivileged spec) [A: from the published mapping tables, to be pinned by tests].
AArch64 LSE (`ldaddal`, `swpal`, `casal`) is a later option, gated on the target feature; v8.0
LL/SC is correct everywhere. Windows on ARM64 and macOS AArch64 use the same AArch64 rows;
PE x86-64 uses the x86 rows.

**Inline, not a call.** The new ops are emitted at the method call, so `fetch_add` is one
`lock xadd` instead of a runtime call plus a CAS loop. The runtime's own `raw_atomic_*`
intrinsics stay as they are for runtime code, but their lowering moves onto the new ops too, so
the runtime gets cheaper acquire/release without a change in its source. That also fixes the
x86 SC-load `mfence`, which every `rt_task_wait` and `rt_job_await` pays today.

**Effects and checking.** No method allocates or fails (`@no_alloc`, `@no_panic` hold for every
one of them). `Atomic<T>` is `Send` and `Share` for every `T` above. As now, no `&mut` to the
inside can be formed; the cell is reached only through methods.

**How `Atomic<u64>` migrates.** Source is unchanged: every method name in use today keeps its
meaning. The type changes from kind 11 with no argument to kind 11 with the width as its argument.
Interface files carry `Atomic<u64>` already spelled with its argument [A: check the writer]; if
not, the interface format version goes up by one in the same change, as closure bounds just did
(format 6). `rt_atomic_load/store/...` and the CAS loops in `runtime.grl` are deleted once nothing
calls them (dead-code rule). The heap cell stays until unboxed records; then `Atomic::new` stops
allocating, which is the change that removes the last allocation from `concurrent_map`'s shard
counters and from every `Atomic` in a record.

### Files, tests, benchmark

- Files: `compiler/native.grl` (type check for the widths, the methods, the ops), `machine.grl`
  (AArch64 and RV64 lowering of the four ops), `llvm.grl` (atomic instructions with orderings),
  `runtime.grl` (intrinsics move onto the ops; dead helpers deleted), `book/chapters/concurrency.md`,
  `docs/design/concurrency-v1.md` (ordering section), `CHANGELOG.md`.
- Corpus cases:
  - `atomic-widths-wrap`: each width wraps at its own size, signed min/max.
  - `atomic-methods-every-order`: every method name runs, on all three targets.
  - `atomic-invalid-order-has-no-name`: `load_release` is refused, naming the valid loads.
  - `atomic-no-alloc-no-panic`: an `@no_alloc @no_panic` function using every method.
  - asm pins: x86 SC load has no `mfence`; `fetch_add` is `lock xadd` and makes no call;
    AArch64 acquire load is `ldar`; RV64 relaxed `fetch_add` is `amoadd.d` with no fence.
  - Litmus, as checks that cannot fail if the lowering is right: message passing with release
    and acquire, and store buffering with SC. qemu-user's TCG is not a weak machine, so these
    prove the code shape, not the hardware ordering, on aarch64 and riscv64. They run for real on
    an AArch64 host when one is available.
- Benchmark: `bench/atomics.grl`, with uncontended and 24-thread contended `fetch_add` rates, and
  an SPSC ring of release stores and acquire loads, before and after. Expected: `fetch_add` goes
  from a call plus a CAS loop to one instruction.

### Decisions for stage 7

1. Narrow widths now, on the 8-byte cell, or only when unboxed records give inline layout?
   **Recommend now**: the API is what users write, and the layout change is invisible to them.
2. AArch64 baseline v8.0 LL/SC, LSE later behind a target feature? **Recommend yes.**
3. Is `fetch_min/max` signedness taken from `T`? **Recommend yes** (no separate `umin` name).

## Stage 6: blocking foreign calls

### What exists

- A foreign call is a direct C-ABI call. Its only runtime step is the thread-pointer switch to
  the thread's libc TCB [V native.grl `ffi_emit_call`, :13990; `tls_enter_foreign`]. On a worker it
  occupies the worker for the whole call (decision B3). `rt_blocking_enter` only prints a one-time
  warning [V runtime.grl `rt_blocking_enter`].
- The runtime's own blocking operations (`host::read_file`, `write_file`, `command`, sleep without
  a timer) go through `rt_blocking_call`/`rt_io`, then `rt_offload` [V runtime.grl:5023, :5040,
  :5055]. That **creates an OS thread for each call** (map 1 MiB, clone, join, unmap) and parks the
  task until the thread is done.
- What makes a handoff possible already: a task's context switch saves to and restores from the
  *thread record* (word 8, the scheduler stack pointer, [V os-linux.grl `rt_os_ctx_enter`/`leave`]),
  not from the worker block. So a thread can give its worker block (deques, runner, free lists) to
  another thread while it keeps running the task's stack, and still switch back to its own
  scheduler frame afterwards.

### Proposal

**Declaration.** `extern "C" blocking lib "c" fn fsync(fd: i32) -> i32;`. `blocking` sits
among the `lib`/`as` clauses of `extern_declaration` [V native.grl:14868]. It is a property of the
foreign function: a bit beside `ext` in the function record, and ` blocking=1` beside ` extern=`
in the interface record [V native.grl:41941]. Interface readers that do not know the field ignore
it [A: check `iface_r_*`]; otherwise the format version goes up. A `cfn` type may say
`blocking cfn(...)` later; not in this stage.

**The model: worker blocks and threads are separate.** A *worker block* (Go's P) is the deques,
the runner, the free lists and the stats. A *thread* (Go's M) runs one. Today they are one-to-one
for life. Stage 6 lets a block move:

- **Enter** (before the TCB switch, at every `blocking` call site): on a thread that runs no
  worker block (main, a plain thread, a C thread) it does nothing - one load and a branch. On a
  worker it marks the block "in a blocking call since T" and pins the task (task word, below). If
  the block has queued work, or another worker is parked while work is queued anywhere, it hands
  the block to a spare thread now. Otherwise it hands it off lazily: *sysmon* (below) does it if
  the call is still running after 50 us.
- **Leave** (after the call): if the block is still this thread's, it clears the mark and
  continues - one load and a store. If the block was handed off, the thread tries to take a free
  block (one whose thread became a spare); failing that it flags its task runnable, switches back
  to its own scheduler frame (thread record word 8), puts the task on the injection ring, and
  becomes a spare itself.
- **Spares** are parked OS threads, created on demand and reused. Their number is capped at 2x
  workers by default (`sched::Config.max_spares`, 1..256). A handoff that finds no spare and the
  cap reached does not hand off; the block stays occupied, as today, and the warning below says
  so once. Idle spares above `workers` exit after 1 s.
- **Sysmon** is not a new thread: the reactor already has a timer heap and wakes for timers. When
  any block is in a blocking call it arms a 50 us tick, and on each tick hands off every block
  that has been in a call for 50 us or more while work is queued. With nothing blocked it arms
  nothing.
- **`rt_offload` folds into this.** `host::read_file` in a task becomes enter, the syscall on the
  task's own thread, then leave. No thread is created per call, the task does not switch, and the
  worker's queue moves to a spare only if the call actually takes long. `rt_offload`,
  `rt_offload_main` and the per-call thread spawn are deleted. Windows keeps its completion-port
  path for descriptor I/O; its other offloads use the same handoff (fibers switch exactly like
  the Linux stack switch: `SwitchToFiber(thread record word 8)` [V os-windows.grl:1086-1092]).

**By caller.**

| caller | what `blocking` does |
|---|---|
| main or a plain thread (`thread::spawn`) | nothing; the thread blocks, which is its own business |
| a green task on a worker | enter/leave above; other tasks and jobs keep running on a spare |
| a job (it runs on a runner, which is a task) | the same; the job's forker waits as for any long job |
| a C thread calling into Grail that then calls a `blocking` function | nothing (no worker block) |

**Pinning, and callbacks during the call.** While a task is inside any foreign call that can call
back - known at compile time: the foreign function takes a `cfn` or a handle with callbacks - it
must not migrate. C frames are on its stack, and C may hold thread-local state. A pin counter in
the task record (incremented by enter, decremented by leave) makes `rt_suspend` block the
*thread* on the task's park word instead of switching stacks (exactly the thread-per-task mode's
suspend [V runtime.grl `rt_suspend`]). A callback may therefore sleep, lock, join a task or fork
jobs. Its waits block the thread, and its forks behave as from a plain thread: the forker claims
its own jobs back and helps with nothing, because the block may already be on a spare. This also
closes a hole that exists **today**: a callback that parks inside a non-blocking foreign call
switches the task, C frames and all, onto whichever worker resumes it. Pinning applies to every
foreign call that can call back, `blocking` or not.

**Cancellation.** A foreign call cannot be interrupted. Cancellation is observed when it returns,
at the task's next cancellable wait. A `blocking` call does not set the cancellable-wait word.
Interruptible blocking I/O is what `host::read_fd` with the reactor is for.

**A non-`blocking` call that blocks anyway.** It still costs a worker for its duration (B3). Sysmon
can see it if every foreign call on a worker records "in a foreign call since T" - two stores per
call, one before and one after. With that:
- a worker in a foreign call for more than 10 ms while work is queued is handed off by sysmon
  exactly like a `blocking` one, and the runtime says once, naming the symbol, that it should be
  declared `blocking`;
- every foreign call site gets the leave check (one load and a branch), because any call may come
  back to a handed-off block.

**Recommendation:** do it. The cost is two stores, a load and a branch per foreign call, which is
noise next to the call itself (to be measured: `bench/ffi_call.grl`, a tight loop of a trivial C
function). In exchange, a blocking C call cannot stall the scheduler any more, whatever it was
declared. `blocking` then means "hand off at once, do not wait 10 ms". The existing
`rt_blocking_enter` warning is replaced by the sysmon warning, which names the function.

### Files, tests, benchmark

- Files: `compiler/native.grl` (parse, record bit, interface field, call-site enter/leave and pin,
  the per-call marker), `compiler/runtime.grl` (blocks vs threads, spares, handoff, sysmon tick,
  `rt_offload` deleted, `rt_blocking_enter` replaced), `os-linux.grl` / `os-windows.grl` /
  `darwin.grl` (spare thread start, the reactor tick), `lib/thread.grl` / `sched::Config`
  (`max_spares`), `docs/ffi.md`, `docs/design/decisions-b2-b6.md` (B3 amended), the book,
  `CHANGELOG.md`.
- Corpus cases (x86_64 executes; aarch64 and riscv64 under qemu; Windows via `windows.mjs check`):
  - `ffi-blocking-does-not-stall-tasks`: `tests/concurrency/blocking_call.grl` turned around. One
    worker per task makes a 100 ms `usleep` declared `blocking`; a ticker task's worst gap stays
    under 20 ms.
  - `ffi-undeclared-blocking-is-handed-off`: the same with no `blocking`. Worst gap under 30 ms,
    and stderr names `usleep` once.
  - `ffi-spares-are-reused`: 1000 blocking calls from 8 tasks, then the thread count is at most
    workers + reactor + main + `max_spares`.
  - `offload-does-not-create-a-thread-per-call`: 1000 `host::read_file` from a task, with the same
    thread bound.
  - `ffi-callback-during-blocking-call-may-wait`: C calls back, and the callback sleeps, joins a
    task and forks a `pool::join`; the results are correct and the task did not migrate (it
    compares the thread record before and after).
  - `ffi-callback-parks-without-migrating`: the same through a non-`blocking` call (the hole
    above).
  - `ffi-blocking-in-interface`: a module exports a `blocking` extern, and a separately compiled
    user module gets the handoff (asm pin on the enter call).
  - `ffi-blocking-on-main-is-a-plain-call`: asm pin; no handoff on a plain thread at run time.
- Benchmark: `bench/frame.grl` with a mode in which one task calls a `blocking` 100 ms
  `usleep` in a loop (and one in which it is undeclared). Report frame median, p99 and max, and
  the I/O task's lateness, against no blocking task and against today. Expected: today's stall
  (one worker gone per blocking task, and a stalled frame when they exceed the workers) is gone.
  Plus `bench/ffi_call.grl` for the per-call cost of the marker.

### Decisions for stage 6

1. The per-call "in a foreign call" marker and sysmon handoff for undeclared calls.
   **Recommend yes.**
2. Spare cap default 2x workers, idle spares above `workers` exit after 1 s. **Recommend yes.**
3. Pin every foreign call that can call back, not only `blocking` ones (closes today's
   migration hole). **Recommend yes.**
4. Sysmon on the reactor's timer, 50 us for declared calls and 10 ms for undeclared ones.
   **Recommend yes**; the numbers are a starting point to measure.

## Stage 5: priority classes, splits by grain, and the `chunks_mut` rename

Stage 5 comes after the closure-bounds work re-typed `lib/pool.grl` (merged: `map`, `run`,
`for_chunks` and `chunks_mut` take `Fn<Share>`, `join` takes `Fn<Send>`, `spawn` takes
`FnMut<Send, Owned>` [V lib/pool.grl:54-139]), so the pool's signatures change once here.

### What exists

- One class: one job deque per worker and one job injection ring (stage 1).
- **Splits depend on the machine.** `parallel_map` makes `workers * 4` leaves
  [V runtime.grl:2987], so a float reduction over its results can differ between a 4-core and a
  64-core run. `parallel_for_chunks(data, chunks, f)` and `pool::chunks_mut` take a chunk *count*
  [V runtime.grl:3054, lib/pool.grl:106]. Halving is already deterministic in the leaf count
  (`rt_job_split`).
- Callers of the count form: `lib/pool.grl`; `tests/pool/chunks_mut.grl`, `chunks_mut_timing.grl`,
  `job_handle.grl`; `tests/sched/job_failure.grl`; `book/examples/pool-chunks-mut.grl` and its
  Rust twin; 13 corpus cases; the book chapters `concurrency` and `closures`; and the design notes
  (`parallelism`, `scheduler`, `closure-bounds`, `concurrency-model`). `abundance/` has none
  [V rg].
- The clock: `host::now_us` and every runtime time read are `clock_gettime` *syscalls* (228), not
  the vDSO [V runtime.grl `f_host_now_us`]. A per-job timestamp would cost a syscall per fork,
  which matters for the starvation counter below.

### Proposal

**The grain form and its name.** `pool::split_mut(data: &mut [T], grain: u64, f: Fn<Share>(&mut [T]))`.
`f` receives disjoint slices of at most `grain` elements; the leaves are `[k*grain, min(n,
(k+1)*grain))`, a function of `n` and `grain` alone. The name reads beside `join`, `map`, `range`
and `reduce` as what it does to the data. `chunks_mut` is removed in the same change, every caller
above is migrated, and there is no alias. The builtin becomes `parallel_split(data, grain, f)`;
`parallel_for_chunks` is removed with its count meaning. `grain == 0` is refused at run time with
a named failure rather than treated as 1 [A: or a refinement `grain: u64 where grain > 0`, which
the language has; recommended].

`pool::for_chunks` (owned chunks of a moved vector) takes the same treatment: it becomes
`pool::split(data: T[], grain, f)` and returns the per-piece results in order. `map` and `run`
keep their shapes but stop depending on the worker count: they split into pieces of
`max(1, n / 256)` elements, at most 256 leaves, whatever the machine. New:
- `pool::range(n, grain, ctx, f: Fn<Share>(u64, u64, &C))` for `[lo, hi)` index ranges;
- `pool::reduce(n, grain, ctx, zero, leaf, merge)`, which merges in index order: the tree is
  fixed by `(n, grain)`, so a float reduction is bit-identical on any number of workers.

**Classes.** `pool::Class { Frame, Normal, Background }`.
- A class is a property of the *stack* doing the forking, not of each call. `pool::with_class(class,
  f)` sets it for the duration of `f` on the current task or runner (a word in the record; the
  task record's existing words are untouched - it goes into the jobs' own record, word 112, and a
  task word reserved with the gaps12-sync author). Forks inherit their forker's class, and a runner
  takes the class of the job it runs, so a whole fork tree has one class without any signature
  changing. `task_scope` tasks are `Normal` until stage 2's `TaskConfig.class`.
- Each worker gets three job deques and there are three job injection rings. A worker takes its
  own `Frame` jobs, then injected `Frame`, then steals `Frame`, then the same for `Normal`, then for
  `Background` - strict between classes (D8). Tasks stay in their single deque between `Normal`
  and `Background` jobs [A: the order of tasks against classes is decision 3].
- `background_cap` (default `max(1, workers / 4)`): a worker does not *start* a `Background` job
  while that many workers are running one (an atomic count). No preemption: a running
  `Background` job finishes.
- **Starvation is visible, not bounded** (D8): `sched::stats()` returns, among others, the age of
  the oldest queued `Background` job. A job is stamped not with the clock but with a scheduler
  *epoch* that the reactor advances every millisecond while any `Background` work is queued, so
  forking costs one load. The age is `(epoch now - epoch stamped)` ms, maximised over queued
  `Background` entries. The `GRAIL_SCHED_STATS` line prints it.
- **Stale entries across classes.** A queue entry is a hint and the claim is the CAS on the record
  (stage 1). With classes, a stale entry in one class's deque can name a later job of another
  class. The record stores its class (word 112), and a worker that takes an entry from class `X`'s
  deque **skips it, without claiming, when the record's class is not `X`**. The job's own entry is
  in its own class's deque, or its forker takes it back by pointer, so skipping loses nothing, and
  the claim never runs a job at the wrong priority. A stale entry in the *same* class claiming a
  later job is harmless (stage 1's argument).
- **Helping with classes.** Leapfrogging already restricts a waiter to its own job's descendants,
  which inherit its class, so "steal only the same or a higher class" holds without a new test.
  It is stated as an assertion in `rt_job_may_help` [A: debug only].

**`sched::start(Config)`.** `lib/sched.grl` with `Config { workers, background_cap, idle_spin_us,
pin_workers, warm_stacks, seed }`, applied by `sched::start` before the scheduler exists. A second
call, or a call after anything started it, returns an error value; it does not abort.
`GRAIL_WORKERS` still overrides `workers` (tests rely on it).
- `pin_workers`: `sched_setaffinity` worker i to CPU i (Linux); `SetThreadAffinityMask` on
  Windows; a no-op on macOS, reported in the result.
- `warm_stacks`: n stacks pre-mapped per worker, so a frame never `mmap`s.
- `seed`: the steal victims' xorshift seed (reproducible interleavings with `workers: 1`).
- `idle_spin_us`: re-measure on a quiet machine before choosing the default. Stage 1 measured
  spinning as a loss on a loaded one.
- The 61-tick fairness check (injected work every 61st take) goes in with the classes.

### Files, tests, benchmark

- Files: `compiler/runtime.grl` (three deques and rings per worker, class word, skip rule, cap,
  epoch, stats, splits by grain, `sched::start`), `compiler/native.grl` (`parallel_split` replaces
  `parallel_for_chunks`), `lib/pool.grl` (`split_mut`, `split`, `range`, `reduce`, `with_class`,
  `Class`), new `lib/sched.grl`, the callers listed above, the book chapter and example (and the
  Rust twin, renamed), `CHANGELOG.md`.
- Corpus cases:
  - `pool-split-mut-is-by-grain`: leaves are `ceil(n/grain)`, independent of `GRAIL_WORKERS` (run
    at 1 and 24).
  - `pool-reduce-bit-identical-across-workers`: a float sum with `GRAIL_WORKERS` 1, 3 and 24 prints
    the same bits.
  - `pool-chunks-mut-is-gone`: refused, naming `split_mut`.
  - `sched-frame-not-starved-by-background`: 4x workers `Background` jobs of 50 ms each; a `Frame`
    pass of 64 leaves each frame finishes within 5 ms of its solo time.
  - `sched-background-cap-holds`: no more than `cap` `Background` jobs run at once (an atomic
    high-water).
  - `sched-stale-entry-wrong-class-skipped`: a stress test of records recycled across classes
    (checksum).
  - `sched-oldest-background-wait-reported`: `sched::stats()` grows while `Frame` work saturates
    the machine.
  - `sched-start-twice-is-error`, `sched-seeded-run-reproduces` (`workers: 1`, same output order).
- Benchmark: `bench/frame.grl` with the importer as a `Background` fork tree. Gate: frame p99
  within 10% of the run without the importer, and the oldest-`Background` wait reported.

### Decisions for stage 5

1. Names: `split_mut` / `split` (for today's `chunks_mut` / `for_chunks`), plus `range` and `reduce`.
   **Recommend.**
2. `grain` as `u64 where grain > 0` (a refinement the caller must show) rather than a run-time
   failure. **Recommend.**
3. Where tasks sit against job classes: between `Normal` and `Background` jobs until stage 2 gives
   tasks a class. **Recommend.**
4. The class lives on the forking stack (`with_class`) rather than being an argument of every
   call. **Recommend**; `pool::scope(class, ...)` from the model note becomes unnecessary.

## Follow-up (recorded, not scheduled): a vDSO clock

`host::now_us`, `host::now_ms` and every runtime time read are `clock_gettime` system calls
(syscall 228), not the vDSO, which costs too much for frame timing at hundreds of reads per
frame. Reading the vDSO from a libc-free runtime is its own small piece of work: find
`AT_SYSINFO_EHDR` in the auxiliary vector at startup, walk the ELF dynamic symbols for
`__vdso_clock_gettime` (`__kernel_clock_gettime` on AArch64 and RV64), and call it with the
syscall as the fallback. Windows and macOS have their own fast paths (`QueryPerformanceCounter`,
`mach_absolute_time`).

## Order

Stage 5, then 6, then 7: classes and the deterministic split are what the frame loop needs first.
Stage 6 removes the last way a correct program can stall the scheduler. Stage 7 is mostly
independent and can go in parallel with either (another agent could take it).
