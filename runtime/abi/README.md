# Native OS ABI backends

This directory holds the platform side of the contract in `include/grail/`. Nothing here is
compiled into the Grail compiler or a Grail program: `compiler/native.grl` and
`compiler/runtime.grl` are unchanged. The Linux implementation is a **hosted C reference
backend** used to prove the contract and to act as a behavioural oracle. It deliberately uses
libc/POSIX and is not a replacement for the freestanding Grail runtime.

```
include/grail/            public C ABI (stable contract)
runtime/abi/              portable implementation + native backends
  grail_abi.c             version negotiation and output-copy helper
  grail_error.c           portable statuses, Win32/Mach mapping
  grail_unicode.c         strict UTF-8 / UTF-16
  grail_path.c            POSIX and Windows lexical rules (one file, two modes)
  grail_handle_table.[ch] generation-checked linear handles
  grail_error_posix.c     Linux errno mapping (hosted POSIX only)
  grail_env_store.[ch]    shared UTF-8 environment store and snapshots
  linux/                  hosted reference backend
  windows/                Win32 backend + fail-closed stubs
  macos/                  libSystem backend + fail-closed stubs
tests/abi/                C contract and behaviour tests
tools/abi-test.mjs        test runner (also `just abi-test`)
```

## Backend rules

1. **Fail closed.** While a domain is incomplete, `grail_os_capabilities()` must not report its
   bit and every entry point in that domain must return `GRAIL_E_UNSUPPORTED`. Never return a
   made-up success or silently run a "concurrent" API sequentially.
2. **Capabilities are all-or-nothing per advertised feature.** A domain may have separate bits
   (`FILE_METADATA`, `FILE_NONBLOCKING`, `SYMLINKS`); set one only after every function it
   covers is implemented and covered by a test on that platform.
3. **Handles are linear.** Use a generation-checked table (or an equivalent scheme). A stale,
   double-closed or cross-domain handle returns `GRAIL_E_INVALID_HANDLE`; it is never
   undefined behaviour and never names a reused resource.
4. **Allocation goes through `grail_allocator`.** Backend bookkeeping must use the hooks
   supplied at `grail_os_init`, so the runtime's allocation accounting stays exact. A backend
   that must use the platform allocator documents why.
5. **No blocking under a global lock.** Table lookup may be locked; I/O and waits must not be.
6. **Never read or clear `errno`/`GetLastError` at the ABI boundary.** Translate it immediately
   into a portable status and preserve the raw value with `grail_os_error_last`.
7. **No structure by value.** Add fields only at the end of a structure and gate them with
   `struct_size`; bump `abi_version` for a breaking change.
8. **Build shared-library backends with `GRAIL_ABI_BUILD`.** On Windows the public header
   declares the symbols `dllimport` for consumers; the defining translation units must set
   `GRAIL_ABI_BUILD` (or link statically with `GRAIL_ABI_STATIC`), or the compiler rejects the
   inconsistent attribute.

## Status

| Area | Contract | Portable implementation | Linux reference | Windows | macOS |
| --- | --- | --- | --- | --- | --- |
| Version/errors/Unicode | header | yes | n/a | n/a | n/a |
| Paths | header | POSIX + Windows rules, both tested | cwd, set-cwd, executable | cwd, set-cwd, executable | cwd, set-cwd, executable |
| Files/pipes | header | handle table | open/read/write/seek/truncate/sync/stat/close, pipe | open/read/write/seek/truncate/sync/stat/close, pipe | open/read/write/seek/truncate/sync/non-blocking/close, pipe |
| File metadata | header | format | stat | stat | not implemented |
| Directories | header | handle table | open/next/close, mkdir/remove/rename | open/next/close, mkdir/remove/rename | open/next/close, mkdir/remove/rename |
| Environment | header | env store | get/set/unset/iterate | get/set/unset/iterate | get/set/unset/iterate |
| Time | header | n/a | monotonic/realtime/CPU, sleep, local offset | monotonic/realtime/CPU, sleep | monotonic/realtime/CPU, sleep |
| Threads/sync | header | handle table | complete subset | thread/mutex/condvar | thread/mutex/condvar |
| Dynamic libraries | header | handle table | complete subset | LoadLibraryExW/GetProcAddress | dlopen/dlsym |
| Processes | header | options/status layout | fork/execve/wait4 subset | CreateProcessW subset | posix_spawn subset |
| Sockets/DNS | header | address layout | TCP/UDP IPv4+IPv6, options, DNS | not implemented | not implemented |

