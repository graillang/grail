# Windows x86-64 backend (PE/COFF)

Status: two working PE targets. `--target windows-x86_64` emits COFF-compatible x86-64 assembly;
`--target windows-aarch64` emits COFF-compatible ARM64 assembly through the shared AArch64
selector. The Clang integrated assembler turns them into `IMAGE_FILE_MACHINE_AMD64` /
`IMAGE_FILE_MACHINE_ARM64` objects and `lld-link` links console PE32+ images against
Grail-generated import libraries. A portable-runtime subset that talks to kernel32 runs under
Wine on x86-64 (console output, formatted integers/floats, file write/read, exit codes and
command-line arguments); the ARM64 image is validated statically because no ARM64 Windows runner
exists here.

## Why assembly, not a hand-written object emitter

The compiler is a text-assembly backend: `native.grl` emits AT&T x86-64, `machine.grl` rewrites
that text for AArch64/RISC-V, and `optimize.grl` rewrites it per function. Keeping one textual
form means the PE target shares checking, lowering and optimisation with the Linux targets
instead of forking the backend. PE/COFF-specific work therefore lives in four places:

1. **Directives** (`native.grl`): `.def NAME / .scl 2 / .type 32 / .endef` replaces the ELF
   `.type NAME,@function` for ordinary functions and closure bodies. The ELF-only
   `.note.GNU-stack` section is omitted; `.text`, `.data`, `.bss`, `.rodata`,
   `.pushsection/.popsection`, `.p2align` and absolute `.set` symbols are accepted by the COFF
   assembler unchanged.
2. **Entry and exit** (`native.grl`): a PE image is entered at `grail_entry` with no argv on the
   stack, so the stub clears the three process-state words, aligns the stack and calls
   `rt_thread_init`; the OS layer fills argv/envp from Win32. Process exit is
   `movl %edi,%ecx; call *__imp_ExitProcess(%rip)` instead of `exit_group`.
3. **Imports** (`native.grl`): `raw_win32(Symbol, args...)` is the only FFI primitive. The
   compiler knows each symbol's arity, so it emits the Win64 sequence itself. `raw_map` maps to
   `VirtualAlloc`, the thread pointer reads TEB+0x28 (`%fs:40`), and Linux-only intrinsics
   (clone, stack switch) trap with `ud2` instead of emitting ARM mnemonics.
4. **OS layer** (`compiler/os-linux.grl`, `compiler/os-windows.grl`): the portable runtime keeps
   its operation IDs, and the OS file provides `rt_syscall`, `rt_syscall4`, `rt_readlinkat`,
   `rt_faccessat`, `rt_accept4` plus `rt_os_init`. Only one OS file is compiled per target, so
   the runtime above it is unchanged and the Linux build never sees Win32 code.
5. **Unwind data** (`native.grl`): a post-pass over the final assembly wraps every `.def` function
   in `.seh_proc/.seh_pushreg %rbp/.seh_setframe %rbp, 0/.seh_stackalloc <n>/.seh_endprologue/
   .seh_endproc`. The assembler encodes that into `.xdata` and a `.pdata` RUNTIME_FUNCTION table,
   which `lld-link` publishes as the PE exception directory.

## Calling convention

Two conventions coexist, and the boundary is explicit:

- **Grail-internal calls** keep the existing register order (`%rdi, %rsi, %rdx, %rcx, %r8, %r9`,
  result in `%rax`, callee-saved `%rbx, %r12-%r15` saved in the frame). Six arguments maximum;
  every argument is register-passed and slots are addressed relative to `%rbp`. This is a private
  convention, not a platform ABI: nothing outside Grail code may call a `f_*`/`rt_*` symbol
  directly. It stays valid under Win64 because the only Windows calls into Grail code are the
  loader entry (a fixed stub) and future thread thunks, which must save `%rdi/%rsi`.
- **Win32 imports** use the real Win64 ABI: `%rcx, %rdx, %r8, %r9`, 32 bytes of caller shadow
  space, 16-byte stack alignment at the call, arguments 5..7 at `32(%rsp)`, `40(%rsp)`,
  `48(%rsp)`, and `%rax` for the result. `raw_win32` sizes the frame as
  `32 + 8 * max(0, args - 4)` rounded up to 16, then loads registers and stack words from the
  compiler's slots. The call target is the IAT slot (`call *__imp_Name(%rip)`); a direct
  `call __imp_Name` would enter the IAT data instead of the function, which was the first bug the
  Wine runs caught.

## Import libraries

