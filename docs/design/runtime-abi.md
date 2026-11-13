# Cross-platform OS ABI (contract and scaffold)

2026-11-08. Status: **proposal plus scaffolded implementation**. The C headers under
`include/grail/` are the normative contract. Portable pieces (versioning, error mapping,
Unicode, lexical paths) are implemented and tested; the Linux reference shim implements files,
directories, environment, time, threads, dynamic libraries, child processes and TCP/UDP
sockets. Windows and macOS have full-function backends covering
init/time/environment, paths, files and metadata, directory iteration, threads/synchronization,
dynamic libraries, child processes, local-time offsets, sockets and DNS. Platform subfeatures
that cannot be provided fail closed at runtime and are documented per backend. Nothing here is
linked into the compiler or shipping runtime; the first Grail-facing wrappers are a separate,
FFI-gated layer.

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
| Time | `grail_time.h` | n/a | monotonic/realtime/CPU, sleep, local offset | monotonic/realtime/CPU, sleep, local offset | monotonic/realtime/CPU, sleep, local offset |
| Environment | `grail_env.h` | shared store | get/set/unset/enumerate | get/set/unset/enumerate | get/set/unset/enumerate |
| Files/pipes | `grail_fs.h` | handle table | open/read/write/seek/truncate/sync/stat/close, pipe | open/read/write/seek/truncate/sync/stat/close, pipe | open/read/write/seek/truncate/sync/non-blocking/close, pipe |
| File metadata | `grail_fs.h` | format | `file_stat`/`fs_stat` | `file_stat`/`fs_stat` | `file_stat`/`fs_stat` ($INODE64) |
| Directories | `grail_fs.h` | handle table | open/next/close, mkdir/remove/rename | FindFirstFileW/FindNextFileW, mkdir/remove/rename | opendir/readdir, mkdir/remove/rename |
| Paths | `grail_path.h` | POSIX + Windows rules, both tested | cwd, executable | cwd, executable | cwd, executable |
| Processes | `grail_proc.h` | options/status layout | fork/execve/wait4 subset | CreateProcessW subset | posix_spawn subset |
| Sockets | `grail_socket.h` | address layout | TCP/UDP IPv4+IPv6, options, DNS | TCP/UDP IPv4+IPv6, options, DNS | TCP/UDP IPv4+IPv6, options, DNS |
| Threads/sync | `grail_thread.h` | handle table | pthread thread, mutex, condvar | CreateThread/SRWLOCK/CONDITION_VARIABLE | pthread thread/mutex/condvar |
| Dynamic libraries | `grail_dl.h` | handle table | dlopen/dlsym/dlclose | LoadLibraryExW/GetProcAddress | dlopen/dlsym/dlclose |

The Windows and macOS backends use pinned Win32 and Darwin declarations rather than platform
SDK headers, so they can be compiled for Win64 and Apple ARM64 on this host. The Windows
metadata/reparse/DNS subset is executed under Wine; macOS and the rest of the Windows surface
are compile-checked only. All 95 public functions are defined on both. The capability
word includes `FILE_METADATA`, `FILE_NONBLOCKING`, `SYMLINKS` and `RESOLVE`; platform
subfeatures that cannot be provided still fail closed at runtime (Windows non-blocking mode is
pipe-only, `REUSE_PORT` is unsupported, and `readlink` handles symlink/mount-point reparse
records).

Where a platform subfeature cannot be provided (Windows non-blocking mode on regular files,
`REUSE_PORT`, or a non-reparse `readlink`), the call returns `GRAIL_E_UNSUPPORTED` or
`GRAIL_E_INVALID_ARGUMENT`; it is never a silent success or a sequential fallback under a
concurrent name. The public function surface itself is complete on both backends.

## What the compiler hands the runtime: a handshake that carries its length

Two branches write the same program: `compiler/native.grl` emits the code, `compiler/runtime.grl`
is the runtime that code calls. They are separate lanes with a shared contract at every point where
one fills a buffer the other owns, and one of those points had no length in it at all.

