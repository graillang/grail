# Main-thread stack exhaustion, and why it says nothing

A task's stack is guarded: `rt_os_stack_guard_install` maps a `PROT_NONE` page at the low end, the
handler reports `error: stack overflow` and exits 134. The **main thread's** stack has neither, and
the difference is visible to a user:

```grl
fn f(n: u64) -> u64 { if n == 0 { return 0; } return 1 + f(n - 1); }
fn main() -> u64 { println(f(100000000)); return 0; }
```

```
$ ./deep && echo $?
Segmentation fault (core dumped)
139
```

No message, no line, no frame. Every other way a program can die in this language names what happened
and where (see `frontend-robustness.md`, classes 1-3). This is the last one that does not.

## Why it is not the same fix as a task stack

A task stack is memory the runtime allocates, so the runtime can reserve a guard page below it and
know the usable range. The main thread's stack is created by the kernel at `exec` and grows on demand
down to `RLIMIT_STACK`; there is no page the runtime can mark `PROT_NONE` without either moving the
stack (dangerous: frame pointers, TLS, unwinders) or pre-faulting a bound and enforcing it ourselves.

So the achievable goals, in order of value:

1. **Say what happened.** A `SIGSEGV` whose fault address is within a stack's worth of the current
   stack pointer is a stack overflow with near-certainty; report `error: stack overflow` with the
   site table's location and exit 134, exactly as a task does.
2. **Do not lie about other faults.** A `SIGSEGV` far from the stack pointer is a real memory fault
   and must not be reported as an overflow.
3. Do not change how much stack a program gets. This is a diagnostic change, not a policy change.

## The mechanism

- Install a `SIGSEGV` handler with `SA_ONSTACK` on an alternate stack (the runtime already owns one
  for the task-stack path, so this reuses it), only on Linux x86-64/aarch64/riscv64 to start.
