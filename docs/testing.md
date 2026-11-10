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
