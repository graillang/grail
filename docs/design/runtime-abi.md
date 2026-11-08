# Cross-platform OS ABI (contract and scaffold)

2026-11-08. Status: **proposal plus scaffolded implementation**. The C headers under
`include/grail/` are the normative contract. Portable pieces (versioning, error mapping,
Unicode, lexical paths) are implemented and tested; the Linux reference shim implements files,
directories, environment, time, threads, dynamic libraries, child processes and TCP/UDP
sockets. Windows and macOS have statically verified backends for init/time/environment/
cwd/executable, file basics, directory iteration, threads/synchronization and dynamic
libraries, with every unimplemented function explicitly fail-closed. Nothing here is linked into Grail programs yet, and no C source is part of the
compiler or runtime build.

The runtime today is Linux-only: `compiler/runtime.grl` maps portable operation IDs to Linux
syscalls behind `rt_syscall`, emits freestanding ELF, and exposes a small `host::*` builtin
surface. This contract generalises that boundary without changing the language or
`compiler/native.grl`. It is also the type vocabulary that `extern "C"` declarations use, so
the FFI lane and the OS backend cannot drift apart.

## Why a separate boundary

- Grail's internal calling convention passes up to six word arguments in registers and
  returns one word. The ABI keeps every function at six arguments or fewer, every scalar at
  64 bits and every structure behind a pointer, so no stack-argument or aggregate-classification
  rule is needed on x86-64, AArch64 or RISC-V 64.
- Linux syscall numbers, Win32 calls and Mach/libSystem calls stay behind per-platform shims.
  Runtime code sees only the portable statuses and handles defined here.
- C hosts and C libraries see ordinary `extern "C"` symbols with fixed-width scalars, opaque
  handles and pointer-passed structures.

## Normative boundary rules

1. Every scalar argument and result is 64 bits. Sub-word C types are not used across the
   boundary; enums are passed as `uint64_t` values.
2. No structure is passed or returned by value. Structures cross as pointers to caller- or
   callee-owned storage and have explicit field order.
3. No floating-point value crosses this ABI.
4. Byte inputs are `(const uint8_t *, uint64_t length)` pairs. They are UTF-8 where the
   contract says text; they are never NUL-terminated at the boundary and may contain zero
   bytes only where the contract allows it.
5. Byte outputs are `(uint8_t *out, uint64_t capacity)` pairs. The call returns the required
   length; a value greater than `capacity`, or a NULL `out`, means nothing was written and
   the caller must retry with a larger buffer.
6. A negative `grail_status` or `grail_result` is a portable error. Zero is success. There
   are no positive statuses.
7. Handles are non-zero 64-bit opaque identifiers. Each handle has exactly one closer. A
   closed or unknown handle returns `GRAIL_E_INVALID_HANDLE`; it is never undefined
   behaviour, and generation counters prevent stale handles from naming a reused resource.
8. All fallible entry points require a successful `grail_os_init`. Pure helpers (error text,
   Unicode, lexical path manipulation, version query) work before initialization.
9. Callbacks are C function pointers plus a `void *user` word. Capturing closures and
   ordinary Grail function values are not C-callable; only `extern "C"` definitions are.
10. The ABI never exposes scheduler state, green tasks, readiness registrations or the
    allocator's internal layout. Those stay inside the runtime.

## Core surface

```c
uint64_t grail_abi_version(void);
grail_status grail_abi_check(uint64_t major, uint64_t minor);
grail_status grail_os_init(const grail_allocator *allocator, const grail_startup *startup);
grail_status grail_os_shutdown(void);
uint64_t grail_os_capabilities(void);
grail_status grail_os_error_last(grail_os_error *out);
```

`grail_allocator` supplies allocate/reallocate/release hooks so backend bookkeeping is
visible to the runtime's allocation accounting. The Grail runtime passes its own allocator;
a C host that embeds the runtime may pass any conforming allocator. Backends may not call
`malloc` for state that survives an ABI call unless the allocator hooks are unusable, and
must document that exception.

`grail_startup` carries UTF-8 argument and environment blocks with per-entry offsets. Each
entry is NUL-terminated, but the terminator is not part of the entry. The entry shim, not
the backend, is responsible for converting the Windows UTF-16 command line/environment and
for validating POSIX bytes. After initialization, environment reads come from the runtime's
copy, so enumeration is deterministic; mutations update the copy and propagate to the OS so
spawned children inherit them.

Capability bits let the runtime fail early and let tests distinguish "not implemented from
this backend" from a real error. A backend must clear a capability bit until every function
in that domain is implemented and tested.

## Error model

