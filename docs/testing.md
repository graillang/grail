# Running the tests locally

Every suite runs from the repository root with Bun. The compiler is built on demand and cached by
content under `.work/native/<hash>/`; the tools print the compiler path when `GRAIL_COMPILER` is not
set.

## `grail test`: one command, two corpora

`grail test` is the front door, and what it runs depends on where it runs:

- **In the Grail tree** (a `tests/native-cases.json` and a `tools/test-native.mjs` beside the working
  directory) it forwards every argument to `tools/test-native.mjs`. That is one engine, not two: the
  semantics of `grail test --filter ffi- --jobs 8` and `bun tools/test-native.mjs --filter ffi- --jobs 8`
  are the same by construction, and every gate that calls the tool directly keeps working.
- **In a project** (`grail new`, a `grail.pkg` and programs under `tests/`) it compiles each selected
  program and runs it; a non-zero exit is the failure. Paths on the command line are files or
  directories, and the default is `tests/`.

Both print the same report: one `test NAME ... ok` line per case, a `FAIL NAME` block for each
failure (the name, its source path, the exit status and signal, and what the program printed), and a
final `passed X failed Y skipped Z` line. The exit status is 0 when nothing failed, 1 when something
did, so `grail test` is a gate in a script.

| flag | meaning |
|---|---|
| `--filter TEXT` | only cases whose name (corpus) or path (project) contains TEXT |
| `--list` | print the selected names and run nothing |
| `--shard i/n` | run shard i of n, by position |
| `--jobs N` | run N in flight: the corpus engine starts N child processes, one stripe of cases each, and a project starts one child per test with a per-test log. The report is still in case order, `--fail-fast` included |
| `--fail-fast` | stop at the first failure. With `--jobs N` the tests already running finish, and the ones that never started are reported as `skipped` |
| `--update` | corpus only: rewrite the expectations of the selected cases that differ, and nothing else |