"Complete subset" means the documented functions are implemented and tested for that platform;
the shipping Grail implementation must reproduce the Linux semantics without the C layer. The
Linux reference includes child processes (fork/execve/wait4, argv/environment/cwd/stdio, PATH
search, wait-with-timeout, terminate/kill) and TCP/UDP sockets (IPv4 and IPv6 when the probe
succeeds, `accept4`, send/receive, shutdown, address queries, non-blocking mode, the documented
socket options and `getaddrinfo`). Readiness registration remains private to the shipping
runtime, and the C layer must not become a second scheduler.

The Windows and macOS backends are **statically verified implementations**: they
compile for Win64 and Apple ARM64 but have not been executed on those systems. Their
unimplemented functions are present as explicit `GRAIL_E_UNSUPPORTED` stubs, and their
capability words advertise only what is implemented. `GRAIL_CAP_FILE_METADATA` distinguishes
byte I/O from `file_stat`/`fs_stat`; Linux and Windows set it, macOS clears it.
`GRAIL_CAP_FILE_NONBLOCKING` covers `file_set_nonblocking` and
`GRAIL_OPEN_NONBLOCKING`; Linux and macOS set it, Windows clears it. `GRAIL_CAP_SYMLINKS`
covers `readlink`/`realpath` (not metadata); Linux and macOS set it, Windows clears it.

## Linux reference backend

Files: `linux/grail_os_linux.c` (init, environment, time, paths),
`linux/grail_os_linux_fs.c` (files, directories, pipes, stat),
`linux/grail_os_linux_thread.c` (pthreads, mutex, condvar, dlopen),
`linux/grail_os_linux_proc.c` (processes) and `linux/grail_os_linux_net.c` (sockets/DNS).

Deliberate limits, all visible in the API or capability word:

- `created_ns` is 0 (Linux `stat` has no birth time without `statx`; the shipping runtime
  should use `statx` and report `STATX_BTIME`).
- Process spawn/wait/timeout/terminate/kill are implemented with `fork`/`execve`/`wait4`; only
  async-signal-safe calls run between fork and exec, and an exec-error pipe reports the child's
  `errno`. `GRAIL_PROC_NO_WINDOW` is accepted as a no-op on Linux. `close` does not wait or
  kill, so an unreaped child can remain a zombie until process exit (documented in the header).
- Sockets are blocking by default and use `accept4(SOCK_CLOEXEC)`. IPv6 capability is probed at
  init. Unix-domain sockets are not part of this contract version.
- `realpath` uses the host C library's allocation; this is acceptable only in the oracle.
- Directory iteration uses `readdir`/`d_type` with an `fstatat` fallback.
- File descriptors are opened `O_CLOEXEC`; the process backend must duplicate explicit
  standard-stream handles rather than relying on inheritance.

## Windows implementation and remaining mapping

