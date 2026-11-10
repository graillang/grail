# Sampling profiler: `grail profile`

Status: **implemented for Linux x86-64**. The sampler is part of the program's own runtime, so no
external profiler, `perf`, `nm` or `addr2line` is involved at any point.

```sh
grail build main.grl
grail profile --rate 1000 -- ./target/main
```

```
grail profile: ./target/main
  non-PIE (ET_EXEC): sample addresses are link-time .symtab addresses, no adjustment
  1000 Hz ITIMER_PROF, 396 samples in 0.40 s of CPU time (effective 996 Hz)

  samples  share  function                    module
      392  99.0%  hot                         main
        3   0.8%  rt_syscall                  runtime
        1   0.3%  cool                        main
        0   0.0%  [unknown]                   -
      396 100.0%  total
```

## Usage

`grail profile [--rate N] [--out FILE] -- PROGRAM [ARGS]`

- `--rate N` — samples per second of CPU time to request (default 200, maximum 1000000). The timer
  interval is `1/N` seconds of CPU time, but the kernel accounts CPU time per tick, so the effective
  rate tops out around one kilohertz and very high requests buy nothing: the report always prints
  the measured CPU time and the effective rate (`samples / CPU seconds`), and says so when the
  request could not be honoured. Short programs need a higher rate for a useful table: at 200 Hz,
  0.05 s of CPU gives ten samples.
- `--out FILE` — also write the report to `FILE`. The report always goes to stdout, and the
  program's own output is forwarded before it.
- `--` separates the program and its arguments. Everything after the first non-flag token belongs to
  the program.
- The exit status is the program's own exit status, so `grail profile` composes with scripts.

`grail profile` only works on Linux x86-64 binaries built by this compiler: the target must contain
the runtime sampler described below.

## What the numbers mean

| Column | Meaning |
| --- | --- |
| `samples` | Samples whose interrupted instruction pointer fell inside this symbol's range. |
| `share` | `samples` as a percentage of the total, rounded to a tenth. |
| `function`, `module` | The ELF symbol name `f_<module>_<function>` split in two. `runtime` functions appear under module `runtime`; other unresolved symbols keep their whole name. |
| `[unknown]` | Samples whose address is outside every `STT_FUNC` symbol in the program's `.symtab` (libc, the loader, the vDSO, a stripped program). Always printed, even at 0, so nothing is silently dropped. |
| `total` | Every sample the timer produced, including `[unknown]`. Always equals the sum of the rows. |

Two extra lines above the table state:

- how addresses were interpreted: `non-PIE (ET_EXEC)` means sample addresses are the link-time
  addresses in `.symtab` and no adjustment was made. A position-independent (`ET_DYN`) binary is
  reported as such and every sample falls into `[unknown]`, because the load bias is not known on
  the inspecting side;
- the requested rate, the sample count, the measured CPU time and the effective rate. The CPU time
  comes from `CLOCK_PROCESS_CPUTIME_ID` in the target (read when sampling is armed and again when the
  samples are written), not from `samples / rate`, so a capped rate cannot make the run look
  shorter than it was.

A third line appears when the fixed buffer filled up: `N samples dropped after the 65536-sample
buffer filled`. Raising `--rate` lowers the time a buffer covers, so a very long run at a high rate
should be split or re-run at a lower rate.

## How it works

1. `grail profile` creates a private scratch directory under `TMPDIR` (`/tmp` when the variable is
   unset) with `mkdir`, which is the atomic claim that keeps two profilers started in the same
   millisecond apart, and puts the arming request in the target's environment:
   `GRAIL_PROFILE="1 RATE CAPACITY SAMPLEPATH"`. The environment is the inherited one plus that
   entry, composed with `host::environment()` and passed with `host::command_with`, so the target
   still sees everything it would have seen and nothing is written to its working directory.
2. At startup the runtime (`compiler/runtime.grl`) reads `GRAIL_PROFILE`. When it is present on
   Linux x86-64 it maps a control page plus a 65536-entry address buffer, installs a 64 KiB
   alternate signal stack, installs a `SIGPROF` handler with `SA_SIGINFO|SA_RESTART|SA_ONSTACK` and
   starts `ITIMER_PROF` with interval `1/rate`. A killed run cannot arm a later one: the request
   exists only in the environment of the process the command started.
3. The handler reads the interrupted `RIP` from the `ucontext_t` the kernel passes as its third
   argument, claims a slot with a CAS loop (no lock, no allocation, no syscall) and stores one word.
   It cannot deadlock against the allocator: it never takes the allocator lock and never allocates.
   Samples beyond the buffer's capacity are counted, not stored.
4. On normal exit, `host::exit` or a runtime abort, the runtime stops the timer and writes
   `GRPROF2\n`, the rate, capacity, count, dropped count and the measured CPU nanoseconds, then the
   raw addresses.