`tools/windows.mjs` writes its own COFF import library. Each entry point becomes a *short import
object*: the 20-byte `coff_import_header` (`Sig1=0, Sig2=0xffff, Version=0, Machine=0x8664,
TimeDateStamp=0, SizeOfData, Ordinal=0, Type=IMPORT_NAME_NOPREFIX(4)`) followed by
`Name\0kernel32.dll\0`. `llvm-ar rcs` archives them into `kernel32.lib`; `lld-link` turns each
member into an IAT slot, ILT entry, hint/name record and import descriptor. No MinGW or Windows
SDK is required. Link line:

```sh
lld-link /nologo /entry:grail_entry /subsystem:console /nodefaultlib /dynamicbase /nxcompat \
         /out:program.exe program.obj kernel32.lib
```

## Unwind data

`.seh_*` directives require absolute values, and frame sizes are only final after code
generation (`.set .F<n>, <bytes>`). The Windows target bypasses the ELF optimizer, so every
function still has the fixed prologue `pushq %rbp / movq %rsp,%rbp / subq $.F<n>,%rsp`. The
compiler therefore collects the `.set .F` values in emission order (one per function, in the same
order as the `.def` records) and inserts a frame-pointer unwind description per function. The
encoder reports `PrologSize 8, FrameRegister RBP, FrameOffset 0`, one `PUSH_NONVOL rbp`,
`SET_FPREG rbp`, and `ALLOC_SMALL <frame>`; 240 functions in the hello image produce 240
RUNTIME_FUNCTION records (`Entry 3 ... Exception Directory [.pdata]`, 0xb40 bytes).

A function whose prologue does not match the standard shape is left without unwind records rather
than given an inaccurate description. Today that is only the `.D<ty>` drop thunks (which push
`%r12/%r13` after the frame pointer) and the `grail_entry` stub, which has no frame.

## Runtime surface

The Windows OS layer implements the operation IDs the portable runtime already uses:

| Operation | Win32 calls |
| --- | --- |
| read / write / close | `ReadFile`, `WriteFile`, `CloseHandle` (`GetStdHandle` for fd 0..2) |
| open | `CreateFileW` with Linux access/disposition flags translated |
| mapped memory | `VirtualAlloc` (`raw_map`), `VirtualFree` (munmap) |
| process | `ExitProcess`, `GetCurrentProcessId` |
| time | `GetTickCount64` (monotonic ms), `Sleep` |
| files/directories | `GetFileAttributesW`, `CreateDirectoryW`, `DeleteFileW`, `RemoveDirectoryW` |
| directory stream | `FindFirstFileW`, `FindNextFileW`, `FindClose`, rewritten as a dirent64 stream |
| startup | `GetCommandLineW` + `GetEnvironmentStringsW`/`FreeEnvironmentStringsW`, `SwitchToThread` |
| child process | `CreateProcessW` with a UTF-16 command line and environment block |
| threads | `CreateThread`, `WaitForSingleObject`, `CloseHandle` |
| sockets | `WSAStartup`/`WSACleanup`, `WSASocketW`, `bind`, `listen`, `accept`, `connect` (ConnectEx), `WSARecv`, `WSASend`, `getsockname`, `setsockopt`, `closesocket` (ws2_32) |
| address waits | `WaitOnAddress`, `WakeByAddressSingle`, `WakeByAddressAll` (kernelbase.dll) |
| COM startup | `CoInitializeEx`, `CoUninitialize` (combase.dll) |

No `-A` entry point is reachable from a Grail image. `tools/test-windows.mjs` asserts that against
every case's object, with the list of ANSI entry points it refuses in `ansiImports`, so a
`CreateFileA` reintroduced anywhere fails the suite rather than quietly mangling a path.

### Text at the Win32 boundary

One convention, stated once and used everywhere: **every entry point in `os-windows.grl` takes and
returns UTF-8**, and the wide form exists only between a conversion helper and the call that follows
it. `rt_cstr` in the portable runtime produces the NUL-terminated UTF-8; `rt_win_wide(slot, utf8)`
turns it into UTF-16 in a fixed conversion slot and reports the unit count or a negative errno; and
`rt_win_utf8_of(dst, cap, wide, units)` is the answer in the other direction for `FindFirstFileW`
results, `GetModuleFileNameW`, `GetCurrentDirectoryW`, the environment block and the command line.
No call site converts by hand, which is what keeps a new file operation from forgetting.

