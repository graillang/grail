# macOS backend: Mach-O, Apple ABIs and libSystem

`macos-x86_64` and `macos-aarch64` are the two Mach-O targets. They reuse the same checked word
stream, optimizer and instruction selection as the Linux ports (`compiler/native.grl`,
`compiler/machine.grl`); only the object format, the process entry, the symbol spelling and the
system boundary differ. Everything below is implemented in this tree and checked statically by
`tools/test-macos.mjs`. **Nothing in this section has been executed on macOS hardware.**

## Target selection

```
grail [--target macos-x86_64|macos-aarch64] OUT.s ENTRY.grl MODULE.grl... darwin.grl runtime.grl
```

The CPU remains `target` (0 x86-64, 1 AArch64, 2 RISC-V); the object format is a separate
`plat` flag (0 ELF, 1 Mach-O). `raw_target()` reports the combination as 0/1/2 for ELF and
10/11 for Mach-O, which is how the portable runtime decides that it hands operation numbers
straight to the Darwin bridge instead of remapping Linux syscall numbers. RISC-V has no Mach-O
form; `macos-riscv64` is rejected.

## Emitted assembly

Mach-O differences from the ELF output, all in `compiler/native.grl` and `compiler/machine.grl`:

| Concern | ELF output | Mach-O output |
| --- | --- | --- |
| Build metadata | — | `.build_version macos, 11, 0` |
| Function symbols | `f_mod_name`, `rt_*` | `_f_mod_name`, `_rt_*` (leading underscore) |
| ELF-only directives | `.type sym,@function`, `.note.GNU-stack` | omitted |
| Read-only data | `.pushsection .rodata` | `.pushsection __TEXT,__const` |
| Zero-fill state | `.bss` + `rt_state: .zero 4096` | `.section __DATA,__bss` + `.space 4096` |
| AArch64 page address | `adrp x13,sym` + `:lo12:sym` | `adrp x13,sym@PAGE` + `sym@PAGEOFF` |
| Entry symbol | `_start` (kernel entry) | `_main` (C `main`, called by libSystem) |

Symbol underscores are applied in one place: `mangle` for Grail functions, `sym` for imported
libSystem names and data, and a final line pass (`darwinify`) for direct calls and address
materialisation that the compiler emits from string literals. Imported names are C names
(`raw_import("write", ...)` becomes `call _write`); a name that already begins with `_` is used
as the final symbol, which is how libc internals such as `__error` (Mach-O `___error`) are
reached.

## Process entry and Apple calling convention

`_main` is entered by libSystem with `argc`, `argv`, `envp` in the C argument registers
(`rdi`/`rsi`/`rdx`, or `x0`/`x1`/`x2`) and a 16-byte-aligned stack whose guard page is already
installed. The emitted stub stores the three words in `_rt_state`, calls `_rt_thread_init`, calls
the Grail entry function and finishes through `_exit`, so the runtime's balanced-allocation check
and `rt_shutdown` still run before exit:

```
_main: pushq %rbp        # x86-64: 16-byte-align the frame
       movq %rsp,%rbp
       movq %rdi,_rt_state(%rip)      # arm64: str x0,[x13] via adrp/add
       movq %rsi,_rt_state+8(%rip)
       movq %rdx,_rt_state+16(%rip)
       call _rt_thread_init
       ...  program, rt_live check, rt_shutdown, call _exit
```

Grail's own convention already matches the Apple ABIs for uniformly word-sized arguments and
results: six word arguments in `rdi,rsi,rdx,rcx,r8,r9` / `x0-x5`, result in `rax` / `x0`,
callee-saved `rbx,r12-r15` / `x19-x23`, `rbp`/`x29` frames. Frames are sized to a multiple of 16
and every prologue preserves 16-byte stack alignment (`div(n+1,2)*16`, `stp x29,x30,[sp,#-16]!`),
so a call into libSystem is ABI-clean at the call instruction. x18 is never allocated, and no
red zone is used.

