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
| open | `CreateFileA` with Linux access/disposition flags translated |
| mapped memory | `VirtualAlloc` (`raw_map`), `VirtualFree` (munmap) |
| process | `ExitProcess`, `GetCurrentProcessId` |
| time | `GetTickCount64` (monotonic ms), `Sleep` |
| files/directories | `GetFileAttributesA`, `CreateDirectoryA`, `DeleteFileA`, `RemoveDirectoryA` |
| startup | `GetCommandLineA` + `GetEnvironmentStringsA`, `SwitchToThread` |

Threads, sockets, epoll, futex and directory streams return `-ENOSYS`; the portable runtime
reports or aborts on those paths, and no thread creation is emitted. `mremap` is unimplemented, so
growing an allocation of 512 KiB or more aborts instead of moving the arena.

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

The entry stub is the same `grail_entry` shape: zero the three process-state words, align SP
(`andq $-16,%rsp` lowers to `and sp,sp,#...`), call `rt_thread_init` (which parses the Win32
command line) and call the Grail entry. Import libraries are the same short-import objects with
`Machine = 0xAA64`, assembled with `clang --target=aarch64-pc-windows-msvc` and linked with
`lld-link /machine:arm64`.

Static evidence for the hello image: object `Format: COFF-ARM64`, `IMAGE_FILE_MACHINE_ARM64
(0xAA64)`, `grail_entry` in `.text`, relocations `IMAGE_REL_ARM64_PAGEBASE_REL21`,
`PAGEOFFSET_12A/12L` and `BRANCH26`; image PE32+ console with a nonzero entry RVA and a
`kernel32.dll` import descriptor. Four programs (hello, integer printing, file write/read, full
argv list) are compiled and inspected by `tools/windows.mjs check`.

ARM64 limits: no `.pdata`/`.xdata` yet (Windows ARM64 wants packed unwind entries, which the
x86-only `.seh_*` pass does not produce), so frames are not described; the runtime gaps
(threads, sockets, directory streams, `mremap`, ANSI-only paths, integer-only import arguments)
are the same as x86-64. Execution is not testable on this host: Wine on x86-64 cannot run an
ARM64 PE image and `qemu-aarch64-static` is a Linux-ELF emulator, so ARM64 acceptance requires an
ARM64 Windows host, ARM64 Wine, or a Windows-on-ARM machine.

## Verification

`bun tools/windows.mjs check` (with `GRAIL_COMPILER` pointing at a tree-built compiler) checks
eight x86-64 programs: hello, u64 exit code, integer printing, float printing, file write/read,
single-argument entry, struct fields and a full argv list, plus four windows-aarch64 programs
validated statically. For every x86-64 case it asserts:

- the `.s` uses COFF directives only (no `@function`, no `.note.GNU-stack`, no `_start`) and exits
  through `call *__imp_ExitProcess(%rip)`;
- the object is `COFF-x86-64` with `IMAGE_FILE_MACHINE_AMD64`, `grail_entry` defined in `.text`,
  and every `__imp_*` reference provided by the generated library;
- the image is PE32+ console with a nonzero entry RVA and a `kernel32.dll` import descriptor
  containing `ExitProcess`, `WriteFile`, `GetCommandLineA` and `CreateFileA` where used;
- when Wine is installed, the program's stdout and exit code match the expected values (the
  repository-local `.work/wine-prefix` is used unless `WINEPREFIX` is set);
- the ARM64 cases produce a `COFF-ARM64` / `IMAGE_FILE_MACHINE_ARM64` object with the page/offset/
  branch relocations, an ARM64 PE32+ console image and the expected kernel32 imports, and contain
  no x86 instruction spelling;
- `windows-riscv64` is rejected with a diagnostic without clobbering an existing artifact;
- the same programs still build and *run* as Linux ELF (x86-64), including identical argv
  behaviour, and still build as Linux AArch64 and RISC-V ELF.

## ABI limits of the current backend

- **x86-64 only `.pdata`.** Windows ARM64 images have no exception directory (packed unwind
  entries are not emitted); the x86-64 description still lacks an exception personality.
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
- **Missing runtime services**: threads, sockets, directory listing, `exe_path`
  (`GetModuleFileNameA` is not wired) and `mremap`. Environment lookups walk the pointer table
  built from `GetEnvironmentStringsA`; `GetEnvironmentVariableA` is declared but unused.
- **ANSI paths only.** `CreateFileA`/`GetFileAttributesA` truncate non-ANSI names to the active
  code page; the `*W` APIs and UTF-16 conversion are future work.
- **Command-line quoting** implements the documented backslash/quote rules; `CommandLineToArgvW`
  corner cases and CRT globbing are not tested.

## Remaining work

1. Exception personality and panics: `RaiseException` plus a handler, then unwinding through
   drop thunks (they need unwind records of their own or a reshaped prologue).
2. Optimizer support for the `.def` function form, including describing promoted registers.
3. Threads: `CreateThread` with a Win64-compatible thunk, `WaitForSingleObject`, and
   `WaitOnAddress`/SRW locks to replace futex and the scheduler's epoll boundary.
4. Allocation: `mremap` emulation by allocate-copy-release and a Windows-aware arena policy.
5. Files and processes: directory streams (`FindFirstFileA`), `GetModuleFileNameA`,
   `MoveFileA`/remove semantics, and the `*W` APIs with UTF-16 conversion.
6. CLI integration: `grail build --target windows-x86_64` currently points at
   `tools/windows.mjs`; the import library writer and PE link could move into the Grail tool.
7. Runtime acceptance: run the native corpus under Wine, including ownership aborts and UTF-8
   rejection, once unwinding and the error paths exist.
