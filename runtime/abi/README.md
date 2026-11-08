# Native OS ABI backends

This directory holds the platform side of the contract in `include/grail/`. Nothing here is
compiled into the Grail compiler or a Grail program: `compiler/native.grl` and
`compiler/runtime.grl` are unchanged. The Linux implementation is a **hosted C reference
backend** used to prove the contract and to act as a behavioural oracle. It deliberately uses
libc/POSIX and is not a replacement for the freestanding Grail runtime.

```
include/grail/            public C ABI (stable contract)
runtime/abi/              portable implementation + backend skeletons
  grail_abi.c             version negotiation and output-copy helper
  grail_error.c           portable statuses, errno/Win32/Mach mapping
  grail_unicode.c         strict UTF-8 / UTF-16
  grail_path.c            POSIX and Windows lexical rules (one file, two modes)
  grail_handle_table.[ch] generation-checked linear handles
  linux/                  hosted reference backend
  windows/                skeleton; every entry point returns UNSUPPORTED
  macos/                  skeleton; every entry point returns UNSUPPORTED
tests/abi/                C contract and behaviour tests
tools/abi-test.mjs        test runner (also `just abi-test`)
```

## Backend rules

1. **Fail closed.** While a domain is incomplete, `grail_os_capabilities()` must not report its
   bit and every entry point in that domain must return `GRAIL_E_UNSUPPORTED`. Never return a
   made-up success or silently run a "concurrent" API sequentially.
2. **Capabilities are all-or-nothing per domain.** Set a bit only after every function in that
   domain is implemented and covered by a test on that platform.
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
| Paths | header | POSIX + Windows rules, both tested | cwd, set-cwd, executable | skeleton | skeleton |
| Files/dirs/pipes | header | handle table | complete subset | skeleton | skeleton |
| Environment | header | iterator rules | complete subset | skeleton | skeleton |
| Time | header | n/a | complete subset | skeleton | skeleton |
| Threads/sync | header | handle table | complete subset | skeleton | skeleton |
| Dynamic libraries | header | handle table | complete subset | skeleton | skeleton |
| Processes | header | options/status layout | fork/execve/wait4 subset | skeleton | skeleton |
| Sockets/DNS | header | address layout | TCP/UDP IPv4+IPv6, options, DNS | skeleton | skeleton |

"Complete subset" means the documented functions are implemented for the host POSIX surface;
the shipping Grail implementation must reproduce the semantics without the C layer. The Linux
reference now includes child processes (fork/execve/wait4, argv/environment/cwd/stdio, PATH
search, wait-with-timeout, terminate/kill) and TCP/UDP sockets (IPv4 and IPv6 when the probe
succeeds, `accept4`, send/receive, shutdown, address queries, non-blocking mode, the documented
socket options and `getaddrinfo`). Readiness registration remains private to the shipping
runtime, and the C layer must not become a second scheduler.

## Linux reference backend

Files: `linux/grail_os_linux.c` (init, environment, time, paths), `linux/grail_os_linux_fs.c`
(files, directories, pipes, stat), `linux/grail_os_linux_thread.c` (pthreads, mutex, condvar,
dlopen), `linux/grail_os_linux_proc.c` and `linux/grail_os_linux_net.c` (explicit
`UNSUPPORTED`).

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

## Windows mapping (for the Windows backend lane)

Every function in the public headers has a Win32/Winsock counterpart. The skeleton implements
none of them; this table is the implementation checklist. All paths cross the boundary as UTF-8
and must be converted to UTF-16 with `MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS)`.

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

## macOS mapping (for the macOS backend lane)

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

## Porting checklist

1. Implement `grail_os_init`/`shutdown`/`capabilities`/`error_last` and the allocator plumbing.
2. Add the handle tables and the error translation table; test stale/double-close handles.
3. Implement one domain at a time; after its tests pass, set its capability bit.
4. Keep the C contract test (`tests/abi/test_headers.c`) compiling for the target and add a
   native behaviour test that exercises every implemented entry point.
5. Do not expose raw OS errors, descriptors, pointers or scheduler objects through the public
   ABI. The safe Grail surface is defined in `docs/design/runtime-api.md`.
