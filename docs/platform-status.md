# Cross-platform status

Last verified: 2026-11-08 on `main` at `261f656`.

This page distinguishes what has actually been built and executed from scaffolding and
static inspection. A cross-built object is not platform support. A header parsing is not a
backend. A project that has a port plan is not a port.

## Hosted compiler and runtime

| Target | Compiler output | Execution evidence | Status |
| --- | --- | --- | --- |
| Linux x86-64 | ELF | 604 native/rejection tests, 174 CLI checks, 45 Grail + 45 Rust book checks, byte-identical self-host | **Supported** |
| Linux AArch64 | ELF cross-image, refreshed bootstrap | Cross-build and ELF architecture checks only; no qemu runner here | Cross-build only |
| Linux RISC-V64 | ELF cross-image, refreshed bootstrap | Cross-build and ELF architecture checks only; no qemu runner here | Cross-build only |
| Windows x86-64 | PE32+ console images, COFF objects, kernel32 imports, Win32 OS layer, C runtime shims | `bun tools/windows.mjs check` 10/10; **8 programs executed under Wine**, including files/argv/stdio/float | **Wine runtime verified** |
| Windows AArch64 | ARM64 PE/COFF, Win64 ARM64 imports, import libs | `bun tools/windows.mjs check` 16/16; 4 ARM64 images statically verified; no ARM64 runner | Cross-build only |
| macOS x86-64 / AArch64 | Mach-O objects/exes, libSystem layer, platform-module runtime | `bun tools/test-macos.mjs` 4 objects + 4 images; **not executable here** | Cross-build only |

Windows x86-64 has `.pdata`/`.xdata`, a Win32 console/files/argv/time layer, and 8 executed programs
under Wine. ARM64 has PE/COFF images and `.pdata`/`.xdata` frame records, statically verified.
Worker threads and COM remain unimplemented. Grail-internal calls still use
the private register convention; Win64 is used at import boundaries. This is Wine verification,
not Windows hardware verification. macOS has a libSystem layer and a platform-module runtime, and now links frameworks and ad-hoc
signatures with static LC_LOAD_DYLIB/CodeDirectory verification. There is still no Apple-hardware
execution, and signing proves integrity, not trust or notarization. Grail-internal calls still use the private register
convention; the C ABI is used at imports. The macOS images must not be run on Linux.

Linux AArch64 and RISC-V64 are cross-build verified, not runtime verified. Linux x86-64 is the
only target with full compiler and runtime execution evidence.

## Runtime ABI

`runtime/abi` has a versioned C contract for errors, handles, paths, files, directories, time,
environment, processes, sockets, threads and dynamic loading, plus a tested Linux reference
backend. Windows and macOS backends are fail-closed skeletons: they return explicit
`UNSUPPORTED`/`NOT_IMPLEMENTED` instead of pretending to succeed. `bun tools/abi-test.mjs`
currently runs more than 8,000 checks across core, handles, POSIX/Windows path semantics,
process/socket skeletons and the Linux backend.

This is an ABI and reference-runtime layer, not yet a Grail-language standard library binding.

## FFI and v3 ABI

The first FFI slice is implemented: `extern "C"` declarations with `unsafe` calls, scalar
parameters/results (up to six), symbol renaming and link notes. The C shim tests execute on
x86-64 and cross-link on AArch64/RISC-V. Still missing: callbacks, opaque handles, byte/string
views, records/struct layout, by-value structs, stack args, variadics and dynamic loading. The
C headers under `include/grail` are the runtime ABI contract.

## Graphics and shaders

Implemented and tested: versioned C RHI ABI, null backend, wire structures, offline
HLSL→SPIR-V/DXIL reflection, shader permutation enumeration and real per-combination
compilation, key→bytecode library resolution, a headless Vulkan device probe, and a Vulkan
device core (device/queues, bindless layouts, shader modules, graphics pipeline, pipeline
cache) verified on AMD RADV (RX 7900 GRE). `make -C graphics test` has 319 checks;
`make -C graphics vk-probe` has 21 hardware checks; `make -C graphics vk-smoke` has 51.
`make -C graphics shader-check` verifies real artifacts and adds 122 checks; `perm-test` has
8 tests.

Not implemented: Vulkan buffers/textures/command buffers/submission/swapchain, D3D12, Metal,
the SDL3 window backend and a renderer. The null backend validates contracts only.

## Tooling

Implemented: deterministic native/cross build runner, platform matrix, packaging and checksums,
signing hooks, install scripts, CI plan/lint, and an LSP MVP with compiler-sourced diagnostics.
Not implemented: debugger, profiler, and hosted macOS release artifacts.

## Applications

Abundance and Borg Agent have landed port inventories and staged boundaries. Abundance CPU math, FNV-1a, world envelope, landscape digest, ABWCACH8/9 containers, full
cache-body decode and the ABCP2 checkpoint container are ported with bit-exact C++ parity
(189 exact values). Borg Agent has JSON, wire, TOML/config, local-session ownership and JSON-RPC dispatch parity
(674 reference lines). RHI/renderer/editor and remaining Borg OS services are still open.

## Verification commands

```sh
bun tools/test-native.mjs       # Linux native/rejection corpus
bun tools/abi-test.mjs          # runtime C ABI and reference backend
bun tools/windows.mjs check     # Windows COFF/PE static checks, no execution
bun tools/test-ffi.mjs          # extern "C" scalar ABI through a C shim
bun test tools/lsp.test.mjs     # LSP stdio and diagnostics
make -C graphics test           # RHI C ABI, null backend, shader library
make -C graphics shader-check   # real DXC/SPIR-V artifacts and reflection
make -C graphics perm-test      # shader permutations
make -C graphics vk-probe       # Vulkan device/capability probe (GPU, skipped without loader)
make -C graphics vk-smoke       # Vulkan device core, shader modules, pipeline cache (GPU)
just abundance-test             # Abundance math/hash bit-exact parity
bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs
```