Implemented in `windows/grail_os_windows.c`: init/shutdown/capabilities/error detail;
monotonic, realtime and process/thread CPU clocks with `Sleep`; environment
get/set/unset/snapshot iteration; current directory, executable path; file
open/read/write/seek/truncate/sync/stat/close; pipes; path stat, mkdir (including parents),
remove and rename; `FindFirstFileW`/`FindNextFileW` directory iteration; `CreateThread`/
`WaitForSingleObject` threads; `SRWLOCK` mutexes and `CONDITION_VARIABLE` condition variables;
`LoadLibraryExW`/`GetProcAddress`/`FreeLibrary` with `FormatMessageW` loader errors.
Child processes use `CreateProcessW` with a validated argv/environment, UTF-16 environment
block, working directory, inheritable standard handles (explicit, inherited or NUL), Win32
search path, wait/timeout, terminate/kill and process ids. `windows/grail_os_windows_stubs.c`
returns `GRAIL_E_UNSUPPORTED` for non-blocking files, readlink/realpath, local-time offsets and
sockets. Capabilities are
`GRAIL_CAP_FILES | GRAIL_CAP_FILE_METADATA | GRAIL_CAP_PATHS | GRAIL_CAP_UNICODE |
GRAIL_CAP_ENVIRONMENT | GRAIL_CAP_ENV_MUTATION | GRAIL_CAP_TIME | GRAIL_CAP_CPU_TIME |
GRAIL_CAP_DIRECTORIES | GRAIL_CAP_THREADS | GRAIL_CAP_SYNC_PRIMITIVES |
GRAIL_CAP_DYNAMIC_LIBRARIES | GRAIL_CAP_PROCESSES`. Thread names are not applied,
`GRAIL_DL_LAZY`/`GLOBAL` are accepted as no-ops because Win32 has no direct equivalents, and
`terminate` falls back to `TerminateProcess` when no console control event can be delivered.

All paths cross the boundary as UTF-8 and are converted to UTF-16 with
`MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS)`; output paths use
`WideCharToMultiByte`. The declarations are pinned in `grail_win32.h` so a host without the
Windows SDK can compile-check the backend. The bullets below record the platform APIs used by
the implemented layer and the advanced options still to add.

- **Init:** `WSAStartup(MAKEWORD(2,2))`, initial environment snapshot from
  `GetEnvironmentStringsW`, console setup (`SetConsoleOutputCP(CP_UTF8)` and
  `SetConsoleCP(CP_UTF8)` or wide writes), thread-local error slot.
