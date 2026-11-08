# Windows x86-64 backend (PE/COFF)

Status: first working increment. `--target windows-x86_64` emits COFF-compatible x86-64 assembly,
which the Clang integrated assembler turns into an `IMAGE_FILE_MACHINE_AMD64` object and
`lld-link` links into a console PE32+ image against Grail-generated import libraries. Programs
produced by this increment compile and link but do not yet run: the shipped runtime is still the
Linux runtime and its OS calls are unresolved Win32 work (see *Remaining work*).

## Why assembly, not a hand-written object emitter

The compiler is a text-assembly backend: `native.grl` emits AT&T x86-64, `machine.grl` rewrites
that text for AArch64/RISC-V, and `optimize.grl` rewrites it per function. Keeping one textual
form means the PE target shares checking, lowering and optimisation with the three Linux targets
instead of forking the backend. PE/COFF-specific work therefore lives in three places only:

1. **Directives** (`native.grl`): `.def NAME / .scl 2 / .type 32 / .endef` replaces the ELF
   `.type NAME,@function` for both ordinary functions and closure bodies.
2. **Entry and exit** (`native.grl`): a PE image is entered at `grail_entry` with no argv on the
   stack, so the stub only clears the three process-state words and skips the Linux `%rsp` argv
   walk. Process exit becomes `movl %edi,%ecx; call __imp_ExitProcess` instead of `exit_group`.
3. **x86-only intrinsics**: `raw_map` maps to `VirtualAlloc(0,size,MEM_COMMIT|MEM_RESERVE,
   PAGE_READWRITE)`; the thread pointer uses TEB+0x28 (`%fs:40`) instead of the Linux `%fs:0`.
   Thread creation and stack switching trap (`ud2`) because no Windows thread runtime exists yet.

The trailing `.note.GNU-stack` section is ELF-only and is omitted; `.text`, `.data`, `.bss`,
`.rodata`, `.pushsection/.popsection`, `.p2align` and absolute `.set` symbols are accepted by the
COFF assembler unchanged.

## Calling convention

Two conventions coexist, and the boundary is explicit:

- **Grail-internal calls** keep the existing register order (`%rdi, %rsi, %rdx, %rcx, %r8, %r9`,
  result in `%rax`, callee-saved `%rbx, %r12-%r15` saved in the frame). Six arguments maximum;
  every argument is register-passed and slots are addressed relative to `%rbp`. This is a private
  convention, not a platform ABI: nothing outside Grail code may call a `f_*`/`rt_*` symbol
  directly. It stays valid under Win64 because the only Windows calls into Grail code will be
  loader entry (a fixed stub) and future thread thunks, which save `%rdi/%rsi` themselves.
- **Win32 imports** use the real Win64 ABI: `%rcx, %rdx, %r8, %r9`, 32 bytes of shadow space
  reserved by the caller, 16-byte stack alignment at the call, and `%rax` for the result. The
  compiler emits `subq $48,%rsp` (shadow space plus one stack argument slot, alignment-preserving)
  around each imported call and names only the IAT slot `__imp_<Symbol>`.

`ExitProcess` and `VirtualAlloc` are the only imports the compiler emits today; the import
library already declares the full planned kernel32 surface so the tooling does not change when
the runtime starts using it.

## Import libraries

`tools/windows.mjs` writes its own COFF import library. Each entry point becomes a *short import
object*: the 20-byte `coff_import_header` (`Sig1=0, Sig2=0xffff, Version=0,
Machine=0x8664, TimeDateStamp=0, SizeOfData, Ordinal=0, Type=IMPORT_NAME_NOPREFIX(4)`) followed by
`Name\0kernel32.dll\0`. `llvm-ar rcs` archives them into `kernel32.lib`. `lld-link` expands each
member into an IAT slot, an ILT entry, a hint/name record and an import descriptor, which is why
the compiler can call `__imp_WriteFile` without any linker script. No MinGW/Windows SDK is needed.

Link line used by the tooling:

```sh
lld-link /nologo /entry:grail_entry /subsystem:console /nodefaultlib /dynamicbase /nxcompat \
         /out:program.exe program.obj kernel32.lib
```

## Verification

`bun tools/windows.mjs check` (with `GRAIL_COMPILER` pointing at a tree-built compiler) is a
cross-build suite that never executes guest code, so it runs on any Linux host:

- the emitted `.s` uses COFF directives only (no `@function`, no `.note.GNU-stack`, no `_start`)
  and always calls `__imp_ExitProcess`;
- the object is `COFF-x86-64` with `IMAGE_FILE_MACHINE_AMD64`, `grail_entry` defined in `.text`,
  and every `__imp_*` reference provided by the generated import library;
- the image is PE32+ console with entry point RVA, a `kernel32.dll` import descriptor and exactly
  the expected imported symbols;
- an unknown target is rejected with a diagnostic and does not overwrite an existing artifact;
- the shared x86-64 path still builds and *runs* the same program as ELF.

Wine 11.21 is present on the development host; it executes a hand-written PE produced by this
toolchain, but a compiled Grail program still reaches Linux `syscall` instructions from the
runtime and faults. That is the next increment, not a linker or formatting defect.

## ABI limits of this increment

- **No unwind data.** `IMAGE_DIRECTORY_ENTRY_EXCEPTION` is empty: the assembler's `.seh_*`
  directives require absolute values, while frame sizes are only known after `optimize.grl`
  rewrites the prologue (`.set .F<label>` plus a promotion prelude). Emitting `.pdata`/`.xdata`
  needs the optimizer to describe the final frame, so exceptions and stack walking are not
  supported yet.
- **No runtime.** `compiler/runtime.grl` is still the Linux runtime: allocation goes through
  `raw_map` (now `VirtualAlloc`), but file, console, process and environment calls still use the
  Linux syscall boundary, and thread creation traps. A program links and can be inspected, but
  must not be executed.
- **argv is not recovered** from `GetCommandLineA`; the entry stub stores zeros in the process
  state, so an entry function taking `&[u8]` observes an empty argument vector.
- **Fixed register convention**: no floating-point/aggregate argument passing, no stack-passed
  parameters above six, matching the existing Linux backends.
- The compiler still refuses `--target windows-arm64` etc.; only x86-64 PE is defined.

## Remaining Windows runtime work

1. Split the OS boundary out of `runtime.grl` behind the target, or add a Windows runtime module,
   and route `open/read/write/close/stat/rename/remove/mkdir` through kernel32
   (`CreateFileA`, `ReadFile`, `WriteFile`, `CloseHandle`, `GetFileAttributesA`, …).
2. Console: `GetStdHandle` + `WriteFile`, and UTF-16 to UTF-8 conversion for the broad (`*W`)
   APIs if non-ANSI paths are ever needed.
3. Heap: `VirtualAlloc`/`VirtualFree` policy for the arena allocator, and `mremap` emulation by
   allocate-copy-release for large growth.
4. Process: argv/env from `GetCommandLineA` and `GetEnvironmentVariablesA`, `ExitProcess`, exit
   codes, `Sleep`, `GetSystemTimeAsFileTime` for `now_ms`.
5. Threads and structured concurrency: `CreateThread` with a thunk that saves the Win64
   callee-saved registers, `WaitForSingleObject`, and a futex replacement (SRW locks or
   `WaitOnAddress`) for mutexes and the scheduler.
6. Unwind: `.pdata`/`.xdata` from the optimizer, so failures produce usable stack traces and
   `RaiseException`-based panics can unwind.
7. Runtime acceptance: run the cross-build suite under Wine, then extend it with stdout/exit-code
   assertions once the runtime exists.
