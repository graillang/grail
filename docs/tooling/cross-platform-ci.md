# Cross-platform build, test and distribution foundation

This document is the design and operating manual for Grail's cross-platform
foundation. The implementation is compiler-free: it describes targets, detects
host tools, builds/packages/signs artifacts and gates CI. The only **natively
runnable** compiler backends today are Linux ELF on **linux-x86_64**,
**linux-aarch64** and **linux-riscv64**; the latter two execute under qemu-user
when a runner is installed. **windows-x86_64** emits PE/COFF objects and PE32+
images, and ten test programs execute under Wine, but this release lane ships
**non-executable object bundles** and claims no hosted Windows toolchain.
**windows-aarch64** emits ARM64 PE/COFF objects and images that pass static
checks; there is no ARM64 runner, and its release lane remains planned.
**macos-aarch64** and **macos-x86_64** emit Mach-O objects that are statically
verified; they are **build-only** targets with no macOS execution claim.

The tooling lanes do not implement code generation; the Windows and macOS
backends live in `compiler/native.grl`, `compiler/darwin.grl` and the `os-*`
platform modules.

## Support matrix

| Platform id | OS / CPU | Compiler backend | CI runner | Artifact |
| --- | --- | --- | --- | --- |
| `linux-x86_64` | Linux / x86-64 | implemented (ELF) | `ubuntu-24.04` | `grail-VERSION-linux-x86_64.tar.gz` |
| `linux-aarch64` | Linux / AArch64 | implemented (ELF) | `ubuntu-24.04-arm` | `grail-VERSION-linux-aarch64.tar.gz` |
| `linux-riscv64` | Linux / RISC-V 64 | implemented (ELF) | self-hosted or cross lane | `grail-VERSION-linux-riscv64.tar.gz` |
| `windows-x86_64` | Windows / x86-64 | **build-only** (PE/COFF objects) | `ubuntu-24.04` (cross) | `grail-VERSION-windows-x86_64-objects.zip` |
| `windows-aarch64` | Windows / AArch64 | static-only (ARM64 PE/COFF); release lane planned | `windows-11-arm` | `grail-VERSION-windows-aarch64.zip` |
| `macos-aarch64` | macOS / AArch64 | **build-only** (Mach-O objects) | `ubuntu-24.04` (cross) | `grail-VERSION-macos-aarch64-objects.tar.gz` |
| `macos-x86_64` | macOS / x86-64 | **build-only** (Mach-O objects) | `ubuntu-24.04` (cross) | `grail-VERSION-macos-x86_64-objects.tar.gz` |

- **supported** — the compiler emits a runnable program for that OS/CPU.
- **build-only** — objects and images are built and verified statically; release
  artifacts are non-executable object bundles, not runnable toolchains. Windows
  execution is verified separately under Wine, but no Windows toolchain is
  claimed by these artifacts.
- **planned** — the lane, naming, packaging and signing hooks exist but the
  compiler backend does not. Planned lanes never claim a runnable binary.

`runnable` is an explicit field on every platform and on every lane result.
`windows-x86_64` and both macOS targets are `build-only`/`runnable: false`.
Wine may execute Windows test programs, but that does not make the object bundle
an executable release.

## Build lanes

| Lane | Host | Target | Execution | Required |
| --- | --- | --- | --- | --- |
| `native-linux-x86_64` | `linux-x86_64` | `linux-x86_64` | native | yes |
| `native-linux-aarch64` | `linux-aarch64` | `linux-aarch64` | native | yes |
| `cross-linux-aarch64` | `linux-x86_64` | `linux-aarch64` | qemu-user | yes |
| `cross-linux-riscv64` | `linux-x86_64` | `linux-riscv64` | qemu-user | yes |
| `native-linux-riscv64` | `linux-riscv64` | `linux-riscv64` | native | optional (self-hosted) |
| `cross-windows-x86_64` | `linux-x86_64` | `windows-x86_64` | static | yes (build/static) |
| `native-windows-x86_64` | `windows-x86_64` | `windows-x86_64` | static | optional |
| `cross-windows-aarch64` | `windows-x86_64` | `windows-aarch64` | native | optional |
| `native-windows-aarch64` | `windows-aarch64` | `windows-aarch64` | native | optional |
| `cross-macos-aarch64` | `linux-x86_64` | `macos-aarch64` | static | yes (objects) |
| `cross-macos-x86_64` | `linux-x86_64` | `macos-x86_64` | static | yes (objects) |
| `native-macos-aarch64` | `macos-aarch64` | `macos-aarch64` | static | optional |
| `native-macos-x86_64` | `macos-x86_64` | `macos-x86_64` | static | optional |
| `cross-macos-x86_64-native` | `macos-aarch64` | `macos-x86_64` | static | optional |

