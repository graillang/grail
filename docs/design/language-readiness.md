# Language readiness before graphics and porting

Audit date: 2026-11-08, against `main` (compiler with the host-TLS bridge, `a3babb1` and later).
Priority is Windows first, then Linux, then macOS. Evidence is the compiler, the test suites and
the design notes named below; `implementation-status.md` is current except where noted.

## A. Core work - status (2026-11-08)

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| A1 | FFI floats | **Done** for direct and `cfn` calls on SysV, Win64, AAPCS64, RV64 LP64D; exported callbacks still integer-only | `tests/ffi/call_abi.grl` on 3 Linux targets + Windows x64 (Wine) |
| A2 | FFI narrow integers | **Done** (same scope), with result re-extension and RV64 `u32` sign-extension | same |
| A3 | C records by value | **Results done** (registers and hidden result pointer, all ABIs); records as *arguments* by value, nested records and records with float fields remain | `tests/ffi/call_records.grl` on 3 Linux targets + Windows x64 |
| A4 | Stack arguments / variadic | **Stack arguments done** (64 words, 2 KiB); variadic C calls remain | `call_abi` ten-argument cases |
| A5 | Windows FFI path | **Done** for `extern "C"` calls and callbacks (Win64 thunk preserving rdi/rsi/xmm6-15); COM intrinsics still 4 integer arguments | Windows suite: 29 checks, 15 under Wine |
| A6 | Windows dynamic loading | **Done** (x64) | `ffi-dynamic-loading` Wine case |
| A7 | Stdlib on Windows | **Done** for files, sockets, processes/threads, output capture | `tools/test-ffi-runtime-windows.mjs`, 4 tests under Wine |
| A8 | Typed OS errors on Windows | **Done** for the host layer (`GetLastError` -> errno) | `io-error-mapping` Wine case |
| A9 | Process stdio capture | **Done** (`pipe`, `spawn_with`, `read_to_end`) | Linux + Wine |
| A10 | Windows ARM64 threads | **Done statically** (bridge emitted and published); no ARM64 Windows runner | ARM64 static checks |
| A11 | Mutable/borrowed captures, borrowed closure params | **Open - needs a design decision** (see B6) | `docs/design/closures.md` |
| A12 | Iteration | **Partial**: `vecs::fold` (any type), `any/all/count/position_num`; generic predicates need A11 | native case `vecs-fold-and-predicates` |
| A13 | Windows debug info | **Line tables done** (CodeView + PDB, unwind preserved); types, locals in PDB, debugger attach remain | `tools/test-debug-lines.mjs` |

Remaining implementable core gaps: records as by-value *arguments* and nested/float records,
variadic C calls, float/narrow callback parameters, COM beyond four integer arguments, DWARF and
CodeView type information, AArch64/RISC-V/macOS dynamic loading.

## B. Decisions needed from the project owner before implementation

| # | Decision | Evidence |
| --- | --- | --- |
| B1 | **Separate compilation and checked module interfaces.** The compiler reads every module and emits one assembly file. Borg (about 363,000 lines) cannot be built that way; Abundance probably can at first. Needs a module-interface design. | `implementation-status.md`, `borg-agent-port.md` blocker 2 |
| B2 | **Authority / capability model** for OS access (ambient `host::` functions today). | `implementation-status.md` |
| B3 | **Suspension and blocking contract** for foreign calls inside green tasks (what happens when a task calls a blocking DLL function). | `implementation-status.md`, `concurrency-v1.md` |
| B4 | **Windows I/O readiness model**: the green-task reactor is epoll-only; Windows needs IOCP (or a documented thread-per-blocking-call policy). | `runtime.grl` |
| B6 | **Closure capture model**: mutable captures (FnMut) and closure parameters that hold borrows need lifetime rules for the closure object - either region-bounded closures (cannot escape the borrow's scope) or by-reference capture cells with explicit `move`. Generic iterator adapters over borrowed elements depend on it. | `docs/design/closures.md` |
| B5 | **Abort/unwind policy**: abort paths do not unwind, and nothing may unwind across the C boundary. | `implementation-status.md` |

## C. Libraries (not language core; needed by the ports, scheduled with them)

JSON with exact numbers, TOML, regex/glob, base64/uuid, hashes and crypto, TLS (system stack via
FFI recommended), HTTP, compression and image codecs, arenas and channels.

## Order

A1-A5 (one compiler batch), A6, A7-A9, A10, A11-A12, A13; one bootstrap refresh per compiler
batch. B-items are raised with the project owner rather than decided here. Graphics work (D3D12
pipelines, presentation, Metal) waits for the checkpoint after section A.
