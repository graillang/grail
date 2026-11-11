# Running the tests locally

Every suite runs from the repository root with Bun. The compiler is built on demand and cached by
content under `.work/native/<hash>/`; the tools print the compiler path when `GRAIL_COMPILER` is not
set.

## The full gate

```sh
export PATH="$HOME/.local/qemu-static/usr/bin:$PATH"     # qemu-user for the cross targets
C=$(bun tools/native.mjs build 2>&1 | tail -1)
export GRAIL_COMPILER=$C GRAIL_FFI_COMPILER=$C

for t in 'test-native.mjs x86_64' test-cli.mjs 'book.mjs check' test-selfhost.mjs \
         abundance-test.mjs borg-test.mjs test-ffi.mjs 'ci.mjs lint' test-debug-lines.mjs \
         'windows.mjs check' lsp-test.mjs test-profile.mjs test-authority.mjs test-facts.mjs \
         'test-native.mjs aarch64' 'test-native.mjs riscv64'; do
  echo "== $t"; bun tools/$t 2>&1 | tail -2
done
for t in x86_64 aarch64 riscv64; do GRAIL_BACKEND=llvm bun tools/test-native.mjs $t; done
```

The typed-IR `f32` facts can be checked on top of that: `GRAIL_BACKEND=llvm GRAIL_VERIFY_FACTS=1
bun tools/test-native.mjs x86_64` makes the lifter assert `fpext(fptrunc(d)) == d` at every word a
fact treats as an `f32`, so a wrongly typed slot or call aborts instead of printing a plausible
wrong number. It is off by default because the check costs a compare per fact use.

`ci.mjs lint` is the cheapest check and catches most documentation and workflow drift.

## Two traps worth knowing

**Do not set `GRAIL_SYSROOT_*` unless you have a real glibc sysroot.** The cross targets link
statically by default, which needs no libc. Without a sysroot, a case that declares
`extern "C"` cannot link on aarch64/riscv64 (there is no `-lc` to find), so those fixtures carry
`"targets": ["x86_64"]` and the runner reports them as `skipped (host-only)`. Pointing
`GRAIL_SYSROOT_AARCH64` at a tree that only holds QEMU binaries *causes* the `-lc` failure, because
it switches the link to dynamic.

**The bootstrap reseed needs QEMU on `PATH` too.** `bun tools/bootstrap.mjs update all` compiles the
compiler for every target and *runs* the aarch64/riscv64 results to check self-hosting, so without
`$HOME/.local/qemu-static/usr/bin` on `PATH` it fails with `compiler execution failed (null)` and a
`qemu-aarch64-static: not found` line in the captured output. It also hashes the compiler sources as
it starts and refuses to publish if they change mid-run, so do not edit `compiler/*.grl` while it
runs. Expect up to an hour per emulated target.

**A host builtin that the compiler itself calls needs a two-step bootstrap.** The checked-in seed
(`compiler/bootstrap/native.s`) *is* the compiler, including its table of `host::` builtins in
`compiler/native.grl` — so a seed recorded before the builtin existed cannot compile a
`compiler/*.grl` that calls it:

```text
compiler/cli.grl:1623:40: unknown function at byte 50438 near '('
  |     mut environment = host::environment();
```

The cycle is closed in two steps, and both of them need `GRAIL_COMPILER` set to a compiler that
already knows the builtin (build one from the same sources with an older seed that does not call it,
or with a seed that has been reseeded once):

```sh
unset GRAIL_COMPILER                            # the trap: an explicit stage0 is accepted as-is
bun tools/ci.mjs preflight                      # sub-second; names a stale seed in its blockers
export GRAIL_COMPILER=/path/to/staged/grail      # a compiler that knows the new builtin
bun tools/native.mjs build                      # -> echoes GRAIL_COMPILER: the tree is buildable
bun tools/bootstrap.mjs verify x86_64           # ~20 s, works with GRAIL_COMPILER set: "checked-in
                                                #   bootstrap is stale" if the seed predates the builtin
bun tools/bootstrap.mjs update all              # reseeds every target from these sources
unset GRAIL_COMPILER
rm -rf .work && bun tools/native.mjs build       # the check CI runs: a fresh clone with no dev compiler
```

`ci.mjs preflight` is the cheapest check of all: it compares the source digests recorded in
`compiler/bootstrap/manifest.json` with the working tree and blocks with `published bootstrap is
stale for: compiler/…`. **It only says that with `GRAIL_COMPILER` unset** — an explicit stage0 is
accepted as-is, which is exactly how a branch can be green in every suite and still fail CI.
`bootstrap.mjs verify <host>` is the slower exact version: it compiles the compiler with whatever
compiler is available, proves the result self-hosts to identical assembly, and compares that against
the checked-in seed, so it reports the staleness even when `GRAIL_COMPILER` is set.

`bootstrap.mjs` calls `buildCompiler()`, which honours `GRAIL_COMPILER`, so both of its steps must
run with the same variable set; without it, `update all` re-enters the stale seed and fails the same
way. A builtin used *only* by user code (a program, `lib/`, a fixture) does not need any of this: it
is resolved when that program is compiled by a compiler that has the new table, and the seed is only
ever asked to compile the compiler's own sources. If the compiler's own sources must call the
builtin, a reseed on the same branch is part of the change, not a follow-up.