`grail_error.h` defines the portable statuses. Backends translate native failures and keep
the original value in thread-local storage:

```c
typedef struct grail_os_error { uint64_t domain; uint64_t code; } grail_os_error;
```

Domains are `ERRNO`, `WIN32`, `MACH` and `HRESULT`; the detail is diagnostic only and never
changes the portable status. `grail_os_error_last` is thread-local and is not cleared by a
successful call. `GRAIL_E_SYSTEM` means "unclassified"; the raw detail is the only useful
information then. Transient statuses (`WOULD_BLOCK`, `INTERRUPTED`, `TIMED_OUT`, `BUSY`)
are the only ones a retry loop may treat as "try again immediately".

The errno, Win32 and Mach tables in `runtime/abi/grail_error.c` are the normative mapping.
Two deliberate differences from the current Linux-only `lib/io.grl` behaviour:

- `EPERM` and `EACCES` both map to `GRAIL_E_ACCESS_DENIED` (the current library maps both to
  `PermissionDenied`, which is compatible), but an unset variable is `GRAIL_E_NOT_FOUND`,
  distinct from a set-but-empty value.
- `ENOTSUP`/`EOPNOTSUPP` and unimplemented backend functions map to
  `GRAIL_E_UNSUPPORTED`, not to a generic OS error.

## Unicode

`grail_os_utf8_validate`, `grail_os_utf8_to_utf16` and `grail_os_utf16_to_utf8` are strict:
overlong sequences, surrogate code points, values above U+10FFFF, truncated sequences and
unpaired UTF-16 surrogates are rejected. There is no replacement-character mode, BOM
stripping, CESU-8 acceptance or normalization. Paths are UTF-8 with `/` as the canonical
separator in the ABI; the Windows backend converts to UTF-16 and native separators at the
syscall boundary. macOS filenames may be stored in NFD; the ABI preserves the bytes the OS
returns and does not normalize them, so callers must not assume byte equality across
filesystems.

## FFI alignment

The FFI contract (draft, `extern "C"` declarations with `&[u8]` expanding to a pointer/length
pair, structs crossing by reference, opaque `handle`, linear ownership) maps directly:

- `&[u8]` supplies the `(const uint8_t *, uint64_t)` input pair.
- `&mut [u8]` supplies the `(uint8_t *, uint64_t)` output pair; the returned required length
  drives the retry.
- `handle` names the 64-bit handle typedefs in the domain headers.
- Pointer-passed POD records are declared `extern record` with natural C layout; no
  by-value aggregate support is required.
- Every extern call is already unsafe, matching the fact that OS handles are linear
  resources and every closer is an explicit declaration.
- C-to-Graal callbacks are a later FFI increment. Until then the allocator hooks and thread
  entry points stay on the C/backend side; no Grail wrapper may assume C can call generated
  Grail code.
- The ABI does not read or clear `errno`; it returns portable statuses and exposes raw
  detail through `grail_os_error_last`. An FFI-side `errno()` accessor is therefore not
  needed for this boundary.

## Domain status

| Domain | Header | Portable implementation | Linux reference | Windows | macOS |
| --- | --- | --- | --- | --- | --- |
| Core, error, Unicode | `grail_abi.h`, `grail_error.h`, `grail_unicode.h` | yes, tested | n/a | n/a | n/a |
| Time | `grail_time.h` | n/a | monotonic/realtime/CPU, sleep, local offset | monotonic/realtime/CPU, sleep | monotonic/realtime/CPU, sleep |
| Environment | `grail_env.h` | shared store | get/set/unset/enumerate | get/set/unset/enumerate | get/set/unset/enumerate |
| Files/pipes | `grail_fs.h` | handle table | open/read/write/seek/truncate/sync/stat/close, pipe | open/read/write/seek/truncate/sync/stat/close, pipe | open/read/write/seek/truncate/sync/non-blocking/close, pipe |
| File metadata | `grail_fs.h` | format | `file_stat`/`fs_stat` | `file_stat`/`fs_stat` | not implemented |
| Directories | `grail_fs.h` | handle table | open/next/close, mkdir/remove/rename | FindFirstFileW/FindNextFileW, mkdir/remove/rename | opendir/readdir, mkdir/remove/rename |
| Paths | `grail_path.h` | POSIX + Windows rules, both tested | cwd, executable | cwd, executable | cwd, executable |
| Processes | `grail_proc.h` | options/status layout | fork/execve/wait4 subset | not implemented | not implemented |
| Sockets | `grail_socket.h` | address layout | TCP/UDP IPv4+IPv6, options, DNS | not implemented | not implemented |
| Threads/sync | `grail_thread.h` | handle table | pthread thread, mutex, condvar | CreateThread/SRWLOCK/CONDITION_VARIABLE | pthread thread/mutex/condvar |
| Dynamic libraries | `grail_dl.h` | handle table | dlopen/dlsym/dlclose | LoadLibraryExW/GetProcAddress | dlopen/dlsym/dlclose |