Conversion lives in one 128 KiB mapping made at startup: five 16 KiB slots, four for UTF-16 (8 KiB
units each) and one for the UTF-8 of a wide result. The arena is untracked memory claimed at state
word 3600, so converting costs no user allocation in either direction and `rt_syscall`'s allocation
path stays untouched. A path of more than 8191 units is refused with `ENAMETOOLONG` rather than
truncated.

The two directions have deliberately different failure policies:

- **Outbound (a path a program produced)**: invalid UTF-8 is refused with `EINVAL`. No replacement
  character is ever written into a file name, so a program that builds a name out of bytes that are
  not text gets an error it can report instead of a differently-spelled file. The encoder rejects
  overlong forms, bare continuation bytes, truncated sequences, encoded surrogates and code points
  above U+10FFFF, and encodes a code point above U+FFFF as the surrogate pair UTF-16 requires.
- **Inbound (text the OS handed us)**: an unpaired surrogate becomes U+FFFD, in
  `rt_win_wide_cp` and only there. A command line or an environment entry is not something the
  program can fix by retrying, and refusing `argv[0]` would leave the process with no arguments at
  all. `rt_win_utf8_of` still refuses such text for a *path result* (a directory entry that cannot
  be represented is skipped rather than turned into a name that does not exist).

`rt_win_split_w` is the wide command-line splitter: the same CommandLineToArgvW rules as before
(backslash only escapes a quote, a quote is escaped by doubling the backslashes in front of it) but
applied to UTF-16 units, with each kept unit re-encoded as UTF-8 as it is written. `rt_win_quote_w`
is the inverse for `CreateProcessW`, so an argument survives the trip in both directions.

The environment block for a child is UTF-16 and sorted case-insensitively, as `CreateProcessW`
requires, and the call passes `CREATE_UNICODE_ENVIRONMENT`. Without that flag Windows reads a
non-NULL block as ANSI bytes, which turns a UTF-16 environment into a one-letter variable name and
an otherwise empty list - the first bug the wide environment had, and the reason the argument is
worth stating here.

Directories are the one place where the portable interface and Win32 disagree about what a
descriptor *is*: the portable layer opens a directory with `open` and reads it with `getdents`.
`rt_win_open` therefore answers a read-only open of a directory with an enumeration - a tagged
descriptor in the platform's own list, backed by `FindFirstFileW` - and `rt_syscall(217)` rewrites
the find results into the Linux `dirent64` record stream the portable decoder already parses (record
length at 16, type at 18, name at 19), exactly as `darwin.grl` translates `getdirentries64`. The
attribute query decides which case a path is, not a failed `CreateFileW`: Wine opens a directory
handle where Windows returns `ERROR_ACCESS_DENIED`, and a platform layer that depended on that
difference listed nothing at all under Wine.

### COM interop

COM needs two calls the import path cannot express: a *direct* call to a symbol linked into the
image (no IAT), and an *indirect* call through a function pointer loaded from a vtable slot. Both
use the Windows ABI and are compiler intrinsics for unsafe runtime modules:

| Intrinsic | x86-64 | windows-aarch64 |
| --- | --- | --- |
| `raw_win_local(Symbol, a..d)` | `%rcx/%rdx/%r8/%r9` then `call Symbol` | `%rdi/%rsi/%rdx/%rcx` (lowers to `x0..x3`) then `call Symbol` |
| `raw_win_call(slot, a..d)` | args in `%rcx/%rdx/%r8/%r9`, `movq slot,%r11`, `call *%r11` | args lower to `x0..x3`, `%rax`→`x9` holds the slot, `wininvoke` lowers to `ldr x16,[x9]; blr x16; mov x9,x0` |

`tests/com-shim-x64.s` and `tests/com-shim-arm64.s` are minimal C-ABI shims compiled and linked by
`tools/windows.mjs`: a static `IUnknown` object `{vtable, refcount, payload}` with a
`grail_com_make_object(void **out)` factory, a `grail_com_iid_address()` accessor and
`QueryInterface`/`AddRef`/`Release` entries. `QueryInterface` compares the 16-byte IID, nulls
`*ppv` on failure and returns `S_OK`, `E_NOINTERFACE` (`0x80004002`) or `E_POINTER`
(`0x80004003`); `AddRef`/`Release` use `lock xaddl` on x86-64 and plain load/add/store on ARM64,
returning the new count.

