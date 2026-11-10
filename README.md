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
| `windows-x86_64` | `grail-VERSION-windows-x86_64.zip`, `...-compiler.exe`, `...-objects.zip` | **Not runnable yet**: cross-built PE32+ image and COFF objects, static checks only |
| `windows-aarch64` | none | **Not built**: ARM64 PE code generation is not implemented; the lane is planned |
| `macos-aarch64` | `grail-VERSION-macos-aarch64-objects.tar.gz` | **Nothing**: non-executable Mach-O objects, statically checked only |
| `macos-x86_64` | `grail-VERSION-macos-x86_64-objects.tar.gz` | **Nothing**: non-executable Mach-O objects, statically checked only |

Build the compiler with `bun tools/native.mjs build` (Bun, Clang assembler and LLD required).
There is no Rust seed or C-backend dependency. `just book` builds and opens the offline book;
Rust is needed only to verify the book's Rust counterparts.

This remains a work-in-progress language, not a promise of complete v1 library support.
The Windows x86-64 backend emits PE/COFF objects and PE32+ images; Windows programs are
verified under Wine, while release artifacts are non-executable object bundles. The macOS
x86-64 and AArch64 backends emit Mach-O objects and linked images that are checked statically
but never executed here (see [docs/design/windows-backend.md](docs/design/windows-backend.md)).
The Windows backends emit and link PE32+ console images for x86-64 and ARM64; the x86-64 runtime
layer covers console output, files, exit codes, argv and OS threads under Wine (ARM64 is statically
validated), and sockets plus processes/threads are reachable through the FFI shim. The built-in
socket operations, the green-task scheduler and exception unwinding are still missing there (see
[docs/design/windows-backend.md](docs/design/windows-backend.md)).
Additional numeric primitives and structured concurrency are not yet implemented. Historical research under `research/` records earlier design experiments.
