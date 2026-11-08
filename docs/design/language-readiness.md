# Language readiness before graphics and porting

Audit date: 2026-11-08, against `main` (compiler with the host-TLS bridge, `a3babb1` and later).
Priority is Windows first, then Linux, then macOS. Evidence is the compiler, the test suites and
the design notes named below; `implementation-status.md` is current except where noted.

## A. Core work to finish now (implementable, needed by both ports)

| # | Gap | Evidence | Why it blocks |
| --- | --- | --- | --- |
| A1 | **Done for direct calls** (callbacks and `cfn` remain): **FFI floats**: `f32`/`f64` arguments and results are rejected at the C boundary on every ABI (SysV, AAPCS64, RV64, Win64) | `docs/ffi.md` "Not implemented" | every graphics, audio, math and most Win32 APIs pass floats |
| A2 | **Done for direct calls** (callbacks and `cfn` remain): **FFI narrow integers**: `i8`..`u32` at the boundary, with C sign/zero extension | `docs/ffi.md` | Win32 is built on 32-bit `DWORD`/`BOOL`/`UINT`/`HRESULT` |
| A3 | **C structs by value**: passing and returning records (SysV eightbytes, `sret`, Win64 rules), nested records, records holding floats or pointers | `docs/ffi.md` | `RECT`, `POINT`, `LARGE_INTEGER`, every descriptor struct |
| A4 | **Stack arguments done for direct calls; variadic remains**: **More than six argument words** (stack arguments) and variadic C calls | `docs/ffi.md` | `CreateWindowExW` has 12 arguments; `printf`-style logging |
| A5 | **Done for direct `extern "C"` calls (Wine-executed); COM intrinsics still 4 integer arguments**: **Windows FFI path**: `extern "C"` calls on PE targets with the full Win64 convention, and COM calls beyond 4 integer arguments | `docs/design/windows-backend.md` COM limits | COM methods take floats and long argument lists |
| A6 | **Windows dynamic loading**: `LoadLibraryW`/`GetProcAddress`/`FreeLibrary` through extern declarations, executed under Wine | dynamic loading is Linux x86-64 only (`docs/ffi.md`) | plugins, optional system DLLs, GPU runtimes |
| A7 | **Stdlib on Windows**: run the `sys_grail` file/socket/process/thread/time/env wrappers on Windows (the C ABI passes 47 Wine checks; the Grail wrappers have only run on Linux) | `tools/test-ffi-runtime.mjs` is Linux-only | a program that runs on Linux must run on Windows |
| A8 | **Typed OS errors across platforms**: `io::Error` maps six Linux errno values; Win32 `GetLastError` codes are not mapped | `lib/io.grl` | every fallible OS call on Windows reports `Other(code)` |
| A9 | **Process stdio capture** (pipes to a child's stdin/stdout/stderr) | `docs/design/grail-ffi-runtime.md` limits | build tools, compilers, any subprocess integration |
| A10 | **Windows ARM64 thread creation** | `docs/design/windows-backend.md` | threads are part of the core runtime contract |
| A11 | **Mutable and borrowed closure captures** (`FnMut`) and coercing named functions to `Fn` | `docs/design/closures.md` "Not yet" | callbacks that accumulate, visitors, event handlers |
| A12 | **Iteration**: `filter`/`fold`/`any`/`all` and an iterator protocol (only eager `map` and `sort` exist) | `lib/vecs.grl` | ordinary data processing in both ports |
| A13 | **Windows debug info**: CodeView/PDB, so Windows debuggers can show lines and locals (DWARF exists only for Linux x86-64, without type DIEs) | `docs/tooling` | debugging customer crashes on Windows |

## B. Decisions needed from the project owner before implementation

| # | Decision | Evidence |
| --- | --- | --- |
| B1 | **Separate compilation and checked module interfaces.** The compiler reads every module and emits one assembly file. Borg (about 363,000 lines) cannot be built that way; Abundance probably can at first. Needs a module-interface design. | `implementation-status.md`, `borg-agent-port.md` blocker 2 |
| B2 | **Authority / capability model** for OS access (ambient `host::` functions today). | `implementation-status.md` |
| B3 | **Suspension and blocking contract** for foreign calls inside green tasks (what happens when a task calls a blocking DLL function). | `implementation-status.md`, `concurrency-v1.md` |
| B4 | **Windows I/O readiness model**: the green-task reactor is epoll-only; Windows needs IOCP (or a documented thread-per-blocking-call policy). | `runtime.grl` |
| B5 | **Abort/unwind policy**: abort paths do not unwind, and nothing may unwind across the C boundary. | `implementation-status.md` |

## C. Libraries (not language core; needed by the ports, scheduled with them)

JSON with exact numbers, TOML, regex/glob, base64/uuid, hashes and crypto, TLS (system stack via
FFI recommended), HTTP, compression and image codecs, arenas and channels.

## Order

A1-A5 (one compiler batch), A6, A7-A9, A10, A11-A12, A13; one bootstrap refresh per compiler
batch. B-items are raised with the project owner rather than decided here. Graphics work (D3D12
pipelines, presentation, Metal) waits for the checkpoint after section A.
