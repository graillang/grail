# Windows x86-64 backend (PE/COFF)

Status: working console backend. `--target windows-x86_64` emits COFF-compatible x86-64 assembly;
the Clang integrated assembler turns it into an `IMAGE_FILE_MACHINE_AMD64` object and `lld-link`
links a console PE32+ image against Grail-generated import libraries. A portable-runtime subset
that talks to kernel32 runs under Wine: console output, formatted integers/floats, file
write/read, exit codes and command-line arguments are verified by `tools/windows.mjs check`.

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

## Runtime surface

The Windows OS layer implements the operation IDs the portable runtime already uses:

| Operation | Win32 calls |
| --- | --- |
| read / write / close | `ReadFile`, `WriteFile`, `CloseHandle` (`GetStdHandle` for fd 0..2) |
| open | `CreateFileA` with Linux access/disposition flags translated |
| mapped memory | `VirtualAlloc` (`raw_map`), `VirtualFree` (munmap) |
| process | `ExitProcess`, `GetCurrentProcessId` |
| time | `GetTickCount64` (monotonic ms), `Sleep` |
| files/directories | `GetFileAttributesA`, `CreateDirectoryA`, `DeleteFileA`, `RemoveDirectoryA` |
| startup | `GetCommandLineA` + `GetEnvironmentStringsA`, `SwitchToThread` |

Threads, sockets, epoll, futex and directory streams return `-ENOSYS`; the portable runtime
reports or aborts on those paths, and no thread creation is emitted. `mremap` is unimplemented, so
growing an allocation of 512 KiB or more aborts instead of moving the arena.

## Verification

`bun tools/windows.mjs check` (with `GRAIL_COMPILER` pointing at a tree-built compiler) checks
eight programs: hello, u64 exit code, integer printing, float printing, file write/read,
single-argument entry, struct fields and a full argv list. For every case it asserts:

- the `.s` uses COFF directives only (no `@function`, no `.note.GNU-stack`, no `_start`) and exits
  through `call *__imp_ExitProcess(%rip)`;
- the object is `COFF-x86-64` with `IMAGE_FILE_MACHINE_AMD64`, `grail_entry` defined in `.text`,
  and every `__imp_*` reference provided by the generated library;
- the image is PE32+ console with a nonzero entry RVA and a `kernel32.dll` import descriptor
  containing `ExitProcess`, `WriteFile`, `GetCommandLineA` and `CreateFileA` where used;
- when Wine is installed, the program's stdout and exit code match the expected values (the
  repository-local `.work/wine-prefix` is used unless `WINEPREFIX` is set);
- `windows-arm64` is rejected with a diagnostic without clobbering an existing artifact;
- the same programs still build and *run* as Linux ELF, including identical argv behaviour.

## ABI limits of the current backend

- **No unwind data.** `IMAGE_DIRECTORY_ENTRY_EXCEPTION` is empty: the assembler's `.seh_*`
  directives need absolute values, while frame sizes are only known after `optimize.grl` rewrites
  the prologue (`.set .F<label>` plus a register-promotion prelude). A usable `.pdata`/`.xdata`
  description must therefore come from the optimizer. Exceptions, panics that unwind, and stack
  walking are unsupported.
- **Private convention, not a public ABI.** Grail functions do not follow Win64 argument order,
  so they are not callable from C, and callbacks from Win32 (thread start, window procedures,
  handlers) need hand-written thunks that save `%rdi/%rsi/%rbx/%r12-%r15`.
- **Integer-only import arguments.** `raw_win32` passes pointer/integer words; floating-point
  and aggregate parameters or returns are not implemented, and there is no variadic support.
- **Missing runtime services**: threads, sockets, directory listing, `exe_path`
  (`GetModuleFileNameA` is not wired) and `mremap`. Environment lookups walk the pointer table
  built from `GetEnvironmentStringsA`; `GetEnvironmentVariableA` is declared but unused.
- **ANSI paths only.** `CreateFileA`/`GetFileAttributesA` truncate non-ANSI names to the active
  code page; the `*W` APIs and UTF-16 conversion are future work.
- **Command-line quoting** implements the documented backslash/quote rules; `CommandLineToArgvW`
  corner cases and CRT globbing are not tested.

## Remaining work

1. `.pdata`/`.xdata` from the optimizer, then `RaiseException`-based panics and usable stack
   traces.
2. Threads: `CreateThread` with a Win64-compatible thunk, `WaitForSingleObject`, and
   `WaitOnAddress`/SRW locks to replace futex and the scheduler's epoll boundary.
3. Allocation: `mremap` emulation by allocate-copy-release and a Windows-aware arena policy.
4. Files and processes: directory streams (`FindFirstFileA`), `GetModuleFileNameA`,
   `MoveFileA`/remove semantics, and the `*W` APIs with UTF-16 conversion.
5. CLI integration: `grail build --target windows-x86_64` currently points at
   `tools/windows.mjs`; the import library writer and PE link could move into the Grail tool.
6. Runtime acceptance: run the native corpus under Wine, including ownership aborts and UTF-8
   rejection, once unwinding and the error paths exist.
