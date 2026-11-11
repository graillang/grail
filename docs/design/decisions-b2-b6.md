# Owner decisions: language readiness B1-B7

Decided 2026-11-10 against `main` at `9caae07`, under the project owner's direction to "do
everything properly" and to settle the seven open items in
[language readiness](language-readiness.md) section B. The owner delegated the choices; this page
records them, so that they are not re-argued as if they were still open.

The page is named after the items that were still open (B2-B6). B1 and B7 are recorded here as
well, because they are decided *and in progress* and the readiness table links one page per row.

Every item states the decision, the alternatives that were considered and rejected, what breaks if
the decision is wrong, and where the compiler, runtime, tests or documents enforce it. A later
change that wants to depart from a decision has to name the condition under "Revisit when" - a
decision without a stated trigger is what made these items outstanding for so long.

## Summary

| # | Decision | State |
| --- | --- | --- |
| B1 | Separate compilation with checked module interfaces: **accepted**. The plan of record is [separate-compilation.md](separate-compilation.md); this record fixes the decision and its obligations, not the format. | Implementation starting |
| B2 | Ambient `host::` stays for v1 as a **recorded deviation** from the capability model, with the conditions that force the change listed below. | Decided |
| B3 | A foreign call **blocks the executing thread**; no green-task scheduling integration is promised for v1. Foreign calls are valid on every runtime thread (per-thread host TLS; runtime threads are glibc threads); callbacks on C-created threads abort by name. | Decided; task semantics now identical on Linux and Windows |
| B4 | Windows runs **the same green scheduler as Linux** (Win32 fibers on one scheduler thread); thread-per-task is an explicit opt-in (`GRAIL_TASKS=thread`). IOCP stays a named future work item. | Decided and implemented |
| B5 | **Abort never unwinds**; nothing may unwind across the C boundary. There is no `defer` and no cleanup runs on an abort path. | Decided |
| B6 | Closures capture references and views and cannot outlive the borrow; **`FnMut`/mutable captures are implemented** under the six rules fixed below. | Implemented |
| B7 | Records passed by value to C: **accepted**, spelling `v: byval R`. | Implemented on x86-64, AArch64 and RISC-V 64; Windows x86-64 and ARM64 refuse the marker |

## B1: separate compilation accepted

**Decision.** The compiler grows a separate-compilation path with a checked module-interface
artifact: a module's exported signatures, layouts and ownership/origin contracts are checked once
and consumed by importers without re-reading every other module's source or re-emitting one
assembly file per program. The decision is the *capability and its obligations*; the format,
incrementality policy, cache keys and the artifact's on-disk encoding belong to the implementation,
whose plan of record is [separate-compilation.md](separate-compilation.md) (text interfaces with a
hash-verified dependency list, per-module objects, and - for v1 - source availability for generic
instantiation sites rather than serialised generic bodies).

Obligations the implementation must satisfy, taken from decisions already in the ledger:

- An importer's check may not depend on a provider's body (P02 in [decisions.md](decisions.md)).
- The artifact is content-addressed and invalidates transitively; a stale provider must fail the
  build rather than produce a green one (P11's evidence hashes; the bootstrap manifest is the
  existing precedent for recording source and artifact digests).
- Anything a client needs to check - exported origins, capture bounds, and later effect summaries -
  is in the artifact; "the provider compiled" is not a substitute for a contract.

**Alternatives considered.** (a) Keep whole-program compilation only: rejected, a 363,000-line port
cannot be built that way and every build pays for modules it does not use
([borg-agent-port.md](borg-agent-port.md) blocker 2). (b) C-header-style textual interfaces:
rejected, aggregate layout and ownership/origin contracts would be hand-maintained and unchecked.
(c) Link LLVM IR/objects now: rejected, it fixes codegen ABI details before the language's contract
artifact exists and moves diagnostics after the link.

**Consequence if wrong.** If the artifact turns out to be insufficient for the ownership and
origin checks, clients are either unsound (a program with a borrow that is invalid across a module
edge is accepted) or we fall back to whole-program checking. The cost is a redesign of the artifact
format, not of the language.

**Enforced by.** Stage 1: `grail build --split` writes one assembly file per module (`.grail_part`
markers from the emitter, offsets from the optimizer, the writer cutting the finished stream), the
CLI assembles the parts concurrently and links once, and `bun tools/split-test.mjs` (`just test-split`,
a CI job) proves that the parts concatenate to the single assembly file and that `--split` and
whole-program builds run the same program. Whole-program emission is still the default and there is no
interface artifact yet, so [implementation-status.md](implementation-status.md) keeps reporting
"Separate compilation with checked library contracts" as missing. The readiness row B1 tracks it.

## B2: ambient host authority, a recorded deviation

**Decision.** For v1, OS access stays ambient: any module may call the `host::` builtins and they
need no capability, effect or `unsafe` block. This is recorded as a **known deviation** from the
capability model the design wants, not as the intended end state.

What actually exists today (verified against the compiler):