The fresh-clone step is the one to run before pushing such a change. `GRAIL_COMPILER` makes every
suite pass while the published seed still cannot build the compiler, so a branch can be green locally
and still fail CI's clean-clone preflight; `ci.mjs` already refuses a stale seed, it just never ran
here.

**An abort case is host-only.** qemu reports an abort as a delivered signal (`qemu: uncaught target
signal 6`), while natively the process exits 134 (128+SIGABRT) - the B5 policy. A case that pins the
exit *status* of an abort therefore carries `"targets": ["x86_64"]`, and the policy is verified natively
(plus on Windows under Wine, with its own case), not through emulation.

**Slice a suite instead of waiting for it.** A full native run is minutes per backend, so the runner
takes three opt-in knobs (a plain invocation is unchanged):

    GRAIL_TEST_FILTER='^ffi-' bun tools/test-native.mjs x86_64      # one area, seconds
    GRAIL_TEST_SHARD=2/4 bun tools/test-native.mjs x86_64            # a quarter, for parallel gates
    GRAIL_TEST_RESUME=1 bun tools/test-native.mjs x86_64             # skip cases that already passed

Shards are safe to run **in parallel with each other** in one worktree: each case owns
`.work/native-tests/<target>/<case>`, and a shard's case set is disjoint from every other shard's. What
is *not* safe is a shard or a filtered run started while a **full** run of the same target is still
alive — they select overlapping cases and then collide on the same directory (`unable to rename
temporary … .o.tmp`). Kill the full run first; a killed shell does not kill it. Resume markers are keyed by the compiler's content-addressed
path and the backend, so a rebuilt compiler or a different `--backend` never reuses another run's passes.

**Long suites outlive their shells.** `timeout 9000 bun tools/test-native.mjs …` keeps running when the
wrapper process is killed (a backgrounded exec that is reaped, an OOM kill of the shell), so a retry
silently doubles the load: two or more suites then share `.work/native-tests/<target>/` and both crawl,
which looks exactly like a hang. Before retrying, check and kill the *inner* command:

    ps -eo pid,etime,args | rg 'tools/test-nativ[e]\.mjs'   # note the bracket: it stops the pattern matching itself
    pkill -f 'tools/test-nativ[e]\.mjs'

**A `pkill -f` pattern that matches your own command line kills the run you just started.** A command
like `pkill -f 'test-native.mjs x86_64'; … bun tools/test-native.mjs x86_64` matches its own wrapper
and dies before the suite starts, producing no log and no output — which reads identically to a suite
that failed silently. Use the bracketed pattern above, or kill by pid.

**Check memory before a long run.** The LLVM and `--verify-facts` passes compile and link every case;
on a machine that is also building something large, the kernel's OOM killer ends them as
`exit=137` / `compiler crashed (SIGKILL)`, which is not a compiler failure. `free -g` first: below
about 30 GB available, wait.

**Run one suite per worktree at a time.** `test-native.mjs` and the other runners use
`.work/native-tests/<target>/<case>/` inside the worktree, so two suites started in the same
checkout delete each other's intermediate files. The symptom is a bogus clang failure such as
`unable to rename temporary … .o.tmp: No such file or directory`, which looks like a backend bug and
is not. Use a separate worktree per concurrent run, or serialize them.

## Timing

On a loaded machine the x86-64 native suite is roughly 10–20 minutes, the aarch64 and riscv64 suites
are slower because every case runs under QEMU, and the LLVM legs recompile the whole corpus. A full
gate is 2–3 hours; run it in a watched job that logs to a file rather than holding a terminal.

## What each suite covers

- `test-native.mjs <target>` — compile, run and compare `tests/native-cases.json` (execution,
  diagnostics and intentional rejections). `GRAIL_BACKEND=llvm` runs the same corpus through the
  LLVM backend.
- `test-selfhost.mjs` — the compiler compiles itself twice and the two outputs must be identical.
- `book.mjs check` — every book example compiles, runs, and matches its expected output next to an
  equivalent Rust program.
- `abundance-test.mjs`, `borg-test.mjs` — the ports, compared bit-for-bit against their C++ and
  reference outputs.
- `test-facts.mjs` — the typed-IR `f32` facts (docs/design/typed-ir.md, F2): the fixtures' exact
  values with and without `--verify-facts`, the round-trip check in the module, and the
  address-taken slot the lifter must drop.
- `test-ffi.mjs` — C interop fixtures, reporting how many are executed versus cross-compiled only.
- `windows.mjs check` — PE/COFF cross-builds plus the executed subset under Wine. The task cases
  run on the default green scheduler; `tasks-thread-mode` sets `GRAIL_TASKS=thread` (per-case `env`
  in `tests/windows-cases.json`, passed to both the Wine and the ELF run) to pin the opt-in
  thread-per-task scheduler.
- `lsp-test.mjs`, `test-profile.mjs`, `test-authority.mjs` — the language server, the sampling
  profiler and the capability model.