Linux cross lanes build the target compiler with the host compiler
(`grail --target ... compiler/*.grl`), assemble with `clang --target=...` and
link with `ld.lld -m ...`. Execution needs `qemu-ARCH-static`; when it is
missing, `bun tools/ci.mjs test --compile-only` still compiles, assembles,
links and verifies the ELF machine type, and the missing runner is reported.

The Windows lane uses `tools/windows.mjs`: it compiles the same compiler
sources with `--target windows-x86_64`, assembles COFF with `clang
--target=x86_64-pc-windows-msvc`, generates the short-import `kernel32.lib`
with `llvm-ar`, and links with `lld-link`. It never executes the image.

The macOS lanes compile with `--target macos-x86_64|macos-aarch64`, the
`darwin.grl` platform module and Mach-O assembly (`x86_64-apple-macos11` /
`arm64-apple-macos11`). Objects are inspected with `llvm-objdump --macho` and
`llvm-nm`; no macOS binary is executed.

## CI workflow and gating

`.github/workflows/ci.yml` has these layers:

1. **tooling** (always green): unit tests for the matrix, archives, packaging
   and signing, `bun tools/ci.mjs lint`, and the matrix/plan report.
2. **preflight**: `bun tools/ci.mjs preflight --json` compares the checked-in
   bootstrap manifest with the compiler sources and exposes `ready`.
3. **runtime ABI**: `bun tools/abi-test.mjs` runs the C contract tests, the
   hosted Linux ABI oracle and header parsing for all five ABI targets.
4. **graphics**: `make -C graphics test` runs the RHI/null-backend/device/wire
   C suites; `bun test graphics/tests/shader_permutations.test.mjs` proves each
   shader permutation compiles to distinct bytecode (it skips when DXC is not
   installed, and says why).
5. **Linux build lanes**: native x86-64/AArch64 and cross AArch64/RISC-V64.
   They run only when `preflight.ready == true`.
6. **Windows x86-64 cross**: builds the host compiler, builds the PE compiler
   image, runs the static COFF/PE checks and packages the build-only zip. CI does
   not execute the images; `bun tools/windows.mjs check` runs eight of the test
   programs under Wine locally, and the job name says `build-only, static`.
7. **Target object bundles**: a matrix job packages non-executable COFF/Mach-O
   object bundles for `windows-x86_64`, `macos-aarch64` and `macos-x86_64` with
   `SHA256SUMS` and `objects.json` provenance. `macos-static` runs the Mach-O
   object/executable checks without executing anything.
8. **Windows/macOS coverage**: detection, `build --allow-blocked` and the
   signing dry-run plan. `--allow-blocked` exits 0 for known backend blockers
   and for not-applicable hosts, so the matrix is exercised without a false
   green binary.
9. **LSP**: the tooling job runs the protocol tests; a preflight-gated `lsp`
   job builds the compiler and runs the compiler-backed stdio session
   (`tools/lsp.test.mjs`).
10. **DWARF line tables**: the preflight-gated `debug-lines` job builds the
    compiler and runs `tools/test-debug-lines.mjs`, verifying `.debug_line`
    rows and `grail debug lines` for Linux x86-64.

`release-sign` is tag-only and environment-gated (`RELEASE_SIGNING=true`).

## Windows x86-64 build-only lane

`tools/ci.mjs` supports `--platform windows-x86_64` from a Linux x86-64 host:

```sh
GRAIL_COMPILER=/path/to/host/grail bun tools/ci.mjs build --platform windows-x86_64
bun tools/ci.mjs test --platform windows-x86_64
bun tools/ci.mjs package --platform windows-x86_64
```

The build compiles the compiler sources to `windows-x86_64`, assembles a COFF
object, generates the in-tree `kernel32.lib` short-import objects and links the
PE32+ console image. Static checks require:

- object: `Format: COFF-x86-64`, `IMAGE_FILE_MACHINE_AMD64`, `grail_entry` in
  `.text`, and every `__imp_*` slot backed by a short-import object;
- image: PE32+, console subsystem, a non-zero entry RVA, a `kernel32.dll`
  import descriptor, and only the expected imports;
- process exit is the `ExitProcess` import, not a Linux syscall;
- a Linux ELF regression still compiles and runs;
- `--target windows-arm64` is rejected without clobbering an existing artifact.

The package contains `share/doc/grail/WINDOWS-BUILD-ONLY.txt` and its manifest
records `tier: build-only`, `runnable: false`, `runtime: unverified`. The image
is **never executed**, even on hosts with Wine: argv recovery, worker threads,
file/directory host services and `.pdata`/unwind data are not implemented.

## Target object bundles (non-executable)