- The `host::` surface is 28 builtins registered in `compiler/native.grl` (`host_fn` table, near
  line 20115): `target`, `argc`, `arg`, `read_file`, `write_file`, `print`, `print_num`, `newline`,
  `command`, `sleep_ms`, `now_ms`, `pipe`, `read_fd`, `write_fd`, `close`, `env`, `exe_path`,
  `exists`, `mkdir`, `list_dir`, `tcp_listen`, `tcp_port`, `tcp_accept`, `tcp_connect`, `open`,
  `exit`, `remove`, `create_dir`. They are compiler-known names, not library functions, so a
  module cannot shadow or restrict them, and nothing records who used them.
- A module that is not `main` can call `host::print` directly (compiled and linked in this review);
  the module declaration does not grant or withhold authority.
- The authority boundaries that *do* exist are about the raw machine, not the OS: `unsafe module`
  is reserved by name to `runtime` (and `darwin` on macOS) - `compiler/native.grl:7265-7274`
  rejects any other module that claims it; the runtime may not publish safe interfaces or be called
  from safe code (`native.grl:6684`, `native.grl:8932`); a foreign call, `cstr`, `cptr` and
  `cptr_mut` need a lexical `unsafe { }` block (`native.grl:9267-9272`, `11108-11134`).
- FFI is therefore gated by `unsafe`, while files, processes, sockets, environment and process exit
  through `host::` are not gated at all.

**What landed since, and what it does not change.** Two increments give a program a way out of the
deviation without changing the default:

- `lib/authority.grl` is an ordinary Grail module (not a builtin) whose `Authority` value carries one
  grant - read or write under a root, processes, sockets - and whose gated functions refuse a path
  outside it before the operating system sees it. Containment is lexical and component-wise after
  normalising `.`, `..` and duplicate separators, so `/database` is not under `/data`; a denial is a
  distinct `authority::Error` value, not an OS error. `docs/authority.md` states the rule and the
  paths it does not cover.
- `--deny-ambient-host` turns every `host::` reference in a module that has not written `use host;`
  into a compile error, and `lib/authority.grl` is the only standard-library module that opts in. A
  program written against `authority::` therefore needs no ambient access at all.

Neither is the capability model: `host::` stays ambient unless the switch is given, the switch is
per-build rather than per-component, and there is still no place to express "this component may not
spawn processes" for a module the build did not author. Revisit triggers 1-4 are unchanged.

**Revisit when** any of these becomes true; each one breaks the deviation rather than merely making
it inconvenient:

1. Grail runs untrusted code in process - third-party modules, plugins or extensions that are not
   part of the program being built. Ambient `host::` then means any loaded module has the file,
   process, network and exit authority of the host.
2. A sandbox or restriction is promised (path roots, network allow-lists, no subprocesses). There is
   currently no place to express "this component may not spawn processes".
3. `host::` appears in a published interface. An interface artifact (B1) that hides ambient
   authority would be lying about its dependencies.
4. A library is shipped as a component with an authority claim in its documentation.

**Alternatives considered.** (a) Capabilities as ordinary parameters now (`Console`, `Dir`, `Net`,
`Allocator` values passed at the entry point): deferred, not rejected. It needs the interface and
summary machinery B1 is building plus the lexical-context question in
[memory-model-competition.md](memory-model-competition.md) section 7 (P04), and it would rewrite
every stdlib and port call site before there is a second implementation to test the design against.
(b) A suspension/effect name (`effects(fs)`) as the primary mechanism: rejected as *the* model,
because effects describe operations while authority must describe retained permission
([memory-model-competition.md](memory-model-competition.md) rule 6 in section 7); a function with
no `fs` effect may still hold a directory handle. (c) Drop the capability goal: rejected, that
deletes the first step of the V3 order in [syntax-v2-scope.md](syntax-v2-scope.md) without saying
so.

**Consequence if wrong.** If Grail is combined with untrusted modules before the change, the
sandbox claim is false: any module can read and write files, spawn processes, open sockets and exit
the process, and there is no diagnostic to catch it. If the change is made too late, the cost is
mechanical: dozens of stdlib entry points and call sites gain a parameter, with the compiler
finding all of them.

**Enforced by.** Today: `lib/authority.grl` and its `bun tools/test-authority.mjs` suite,
`--deny-ambient-host` in `compiler/cli.grl`, the book's *Capabilities instead of ambient access*
section with its `authority` example, the compiler's sealing of the runtime (above), the `unsafe` gate
on FFI, and documentation - the readiness row B2, the "Explicit authority / capabilities" row of
[implementation-status.md](implementation-status.md), the V3 order in
[syntax-v2-scope.md](syntax-v2-scope.md), and the "no ambient console authority" paragraph of
[surface-sketch.md](surface-sketch.md). The deviation itself is recorded in this page.

## B3: foreign calls block the executing thread