`--update` rewrites a case's `stdout` and `status`, because those are what a run observes exactly. A
`stderr` pin and a `signal` pin are contracts of their own (a rejection's diagnostic above all), so a
case whose other pins still disagree is reported as not rewritten instead of being made to pass.
Nothing is rewritten without `--update`, and the file keeps its generated formatting (JSON escapes for
non-ASCII, two-space indent, one trailing newline).

The `GRAIL_TEST_FILTER`, `GRAIL_TEST_SHARD`, `GRAIL_TEST_RESUME=1` and `GRAIL_TEST_JOBS` environment
knobs still work and mean what they always did; the flags are the same selections spelled on the
command line.

## The full gate

```sh
export PATH="$HOME/.local/qemu-static/usr/bin:$PATH"     # qemu-user for the cross targets
C=$(bun tools/native.mjs build 2>&1 | tail -1)
export GRAIL_COMPILER=$C GRAIL_FFI_COMPILER=$C

for t in 'test-native.mjs x86_64' test-cli.mjs 'book.mjs check' test-selfhost.mjs \
         abundance-test.mjs borg-test.mjs test-ffi.mjs 'ci.mjs lint' test-debug-lines.mjs \
         'windows.mjs check' lsp-test.mjs test-profile.mjs test-authority.mjs test-facts.mjs \
         split-test.mjs 'test-native.mjs aarch64' 'test-native.mjs riscv64'; do
  echo "== $t"; bun tools/$t 2>&1 | tail -2
done
for t in x86_64 aarch64 riscv64; do GRAIL_BACKEND=llvm bun tools/test-native.mjs $t; done
```

The typed-IR facts (two of them, F1 and F2) can be checked on top of that: `GRAIL_BACKEND=llvm
GRAIL_VERIFY_FACTS=1 bun tools/test-native.mjs x86_64` makes the lifter assert `fpext(fptrunc(d)) ==
d` at every word a fact treats as an `f32` (F2), and check `cap >= len` on every word a fact treats
as a sequence header (F1), so a wrongly typed slot or call aborts instead of printing a plausible
wrong number. It is off by default because the check costs a compare per fact use.

`ci.mjs lint` is the cheapest check and catches most documentation and workflow drift.

## The aarch64 emulator

The aarch64 legs run under the repository's own `qemu-aarch64-static`: QEMU 11.1.3 with
`tools/qemu/stlr-rcsc.patch`, built by `tools/qemu/build.sh` into
`.work/architectures/toolchain/usr/bin/`, which `runner()` in `tools/native.mjs` uses ahead of
`PATH` (only `GRAIL_QEMU_AARCH64` comes first). Stock 11.1.3 puts a barrier before a store-release
and after a load-acquire but none between them, so on an x86 host an `stlr` followed by an `ldar`
can pass each other, which ARMv8 forbids (both are RCsc). The store-buffering litmus test
(`tests/atomics/litmus_sb.grl`) caught it: at 200,000 rounds stock qemu let through 31-704
forbidden outcomes for the native backend and 2,469-7,458 for LLVM, and the patched build none.
Two barriers, one after each store-release form, close it, with no measurable cost on the filtered
corpus. The build script fetches the tarballs, checks their sha256, builds a static zlib (the host
has no `libz.a`) and QEMU, and needs no root; it does nothing when the installed binary is already
this one, so `tools/gate.sh` runs it every time and prints the version line of the emulator its legs
use. Check a binary with `--version`: it must end in `(grail-stlr-rcsc)`.
`bun tools/test-atomics-litmus.mjs` asserts store buffering under that binary, and only reports
under any other qemu.

## Two traps worth knowing

**Do not set `GRAIL_SYSROOT_*` unless you have a real glibc sysroot.** The cross targets link
statically by default, which needs no libc. Without a sysroot, a case that declares
`extern "C"` cannot link on aarch64/riscv64 (there is no `-lc` to find), so those fixtures carry
`"targets": ["x86_64"]` and the runner counts them in the summary's `skipped`. Pointing
`GRAIL_SYSROOT_AARCH64` at a tree that only holds QEMU binaries *causes* the `-lc` failure, because
it switches the link to dynamic.

**The bootstrap reseed needs QEMU on `PATH` too.** `bun tools/bootstrap.mjs update all` compiles the
compiler for every target and *runs* the aarch64/riscv64 results to check self-hosting, so without
`$HOME/.local/qemu-static/usr/bin` on `PATH` it fails with `compiler execution failed (null)` and a
`qemu-aarch64-static: not found` line in the captured output. It also hashes the compiler sources as
it starts and refuses to publish if they change mid-run, so do not edit `compiler/*.grl` while it
runs. Expect up to an hour per emulated target.

**The seed is checked in compressed.** `compiler/bootstrap/native.s.zst` (and `aarch64.s.zst`,
`riscv64.s.zst`) is the same assembly zstd-compressed, so a reseed adds a few megabytes instead of
50 or 160. It is the file a clone assembles: `bootstrap.mjs update` writes it, and every reader
(`tools/native.mjs buildCompiler`, `ci.mjs preflight`, `bootstrap.mjs verify`) goes through
`seedAssemblyPath`, which decompresses once into `.work/bootstrap-seeds/<compressed-digest>.s` and
holds the result to the manifest. `manifest.json` records the digest of the compressed bytes *and*
the digest and size of the assembly they decompress to, so a stale or corrupt seed is refused by
exactly the same check as before. It is plain zstd (Bun's `node:zlib` compresses and decompresses it,
so no tool or package is needed), and the `zstd` CLI can read it too - `zstd -dc
compiler/bootstrap/native.s.zst | sha256sum` must print the `sha256` in the manifest. Never edit a
seed by hand; `bun tools/bootstrap.mjs update <arch>` rewrites it.

The seed carries no path from the machine that built it: a call-site table names each file relative to
the working directory (`compiler/native.grl`, the form a runtime error prints), so `bootstrap.mjs
verify` matches in any clone and a reseed is a change in the compiler, not in where it was run.
`tools/native.mjs` pins `PWD` to the tree root for the compiler runs that produce a seed, so running
the tools from a subdirectory cannot reintroduce absolute names.

**A host builtin that the compiler itself calls needs a two-step bootstrap.** The checked-in seed
(`compiler/bootstrap/native.s.zst`) *is* the compiler, including its table of `host::` builtins in
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

**Full matrix per batch, not per merge.** A full gate is 860 cases on three backends plus two
emulated targets; running it for every branch makes each merge cost an hour. The budget that works:

| when | what |
|---|---|
| every merge | the suites for the area that changed, **one shard** (`GRAIL_TEST_SHARD=1/4`) |
| every batch | the full matrix once, in CI rather than here |
| publication (a release, or a batch of compiler work is done) | reseed the bootstrap, then fresh-clone build + full matrix |

**Reseed at publication points only.** The published seed exists so a clone with no development
compiler can build; development uses a tree-built compiler (`GRAIL_COMPILER`) and does not need a
fresh seed. A stale seed makes `preflight` red, which is correct and expected between publications -
reseed when you publish, not when you merge. A reseed regenerates three targets by self-compiling the
compiler, and the aarch64/riscv64 halves run under qemu: budget ~90 minutes, and do not start one
while agents are gating, because both want the same cores.

**Cross-target legs belong in CI.** aarch64 and riscv64 under qemu are 40+ minutes each for the full
corpus; a native arm64 runner does them in minutes. Run them locally when the target is what you are
changing, not as part of every gate.

**Slice a suite instead of waiting for it.** A full native run is minutes per backend, so the runner
takes opt-in selection and reporting flags (a plain invocation is unchanged; the older environment
knobs, `GRAIL_TEST_FILTER` / `GRAIL_TEST_SHARD` / `GRAIL_TEST_RESUME=1` / `GRAIL_TEST_JOBS`, still mean
the same thing):

    bun tools/test-native.mjs x86_64 --filter '^ffi-'                # one area, seconds
    bun tools/test-native.mjs x86_64 --shard 2/4                     # a quarter, for parallel gates
    bun tools/test-native.mjs x86_64 --jobs 8 --filter '^ffi-'        # the same area, eight stripes
    bun tools/test-native.mjs x86_64 --list --filter 'doc-'           # what a filter selects
    GRAIL_TEST_RESUME=1 bun tools/test-native.mjs x86_64             # skip cases that already passed

`--jobs N` splits the selection into N stripes, one child process each, with their own case
directories, snapshots and resume markers; the parent merges the reports and prints them in case
order. It is a different axis from `--shard`: shards partition a selection for *separate* gates,
stripes partition it inside *one* run.

One thing `--jobs` changes: a case runs in a **deeper** directory, `.work/native-tests/<target>/stripe-<i>-<n>/<case>`
rather than `.work/native-tests/<target>/<case>`. A case whose `args` are relative paths into the
tree — the five `lib-zlib`, `lib-png`, `lib-jpeg`, `lib-png-write` and `lib-zstd` corpus cases pass
`../../../../tests/lib/<name>` — therefore look one level too shallow under `--jobs` and report
`cannot read a corpus file` with `0 cases, 0 failures`. They are not broken: run them without
`--jobs` (they pass), or run the corpus in jobs mode and read those five as a known artifact. A
green full run in jobs mode is `passed X failed 5` with exactly those names.

Shards are safe to run **in parallel with each other** in one worktree: each case owns
`.work/native-tests/<target>/<case>`, and a shard's case set is disjoint from every other shard's. Native and LLVM runs of one target use separate directories (`x86_64`, `x86_64-llvm`, `x86_64-llvm+facts`), so they may overlap too. What
is *not* safe is a shard or a filtered run started while a **full** run of the same target and backend is still
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
  LLVM backend. `--backend=llvm` is a flag of the compiler, not of `grail build`: the driver has no
  LLVM path (it assembles and links only `OUT.s`, never the `OUT.s.ll` the backend writes beside it),
  so an LLVM build is `compileProgram` in `tools/native.mjs` — what this corpus does — or the
  compiler plus `clang -O2 -c OUT.s.ll`. A case that asserts something the LLVM backend does not
  emit is scoped instead of guessed at: the statement table is native only
  (`docs/design/task-failure-containment.md`, Limits), so the cases that read a failure's `site`
  name `"backends": ["native"]`.
- `test-selfhost.mjs` — the compiler compiles itself twice and the two outputs must be identical.
- `split-test.mjs` — per-module emission: the parts must concatenate to the single assembly file, the
  objects must match it outside relocations, and the linked programs must behave identically. It also
  covers `grail build --split` itself, and proves that the default per-module build (`--per-module`
  included) makes the same program as `--whole-program` on x86-64, AArch64 and RISC-V.
- `book.mjs check` — every book example compiles, runs, and matches its expected output next to an
  equivalent Rust program.
- `abundance-test.mjs`, `borg-test.mjs` — the ports, compared bit-for-bit against their C++ and
  reference outputs.
- `test-optimiser-jumps.mjs` — the text optimiser follows its jumps: a loop with a branch keeps its
  state in registers across the back edge, and over the compiler's own sources (`GRAIL_OPT_STATS=1`
  writes `# grail-jumps <known> <unknown>` before each body) at least 99% of the direct jumps have a
  target the passes know.
