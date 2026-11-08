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
- **Verified cross-platform status:** [docs/platform-status.md](docs/platform-status.md) distinguishes executed targets from scaffolding and cross-builds.
- **Cross-platform OS ABI (proposal/scaffold):** [docs/design/runtime-abi.md](docs/design/runtime-abi.md)
  and [runtime/abi/README.md](runtime/abi/README.md); `just abi-test` runs the C contract tests.
- **First Grail wrappers over the C ABI:** [docs/design/grail-ffi-runtime.md](docs/design/grail-ffi-runtime.md);
  `just ffi-runtime-test` (with a built `GRAIL_COMPILER`) builds, links and executes the Linux
  file/time/env, loopback TCP socket and process/thread tests.
- **Windows ABI evidence under Wine:** `just abi-wine-test` cross-builds the C harness with Zig,
  runs the metadata/reparse/DNS paths under Wine, and statically checks the macOS ARM64 call sites.
- **Proposed numeric types:** [docs/design/numeric-types.md](docs/design/numeric-types.md) (partly implemented: sized integers, `f64`, `f32`, `char`).

Build the compiler with `bun tools/native.mjs build` (Bun, Clang assembler and LLD required).
There is no Rust seed or C-backend dependency. `just book` builds and opens the offline book;
Rust is needed only to verify the book's Rust counterparts.

This remains a work-in-progress language, not a promise of complete v1 library support.
The Windows x86-64 backend emits PE/COFF objects and PE32+ images; Windows programs are
verified under Wine, while release artifacts are non-executable object bundles. The macOS
x86-64 and AArch64 backends emit Mach-O objects and linked images that are checked statically
but never executed here (see [docs/design/windows-backend.md](docs/design/windows-backend.md)).
The Windows x86-64 backend emits and links PE32+ console images, and its runtime layer covers
console output, files, exit codes and argv under Wine; threads, sockets and unwinding are still
missing (see [docs/design/windows-backend.md](docs/design/windows-backend.md)).
The Windows backends emit and link PE32+ console images for x86-64 and ARM64; the x86-64 runtime
layer covers console output, files, exit codes and argv under Wine (ARM64 is statically
validated), while threads, sockets and exception unwinding are still missing (see [docs/design/windows-backend.md](docs/design/windows-backend.md)).
Additional numeric primitives and structured concurrency are not yet implemented. Historical research under `research/` records earlier design experiments.