**Decision.** A foreign call is a blocking call. The compiler emits it as a direct C-ABI call with
no runtime interception (`ffi_emit_call`, `compiler/native.grl:5485`), so the thread that makes the
call is occupied for its whole duration: on a green task that is a worker of the scheduler pool,
and a pool whose workers are all inside foreign code makes every other task wait. This is
documented behaviour for v1 - **no green-task scheduling integration, offload or suspension effect
is promised for foreign calls**, and no part of the type system records that a function blocks.

Two facts that belong to the same decision, because they bound how far "it just blocks" is true:

- **Host TLS is per thread; runtime threads are glibc threads.** Each OS thread's worker record
  carries its own host TLS base (record word 56): the glibc TCB that thread's foreign calls switch
  to, or 0 in a static program, where nothing switches. In a process that loaded libc the runtime
  creates every thread it owns - pool workers, green scheduler threads, the reactor, offload and
  `GRAIL_TASKS=thread` threads - through `pthread_create` (the `rt_host_thread` stub in
  `compiler/native.grl`, armed by `_start` through process-state word 3216), so errno, the malloc
  tcache and `pthread_self` belong to the thread that uses them. A callback finds its thread's record
  through `rt_tls_record`, an initial-exec TLS word glibc allocates in every thread. The alternative,
  a libc-compatible TCB the runtime allocates itself, was rejected as dishonest about glibc: its
  `struct pthread` layout is private and version-specific, and glibc keeps each thread on its own
  lists (the DTV that `dlopen` of a TLS-using library grows, the stack list `setxid` walks, robust
  futexes, rseq registration, the single-threaded flag that lets malloc skip its locks), none of
  which a fabricated TCB would join. Letting glibc build the thread costs an unused glibc-sized stack
  per runtime thread (glibc's default size; the green stacks are the runtime's own) and is what keeps
  every one of those invariants true by construction. **A callback on a thread C created** finds no
  record and adopts one for the outermost callback (mapped, published in `rt_tls_record`, unmapped
  on return), instead of sharing the main thread's. Two limits remain: a callback must not suspend the
  green task that made the foreign call (it could return into C on another thread), and glibc's
  internal signals (`setuid`'s `SIGSETXID`, cancellation) assume the thread pointer is the TCB, which
  is false while a thread runs Grail code.
- **The runtime isolates only the host operations it controls.** `host::read_file`,
  `host::write_file` and `host::command` hand their blocking body to a dedicated OS thread and
  suspend the task (`rt_blocking_call` -> `rt_offload` in `compiler/runtime.grl`). `host::read_fd`,
  `host::write_fd` and `host::sleep_ms` park the task too, by whichever mechanism the platform has:
  on Linux the epoll registration and a timerfd suspend it, and on Windows - which has no reactor -
  the call itself runs on a helper thread (`rt_io` -> `rt_offload`). Either way the *task* waits
  and the scheduler thread keeps running other tasks, which is what makes the two platforms
  observably identical (see B4). That is a property of those builtins, not a contract for user
  foreign calls, and on the offload path it costs one OS thread per blocking call.

**Alternatives considered.** (a) Keep the aspirational wording ("blocking foreign calls are
explicitly isolated") and treat it as done: rejected, it is false for every `extern "C"` call and
was the single largest source of confusion between [concurrency-v1.md](concurrency-v1.md) and the
runtime. (b) Offload every foreign call to a thread: rejected for v1 - `rt_offload` calls a
two-argument Grail function through `raw_call2`, so a general trampoline is needed for arbitrary
signatures, it costs a thread per call, and it does not fix the process-wide TLS base, which is the
real reason a worker could not call libc (since fixed separately, above). (c) Reject foreign calls lexically inside a task scope
(compile error): attractive, but it needs a checked suspension/effect summary - the same missing
machinery as B1's interface contracts - so it is a later increment, not a v1 promise.

**Revisit when** any of: a foreign-call offload trampoline exists (the host TLS base is per-thread
and callbacks on C-created threads adopt a record, so FFI is legal on every thread); effect/suspension summaries are published, at which point
"this call blocks" becomes checkable and a `nosuspend` context can be enforced.

**Consequence if wrong.** The failure mode is a runtime fault, not a diagnostic: a server that
calls a blocking foreign function from tasks starves or deadlocks its worker pool (correctly, in
the sense that it blocks exactly as documented), and multi-threaded FFI corrupted libc state silently
until host TLS became per-thread; a callback on a C-created thread now adopts a record of its own. If instead we had promised isolation we do not have, libraries would rely on it.

**Enforced by.** `tests/ffi/threads.grl` (`bun tools/test-ffi.mjs`, x86-64 and, with a glibc sysroot,
AArch64 and RISC-V 64 under qemu) runs libc calls with errno from a pool worker and a green task and
holds two errno values on two threads at once. Documentation: [docs/ffi.md](../ffi.md) (the per-thread
rule and "Task
scheduling is the same on both platforms"), [concurrency-v1.md](concurrency-v1.md) (what is
offloaded and what is not), this page, and the "Suspension effects and non-suspending cleanup" row
of [implementation-status.md](implementation-status.md). Tests: `tasks-read-file-offload` and
`tasks-sleep-progress` execute the handoff on Windows under Wine and as Linux ELF, so the offload is
verified on both sides; blocking-call isolation remains an acceptance gate named in
[concurrency-v1.md](concurrency-v1.md), and nothing enforces the absence of a blocking foreign call
today.

## B4: Windows runs the same green scheduler, thread-per-task is opt-in

**Decision.** Task semantics are **the same on both platforms**: a `spawn`ned task is a green task
on Windows exactly as on Linux. One Windows scheduler thread runs the tasks cooperatively, a task
runs until it yields or blocks, `sleep`/`wait_fd`/I/O park the *task*, and a blocking host
operation does not stall the other tasks because the runtime offloads it, just as on Linux. The
thread-per-task scheduler that the earlier B4 decision shipped as the only Windows mode is kept as
an **explicit opt-in** (`GRAIL_TASKS=thread`), because it is the better shape for CPU-bound fan-out
once there is a `Send`/`Sync` check - and it is not the default precisely because there is none.

**Readiness mechanism, stated honestly.** Windows has no epoll, eventfd or timerfd, and the
compiler's Win32 import table (`compiler/native.grl`) has no `CreateEvent`, `CreateWaitableTimer` or
Winsock entry points this workstream may add (it is owned elsewhere). So the design uses the two
primitives that exist:

1. **Fibers, not a hand-written stack switch.** `compiler/native.grl` emits `ud2` for `raw_switch`
   on the PE targets, so the Windows platform module switches with `CreateFiberEx`/`SwitchToFiber`/
   `DeleteFiber`/`ConvertThreadToFiber` (declared in `compiler/os-windows.grl` as
   `extern "C" lib "kernel32"`, which the short-import library and `tools/windows.mjs` pick up).
   A task is a fiber on the single scheduler thread; the fiber proc is an `extern "C"` definition
   because Win32 starts a fiber through a `cfn`.
2. **The run queue parks on an address wait** (`WaitOnAddress`/`WakeByAddressAll` on the
   scheduler's idle sequence word) - the same word the Linux build waits on with `FUTEX_WAIT` -
   **and blocking primitives are offloaded to a helper thread** that wakes the parked task, which is
   the policy the earlier B4 decision named thread-per-blocking-call, now applied *below* the task
   abstraction instead of replacing it. So there is no waitable-event set and no socket-pair
   self-pipe: for `host::read_file`, `host::write_file`, `host::command`, `host::read_fd`,
   `host::write_fd` and `host::sleep_ms` the blocking call runs on its own thread (`rt_offload`) and
   the task suspends on its park word; `rt_wait_fd` itself reports ready, because on Windows the
   task is already parked inside the operation that could block.

**What is now identical, precisely.** `spawn`, `join`, `task_scope`, `parallel_map`, cancellation,
result publication, scope-exit joining and the blocking host operations have the same observable
behaviour on both platforms: a task runs until it yields or blocks, a parked task lets the others
run, and `host::read_file` inside a task does not stop another task from making progress. What is
*not* identical is the interleaving order guarantee and the cost model:

- Linux works the queue with one scheduler thread per CPU (clamped to 4-64), so two ready tasks can
  run at the same time; Windows has one scheduler thread, so its queue is FIFO and a two-task
  interleaving is deterministic. Portable code may rely on "runs until it yields or blocks" and on
  scope/join, not on either order.
- A task costs a 256 KiB stack mapping on Linux and a 64 KiB-in-256 KiB fiber on Windows; a blocked
  task costs a scheduler thread on Linux and the only scheduler thread on Windows.
- The opt-in `GRAIL_TASKS=thread` mode changes semantics, not just performance: each task is an OS
  thread, so two tasks really run at once (no cooperative tick), a task that never yields still
  progresses, suspension blocks that task's thread, `rt_wait_fd` returns immediately and
  `rt_reactor_fence` is a no-op. It is the mode to use for CPU-bound fan-out and the mode to avoid
  for anything that assumes tasks are serialised, until `Send`/`Sync` exists.

**IOCP sketch** (unchanged future work item, for whoever picks it up): one completion port created
where the scheduler now creates its epoll fd; overlapped `ReadFile`/`WriteFile` with a completion
key identifying the pending operation; a reactor thread calling `GetQueuedCompletionStatus` where
the reactor now calls `epoll_wait`; the portable `rt_wait_fd`/`rt_suspend`/`rt_wake` protocol
unchanged, with the readiness translation living in `os-windows.grl`. That would replace the
offload-a-blocking-primitive mechanism with real readiness and remove the helper thread per blocked
call; it changes no task-visible semantics, which is why it is not a blocker for green tasks.

**Earlier state, kept because it explains the code.** Before this change the Windows scheduler was
thread-per-task, and before *that* the portable scheduler treated a failed `epoll_create` as fatal,
so the first green-task spawn aborted the process on Windows (reproduced under Wine: exit 134 with
no output, against `42` on Linux). The thread-per-task scheduler is what made `spawn`,
`task_scope` and `parallel_map` work under Wine at all; it is now the opt-in mode rather than the
default.

**Alternatives considered.** (a) Hand-written stack switch on the PE targets: rejected - it needs
`raw_switch` lowering in `compiler/native.grl`, which another workstream owns, and Win32 fibers are
the supported way to switch stacks on Windows. (b) `CreateEvent` per wait plus
`WaitForMultipleObjects` as the readiness mechanism: rejected - bounded at 64 handles, it needs an
import the compiler does not have, and it would only serve timers, since there are no non-blocking
handles to wait on. (c) A socket-pair self-pipe: rejected - Winsock is not imported and the runtime
has no socket layer on Windows, so the pipe would be the only thing it used. (d) Keep thread-per-task
as the default "because it works": rejected - it is exactly the semantic divergence this record
removes, and it hides races that Linux would also have. (e) Ship IOCP now: rejected for sequencing -
an overlapped-I/O lane is a bigger change and changes nothing user-visible that green tasks need.

**Consequence if wrong.** If fibers turn out to be a poor fit (context-switch cost, tooling, or a
host that already uses fibers), only `compiler/os-windows.grl`'s five context functions change: the
portable scheduler, the task API and the tests are written against them. If the single scheduler
thread is too slow for a workload, the opt-in thread mode is available today, and raising
`rt_os_workers()` for Windows later would be a performance change that does not alter the contract
(the "runs until it yields" rule is preserved by any number of scheduler threads).

**Enforced by.** `compiler/os-windows.grl` (fibers, `rt_os_reactor()` = 0, one scheduler thread),
`compiler/runtime.grl` (`rt_task_mode`/`rt_task_threads`, `rt_io`, `rt_offload`),
`compiler/os-linux.grl` and `compiler/darwin.grl` (the same context functions, stack-switch based),
`tools/windows.mjs` (`runtimeImports`) and `tools/test-windows.mjs` (declaration cross-check, fiber
imports for task cases, `GRAIL_TASKS` for the opt-in case). Executed evidence under Wine:
`tasks-scope-and-parallel-map`, `tasks-sleep-overlap`, `tasks-interleave-at-yield`,
`tasks-sleep-progress`, `tasks-read-file-offload`, `tasks-thread-mode`. Documentation:
[docs/ffi.md](../ffi.md) ("Task scheduling is the same on both platforms"),
[concurrency-v1.md](concurrency-v1.md), [windows-backend.md](windows-backend.md).

## B5: abort never unwinds

**Decision.** An abort terminates the process and runs nothing on the way out. Nothing may unwind
across the C boundary - that is a calling-convention obligation on the program, because the compiler
does not and will not enforce it. There is no `defer` statement: what looks like deferred cleanup is
the compiler's generated dropper calls at each scope exit, which exist on return paths only.

**What the runtime actually does** (checked against the code and by running it, because the earlier
assumption "cleanup runs before the abort" is not what happens):

- Every abort site calls `rt_abort` (`compiler/runtime.grl:3-7`): `kill(getpid(), SIGABRT)`, then
  `exit(134)`. On Windows `kill` is a no-op and the same function is `ExitProcess(134)`. There is no
    message - not to stdout, not to stderr - and the native abort cases (`arithmetic-abort-0`,
  `index-assignment-out-of-bounds-aborts`) check the signal `SIGABRT`; the harness compares no
  output on a signal case, so a message would go unnoticed. A probe printing `before abort` and
  then overflowing printed that line and died with 134 (shell: `Aborted (core dumped)`), with
  nothing on stderr.
- Nothing runs before it: no destructors in the aborting frame, none in any caller's frame, no
  `atexit`, no flush. Output that was already written survives because the runtime writes with
  unbuffered `write(2)` syscalls, not stdio buffers - that is the only reason the last line before
  an abort is not lost, and it is not cleanup.
- Abort sites are the runtime guards and the compiler-emitted checks: bounds, checked overflow,
  division by zero, `!` on a failed Option/Result, allocation failure, a `cstr` without its
  terminator, internal runtime invariants, and the end-of-`main` leak counter (`rt_live() != 0` ->
  `call rt_abort`, `compiler/native.grl:20426-20429`).
- There is nothing to unwind *with*: the ELF backend emits no CFI directives and no
  `.eh_frame`/`.debug_frame` (checked with `readelf -S` on a built executable: neither section
  exists). The only unwind data in the project is PE `.pdata` for Windows x86-64, which the OS
  unwinder requires and which contains no Grail handlers ([windows-backend.md](windows-backend.md)).
  A C++ exception thrown through a Grail frame therefore has no Grail cleanup to skip on Linux (it
  has no tables, so the runtime terminates) and may be walked over on Windows (skipping the drops
  that a normal return would have run).

**Alternatives considered.** (a) Unwinding-based cleanup with a `defer` statement: rejected for v1 -
it needs tables on every target, a defined interaction with the C ABI (`.eh_frame` on Linux,
`.pdata` handlers on Windows, and a decision about foreign exceptions), and it replaces deterministic
scope-exit destruction with an exception path that has to be proven to run exactly once. (b) Catch
and recover (`panic = abort` off): rejected, it is the same machinery plus a recovery contract, and
the ledger already rejects hidden blocking destructors and invisible failure paths. (c) Enforce
"nothing unwinds across C" with a compile-time check: rejected as impossible in principle - the
caller controls whether a foreign function throws - so it stays a documented obligation and a test
concern.

**Consequence if wrong.** If any later feature assumes unwinding (catching, error cleanup through
unwinding, a `defer`), every abort site, both backends' unwind data and the C ABI policy have to
change together; a half-unwinding runtime would run some drops and not others and lose the
deterministic-cleanup argument that owned values are freed exactly at their scope exit. If the
program relies on cleanup after a failed foreign call, it silently leaks or leaves a resource open
before dying.

**Enforced by.** `rt_abort` and the 100+ guard sites in `compiler/runtime.grl`; the compiler's
`call rt_abort` emissions at each guard and at the leak check (`compiler/native.grl`, e.g.
`20426-20429`); the absence of CFI/`.eh_frame` in `compiler/native.grl`'s emission; PE `.pdata`
without handlers; the native abort cases; and the "Abort paths do not unwind" statement in
[implementation-status.md](implementation-status.md).

## B6: references captured, FnMut implemented

**Decision.** The deferred part of this record is now implemented under exactly the rules it fixed.
`FnMut` is a distinct closure type; a closure that writes a capture is `FnMut`, calling one takes
exclusive access to the closure, and only written captures change mode.

Implemented and verified in `compiler/native.grl` (`closure_literal`, `capture_written_at`,
`capture_place`, `capture_assignment`, `capture_field`, `emit_closures`, `indirect_call`,
`call_access`, `require_type`, `base_named`):

- **Captures** are found as before. Plain values are copied, owned values move in, and a direct
  reference or view (`&T`, `&[T]`, `&mut T`) moves in as pointer *and* loan, with the borrowed
  region in the closure's type, so the closure still cannot outlive what it borrows
  (`returned borrow escapes its declared input lifetime`). An aggregate that merely holds a borrow
  is still not capturable.
- **Written captures.** The body is scanned for a store to a capture or to a place rooted at it
  (`n = ..`, `n op= ..`, `s.f = ..`, `v[i] = ..`, `*r = ..`), a mutable borrow of it (`&mut n`), and
  a method call on it that may mutate its receiver (a name in a read-only allowlist — `len`,
  `contains`, `get`, … — stays a read; any method call on a captured record or closure counts as a
  write). A capture is written if any of those appears; `Closure.written` records one flag per
  capture and `Closure.mode` is 1 when any flag is set.
- **Type.** `Fn(...)` and `FnMut(...)` are different types (`callable_contract` compares the mode, so
  `same_type` separates them). A `FnMut` closure used where `Fn` is required is rejected with
  `a closure that mutates a captured value is FnMut, not Fn: calling it needs exclusive access to
  the closure, so it cannot be used where a shared call is required`. That covers the `Fn(...)`
  parameter type, function values coerced to it, and the `pool` callbacks that reach a worker. The
  sequential stdlib callbacks (`vecs::sort_by`, `sort_by_key`, `fold`, `filter_nums`, …) were `Fn`
  when B6 landed and take `FnMut` since A12's first step (`closure-fnmut-sort-by-counts`).
- **Environment.** The closure body's hidden first parameter is `&Env` for `Fn` and `&mut Env` for
  `FnMut`, so a store reaches the environment field through an exclusive reference and the existing
  loan machinery has real authority to check. A store to a plain capture is compiled like `*r = v`
  (`capture_assignment`): read the field for `op=`, then `exchange_into` an exclusive reference to
  the field. `s.f = v` and `v[i] = v` route through the same reference, and `&mut capture` returns
  one. Only a *written* capture is mutable in the body; an unwritten exclusive reference or view is
  read-only there (`capture_readonly_type`), so an `Fn` closure cannot reach through a captured
  `&mut`.
- **Calls.** `indirect_call` on an `FnMut` value requires a mutable binding
  (`calling a FnMut closure needs a mutable binding (write: mut f = |...| { ... })`), takes an
  exclusive loan on the closure's own storage for the whole call — arguments included — and ends it
  when the call returns. A second simultaneous call (`f(f(1))`) or a live shared borrow of the
  closure is rejected with `calling a FnMut closure needs exclusive access to the closure: it is
  already borrowed or being called`. A closure with no written capture stays `Fn`: no mutable
  binding, repeated calls, and calls through a live shared reference all keep working.
- **Widening.** A closure that writes nothing is `Fn` and is accepted where `FnMut` is expected,
  because an exclusive call is a stricter promise than the shared call `Fn` makes: by value
  (`move_as`, one owner, never a copy) and as `&mut Fn(...)` for `&mut FnMut(...)`
  (`reference_as_fnmut`, same referent and loan, wider call contract). For a generic `FnMut(T) -> U`
  parameter whose variables the closure itself determines, the closure's signature is widened before
  inference (`widen_to_fnmut_formal`, `closure-fn-widens-to-generic-fnmut`). The reverse direction is
  the rejection above.

Evidence (native corpus, all executed on x86-64): `closure-fnmut-counter`,
`closure-fnmut-disjoint-captures`, `closure-fnmut-sequential-calls`,
`closure-fnmut-second-call-rejected`, `closure-fnmut-shared-borrow-rejected`,
`closure-fnmut-not-fn-rejected`, `closure-fnmut-sort-by-counts`,
`closure-shared-capture-still-fn`, `closure-shared-borrow-of-fn-closure`,
`closure-fnmut-vector-element`, `closure-fnmut-captured-field`,
`closure-fnmut-needs-mut-binding`, `closure-fnmut-through-exclusive-reference`,
`closure-fnmut-mixed-captures`, plus `closure-capture-mutation-fnmut` and
`closure-capture-borrow-mut-fnmut` (the two former read-only rejections, now accepted). The book
example `fnmut` runs in `bun tools/book.mjs check`. The pre-existing escape, aggregate-capture and
move rules keep their cases.

**Rejected rather than allowed** (each is a diagnostic, not a silent behaviour):

- A `FnMut` closure where an `Fn` is required — the aliasing hole rule 2 closes would otherwise be
  open through `sort_by`-style callbacks called from a shared context.
- Calling a `FnMut` closure through a `&FnMut`/`&Fn` reference — a shared reference to the closure
  cannot grant the exclusive access a call needs (`mutation through readonly frame`).
- A by-value `FnMut` *parameter* cannot be called in the callee: Grail parameters are not declared
  mutable, and calling one would need exactly that. Take `&mut FnMut(...)` instead, or move the
  parameter into a `mut` binding and call that, which is how the sequential stdlib callbacks take
  `FnMut` (`mut call = f;`). This is rule 5's shape.
- Using a captured `&mut` in a way the write scan does not recognise as a write is refused by the
  read-only field type rather than silently allowed. Handing a captured `&mut u64` to a function
  that takes `&mut u64` in a closure whose body writes nothing else reports plain
  `type mismatch` (the field is `&u64` there); the fix is to write through it (`*r = ..`), which is
  recognised as a write and makes the closure `FnMut`. Iterating a captured view mutably and
  calling a method on a shared-typed capture inside an `Fn` closure are refused the same way.

**Known limitations recorded, not fixed here:**

- A callable reached through a *reference parameter* (`&Fn`, `&mut Fn`, `&mut FnMut`) can be called
  once, in straight-line code. A second call, or a call inside an `if` or a loop, is rejected with
  `access has no live reference authority`. This is pre-existing: it reproduces on `origin/main`
  with `&Fn` and no `FnMut` involved, and it is why `apply`-style adapters are pinned with a single
  call. Fixing it belongs to the reference-parameter work, not to closures.
- The write scan is syntactic. A method call on a captured *record or closure* is always treated as
  a write (there is no cheap receiver-mode lookup at scan time), so a read-only method call on a
  captured record makes the closure `FnMut` and needs a `mut` binding. Builtin container methods
  outside the read-only allowlist are treated the same way.
- `mut`-declared parameters stay out of scope, as rule 6 says. `Send`/`Share` for closures was
  out of scope here and was taken up by the parallelism work instead: a closure's environment is
  part of its type now and `require_parallel_closure` classifies every capture
  (`docs/design/parallelism.md`).

**Consequence if wrong.** If the write scan misses a write, the closure stays `Fn` and the body
either refuses the store (the read-only field type) or — for a `&mut` capture the scan did not
flag — the call would not take the closure exclusively. The scan therefore errs towards calling a
use a write, and the field type is the second line of defence: broad corpus runs (796 native cases,
the stdlib, `abundance`, the book) found no case where the two disagree silently.

**Enforced by.** The compiler paths listed above; the native cases listed above; the book chapter
[closures.md](closures.md) (design) and the book chapter `book/chapters/closures.md` with its `fnmut`
example; the readiness rows A11/B6 in
[language-readiness.md](language-readiness.md) and [implementation-status.md](implementation-status.md).

## B7: byval record parameters accepted

**Decision.** An `extern "C"` record parameter is the C `R *` today, and stays so (Win32, Vulkan and
D3D12 are written that way). By-value struct arguments get one explicit spelling: **`v: byval R`**, a
parameter of `extern "C" record R` type marked `byval`, meaning the ABI passes the whole record as
C does. Implementation starts after B1 lands.

Implementation notes that follow from the decision (so the implementer does not re-decide):

- Reuse the per-ABI classification the compiler already has for record *results* - SysV eightbyte
  classes, AAPCS64 HFAs, RV64 flattening, Win64 shadow space plus hidden result pointer - for
  arguments, rather than writing a second classifier.
- Keep the bare `R` meaning `R *`. A silent switch to by-value for "small" records would change the
  meaning of existing signatures.
- `byval` is refused for anything that is not an `extern "C"` record, and for records whose
  classification is still unsupported (a result whose embedded records contain floats is already
  refused), so the new spelling never degrades to an approximation.
- [docs/ffi.md](../ffi.md) gains the syntax row and drops the corresponding Limits bullet;
  `tests/ffi/call_records.grl` extends to ImVec2-shaped two-float and mixed int/float records on
  every executed target.

**Alternatives considered.** (a) Implicit by-value when the record is small: rejected - a silent ABI
change that is invisible at the call site and differs per target. (b) A distinct wrapper type
(`by_value(R)`): rejected - two types for one layout, and layout/classification would have to be
duplicated. (c) Pointer-only, let callers copy into a temporary: rejected - ImGui's `ImVec2`
parameters take by value and hand-written temporaries at every call site are worse than a marker.

**Consequence if wrong.** A wrong spelling is a source-level break across the port, but a mechanical
one: the classification is shared with results, so only the marker changes. A wrong ABI
classification is worse - it miscompiles silently - which is why the implementation must extend the
executed record tests rather than adding a compile-only case.

**Enforced by.** [docs/ffi.md](../ffi.md) (the `byval` row and the syntax), readiness rows A3/B7, the
book example `byval-record`, and `tests/ffi/byval_records.grl` with its C twins in
`tests/ffi/byval_shim.c`: 4-, 8-, 16- and 24-byte records, mixed int/float fields, an ImVec2-shaped
float pair, an embedded array, a `byval` parameter after six integer arguments, a record sharing the
stack area with a following scalar, and a call through a `cfn` declaring the same signature - each
twin returns a checksum over every field it received, and the fixture executes on x86-64, AArch64 and
RISC-V 64. The refusals are pinned as `ffi-reject-byval-plain-record`, `ffi-reject-byval-scalar` and
`ffi-reject-byval-callback`, and the Windows x86-64/ARM64 refusal is the diagnostic
`byval is not implemented for the Windows x86-64 and Windows ARM64 ABIs; pass the record by
pointer`.

## Corrections to earlier documents

These were found while verifying the decisions. They are recorded rather than smoothed over,
because a stale claim is what makes a decided item get re-opened.

1. [runtime-api.md](runtime-api.md) opens with "the compiler does not yet accept `extern "C"`
   declarations". It does: [docs/ffi.md](../ffi.md) is the implemented contract and `tests/ffi` plus
   the Windows cases execute it on six targets. A premise note is added there in this change; the
   OS-API, capability and error design in that page still needs to be re-based on the FFI that
   exists before it is used as the capability plan.
2. [implementation-status.md](implementation-status.md) still has "User FFI boundary | Missing - no
   general extern C declarations". FFI is implemented, tested and documented; that row was
   outdated. Fixed in this change.
3. The same file's closures row says borrowing captures are missing. They are implemented, and so
   are mutating captures (`FnMut`); mutable/borrowed closure parameters remain out of scope. Fixed
   in this change and again when B6 landed.
4. [borg-agent-port.md](borg-agent-port.md) lists "No user FFI" (blocker 1) and "No macOS or
   Windows target at all" (blocker 3) as exact blockers. Both were resolved by the A-section work;
   blocker 8 ("no suspension-effect contract or cancellation rule for foreign blocking calls") is
   what B3 now answers. The list is annotated in this change; the remaining blockers stand.
5. [concurrency-v1.md](concurrency-v1.md) said "blocking foreign calls are explicitly isolated".
   Only `host::read_file`, `host::write_file` and `host::command` are, and only from a green task.
   Corrected to describe the offload that exists and the worker-blocking that does not.
6. README claimed Windows threads are missing while `windows-backend.md` documents them and the
   `thread-join`/`thread-wake` cases run under Wine; the same paragraph was duplicated. Corrected.
7. [language-readiness.md](language-readiness.md) row A11 said mutable/borrowed captures are open.
   Borrowed captures are implemented, `FnMut` landed under B6, and only mutable/borrowed closure
   parameters remain deferred. Updated.

## Not decided here

The vocabulary this page deliberately does not settle: the module-interface details beyond the
obligations in B1 (its plan of record is [separate-compilation.md](separate-compilation.md)), the
capability types and their names (B2's revisit trigger), a foreign-call offload trampoline
(B3's revisit trigger), the IOCP implementation (B4), any unwinding or `defer`
feature (B5), and any widening of `FnMut` beyond the six rules above (B6) — for example making a
by-value `FnMut` parameter callable, which needs `mut` parameters. Each of those is a design task
with a stated trigger, not an open question about these decisions.