The Windows and macOS backends use pinned Win32 and Darwin declarations rather than platform
SDK headers, so they can be compiled for Win64 and Apple ARM64 on this host. They have not
been executed on those systems. `GRAIL_CAP_FILE_METADATA` separates byte I/O from metadata;
Linux and Windows set it, macOS clears it. `GRAIL_CAP_FILE_NONBLOCKING` separately covers
`file_set_nonblocking`; Linux and macOS set it, Windows clears it. `GRAIL_CAP_SYMLINKS`
covers `readlink`/`realpath`; Linux and macOS set it, Windows clears it.

"Not implemented" always means the shim returns `GRAIL_E_UNSUPPORTED` and the capability bit
is clear. It never means a silent success or a sequential fallback under a concurrent name.

## Verification

`bun tools/abi-test.mjs` (or `just abi-test`) compiles with a host C compiler and runs:

- `tests/abi/test_core.c`: version negotiation, every portable error text, transient
  classification, POSIX/Win32/Mach mappings, strict UTF-8 rejection cases and UTF-16
  round-trips.
- `tests/abi/test_handle_table.c`: 1000 allocations, stale/double/cross-domain handle
  rejection, slot reuse and destruction.
- `tests/abi/test_paths.c`: POSIX and Windows lexical rules, compiled twice.
- `tests/abi/test_linux_backend.c`: initialized Linux reference backend covering environment
  seeding/mutation/iteration, clocks and sleep, file and directory I/O, pipes, thread
  spawn/join/detach, mutex/condvar behaviour, dlopen/dlsym, child process argv/environment/
  cwd/stdio/PATH/exit-status/timeout/terminate/kill, loopback TCP and UDP, socket options,
  IPv4 name resolution, negative-errno mapping and zero tracked allocation bytes after shutdown.
- `tests/abi/test_env_store.c`: the shared environment store used by both non-Linux backends
  (seed validation, get/set/unset, snapshots, growth and zero live allocation).
- `tests/abi/test_headers.c`: compiled with `clang -ffreestanding` for Linux x86_64, AArch64
  and RISC-V 64, Windows x64 and Apple ARM64, plus explicit structure-size assertions.
- Cross-target object builds for `x86_64-pc-windows-msvc`, `aarch64-pc-windows-msvc`,
  `arm64-apple-macos11` and `x86_64-apple-macos11` with strict warnings and
  `-DGRAIL_ABI_BUILD`; `llvm-nm` confirms all 95 public functions are defined in each backend,
  including the fail-closed stub translation units.

The test suite needs a C compiler and is deliberately separate from the Grail build; no
Grail program links these C files. The Linux reference shim is a behavioural oracle for the
future Grail implementation, not a replacement build path.

The safe Grail surface that will wrap this contract is designed in [runtime-api.md](runtime-api.md).

## Remaining native backend work

Linux (to move from the reference shim to the shipping Grail runtime): port the implemented
fork/execve/wait4 and argv/environment/cwd/stdio/PATH semantics into `runtime.grl`; port the
implemented TCP/UDP/`accept4`/`getaddrinfo` subset behind the readiness reactor; use `statx`
for birth time; and keep raw descriptors and syscalls out of safe code. The C reference is the
behavioural oracle, not a replacement runtime.

Windows implementation is static-only until it runs on a real Windows host. Remaining: compare
the pinned declarations with the current SDK; add `\\?\` long paths and reserved-name policy,
reparse-point metadata, local-time offsets, processes and sockets; apply thread names; define
the loader search-flag semantics; add Windows behaviour tests and set the corresponding
capability bits only after they pass.

macOS implementation is static-only until it runs on macOS. Remaining: verify the pinned
libSystem declarations and add a pinned `struct stat` for metadata; local-time offsets,
processes and sockets; framework/`.tbd` link inputs belong to the macOS backend lane.

Both non-Linux backends also need ABI bridge work outside this directory: Win64 argument
registers/shadow space and Apple ARM64 symbol conventions are compiler/codegen responsibilities.
The current internal convention is SysV-like and is **not** Win64-compatible; this is a
prerequisite dependency for calling these symbols on Windows, recorded here so it is not
mistaken for a shim detail.
