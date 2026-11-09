# Language readiness before graphics and porting

Audit date: 2026-11-09, against `main` with the nested-record, float-record and CodeView-locals work.
Priority is Windows first, then Linux, then macOS. Evidence is the compiler, the test suites and
the design notes named below; `implementation-status.md` is current except where noted.

## A. Core work - status (2026-11-09)

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| A1 | FFI floats | **Done** for direct and `cfn` calls and for callbacks (parameters and results) on SysV, Win64, AAPCS64, RV64 LP64D | `tests/ffi/call_abi.grl`, `callback_floats.grl` on 3 Linux targets + Windows x64 (Wine) |
| A2 | FFI narrow integers | **Done** for calls and callbacks (callee-side extension), and narrow C-record field stores write only their width | same; native case `ffi-c-record-narrow-assign` |
| A3 | C records by value | **Done except by-value arguments**: results in registers or a hidden pointer on every ABI, including float-field results (SysV eightbyte classes, AAPCS64 HFAs, RV64 flattening); `f32`/`f64` fields; nested records embedded by value. Remaining: records passed *by value* as arguments (needs syntax, see B7) | `call_records.grl`, `float_records.grl`, `float_record_results.grl`, `nested_records.grl` |
| A4 | Stack arguments / variadic | **Done**: any number of arguments; variadic C calls on SysV, Win64, AAPCS64 (Linux and Apple's stack convention), RV64 | `call_variadic.grl` on 3 Linux targets + Windows x64; `test-macos` (static) |
| A5 | Windows FFI / COM | **Done**: `extern "C"` calls and callbacks (Win64 thunk); COM methods of any arity and with floats through a typed `cfn` vtable slot | Windows suite: 33 checks, 19 under Wine; `call_com_slot.grl` |
| A6 | Dynamic loading | **Done**: Windows x64 (Wine), Linux x86-64/AArch64/RISC-V (host-TLS bridge; executed under qemu with glibc sysroots), macOS linked for both targets | `dlopen.grl`, `ffi-dynamic-loading`, `test-macos` |
| A7 | Stdlib on Windows | **Done** for files, sockets, processes/threads, output capture | `tools/test-ffi-runtime-windows.mjs`, 4 tests under Wine |
| A8 | Typed OS errors on Windows | **Done** for the host layer (`GetLastError` -> errno) | `io-error-mapping` Wine case |
| A9 | Process stdio capture | **Done** (`pipe`, `spawn_with`, `read_to_end`) | Linux + Wine |
| A10 | Windows ARM64 threads | **Done statically** (bridge emitted and published); no ARM64 Windows runner | ARM64 static checks |
| A11 | Mutable/borrowed captures, borrowed closure params | **Open - needs a design decision** (see B6) | `docs/design/closures.md` |
| A12 | Iteration | **Partial**: `vecs::fold` (any type), `any/all/count/position_num`; generic predicates need A11 | native case `vecs-fold-and-predicates` |
| A13 | Debug info | **Done for line tables and typed locals**: DWARF lines + base types on Linux x86-64, AArch64 and RISC-V 64 (`--verify` clean; gdb prints typed locals); CodeView on Windows x64 with line tables and S_GPROC32/S_REGREL32 symbols (typed, rbp-relative parameters and locals) in the PDB. Remaining: record/string member layout (owned values show as their 8-byte handle) | `tools/test-debug-lines.mjs` |

Remaining implementable core gap: record and string member layout in the debug info. Everything
else in A1-A13 is either done or waits on a decision in section B (by-value record arguments need
B7's syntax; closures need B6).

## B. Decisions needed from the project owner before implementation

| # | Decision | Evidence |
| --- | --- | --- |
| B1 | **Separate compilation and checked module interfaces.** The compiler reads every module and emits one assembly file. Borg (about 363,000 lines) cannot be built that way; Abundance probably can at first. Needs a module-interface design. | `implementation-status.md`, `borg-agent-port.md` blocker 2 |
| B2 | **Authority / capability model** for OS access (ambient `host::` functions today). | `implementation-status.md` |
| B3 | **Suspension and blocking contract** for foreign calls inside green tasks (what happens when a task calls a blocking DLL function). | `implementation-status.md`, `concurrency-v1.md` |
| B4 | **Windows I/O readiness model**: the green-task reactor is epoll-only; Windows needs IOCP (or a documented thread-per-blocking-call policy). | `runtime.grl` |
| B6 | **Closure capture model**: mutable captures (FnMut) and closure parameters that hold borrows need lifetime rules for the closure object - either region-bounded closures (cannot escape the borrow's scope) or by-reference capture cells with explicit `move`. Generic iterator adapters over borrowed elements depend on it. | `docs/design/closures.md` |
| B7 | **Records passed by value to C**: an `extern "C" record` parameter is the C `R *` today (what Win32, Vulkan and D3D12 use). By-value struct arguments (ImGui `ImVec2`, some SDL calls) need a spelling, e.g. `v: byval R`, and per-ABI classification. | `docs/ffi.md` |
| B5 | **Abort/unwind policy**: abort paths do not unwind, and nothing may unwind across the C boundary. | `implementation-status.md` |

## C. Libraries (not language core; needed by the ports, scheduled with them)

JSON with exact numbers, TOML, regex/glob, base64/uuid, hashes and crypto, TLS (system stack via
FFI recommended), HTTP, compression and image codecs, arenas and channels.

## Order

A1-A5 (one compiler batch), A6, A7-A9, A10, A11-A12, A13; one bootstrap refresh per compiler
batch. B-items are raised with the project owner rather than decided here. Graphics work (D3D12
pipelines, presentation, Metal) waits for the checkpoint after section A.