The site walk had a **bare pointer and fixed offsets**. The program's entry publishes the address of
a helper in process-state word 3400; `rt_site_here` and `rt_backtrace` called it as
`helper(scratch)` and read words 0, 8 and 16 - both statement-table bounds and the caller's frame
pointer - or 24 and 32 as well. The helper wrote unconditionally. So the contract lived in two
comments, and the two branches disagreed: the runtime lane sized the caller's scratch by what the
walk *reads* (three words, 24 bytes) while the compiler's helper wrote five (40 bytes). Sixteen bytes
landed in the block header after a 240-byte task record and the next allocation was handed out with
a size word that was really `__stop_grail_funcs`
([task-failure-containment.md](task-failure-containment.md#the-integration-failure-and-the-word-that-wrote-the-header-fixed-gaps2-tmem)).

The handshake now carries its length. Three shapes were considered:

| | shape | why not |
| --- | --- | --- |
| (a) | a descriptor record `{ptr, len, words_written, version}` in a fixed state slot, published by the helper | the length would be published *after* the call that needs it; the caller still has to allocate a buffer before it can learn how big one should be, and a version word is a second thing to keep in step with a layout that has never needed one |
| (b) | call twice: `need = helper(0)` for the required size, then `helper(buf)` to fill | the size query is a call the *older* helper cannot understand. A seed-built helper writes through whatever pointer it is given, so `helper(0)` is a null store: the one case that must never break is the one this breaks first |
| (c) | **a capacity argument plus a returned count**, the runtime never reading past its own buffer | chosen |

The contract, in `rt_sites` as emitted by `native.grl site_table` and consumed by `runtime.grl
rt_sites_fill`:

```
words_written = rt_sites(out, capacity_words)

0  __start_grail_sites    8  __stop_grail_sites    16 the caller's frame pointer
24 __start_grail_funcs   32  __stop_grail_funcs
```

The layout is **append-only**, so a prefix of it is always meaningful and a helper may always write
fewer words than a runtime would like to read:

| capacity | the helper writes | returns |
| --- | --- | --- |
| 0 | the first three words | 3 |
| 1..2 | nothing | 0 |
| 3..4 | the first three words | 3 |
| 5 or more | all five words | 5 |

`0` means "this caller predates the argument", and it is answered with the three words every
runtime since the statement table existed has room for. That is not a special case invented for
taste; it is the compatibility direction that decides the design. **A seed build's runtime is older
than the code it compiles**: the checked-in seed compiles this tree's `runtime.grl`, so the runtime
that runs is new while the helper it calls was emitted by the seed's `native.grl`, or - in the other
order - an old runtime calls a helper emitted by new code. The old runtime's call is
`raw_call2(helper, scratch, 0)` on a **24-byte** scratch, so an argument that arrives as `0` must
mean "three words", and the five-word answer that caused the overrun must be unreachable there.
It also means an offer below three words writes *nothing at all* rather than the floor, so an
explicit capacity is never exceeded.

The other direction - a new runtime calling a helper emitted before the count existed - is answered
by the returned count: such a helper answers `0` (the `xorq %rax,%rax` it ends with) after writing
its words, and the runtime reads `0` as "the words an offer of this size implies". Which is safe
because it pre-zeroes the two function-table words before the call: a helper that writes only the
first three leaves zeros there instead of the block's previous contents, so "this build has no
function table" is a fact rather than a guess, and `rt_backtrace` refuses rather than naming frames
from a table that is not there.

### The runtime is the checking side, not the tolerant one

`rt_sites_fill` returns the number of words the caller may read, and `0` for a refused descriptor:

- no helper in word 3400 (a macOS or `--debug` or LLVM build, a split build, an old seed);
- a count smaller than the three words a statement entry needs;
- **a count larger than the capacity it offered** - a helper that ignored the argument. Nothing is
  read in that case, which is the whole difference from assuming: a runtime that reads first and
  validates afterwards has already walked a table that may not be there.

`rt_site_here` (the containment path, which may not allocate) and `rt_backtrace` share the fill, and
`rt_fail_where` uses it too, so there is one place where the descriptor is asked for and one place
where its length is believed. Each caller asserts `words read <= words written`: the site walk reads
three of `have >= 3`, the backtrace reads five of `have >= 5`.

The buffer on the containment path is the task record's words 200..240, which is
`rt_sites_words()` words.

### The audit: every other place generated code and the runtime share a buffer

`rg -n 'fn rt_sites|rt_site_here|rt_fail_where|rt_backtrace|host_fn\(&mut c, view\("'` over
`compiler/native.grl` and `compiler/runtime.grl` finds one helper: `rt_sites`. `host_fn(...)` names
the `host::*` entry points the compiler binds by name, and `host::backtrace` is
`f_host_backtrace -> rt_backtrace`, a call *into* the runtime that returns an owned text, not a
buffer handed over to be filled. Everything else at the boundary is one of:

| handshake | what crosses | why it cannot overrun |
| --- | --- | --- |
| `rt_sites` (both tables, the frame) | five words into the runtime's buffer | capacity argument + returned count, above |
| `host::backtrace` | an owned text the runtime allocates and returns | `rt_backtrace` bounds every line by `n + 256 < rt_fail_limit()` and its frame walk by depth 64 / 32 lines |
| `host::*` scalar and `&[u8]` calls | values, and a `view` pair (pointer **and** length) | the length is part of the pair for every one of them |
| entry state words (`rt_state` 0/8/16, 184, 3216, 3392, 3400) | one word each | a word has no length to lose |
| `rt_trap` / `rt_fail` / `rt_refine` | the compiler's check kinds and two C strings beside the check | the strings are NUL-terminated statics the runtime only reads |
| compile-time refusal text (`rt_state` 3232..3384) | the runtime's own message, written and read by the runtime | one owner, one length (79 bytes), no generated code |

So the site descriptor was the only word-list handshake, and it is the one that corrupted a header.
The report's own text buffers (`rt_fail_limit`) were already bounded by their writer.

### Proving the refusal

`GRAIL_RT_SITES_OFFER` is a **test-only** fault injection, read once into process-state word 3408:
it replaces the capacity the runtime offers with a smaller number, which is what an older runtime,
a hypothetical smaller buffer or a mismatched future helper would present as. Three corpus cases
pin the three outcomes - an offer of 5 (the whole descriptor: site and function table), of 3 (what
a runtime older than the count receives: the site still names the statement, `host::backtrace`
answers no text), and of 2 (the helper writes nothing and the runtime refuses the descriptor,
leaving the message without a location rather than reading a buffer it was told is too small).

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
  with no remaining stub translation units.
- `tests/abi/wine_harness.c` is cross-built as a Windows PE with Zig/MinGW-w64 and executed
  under Wine: 47 checks cover metadata follow/no-follow, hidden attributes, non-reparse
  readlink rejection, symlink readlink/realpath, regular-file non-blocking rejection and
  `localhost` DNS. `tests/abi/macos_metadata_dns_check.c` is compiled for Apple ARM64 as a
  call-site check (not executed).

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

Windows implementation is executed under Wine for the metadata/reparse/DNS paths, but not yet
on a real Windows host. Remaining: compare the pinned declarations with the current SDK; add
`\\?\` long paths and reserved-name policy; extend non-blocking mode beyond named pipes;
apply thread names; define the loader search-flag semantics and environment-block ordering;
run the rest of the surface on real Windows.

macOS implementation is static-only until it runs on macOS. Remaining: verify the pinned
libSystem declarations and the `$INODE64` stat symbols against the SDK; framework/`.tbd` link
inputs belong to the macOS backend lane. DNS is blocking and must be offloaded by a green-task
runtime.

Both non-Linux backends also need ABI bridge work outside this directory: Win64 argument
registers/shadow space and Apple ARM64 symbol conventions are compiler/codegen responsibilities.
The current internal convention is SysV-like and is **not** Win64-compatible; this is a
prerequisite dependency for calling these symbols on Windows, recorded here so it is not
mistaken for a shim detail.
