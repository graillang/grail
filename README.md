# Grail

A self-hosted language/compiler exploring explicit ownership, checked arithmetic and compact,
uniform syntax. The compiler and runtime are written in Grail and emit native assembly for
Linux **x86-64, ARM64 and RISC-V 64**.

```grl
fn main() {
    mut data = u8[10, 20, 30];
    data.push(40);
    println(data[1]);
    println(data.pop());
}
```

- **Learn:** [Grail by Example](book/README.md), an offline book with runnable Rust comparisons.
- **Build / cross-compile:** [compiler/README.md](compiler/README.md).
- **Semantics:** [compiler/NATIVE.md](compiler/NATIVE.md).
- **Tests:** `bun tools/test-native.mjs` and `bun tools/book.mjs check`.
- **Cross-platform CI / release tooling:** [docs/tooling/cross-platform-ci.md](docs/tooling/cross-platform-ci.md).
- **LSP / debugger / profiler plan:** [docs/tooling/lsp-debugger-profiler.md](docs/tooling/lsp-debugger-profiler.md).
- **Sampling profiler (Linux x86-64):** `grail profile --rate N -- PROGRAM`; see
  [docs/tooling/profiler.md](docs/tooling/profiler.md).
- **Verified cross-platform status:** [docs/platform-status.md](docs/platform-status.md) distinguishes executed targets from scaffolding and cross-builds.
- **Graphics RHI from Grail:** [docs/rhi.md](docs/rhi.md) covers the SDL3 window and the Vulkan instance, physical devices and queue families in `abundance/src/`, what the FFI cannot express yet, and the next increments; `bun tools/abundance-test.mjs` runs both RHI probes.
- **Cross-platform OS ABI (proposal/scaffold):** [docs/design/runtime-abi.md](docs/design/runtime-abi.md)
  and [runtime/abi/README.md](runtime/abi/README.md); `just abi-test` runs the C contract tests.
- **First Grail wrappers over the C ABI:** [docs/design/grail-ffi-runtime.md](docs/design/grail-ffi-runtime.md);
  `just ffi-runtime-test` (with a built `GRAIL_COMPILER`) builds, links and executes the Linux
  file/time/env, loopback TCP socket and process/thread tests.
- **Windows ABI evidence under Wine:** `just abi-wine-test` cross-builds the C harness with Zig,
  runs the metadata/reparse/DNS paths under Wine, and statically checks the macOS ARM64 call sites.
- **Owner decisions on language readiness (B1-B7):** [docs/design/decisions-b2-b6.md](docs/design/decisions-b2-b6.md)
  - separate compilation, ambient authority, blocking foreign calls, Windows I/O readiness,
  abort/unwind, closure captures and `byval` records, each with its alternatives and the condition
  that would reopen it.
- **Proposed numeric types:** [docs/design/numeric-types.md](docs/design/numeric-types.md) (partly implemented: sized integers, `f64`, `f32`, `char`).

## Installing on Windows and macOS

The compiler is a native program on both: `grail.exe` (PE32+) for Windows x86-64 and a Mach-O
`grail` for macOS AArch64 and x86-64. You need the compiler binary, the runtime sources it looks for
beside itself, and **LLVM** - there is no C runtime, no Visual Studio and no Xcode-only path in the
build.