Limitations: the ABI is word-only, so no argument is passed in vector registers and no value is
returned in `xmm0`/`d0` (floating-point values travel as IEEE bit patterns in words). Variadic C
functions are therefore not callable, and `char`/`short`-typed parameters are not widened by the
caller as C requires; the boundary only calls fixed-signature libSystem entry points whose
parameters the runtime passes as full words.

## libSystem boundary

`compiler/darwin.grl` (`unsafe module darwin`) is compiled **only** for Mach-O targets, so ELF
objects contain no Apple imports. It decodes the runtime's stable operation numbers into libSystem
calls and converts `(-1, errno)` back into the runtime's negative-errno convention
(`raw_import("___error")`).

| Operation | libSystem | Notes |
| --- | --- | --- |
| read, write, open, close | `read`, `write`, `open`, `close` | `O_CLOEXEC`/`O_DIRECTORY`/`O_NONBLOCK`/`O_EXCL`/`O_TRUNC`/`O_APPEND` bits are translated |
| mprotect, munmap, mmap | `mprotect`, `munmap`, `mmap` | anonymous maps use `MAP_ANON|MAP_PRIVATE` (0x1002) |
| mremap | `mmap` + copy + `munmap` | macOS has no `mremap`; the arena chain is updated with the new address |
| sched_yield, nanosleep, clock_gettime | same names | `CLOCK_MONOTONIC` is 6 on Darwin, 1 on Linux |
| exit / exit_group | `_exit` | no atexit chain or stdio flush |
| getpid, kill, fork, execve, wait4 | same names | `fork` is allowed but discouraged by Apple |
| mkdirat, unlinkat | `mkdir`, `rmdir`/`unlink` | `AT_REMOVEDIR` selects `rmdir` |
| ppoll | `poll` | `NULL` timeout maps to `-1` (infinite) |
| pipe2, getdents64, sched_getaffinity | `pipe`, `getdirentries64`, `sysconf` | directory records and the cpu-set mask are rewritten in the Linux shapes the runtime parses |
| threads (`clone`) | — | reported as `ENOSYS`; see limits |

## Linking

`tools/native.mjs` assembles with `clang --target=x86_64-apple-macos11` or
`--target=arm64-apple-macos11` and links with `ld64.lld`:

```
ld64.lld -arch x86_64|arm64 -platform_version macos 11.0 11.0 -L <dir> -lSystem -e _main obj -o out
```

Without an SDK there is no `libSystem.tbd`, so the test driver exports a stub `tbd` from the
object's own undefined symbols (plus `dyld_stub_binder`). That produces a structurally complete
executable — `LC_BUILD_VERSION`, `LC_MAIN`, `LC_LOAD_DYLIB /usr/lib/libSystem.B.dylib`,
`NOUNDEFS` — but it is a link-time artifact only and cannot run on Linux. With a real SDK,
`grail build --target macos-*` links against `$GRAIL_SDK/usr/lib/libSystem.tbd` with
`-syslibroot`; without one it stops after writing the object and says so. Framework linking is
not wired up yet; it needs `-framework NAME` plumbing and an SDK.

## What still needs macOS hardware or an SDK

- Execution of any emitted binary, and therefore all runtime, ownership and self-hosting checks.
- Refreshing `compiler/bootstrap/*` for this revision (`bun tools/bootstrap.mjs update all`
  needs the ELF/AArch64/RV64 runs plus QEMU) and a real `libSystem`/framework link.
- Real macOS verification of `_exit`, `poll`, `getdirentries64`, `mremap` emulation and the
  `errno` translation; the code paths mirror the documented Darwin ABI but are unexecuted.
- Threads, `mutex<T>`, `parallel_map` and the readiness reactor: Darwin needs `pthread_create`
  with a per-thread self pointer (macOS exposes no writable thread-pointer register) and
  `kqueue`/`poll` instead of `epoll`/`eventfd`/`timerfd`/`futex`. Those operations currently
  return `ENOSYS`, so the async runtime and worker pools fail cleanly instead of misbehaving.
- Sockets are not mapped (Darwin `sockaddr_in` carries `sin_len`, and `SOCK_CLOEXEC` is not a
  socket-type flag), so `host::tcp_*` returns `ENOSYS`.