The executed x86-64 case prints, in order: `CoInitializeEx` result `0`; factory `0`; AddRef `2`,
`3`; Release `2`, `1`; `QueryInterface` with a null `ppv` `2147500035` (`E_POINTER`); with a null
`riid` `2147500035`; with a null GUID `2147500034` (`E_NOINTERFACE`); with the shim's IID `0`
(`S_OK`) and `*ppv == object` (`0` from the pointer difference); the final Release `1`, `0`;
then `CoUninitialize`.

The same program compiles for `windows-aarch64` against the ARM64 shim and is checked statically:
the assembly contains `bl grail_com_make_object`, `ldr x16,[x9]` and `blr x16`, the object is
COFF-ARM64 and the image is PE32+ ARM64 importing `CoInitializeEx` from `combase.dll`.

COM limits: one static in-process object, a single IID match, no `CoCreateInstance`,
`IDispatch`/`IUnknown` beyond the three methods, no aggregation, no `VARIANT`/`BSTR` marshalling,
no apartment-model or cross-apartment tests (only `CoInitializeEx`/`CoUninitialize` balance).
`raw_win_call`/`raw_win_local` pass at most four word arguments and no floating-point or
aggregate parameters. The ARM64 side is static-only because no ARM64 Windows runner exists.

### Sockets

The runtime's socket operations (`rt_syscall` 41 socket, 42 connect, 49 bind, 50 listen, 51
getsockname, and `rt_accept4`) are Winsock calls. Winsock is started once per process
(`WSAStartup` 2.2, in state word 3616, one winner under a compare-and-swap and the losers waiting)
and cleaned up once from the exit paths (`WSACleanup` before `ExitProcess`), so a program that makes
a hundred connections starts the stack once.

A socket descriptor is a record in the same list the directory enumerations use (kind 1), so the
portable layer still passes one word around and `rt_win_read`, `rt_win_write`, `rt_win_close` and
`rt_syscall` are the only places that know a descriptor is not a handle. The record carries the
socket's `OVERLAPPED` at +32 - one operation per descriptor at a time - plus the byte count and error
of the last completion, the buffer and length handed to `WSARecv`/`WSASend`, the `WSABUF`, the flags
word, and a manual-reset event that is both the request's `hEvent` and the handle a waiter blocks on.
The field list at the top of the socket section in `compiler/os-windows.grl` is the authoritative one.

**Readiness is the operation.** A receive or a send is an overlapped `WSARecv`/`WSASend`; the waiter
blocks in `WSAGetOverlappedResult` on the request's event, which is the one completion mechanism
Winsock delivers for every operation, every host and every socket. A task never performs that wait on
its own worker: it hands the wait to an offload thread and parks, exactly as `host::read_file` does,
and the reactor wakes it with the offload's completion. `WSA_IO_PENDING` is the ordinary answer for a
call that completes later and never reaches the task; any other error means the operation was never
issued, and its errno goes straight back to the caller.

**The completion port is not used for sockets.** Sockets can be joined to the scheduler's port with
`CreateIoCompletionPort`, and a completion's `lpOverlapped` maps back to the record with one
subtraction - both were implemented and exercised - but the port then has to be the thing that
settles the record, and under Wine, the only host that can run these tests, neither a cooperative
accept nor `AcceptEx` ever posts a completion for one: a port-based waiter would spend its life
waiting for a packet the host never sends, so the port path was withdrawn together with `AcceptEx`.
Making sockets completion-port-driven is therefore remaining work, not a limitation of the design:
it needs a host where a completion is guaranteed, and a generation counter on the record so a late
packet cannot settle the operation that replaced it.

**connect** is ConnectEx, the only overlapped connect Winsock offers. It requires a bound socket, so
an unbound one is bound to 0.0.0.0:0 first (a socket the program bound itself answers `WSAEINVAL`,
which is not an error here), and `SO_UPDATE_CONNECT_CONTEXT` is set afterwards so the handle carries
the connection's properties. ConnectEx is not an import: Windows' `mswsock.dll` exports it, Wine's
`ws2_32` and `mswsock` do not, so the runtime asks Winsock for the extension function pointer with
`WSAIoctl(SIO_GET_EXTENSION_FUNCTION_POINTER)` and caches it in state word 3632. Calling that pointer
needs seven arguments, which is why `raw_win_call` now takes up to eight word arguments and emits the
same caller frame `raw_win32` does. If a stack has no ConnectEx, the fallback is a blocking connect on
an offload thread.