5. `grail profile` reads the sample file, removes it and the scratch directory, parses the
   program's ELF `.symtab` (section headers,
   `SHT_SYMTAB` and its linked `.strtab`) and attributes each address with a binary search over
   `STT_FUNC` symbols sorted by address. The compiler emits no `st_size`, so a function's range runs
   from its start to the next function's start; trailing literal data inside `.text` is therefore
   charged to the function before it.

No external tool takes part: the assembler and linker are only used by `grail build`, and the
profile itself needs neither a debug section nor a symbol server.

## Honest limitations

- **Leaf attribution only.** A sample names the function the instruction pointer was in. There is no
  stack walk, so a sample in `rt_alloc` is not also charged to its caller; there is no inclusive
  time and no call graph. A frame-pointer or `.eh_frame`-based unwinder is future work.
- **Inlining.** The optimiser may inline a small function into its caller (and `--debug` builds do
  not). When that happens the samples appear under the caller's symbol. There is no inlined-frame
  information in the profile: `many samples in main` can mean "main is hot" or "an inlined callee
  is hot".
- **No line or column attribution.** There is no `.debug_info`/`.debug_line` lookup in the report, so
  the table stops at function granularity. `grail debug lines` already reads line tables when a
  `--debug` build exists; wiring the profiler to it is future work.
- **CPU time, not wall time.** `ITIMER_PROF` counts user plus system CPU time, so a program blocked
  in a read, sleeping or waiting on a lock collects no samples while it is idle. That is deliberate
  for a CPU profile, but it means "no samples" is not "no time". Time spent in the kernel is
  sampled: the interrupted `RIP` is in the syscall wrapper, which is why `rt_syscall` can appear in
  the table of a program that mostly calls `host::now_ms`.
- **Sampling bias.** The timer fires on a fixed interval of CPU time and the kernel delivers the
  signal when it next returns to user mode. Instructions around syscalls, signal delivery and the
  handler itself are therefore not sampled uniformly; a loop that is shorter than one timer tick may
  be attributed unevenly across runs. Above roughly one kilohertz the kernel's per-tick accounting
  rounds the interval up, so the effective rate stops following `--rate`; that is reported rather
  than hidden.
- **One process, not its children.** The request is an environment variable, so a program that
  spawns Grail programs *with the inherited environment* arms them too, and all of them write to
  the same sample path: the report is whichever process wrote last (normally the target). A child
  started with an explicit environment - `host::command_with`, or `authority::spawn_with` - is not
  armed unless the request is copied into that environment. Nested and concurrent profiles are no
  longer tied to a working directory, but a target that spawns Grail children still shares one
  sample file with them.
- **No report without an exit.** Samples are written when the runtime shuts down. A killed program
  (SIGKILL, a crash inside foreign code, a `SIGSEGV` the runtime does not handle) leaves no report.
- **Cost in every program.** The sampler is compiled into every Grail binary: about 3.4 KiB of
  x86-64 `.text` on a hello-world build, plus a scan of the environment for `GRAIL_PROFILE` at
  every program start (a few hundred comparisons over the inherited variable names, no allocation
  and no syscall). With no such variable no timer is started and no signal handler is installed.
- **Linux x86-64 only.** The handler reads the `ucontext_t` layout of that ABI and uses its syscall
  numbers. The code is compiled into every program but does nothing on other targets;
  `grail profile` refuses to run there. AArch64 and RISC-V would need their `ucontext_t` offsets and
  `setitimer`/`rt_sigaction` numbers; Windows and macOS need a different sampler entirely.
- **Stripped or non-Graal binaries.** A stripped program reports every sample as `[unknown]`. A
  binary without the Grail runtime never writes samples, and `grail profile` reports that instead of
  inventing a profile.
- **The sample file needs a writable `TMPDIR`.** The command creates its scratch directory there and
  the target writes the samples into it. A target whose environment has no `TMPDIR` does not care:
  the path is absolute and comes from the request, not from the target's own variables.

## Tests and CI

`tools/test-profile.mjs` builds a program with a known hot loop, checks that the default build is
`ET_EXEC`, runs `grail profile --rate 1000`, and asserts that the hot function is the first row with
more than half of the attributed samples, that the `[unknown]` row exists, that the rows add up to
the total, that `--out` matches stdout, that the target still sees an environment variable the
runner set (the request travels through `host::command_with`, not through a file), and that no
rendezvous directory and no `grail-profile-` scratch directory is left behind. When
`llvm-strip` or `strip` is available it also strips a copy and asserts that every sample then falls
into `[unknown]` instead of being dropped. Run it with `just profile-test`; CI runs it in the
`profiler` job and `bun tools/ci.mjs lint` asserts the test, this page and the job exist.