- `test-facts.mjs` — both typed-IR facts (docs/design/typed-ir.md): F2's `f32` fixtures' exact values
  with and without `--verify-facts` and the round-trip check in the module, F1's header facts on a
  vector read through its own header (the fact table in the module, the slots and call arguments
  that carry one, and that the native backend's answer is unchanged), and the address-taken slot the
  lifter must drop. F1 is consumed only where the hoist it performs is provably usable, which on this
  corpus is nowhere, so its numbers are about the fact table rather than speed.
- `test-ffi.mjs` — C interop fixtures, reporting how many are executed versus cross-compiled only.
- `windows.mjs check` — PE/COFF cross-builds plus the executed subset under Wine. The task cases
  run on the default green scheduler; `tasks-thread-mode` sets `GRAIL_TASKS=thread` (per-case `env`
  in `tests/windows-cases.json`, passed to both the Wine and the ELF run) to pin the opt-in
  thread-per-task scheduler.
- `lsp-test.mjs`, `test-profile.mjs`, `test-authority.mjs` — the language server, the sampling
  profiler and the capability model.

## The full gate

`tools/gate.sh [--reseed] [LOGDIR]` runs every leg the merge gate needs: the corpus on x86-64,
AArch64 and RISC-V, the LLVM backend plain and with range facts verified on x86-64 and on the
emulated targets (below), and every tool suite
(self-host, FFI, CLI, interface, cache, split, facts, debug lines, Abundance, Borg, grammar,
Windows under Wine, the book, lint). `--reseed` first republishes the bootstrap; `bootstrap.mjs
update all` already proves self-hosting and assembly identity on every target, so no separate
`verify` follows. At most three legs run at once - this machine has crashed under more - and
independent legs overlap within that cap. Each leg logs to `LOGDIR/<leg>.log` ending in `exit=N`;
`LOGDIR/summary.txt` lists failures first, and `LOGDIR/DONE` is written last.

The LLVM backend on AArch64 and RISC-V is two legs per target: `llvm_<arch>_vec`, the `vec` cases
(about a minute each), and `llvm_<arch>_shard<i>of3`, one third of the corpus (about 25 minutes
under qemu). The third is not rotated by date: `i` is the first hex digit of
`git rev-parse HEAD^{tree}` mod 3, plus 1, so the same tree always runs the same cases and the leg's
name says which. Reproduce a failure with `GRAIL_BACKEND=llvm GRAIL_TEST_SHARD=<i>/3 bun
tools/test-native.mjs <arch>`. `ci.mjs lint` checks that the legs are there.

### Two builds of the same compiler must not share a path

`buildCompiler` names its intermediates after the hash of its inputs, not after the process, so two
tools that build the compiler at once in one worktree used to write the same `compiler.s` and
`grail.pending.o` and destroy each other: the symptoms were clang's "no preprocessable inputs" and
ld's "cannot open ...grail.pending.o" inside `command()`, which read like a broken build rather than
a collision. The intermediates now carry the process id and the final name is claimed by `rename`,
which is atomic, so a second caller either finds the finished binary or builds its own copy and
loses the race harmlessly. That is what makes `GATE_JOBS > 1` safe for the tool legs.

## Landing on main

Every branch lands through one queue: `bash tools/land.sh BRANCH` (or `just land BRANCH`). The branch
must already contain `origin/main`: merge main into it and resolve the conflicts on the branch, where
the owner knows both sides. The queue runs one landing at a time on exactly that tree: the build, the
self-host fixed point, the x86_64 corpus in three shards and the tool suites, retrying a failure once
on its own. Green fast-forwards main; anything else leaves main unchanged and says why. The emulated
aarch64/riscv64 legs then run on the build host and are fixed forward. `tools/land-known.txt` lists
the failures that do not block, each with an owner; it only ever shrinks. `tools/land.sh --status`
shows the queue and the last landings.