- In the handler, read the fault address (`si_addr`) and the interrupted stack pointer
  (`ucontext`'s `RSP`/`SP`/`sp`). If `si_addr` is below `sp` and within one page of it, or within a
  window of a few kilobytes, it is a stack overflow; otherwise re-raise the default disposition so
  the process dies as it does today.
- The overflow report goes through the same path as `rt_stack_overflow`: claim the abort once,
  write `error: stack overflow` plus the site location, exit 134.
- The handler must not allocate and must not touch the guard region, so the reporting path is
  syscalls and the static site table only - the same constraint the task path already meets.

## What it must prove

- The repro above prints `error: stack overflow` and exits 134, and the message carries a location.
- A deliberate wild pointer (`unsafe { *(0 as *mut u64) = 1 }`) still dies by SIGSEGV with no
  "stack overflow" text, i.e. the handler does not swallow genuine memory faults.
- Recursion that ends normally (`f(1000)`) is unaffected - no handler fires, no cost.
- A task stack overflow still reports as it does today, through its own guard page; the two paths
  agree in wording.
- The runtime's own recursive-descent parser (the compiler) does not print an overflow report when it
  is simply deep, which the existing corpus legs already cover.

## Implemented (2026-11-16)

The handler is installed for the main thread at startup, in `rt_os_init`, before any user code runs
(`rt_os_stack_guard_install_main` in `compiler/os-linux.grl`): a 64 KiB alternate stack whose base is
kept in process-state word 3592 - the main thread has no worker block to keep it in, unlike the
workers `rt_os_stack_guard_install` prepares - and the same `SIGSEGV` handler a worker installs,
with `SA_ONSTACK|SA_SIGINFO` (plus the `SA_RESTORER` trampoline on x86-64). The `sigaltstack`
record sits in the bottom 64 bytes of that mapping; the handler's frames grow down from its top,
64 KiB away.

**When a fault is an overflow.** Only all three of these hold:

- the signal is `SIGSEGV` (a task's guard fault can also be `SIGBUS`, and that stays the task path's
  business);
- the thread is not running a green task (`rt_current() == 0`): a task's overflow is its guard page's
  job, and a second opinion by distance there would only add a way to be wrong;
- the fault address lies in `[sp - 65536, sp + 4096)`, where `sp` is the interrupted stack pointer
  read out of the `ucontext` the kernel passes as the handler's third argument.

The window is 64 KiB below because it has to hold a *frame*, not a page: an ordinary push faults a
few bytes below `sp`, and a function whose frame is larger than a page faults at the address it has
just reserved. One page *above* `sp` is admitted because that is where a large frame's first touch
lands - the repro's fault address is exactly `sp + 8` (`movq %rdi,-8(%rbp)` in the frame prologue).
Everything else restores `SIG_DFL` and returns, so the faulting instruction runs again and the
process dies of the signal exactly as it does with no handler installed.

**The per-target `ucontext` offsets** are these, in `rt_os_ctx_sp` / `rt_os_ctx_pc`:

| target | `uc_mcontext` | stack pointer | instruction pointer |
| --- | ---: | ---: | ---: |
| x86-64 | 40 | `gregs[15]` = 160 | `gregs[16]` = 168 |
| aarch64 | 176 | `sp` = 432 | `pc` = 440 |
| riscv64 | 176 | `sp` = 192 | `pc` = 176 |

Taken with `offsetof()` against each target's own headers, not from memory:

```
struct ucontext uc; unsigned long v[] = {offsetof(ucontext_t, uc_mcontext.gregs[REG_RSP]), ...};
```

compiled by `aarch64-linux-gnu-gcc` and `riscv64-linux-gnu-gcc` and read back with `readelf -x
.data` (432/440 and 192/176). x86-64's 160/168 is the pair the sampling profiler already reads `RIP`
from. The offsets differ in *shape*, not just in value: asm-generic puts the 128-byte sigmask before
a 16-aligned `uc_mcontext`, which is why aarch64 and riscv64 start at 176, and RISC-V's
`user_regs_struct` begins `pc, ra, sp`, so its `pc` sits *below* its `sp`.

**The report** is `rt_stack_overflow_at` in `compiler/runtime.grl`: one `rt_abort_begin` claim,
`error: stack overflow`, then ` --> file:line:col`, then the cleanup-free exit at 134. Nothing is
allocated - the message is built in process-state scratch a byte at a time, and the location line in
the report block beside it (state words 3600..3840), both written straight to fd 2.

A task's overflow still prints the message alone, as it always has; the main thread's names a place,
because its frames are intact but unreachable and the statement can be read from the interrupted
instruction pointer instead of from a frame walk.

The rule is "the statement that names a place and lies in the function the fault address is in": the
entry at or before the address if there is one, otherwise the first entry after it. The second half
is not decoration - a prologue fault is *common* in a deep recursion (the frame's stores land in the
page that cannot be committed; on aarch64 the faulting `stp` is the first instruction of the
function, so the entry at the fault address is the function's own positionless one), and a
positionless entry carries no file by design. Both halves are checked against the function table, so
a function whose body has no statement, and a runtime function, report no place rather than borrowing
their neighbour's.

**What is still silent**, and why that is not a lie:

- a frame that skips more than 64 KiB below `sp`, or a fault more than a page above it, keeps the
  default action - the window is a diagnostic's, not a promise about how much stack a program gets,
  and this changes how much stack a program gets by nothing;
- `SIGBUS` on the main stack;
- thread-per-task tasks (`GRAIL_TASKS=thread`), whose stacks are runtime-made but whose overflow the
  guard page already owns;
- Windows and macOS, as below.

**The evidence** (four cases in `tests/native-cases.json`, executed on x86-64 and - for the three
that need no libc - under QEMU on aarch64 and riscv64):

| case | what it sees |
| --- | --- |
| `main-stack-overflow-reports-and-exits-134` | `before` on stdout, `error: stack overflow` + ` --> ` on stderr, status 134 |
| `wild-pointer-dies-by-sigsegv-without-an-overflow-report` | `strlen(cnull())` dies by `SIGSEGV` with no `stack overflow` text (x86-64 only: it needs libc) |
| `deep-recursion-that-ends-is-unaffected` | `f(1000)` prints `1000`, status 0, stderr empty |
| `task-stack-overflow-reports-and-exits-134` | unchanged: a task's overflow still prints the same message and exits 134 |

`docs/design/scheduler.md` ("Stack overflow") states the same handler for both stacks.

## Deliberately out of scope

- Growing the main stack on demand (segmented stacks, `ucontext` surgery) - a different language.
- Windows and macOS: `vectored` exception handler and `sigaltstack` respectively have the same shape,
  but neither is verifiable on this host, so they follow once a runner exists.
- Turning the recursion into an error the caller can handle: exhaustion is not a recoverable
  condition in this design, and `Option`-wrapping it would push a check into every call.