- **Windows (x86-64).** Install LLVM (`winget install LLVM.LLVM`, or `choco install llvm`). That is
  the whole toolchain: `clang` assembles, `llvm-ar` writes the import library and `lld-link` links,
  so no Windows SDK, no `.lib` files from Microsoft and no Developer Command Prompt are involved.
  Put `grail.exe` where it can find its runtime - beside a `compiler/runtime.grl` (a checkout works:
  `native\grail.exe` finds `..\compiler\runtime.grl`), or install the `lib/grail` tree and point
  `GRAIL_HOME` at it. Then:

  ```powershell
  grail.exe build --target windows-x86_64 hello.grl -o hello.exe
  .\hello.exe
  ```

  Source paths, module search and diagnostics accept `/` or `\`, and drive-letter (`C:\...`) paths
  count as absolute. The console is switched to UTF-8, so a Grail string prints as UTF-8 rather than
  in the ANSI code page.
- **macOS (AArch64, x86-64).** The Xcode command-line tools give `clang` and `ld`. The driver links
  with LLVM's `ld64.lld` by default; `GRAIL_LINKER=ld` selects Apple's own ld64. Point it at the SDK
  once:

  ```sh
  export GRAIL_SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ./grail build --target macos-aarch64 hello.grl -o hello
  ./hello
  ```

  With `GRAIL_SDK` unset the driver still links: it writes a libSystem `.tbd` stub from the object's
  own undefined symbols, which is the same linkage scaffolding `tools/macos.mjs` uses on a Linux
  host, so a cross-built image is a real Mach-O executable with the libSystem dependency.

The evidence behind this section, per platform, is in
[docs/platform-status.md](docs/platform-status.md); the CI lanes that run these binaries on
`windows-latest` and `macos-14` are in [.github/workflows/ci.yml](.github/workflows/ci.yml).

## Release artifacts

Tagging `vX.Y.Z` runs `.github/workflows/release.yml`, which builds every target from the
checked-in bootstrap seed (no development compiler, no network) and publishes a GitHub release
with the artifacts below, one `SHA256SUMS` file, `release.json` provenance and a generated
`RELEASE-README.md`. The full procedure is in [docs/releases.md](docs/releases.md).

| Target | Artifact | Runs on |
| --- | --- | --- |
| `linux-x86_64` | `grail-VERSION-linux-x86_64.tar.gz` plus the raw compiler | Linux x86-64, static ELF; executed natively in the release lane |
| `linux-aarch64` | `grail-VERSION-linux-aarch64.tar.gz` plus the raw compiler | Linux AArch64, static ELF; executed natively on the AArch64 release runner |
| `linux-riscv64` | `grail-VERSION-linux-riscv64.tar.gz` plus the raw compiler | Linux RISC-V 64, static ELF; cross-built and smoke-run under qemu, not on RISC-V hardware |
| `windows-x86_64` | `grail-VERSION-windows-x86_64.zip`, `...-compiler.exe`, `...-objects.zip` | Windows x86-64: a PE32+ compiler and programs, run natively by the `windows-latest` CI lane and under Wine on a Linux host |
| `windows-aarch64` | none | **Not built**: ARM64 PE code generation is not implemented; the lane is planned |
| `macos-aarch64` | `grail-VERSION-macos-aarch64-objects.tar.gz` | Apple silicon: a Mach-O compiler and programs, cross-built and linked on Linux, run natively by the `macos-14` CI lane |
| `macos-x86_64` | `grail-VERSION-macos-x86_64-objects.tar.gz` | Intel macOS: a Mach-O compiler and programs, cross-built and linked on Linux (the signing dry-run lane runs on `macos-13`) |

Build the compiler with `bun tools/native.mjs build` (Bun, Clang assembler and LLD required).
There is no Rust seed or C-backend dependency. `just book` builds and opens the offline book;
Rust is needed only to verify the book's Rust counterparts.

This remains a work-in-progress language, not a promise of complete v1 library support.
The Windows x86-64 backend emits PE/COFF objects and PE32+ images, and the compiler and runtime run
there: `bun tools/windows.mjs selfhost` runs the Windows compiler under Wine, compiles a program end
to end and compiles the compiler itself to assembly identical to the Linux compiler's. The macOS
x86-64 and AArch64 backends emit Mach-O objects and linked images; the compiler cross-builds and
links for both and runs in the `macos-14` CI lane. Windows AArch64 is cross-built and statically
verified only. On Windows the built-in socket operations, the green-task scheduler's IOCP reactor
and exception unwinding are still missing, as is dynamic unloading; ARM64 Win32 code generation is
not implemented (see [docs/design/windows-backend.md](docs/design/windows-backend.md)).
Additional numeric primitives and structured concurrency are not yet implemented. Historical research under `research/` records earlier design experiments.