**accept** is a blocking `accept` on an offload thread, and that is a withdrawal rather than a first
choice. `AcceptEx` was implemented first - accept socket created up front, `SO_UPDATE_ACCEPT_CONTEXT`
from the listening socket, `getsockname` afterwards - and it completes only while the connection is
already queued: under Wine it never wakes when the request has to wait for one, so a server built on
it accepted the first client and then hung. The same is true of a blocking `accept` issued from an
offload thread while the connection arrives later, which is why an accept loop over concurrently
connecting clients does not finish under Wine (see *Sockets: what is verified*). A blocking accept on
a helper thread is what the rest of this platform layer does with a call that blocks, it needs no
port, and `win-sockets-echo` runs it end to end.

**Limits.** One operation per descriptor at a time (the record holds one `OVERLAPPED`; the portable
layer never has two tasks reading the same socket). AF_INET only - no IPv6 and no name lookup, as on
the other targets. Datagram sockets are created but `WSARecvFrom`/`WSASendTo` are not implemented:
nothing in the portable runtime or `lib/net.grl` reaches them, so they would be dead code. A task
blocked in a socket operation is not cancellable, because it parks in an offload completion rather
than a cancellable wait, exactly as `host::read_file` behaves. And the joinable-thread table is still
15 slots inside the process state block, so a program holding more than 15 blocking host operations
at once can have a join release a stack it should have waited for; the socket tests stay under it.

**Error mapping** turns Winsock's space into the errno space the portable layer reports:
`WSAEWOULDBLOCK` to `EAGAIN` (which never surfaces to a task, because every operation here
completes), `WSAEINPROGRESS`/`WSAEALREADY` to their errno values, `WSAECONNREFUSED` to
`ECONNREFUSED`, `WSAEADDRINUSE` to `EADDRINUSE`, `WSAENOTSOCK` to `EBADF`, and
`ERROR_OPERATION_ABORTED` to `ECANCELED`. `WSAECONNRESET`, `WSAECONNABORTED` and
`ERROR_NETNAME_DELETED` on a *receive* are end of stream (0 bytes), not an error: reading a closed
connection returns what it got, which is what a portable read loop tests for.

### Threads and address waits (x86-64)

The portable runtime is unchanged: `rt_thread_spawn` still maps a stack, writes its record at the
top and calls `raw_thread_clone`. On `windows-x86_64` that intrinsic now calls
`rt_win_thread_clone`, which uses `CreateThread` with a compiler-emitted bridge:

```
rt_win_thread_start:            # Win64 start routine -> Grail convention
subq $56,%rsp                   # 32B shadow + saved %rdi/%rsi, keeps 16B alignment
movq %rdi,32(%rsp)
movq %rsi,40(%rsp)
movq %rcx,%rdi                  # thread parameter -> first Grail argument
call rt_win_thread_main
movq 32(%rsp),%rdi
movq 40(%rsp),%rsi
addq $56,%rsp
ret
```

`grail_entry` publishes the bridge address at `rt_state+3392`, so the OS layer can pass it as the
start routine without an FFI declaration. The thread record carries the portable entry/argument;
`rt_win_thread_main` runs `rt_thread_main`, then clears the portable "running" word and calls
`WakeByAddressAll`.

Joining needs a real termination wait, not just the running word: the clone stores `1` in the
handle's running word before `CreateThread`, stores the thread handle in the stack slack, and
registers `{running word, thread handle}` in a 15-slot table at `rt_state+3856`. The portable
join's wait (`rt_syscall(202, handle, 0, tid)`) finds that entry and uses
`WaitForSingleObject` + `CloseHandle`, so the stack is only unmapped after the thread has fully
exited. The unmap path also reaps any still-registered thread for that stack, closing the window
where a join observes the running word already cleared. Detached spawns pass a word inside their
own stack, are not registered (their stacks are never freed, as on Linux).

Futex operations map to the address-wait API: `FUTEX_WAIT|PRIVATE` (128) becomes
`WaitOnAddress(address, &expected, 8, INFINITE)` with the expected value copied into the process
scratch word, and `FUTEX_WAKE` (129) becomes `WakeByAddressSingle` for a count of 1 and
`WakeByAddressAll` otherwise. Mutexes, the task scheduler and the producer/consumer test all use
these paths. `WaitOnAddress`/`WakeByAddress*` are imported from `kernelbase.dll`: Wine 11 exports
them there and aborts if they are imported from `kernel32.dll`, which the Wine runs caught.

ARM64 thread creation is still unimplemented (the intrinsic traps); sockets, epoll and directory
streams remain `-ENOSYS`, and `mremap` is unimplemented, so growing an allocation of 512 KiB or
more aborts instead of moving the arena.