```sh
GRAIL_COMPILER=/path/to/host/grail bun tools/ci.mjs objects --platform macos-aarch64
# dist/grail-0.1.0-macos-aarch64-objects.tar.gz
```

Each bundle contains `objects/grail.obj|.o`, `objects/hello.obj|.o`, gzipped
emitted assembly, `share/grail/objects.json` and
`share/doc/grail/OBJECTS-BUILD-ONLY.txt`. `objects.json` records
`kind: relocatable-object`, `executable: false`, `runnable: false`, the target
triple, object format (`coff`/`macho`), architecture, commit, stage0 digest,
compiler source digests and per-file SHA-256. The archive contains no
executable, dylib or `bin/grail`; verification rejects such entries. A
top-level `SHA256SUMS` sits next to the artifact.

Static checks before packaging:

- COFF: `Format: COFF-x86-64`, `IMAGE_FILE_MACHINE_AMD64`.
- Mach-O: `MH_MAGIC_64` with the expected `ARM64`/`X86_64` cputype,
  `LC_BUILD_VERSION` for macOS, and `_main` defined in `.text`.

No target binary is executed by this lane.

## Runtime ABI and graphics lanes

Two independent suites run on every push and do not need a Grail stage0:

```sh
bun tools/abi-test.mjs
make -C graphics test
bun test graphics/tests/shader_permutations.test.mjs
```

- `tools/abi-test.mjs` compiles and runs the OS ABI contract tests with the
  host C compiler: core/error/Unicode, the hosted Linux reference backend,
  generation-checked handles, POSIX and Windows path rules, and
  `-fsyntax-only` parsing for Linux x86-64/AArch64/RISC-V64, Win64 and Apple
  ARM64 headers. It reports the Linux oracle's check count and zero tracked
  allocations at shutdown.
- `make -C graphics test` builds the C RHI/null backend and runs the ABI,
  device and wire suites (219 checks). `shader_permutations.test.mjs` invokes
  `graphics/tools/shader.mjs` per permutation; without the pinned DXC it skips
  with an explicit reason instead of failing.

## Artifact naming

One scheme, generated by `tools/platforms.mjs`:

```
grail-VERSION-PLATFORM[-compiler][-notary].EXT
```

| Kind | Example |
| --- | --- |
| toolchain package | `grail-0.1.0-linux-aarch64.tar.gz` |
| raw compiler | `grail-0.1.0-linux-aarch64-compiler` |
| Windows compiler | `grail-0.1.0-windows-x86_64-compiler.exe` |
| cross-build assembly | `grail-0.1.0-linux-riscv64-compiler.s.gz` |
| Windows object bundle | `grail-0.1.0-windows-x86_64-objects.zip` |
| macOS object bundle | `grail-0.1.0-macos-aarch64-objects.tar.gz` |
| notarization input | `grail-0.1.0-macos-aarch64-notary.zip` |

`VERSION` (repository root) is the single version source; `GRAIL_VERSION`
overrides it for release builds. `SHA256SUMS` sits next to every artifact set.
`artifactPattern()` is the validation contract used by lint, packaging and CI.

## Package layout and installers

Every package uses the layout the compiler already expects:

```
grail-VERSION-PLATFORM/
  bin/grail[.exe]
  lib/grail/runtime.grl
  lib/grail/std/*.grl
  share/doc/grail/{README.md,LICENSE,CHANGELOG.md}
  share/grail/package.json          # version, commit, target, file SHA-256s
  install.sh                        # POSIX (Linux/macOS)
  install.ps1                       # PowerShell (Windows)
  share/doc/grail/WINDOWS-BUILD-ONLY.txt   # build-only Windows packages
```

Linux/macOS produce `tar.gz`; Windows produces `zip`. Both writers are internal
(`tools/archive.mjs`), sort entries, use `SOURCE_DATE_EPOCH` (default 0) and
write identical bytes for identical inputs, so packaging does not depend on the
host's `tar`/`zip`.

Install:

```sh
./install.sh "$HOME/.local"        # or DESTDIR=... ./install.sh /usr/local
powershell -File .\install.ps1 -Prefix "$env:LOCALAPPDATA\Grail" [-AddToPath]
```

The installers copy `bin/grail` plus `lib/grail/{runtime.grl,std/}` so an
installed binary finds its runtime without `GRAIL_HOME`.

## Toolchain and SDK detection

`bun tools/ci.mjs detect --all` reports, per platform:

- required build tools (`clang`, `ld.lld`, `ld64.lld`), with version when the
  tool supports `--version`;
- the SDK: system glibc on Linux, `xcrun --sdk macosx --show-sdk-path` on
  macOS, MSVC/mingw-w64 sysroot on Windows;
- signing tool and credentials by **name** only;
- the backend status (`implemented` or `blocked`) and missing tools.
- the QEMU runner for Linux cross lanes, including the local
  `.work/architectures/toolchain/usr/bin` fallback.