- **Paths:** validate UTF-8 and NULs; convert `/` to `\`; reject reserved device names or let
  the OS reject them (no silent rewriting); add the `\\?\` prefix for absolute paths that
  exceed `MAX_PATH` (normalise `.`/`..` first; `\\?\` disables Win32 normalisation); reject
  unpaired surrogates. `GetFullPathNameW` for `realpath`, `GetCurrentDirectoryW`/`SetCurrentDirectoryW`,
  `GetModuleFileNameW(NULL, ...)`, `GetLongPathNameW` where appropriate.
- **Files:** `CreateFileW` with `FILE_FLAG_BACKUP_SEMANTICS` for directories,
  `FILE_FLAG_OPEN_REPARSE_POINT` for `NO_FOLLOW`, `FILE_FLAG_OVERLAPPED` only for the
  runtime's private async paths; `ReadFile`, `WriteFile`, `SetFilePointerEx`,
  `SetEndOfFile`, `FlushFileBuffers`, `GetFileInformationByHandle`,
  `GetFileInformationByHandleEx(FileBasicInfo/FileStandardInfo)`,
  `GetFileAttributesExW` for path stat, `FindFirstFileW`/`FindNextFileW`/`FindClose` for
  directories. Map `FILETIME` 100 ns ticks to Unix epoch nanoseconds. Synthesise permission
  bits from the read-only attribute; report `GRAIL_STAT_READONLY`/`HIDDEN`/`SYMLINK`.
- **Processes:** `CreateProcessW` with `CREATE_UNICODE_ENVIRONMENT`,
  `CREATE_NEW_PROCESS_GROUP` for `NEW_GROUP`, `CREATE_NO_WINDOW` for `NO_WINDOW`, and
  `STARTF_USESTDHANDLES` with inheritable duplicates of the caller's handles. Build the
  command line with the documented MSVCRT quoting algorithm (backslash/quote runs) and
  `CreateProcessW(lpApplicationName=...)`; do not assume the first token is parsed like
  POSIX. Apply `PATHEXT` and the standard search order for `SEARCH_PATH`. Use
  `WaitForSingleObject` + `GetExitCodeProcess`, `TerminateProcess` for kill, and
  `GenerateConsoleCtrlEvent` for a best-effort terminate on a new process group. `term_signal`
  is always 0. `CloseHandle` closes the process handle; a running child continues.
- **Environment:** `GetEnvironmentVariableW`/`SetEnvironmentVariableW` for propagation,
  but reads/iteration use the runtime copy so enumeration is deterministic. Names and values
  are UTF-16 at the OS boundary; reject a NUL in the UTF-8 input.
- **Time:** `QueryPerformanceCounter`/`QueryPerformanceFrequency` for monotonic, and
  `GetSystemTimePreciseAsFileTime` for realtime; `GetProcessTimes`/`GetThreadTimes` for CPU
  clocks; `Sleep`/`SleepConditionVariableSRW` for blocking waits; `GetTimeZoneInformationForYear`
  (not a single global bias) for `local_offset`.
- **Threads/sync:** `CreateThread` (or `_beginthreadex` if a CRT is present), deferred close via
  a reference-counted record, `SetThreadDescription` for names, `WaitForSingleObject` +
  `GetExitCodeThread` for join, `CloseHandle` for detach/consume, `SRWLOCK` for mutex,
  `CONDITION_VARIABLE` + `SleepConditionVariableSRW` for condvar. `FlsAlloc` if the runtime
  needs thread-local slots.
- **Dynamic libraries:** `LoadLibraryExW` with `LOAD_LIBRARY_SEARCH_DEFAULT_DIRS` or
  `LOAD_WITH_ALTERED_SEARCH_PATH` chosen explicitly, `GetProcAddress`, `FreeLibrary`,
  `FormatMessageW` for `grail_os_dl_error`. An empty name means `GetModuleHandleW(NULL)`.
- **Sockets/DNS:** `WSASocketW`, `bind`, `listen`, `accept` (or `AcceptEx` only through the
  private reactor), `connect`, `WSASend`/`WSARecv`, `sendto`/`recvfrom`, `shutdown`,
  `closesocket`, `setsockopt`/`getsockopt`, `ioctlsocket(FIONBIO)`, `getaddrinfoW` with
  `AI_ADDRCONFIG` semantics documented. Sockets are `SOCKET` values, not file handles, so the
  handle table must keep them in a distinct domain. `WSAStartup` failure must fail
  `grail_os_init`, not each call.

C-to-Graal callback invocation is a later FFI increment. Until it lands, allocator hooks and
thread entry points remain on the C/backend side and are not claimed as Grail-callable.

Prerequisite outside this directory: Grail codegen currently uses a SysV-like integer
convention. Win64 uses `rcx, rdx, r8, r9`, 32 bytes of shadow space, different callee-saved
registers and a 128-byte red zone is absent. Calling these symbols from generated code needs a
Win64 codegen path; the ABI's six-argument ceiling keeps that path free of stack arguments.

## macOS implementation

Implemented in `macos/grail_os_macos.c` with declarations pinned in `grail_macos.h`:
init/shutdown/capabilities/error detail; `clock_gettime`/`clock_getres`/`nanosleep` for
realtime, monotonic, process and thread CPU clocks; environment get/set/unset/snapshot
iteration; `getcwd`/`chdir` and `_NSGetExecutablePath`+`realpath`; file
open/read/write/seek/truncate/sync/set-non-blocking/close with `O_CLOEXEC`; pipes with
`FD_CLOEXEC`; mkdir (including parents)/remove/rename, readlink and realpath;
`opendir`/`readdir` directory iteration with a pinned 64-bit `struct dirent`;
`pthread_create`/`pthread_join`/`pthread_detach` threads; pthread mutexes and relative-time
condition variables; `dlopen`/`dlsym`/`dlclose` with loader error text.
Child processes use `posix_spawn` with argv/environment blocks, file actions for stdio and
working directory, `NEW_GROUP` via `POSIX_SPAWN_SETPGROUP`, and `waitpid` wait/timeout plus
`kill` terminate/kill. `macos/grail_os_macos_stubs.c` returns `GRAIL_E_UNSUPPORTED` for
metadata, local-time offsets and sockets. Capabilities are
`GRAIL_CAP_FILES | GRAIL_CAP_FILE_NONBLOCKING | GRAIL_CAP_PATHS | GRAIL_CAP_UNICODE |
GRAIL_CAP_ENVIRONMENT | GRAIL_CAP_ENV_MUTATION | GRAIL_CAP_TIME | GRAIL_CAP_CPU_TIME |
GRAIL_CAP_SYMLINKS | GRAIL_CAP_DIRECTORIES | GRAIL_CAP_THREADS |
GRAIL_CAP_SYNC_PRIMITIVES | GRAIL_CAP_DYNAMIC_LIBRARIES | GRAIL_CAP_PROCESSES`;
`GRAIL_CAP_FILE_METADATA` is clear because no `struct stat` layout is pinned yet.

## macOS implementation and remaining mapping

- **Init:** environment snapshot from `environ` (copy and validate UTF-8), thread-local error
  slot; no libc `setenv` dependency required for reads.
- **Paths:** pass UTF-8 bytes to libSystem; `getcwd`, `chdir`, `_NSGetExecutablePath` (then
  `realpath`), `realpath`, `readlink`. No normalisation is performed; APFS/HFS+ may store NFD.
- **Files/dirs:** `open` with `O_CLOEXEC`, `O_NOFOLLOW`, `O_DIRECTORY`, `O_NONBLOCK`;
  `read`/`write`, `lseek`, `ftruncate`, `fsync`/`fcntl(F_FULLFSYNC)` for the stronger sync
  where requested, `fstat`/`lstat`/`stat`, `getdirentries` or `fdopendir`/`readdir`,
  `mkdir`/`unlink`/`rmdir`/`rename`, `pipe`. `st_birthtimespec` supplies `created_ns`.
- **Processes:** `posix_spawn` with `POSIX_SPAWN_SETPGROUP`, explicit
  `posix_spawn_file_actions_adddup2` for standard streams, and an explicit `envp`; avoid
  `fork` in a runtime with threads. `waitpid` for wait, `kill(SIGTERM)`/`kill(SIGKILL)` for
  terminate/kill, `WNOHANG` for `wait_timeout`. PATH search is implemented with the platform
  search rules when requested.
- **Environment:** `getenv` only while single-threaded; after init, reads use the runtime copy.
  Mutations call `setenv`/`unsetenv` for child inheritance.
- **Time:** `clock_gettime(CLOCK_MONOTONIC/CLOCK_REALTIME)` or `mach_absolute_time` for
  monotonic; `gettimeofday` for realtime; `getrusage`/`thread_info` for CPU clocks;
  `nanosleep`; `localtime_r` + `tm_gmtoff` (with the 32/64-bit `time_t` caveat documented).
- **Threads/sync:** `pthread_create` with a stack-size attribute, `pthread_setname_np` (may
  reject names; truncate), `pthread_join`, `pthread_detach`, `pthread_mutex_t`,
  `pthread_cond_t` with `pthread_cond_timedwait_relative_np` (no `pthread_condattr_setclock`
  on older SDKs), `sched_yield`.
- **Dynamic libraries:** `dlopen` with `RTLD_LAZY`/`RTLD_NOW` and `RTLD_GLOBAL`/`RTLD_LOCAL`,
  `dlsym`, `dlclose`, `dlerror`; empty name means the main executable.
- **Sockets/DNS:** BSD sockets; there is no `accept4`, so `accept` + `fcntl(FD_CLOEXEC)` +
  `FIONBIO`; `getaddrinfo`/`freeaddrinfo`, `send`/`recv`/`sendto`/`recvfrom`, `shutdown`,
  `setsockopt`/`getsockopt`. Readiness uses kqueue in the private runtime, not this ABI.

Prerequisite outside this directory: Mach-O emission, Apple ARM64 symbol naming and the
SDK/linker inputs are the macOS lane's work. The ABI only defines the runtime service calls.

## Static cross-target evidence and limits

`bun tools/abi-test.mjs` compiles the portable sources plus each backend (including the stub
translation unit) with:

```sh
clang -target x86_64-pc-windows-msvc -ffreestanding -c -std=c11 -Wall -Wextra \
      -Wshadow -Wconversion -Wsign-conversion -Werror -DGRAIL_ABI_BUILD -Iinclude <sources>