### Blocking I/O and readiness (decided)

I/O on Windows is synchronous: `ReadFile`/`WriteFile` with no `OVERLAPPED` structure and no
completion port, so a blocked call occupies its OS thread. **Thread-per-blocking-call is the v1
policy**; IOCP is a named future work item with a design sketch
([B4](decisions-b2-b6.md#b4-windows-thread-per-blocking-call-iocp-deferred)).

Because there is no epoll, the portable scheduler cannot start: `rt_sched` treats a failed
`epoll_create` as fatal, so **the first green-task spawn (`spawn`, `task_scope`, `parallel_map`)
aborts the process on Windows**. A task-scope program that prints `42` and exits 0 on Linux x86-64
exits 134 with no output under Wine. OS threads are the Windows concurrency facility today.

## windows-aarch64

The ARM64 target reuses the x86-64 word machine and the existing AArch64 instruction selector.
Windows-specific codegen is expressed as pseudo-ops that `machine.grl` expands once the target is
known to be PE:

| Pseudo-op | ARM64 expansion |
| --- | --- |
| `winimport Name` | `sub sp,sp,#64`; `adrp x16,__imp_Name`; `ldr x16,[x16,:lo12:__imp_Name]`; `blr x16`; `add sp,sp,#64`; `mov x9,x0` |
| `winexit` | the same IAT load for `__imp_ExitProcess`, then `blr x16` and `brk #0` |
| `wintp` | `ldr x9,[x18,#40]` (Windows keeps the TEB in `x18`; +0x28 is the user pointer) |
| `wintpset` | `str x1,[x18,#40]` |
| `winunsupported` | `brk #0` (Linux syscall/thread/stack-switch intrinsics) |

The argument registers make this a direct mapping: the internal order `%rdi,%rsi,%rdx,%rcx,%r8,%r9`
lowers to `x0,x1,x2,x3,x4,x5`, which is exactly the Win64 ARM64 argument order, and a 7th
argument uses `%r10`→`x6`. `raw_win32` therefore emits only the argument moves plus the pseudo-op;
`machine.grl` adds the 64-byte home space the Win64 ARM64 ABI requires (it keeps the 16-byte SP
alignment) and moves the `x0` result back to the internal `x9`. `raw_map` (`VirtualAlloc`) sets
`x0=0`, `x1=size`, `x2=MEM_COMMIT|MEM_RESERVE`, `x3=PAGE_READWRITE` before `winimport`.

Frame allocation uses a dedicated `framesub` pseudo-op, which lowers to
`movz x10,#((.F<n>)&65535); movk x10,#(((.F<n>)>>16)&65535),lsl #16; sub sp,sp,x10` instead of the
checked-arithmetic subtraction used for ordinary user code. That keeps the prologue a plain SP
adjustment whose delta is exactly the `.set` frame value, which is what the unwind description
must record.

The entry stub is the same `grail_entry` shape: zero the three process-state words, align SP
(`andq $-16,%rsp` lowers to `and sp,sp,#...`), call `rt_thread_init` (which parses the Win32
command line) and call the Grail entry. Import libraries are the same short-import objects with
`Machine = 0xAA64`, assembled with `clang --target=aarch64-pc-windows-msvc` and linked with
`lld-link /machine:arm64`.

### ARM64 unwind data

Windows ARM64 has two unwind encodings: a packed 32-bit form inside the `.pdata` entry, and the
unpacked form whose `.pdata` word is an RVA to an `.xdata` structure. LLVM's ARM64 assembler
builds both from armasm-style directives, so the compiler describes the prologue it emitted:

```
f_main_main:
.seh_proc f_main_main
stp x29,x30,[sp,#-16]!
.seh_save_regp x29, 0
mov x10,sp
.seh_nop
mov x29,x10
.seh_set_fp
movz x10,#((.F1)&65535)
.seh_nop
movk x10,#(((.F1)>>16)&65535),lsl #16
.seh_nop
sub sp,sp,x10
.seh_stackalloc 80
.seh_endprologue
...
.seh_endproc
```

The assembler validates that the directives account for every prologue byte and then encodes a
**full `.xdata` record** (`ExceptionRecord: .xdata`, packed flag clear). That is not an omission:
the packed form cannot express this prologue. In the packed word, `RegI` counts consecutive
integer saves starting at `x19` and `RegF` counts floating-point pairs starting at `d8`; a lone
`x29/x30` frame-pointer save (which is exactly what Grail emits) has no packed encoding, and
`llvm-readobj` confirms that `RegI=12` means `x19..x30`, not "just the pair".

Coverage and limits:

- Every canonical frame-pointer function gets a record: the `hello` image has 240
  RUNTIME_FUNCTION records for 240 `.def` functions, a 0x780-byte exception directory
  (8 bytes each) and 2880 bytes of `.xdata`.
- Leaf functions (no prologue instructions) correctly get no record; the assembler emits nothing
  for an empty `.seh_proc` scope, which is the platform's leaf representation.
- A frame that the pass does not recognise keeps no record rather than an inaccurate one, and a
  `.seh_endproc` is kept inside `.text` (the trailing `rt_state` `.bss` block ends the last
  function).
- `.D<ty>` drop thunks still have a conditional prologue (the function tests its argument before
  saving `%r12/%r13`), so no single unwind description is valid for them; that stays remaining
  work together with the x86-64 exception personality.

Static evidence for the hello image: object `Format: COFF-ARM64`, `IMAGE_FILE_MACHINE_ARM64
(0xAA64)`, `grail_entry` in `.text`, relocations `IMAGE_REL_ARM64_PAGEBASE_REL21`,
`PAGEOFFSET_12A/12L` and `BRANCH26`; `.pdata`/`.xdata` sections; image PE32+ console with a
nonzero entry RVA, a `kernel32.dll` import descriptor and a non-empty exception directory. Four
programs (hello, integer printing, file write/read, full argv list) are compiled and inspected by
`tools/windows.mjs check`.

ARM64 limits: the runtime gaps (sockets, threads on ARM64, `CreateProcessW` over seven register
arguments, integer-only import arguments) are the same as x86-64, and the path layer is shared
because it is the same source file. Execution is not testable on this host:
Wine on x86-64 cannot run an ARM64 PE image and `qemu-aarch64-static` is a Linux-ELF emulator, so
ARM64 acceptance requires an ARM64 Windows host, ARM64 Wine, or a Windows-on-ARM machine.

## Verification

`bun tools/windows.mjs check` (with `GRAIL_COMPILER` pointing at a tree-built compiler) checks
eleven x86-64 programs: hello, u64 exit code, integer printing, float printing, file write/read,
single-argument entry, struct fields, a full argv list, a thread join, a producer/consumer wake
and COM interop, plus five windows-aarch64 programs validated statically. The two thread programs also run
as Linux ELF (clone/futex), so the portable test itself is cross-checked. For every x86-64 case it asserts:

- the `.s` uses COFF directives only (no `@function`, no `.note.GNU-stack`, no `_start`) and exits
  through `call *__imp_ExitProcess(%rip)`;
- the object is `COFF-x86-64` with `IMAGE_FILE_MACHINE_AMD64`, `grail_entry` defined in `.text`,
  and every `__imp_*` reference provided by the generated library;
- the image is PE32+ console with a nonzero entry RVA and a `kernel32.dll` import descriptor
  containing `ExitProcess`, `WriteFile`, `GetCommandLineW` and `CreateFileW` where used, and no
  object imports an ANSI entry point from the `ansiImports` list;
- when Wine is installed, the program's stdout and exit code match the expected values (the
  repository-local `.work/wine-prefix` is used unless `WINEPREFIX` is set);
- the ARM64 cases produce a `COFF-ARM64` / `IMAGE_FILE_MACHINE_ARM64` object with the page/offset/
  branch relocations, an ARM64 PE32+ console image and the expected kernel32 imports, and contain
  no x86 instruction spelling;
- every ARM64 function has an `.xdata` record whose `FunctionLength` is a positive multiple of 4,
  whose prologue contains `stp x29, x30` and `mov fp, sp`, and whose recorded frame size equals
  the `.set .F<n>` value the compiler chose; `.pdata` words carry the RVA form (packed bit clear)
  and the image exception directory is exactly 8 bytes per function;
- `windows-riscv64` is rejected with a diagnostic without clobbering an existing artifact;
- the same programs still build and *run* as Linux ELF (x86-64), including identical argv
  behaviour, and still build as Linux AArch64 and RISC-V ELF.

## ABI limits of the current backend

- **Unwind data without an exception personality.** Frames are described, so a debugger or
  `RtlVirtualUnwind` can walk them, but there is no `.pdata`-driven `__C_specific_handler`
  personality, no `RaiseException` panic path and no handler registration. Hardware faults and
  `ud2` traps terminate the process instead of unwinding. Drop thunks and the entry stub have no
  records.
- **The optimizer is bypassed.** `optimize.grl` recognizes functions by `.type NAME,@function`,
  which COFF output does not emit, so PE programs get no slot forwarding, dead-code removal,
  register promotion or leaf inlining. This is why the prologues are uniform (and unwindable);
  teaching the optimizer the `.def` form is a separate change.
- **Private convention, not a public ABI.** Grail functions do not follow Win64 argument order,
  so they are not callable from C, and callbacks from Win32 (thread start, window procedures,
  handlers) need hand-written thunks that save `%rdi/%rsi/%rbx/%r12-%r15`.
- **Integer-only import arguments.** `raw_win32` passes pointer/integer words; floating-point
  and aggregate parameters or returns are not implemented, and there is no variadic support.
- **Runtime services**: x86-64 threads, joins and address waits work, and `Scope`/`Task` runs the
  same green scheduler as Linux (`rt_os_ctx_*` in `os-windows.grl`, selected by `rt_task_mode()` in
  `runtime.grl`): a task is a Win32 fiber on one scheduler thread, a suspension is a `SwitchToFiber`
  back to it, and the blocking host operations (`host::read_file`, `host::write_file`,
  `host::command`, `host::read_fd`, `host::write_fd`, `host::sleep_ms`) run on a helper thread while
  the task parks, because there is no epoll, eventfd or timerfd. `GRAIL_TASKS=thread` restores the
  old thread-per-task scheduler as an opt-in. `mremap` is emulated by allocate-copy-release;
  sockets on the completion port are still missing.
- **Paths are UTF-8 with a UTF-16 boundary.** Every file and process entry point is the `-W` one and
  a name outside the system code page round-trips; see *Text at the Win32 boundary* above.
- **Long paths are not enabled.** Conversion refuses a path above 8191 units, and the `\\?\` prefix
  that would lift `MAX_PATH` is neither added nor documented for the user to add.
- **Command-line quoting** implements the documented backslash/quote rules; `CommandLineToArgvW`
  corner cases and CRT globbing are not tested.

## Remaining work

1. Exception personality and panics: `RaiseException` plus a handler, then unwinding through
   drop thunks (their conditional prologue needs reshaping before any description is valid).
2. Optimizer support for the `.def` function form, including describing promoted registers.
3. Threads: a `CreateFiberEx`/`SwitchToFiber` bridge for ARM64 (the x86-64 fiber scheduler,
   `CreateThread`, joins and address waits are done; an IOCP reactor is not implemented and the
   runtime offloads a blocking host operation to a helper thread instead).
4. Allocation: `mremap` emulation by allocate-copy-release and a Windows-aware arena policy.
5. Files: `rename` (the runtime has no portable rename operation, so `MoveFileExW` has no caller
   yet) and file metadata (`stat` beyond existence).
6. CLI integration: `grail build --target windows-x86_64` currently points at
   `tools/windows.mjs`; the import library writer and PE link could move into the Grail tool.
7. Runtime acceptance: run the native corpus under Wine, including ownership aborts and UTF-8
   rejection, once unwinding and the error paths exist.

## Sockets: what is verified, and what is not

`win-sockets-echo` runs under Wine and proves the whole path once: `WSAStartup`, an ephemeral
`bind`, `listen`, an overlapped `ConnectEx` whose completion the reactor delivers, `accept`, an
overlapped `WSASend` carrying `ping` plus an emoji, the matching `WSARecv`, the reply, a peer close
read as 0 bytes, and `closesocket` for all three descriptors. `tools/test-windows.mjs` also checks
the object's import slots, so the Winsock entry points (`WSASocketW`, `WSARecv`, `WSASend`,
`WSAIoctl`, `bind`, `listen`, `accept`, `setsockopt`, `closesocket`) have to be in the import table
of an image that uses them.

Open: a server task that accepts in a loop while other tasks connect does not finish under Wine. The
evidence is narrow and reproducible - a connection that is already queued is accepted, a connection
that arrives after the accept call never wakes it, whether the call is `AcceptEx` or a blocking
`accept` on an offload thread, and the client's own `ConnectEx` does complete (it reports a valid
descriptor). Every piece of the machinery is therefore exercised, but the "accept then wait" shape is
not, and on Windows hardware it has to be re-measured before this row is called done. The
completion-port waiter described above is not in the tree for the same reason, and cancellation of a
task blocked in a socket operation is not implemented either: the task parks in the offload
completion, which is not a cancellable wait, exactly as `host::read_file` behaves today.