Environment overrides already used by the compiler are honoured:
`GRAIL_ASSEMBLER`, `GRAIL_LINKER`, `GRAIL_QEMU_X86_64`, `GRAIL_QEMU_AARCH64`,
`GRAIL_QEMU_RISCV64`, plus `GRAIL_COMPILER` for a tree-built stage0.

## Signing and notarization hooks

`bun tools/ci.mjs sign ...` is a dry-run by default: it prints the exact
commands and never resolves secrets. `--execute` resolves env values only for
the child process and never logs them.

- **Linux (optional)**: `GRAIL_GPG_KEY` enables
  `gpg --batch --yes --detach-sign --armor --local-user $GRAIL_GPG_KEY <archive>`.
  Without it the artifact is explicitly `unsigned`.
- **Windows Authenticode**: `WINDOWS_CERT_FILE`, `WINDOWS_CERT_PASSWORD`,
  `WINDOWS_TIMESTAMP_URL`; uses `signtool sign /fd SHA256 /td SHA256 /tr ...`
  or `osslsigncode sign -pkcs12 ...`. Archives are signed after extraction
  (`--binary <tree>/bin/grail.exe`).
- **macOS**: `APPLE_SIGNING_IDENTITY`, `APPLE_NOTARY_PROFILE`;
  `codesign --force --options runtime --timestamp`, then `ditto` to build the
  notarization zip and `xcrun notarytool submit ... --wait`. Stapling is only
  emitted for a `.dmg` (`--dmg`), because notarization tickets do not attach to
  bare CLI binaries.

## Reproducibility

- `SOURCE_DATE_EPOCH` controls archive timestamps (default `0`).
- Entries are sorted; tar uses ustar, zip uses stored entries with UTF-8 names.
- `share/grail/package.json` records version, platform, target, commit and the
  SHA-256 of every file.
- `build` writes `*.build.json` with the stage0 digest, source digests and
  observed binary format.

## Local commands

```sh
bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs
bun tools/ci.mjs lint
bun tools/ci.mjs matrix
bun tools/ci.mjs plan
bun tools/ci.mjs detect --all
bun tools/ci.mjs preflight --json

# With a working stage0 (published bootstrap or GRAIL_COMPILER):
GRAIL_COMPILER=/path/to/grail bun tools/ci.mjs build --platform linux-x86_64
GRAIL_COMPILER=/path/to/grail bun tools/ci.mjs build --platform linux-aarch64
GRAIL_COMPILER=/path/to/grail bun tools/ci.mjs test --platform linux-x86_64
GRAIL_COMPILER=/path/to/grail bun tools/ci.mjs test --platform linux-riscv64 --compile-only
GRAIL_COMPILER=/path/to/grail bun tools/ci.mjs package --platform linux-x86_64
GRAIL_COMPILER=/path/to/grail bun tools/ci.mjs build --platform windows-x86_64
bun tools/ci.mjs test --platform windows-x86_64
bun tools/ci.mjs package --platform windows-x86_64
bun tools/ci.mjs sign --platform linux-x86_64 --artifact dist/grail-0.1.0-linux-x86_64.tar.gz
bun tools/abi-test.mjs
make -C graphics test
bun test graphics/tests/shader_permutations.test.mjs
```

Exit codes: `0` ok, `1` usage/internal, `2` not applicable to this host,
`3` blocked (backend or stage0), `4` missing dependency, `5` failure.

## Current blockers

1. **Stale published bootstrap.** `compiler/bootstrap/manifest.json` records
   source hashes from before the typed-reference migration, so
   `bun tools/native.mjs build` cannot compile the current tree. Workaround:
   build a stage0 from a migration-capable compiler and pass
   `GRAIL_COMPILER=/path/to/grail`. Refreshing bootstraps needs
   `bun tools/bootstrap.mjs update all` on a host where all three bootstraps
   execute (QEMU for AArch64/RISC-V64).
2. **No qemu-user on the development host.** Linux x86-64 native tests pass;
   AArch64/RISC-V64 are cross-assembled and architecture-checked, but execution
   waits for `qemu-aarch64-static` / `qemu-riscv64-static`.
3. **No hosted Windows/macOS toolchain release.** Windows x86-64 PE/COFF
   builds are verified statically and executed under Wine by
   `tools/windows.mjs check`; macOS Mach-O objects/linked images are verified
   statically. The release artifacts in this lane are non-executable object
   bundles, and no macOS execution is claimed. Windows AArch64 remains a
   planned backend.
4. **No hosted RISC-V64 runner.** RISC-V64 is covered by the x86-64 cross lane;
   native RISC-V64 remains an optional self-hosted lane.