clang -target aarch64-pc-windows-msvc -ffreestanding -c ... <same sources>
clang -target arm64-apple-macos11 -ffreestanding -c ... <same sources>
clang -target x86_64-apple-macos11 -ffreestanding -c ... <same sources>
```

It then unions `llvm-nm -g --defined-only` over the objects and checks that all 95 public
functions from `include/grail/*.h` are defined for all four targets. The runner requires
`clang` and `llvm-nm`.

Limits of this evidence:

- The backends have **not been executed** on Windows or macOS; no runtime behaviour is claimed.
- The Windows time layer requires `GetSystemTimePreciseAsFileTime` (Windows 8/Server 2012 or
  later). The macOS time layer requires `clock_gettime` and `os_unfair_lock` (macOS 10.12 or
  later).
- `_Thread_local` error detail assumes static/direct TLS; a DLL build needs an explicit TLS
  strategy before it can claim thread-local detail.
- Windows `NO_FOLLOW`/symlink metadata is limited by `GetFileAttributesExW`; `GRAIL_CAP_SYMLINKS`
  is clear. `mode` is not represented by Win32 file creation, and `file_truncate` moves the
  file pointer. Directory patterns use the normal Win32 path rules, not `\\?\` long paths.
  Thread names are ignored and `GRAIL_DL_LAZY`/`GLOBAL` are no-ops on Windows; parent
  creation for UNC paths is not supported. Windows `SEARCH_PATH` uses the native Win32 search
  order and parent environment, and the environment block is emitted in runtime order. macOS
  `posix_spawn_file_actions_addchdir_np` requires macOS 10.15 or later, and `NO_WINDOW` is a
  no-op. Process-close never waits or kills on either platform. macOS `rename` without `GRAIL_RENAME_REPLACE`
  checks existence with `access`; the check is best-effort and races with a concurrent
  creator. The pinned Darwin `struct dirent` layout is used without the SDK, and `DT_UNKNOWN`
  entries report `GRAIL_FILE_KIND_UNKNOWN` because metadata is unavailable. Thread names are
  applied with `pthread_setname_np`. `GRAIL_THREAD_DETACHED` is rejected on all backends; use
  `grail_os_thread_detach`.
- The Win32 and Darwin declarations are pinned, not taken from the SDK. They match the 64-bit
  ABI used here, but a real platform build should compare them with the current SDK headers.
- macOS metadata is deliberately absent; `struct stat` was not declared without an SDK.
- Windows long-path (`\\?\`) and reserved-name policy are not implemented; directory
  enumeration uses the normal Win32 path rules.
- The Win64 codegen path in the compiler is still a prerequisite for calling these symbols from
  generated Grail code; the C backend compiles independently of that.

## Porting checklist

1. Implement `grail_os_init`/`shutdown`/`capabilities`/`error_last` and the allocator plumbing.
2. Add the handle tables and the error translation table; test stale/double-close handles.
3. Implement one domain at a time; after its tests pass, set its capability bit.
4. Keep the C contract test (`tests/abi/test_headers.c`) compiling for the target and add a
   native behaviour test that exercises every implemented entry point.
5. Do not expose raw OS errors, descriptors, pointers or scheduler objects through the public
   ABI. The safe Grail surface is defined in `docs/design/runtime-api.md`.
