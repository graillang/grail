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

## Deliberately out of scope

- Growing the main stack on demand (segmented stacks, `ucontext` surgery) - a different language.
- Windows and macOS: `vectored` exception handler and `sigaltstack` respectively have the same shape,
  but neither is verifiable on this host, so they follow once a runner exists.
- Turning the recursion into an error the caller can handle: exhaustion is not a recoverable
  condition in this design, and `Option`-wrapping it would push a check into every call.
