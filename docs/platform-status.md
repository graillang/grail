# Cross-platform status

Last verified: 2026-11-08 against current `main`.

This page distinguishes what has actually been built and executed from scaffolding and static
inspection. A cross-built object is not platform support. A header parsing is not a backend.

## Hosted compiler and runtime

| Target | Compiler output | Execution evidence | Status |
| --- | --- | --- | --- |
| Linux x86-64 | ELF | 611 native/rejection tests, 45 Grail + 45 Rust book checks, byte-identical self-host | **Supported** |
| Linux AArch64 | ELF cross-image; self-host identity verified | Cross-build and ELF architecture checks; no qemu runner here | Cross-build only |
| Linux RISC-V64 | ELF cross-image; self-host identity verified | Cross-build and ELF architecture checks; no qemu runner here | Cross-build only |
| Windows x86-64 | PE32+ console images, COFF objects, kernel32 imports, Win32 OS layer | `bun tools/windows.mjs check` 16/16; **8 programs executed under Wine** | **Wine runtime verified** |
| Windows AArch64 | ARM64 PE/COFF, Win64 ARM64 imports, `.pdata`/`.xdata` frame records | `bun tools/windows.mjs check` 16/16; ARM64 images statically verified | Cross-build only |
| macOS x86-64 / AArch64 | Mach-O objects/exes/dylibs, libSystem layer, frameworks, ad-hoc signatures | `bun tools/test-macos.mjs`: 4 objects, 4 images, 2 frameworks, 6 signatures, 2 dylibs; **not executable here** | Cross-build only |

Windows x86-64 has `.pdata`/`.xdata`, a Win32 console/files/argv/time layer, and 8 executed programs
under Wine. ARM64 has PE/COFF images and ARM64 frame records, statically verified. Worker threads
and COM are not on `main` yet (thread work is in review). Grail-internal calls use the private
register convention; Win64 is used at import boundaries. This is Wine verification, not Windows
hardware verification.

macOS links frameworks and ad-hoc signatures with static LC_LOAD_DYLIB, LC_ID_DYLIB and
CodeDirectory verification. There is no Apple-hardware execution; signing proves integrity, not
trust or notarization. The macOS images must not be run on Linux.

Linux AArch64 and RISC-V64 are cross-build verified, not runtime verified. Published bootstrap
seeds are being refreshed after the current compiler batch; until then treat default bootstrap
builds as stale.

## Runtime ABI

`runtime/abi` has a versioned C contract for errors, handles, paths, files, directories, time,
environment, processes, sockets, threads and dynamic loading. All 95 public functions are now
defined on the Windows and macOS backends (the fail-closed stub translation units are gone), and
the ABI test cross-compiles seven objects per target with 95/95 symbols and pinned structure
layouts. The Linux backend is executed and sanitizer-clean; Windows/macOS calls are static-only
until a runtime harness runs them.

This is an ABI and reference-runtime layer, not yet a Grail-language standard library binding.

## FFI and v3 ABI

`extern "C"`, unsafe calls, scalar parameters/results (up to six), symbol renaming and link notes
are on `main` and execute on x86-64. C-layout records, opaque handles, byte/string views and
function-pointer callbacks are implemented and verified on a feature branch, awaiting the compiler
integration and bootstrap refresh. Dynamic loading (`dlopen`/`dlsym`), variadics, by-value structs,
stack arguments and sub-64-bit scalar parameters remain open.

## Graphics and shaders

Implemented and tested: versioned C RHI ABI, null and Vulkan backends, HLSL→SPIR-V/DXIL reflection,
shader permutations, bindless layouts, render graph, graphics and compute pipelines, vertex/index
buffers, indexed and indirect draws, indirect dispatch, offscreen frames, SDL3 window/swapchain
with per-image acquire/render/present semaphores, and swapchain recreate. `vk-smoke` has 421 checks
and `vk-surface` 162, both asserting zero validation errors, warnings and leaks over repeated runs.

Not implemented: D3D12, Metal, depth/MSAA in the graph, multi-queue overlap beyond the graphics
timeline, pipeline-cache persistence, and a renderer/editor above the RHI.

## Tooling

Implemented: deterministic native/cross build runner, platform matrix, packaging and checksums,
signing hooks, install scripts, non-executable Windows/macOS object bundles in CI, CI plan/lint, and
an LSP MVP with compiler-sourced diagnostics. DWARF line tables and `grail debug lines` are in review
on a feature branch. Debugger attach, profiler and hosted macOS release artifacts remain absent.

## Applications

Abundance has CPU math, FNV-1a, world envelope, landscape digest, ABWCACH8/9 containers, cache-body
decode, ABCP2 checkpoints, entity tables, job-priority policy and a clone-thread job executor with
bit-exact C++ parity (254 exact values across seven programs). Its renderer/editor layers are not
ported.

Borg Agent has JSON, wire, TOML/config, local-session ownership, JSON-RPC dispatch and the local-IPC
addressing/lifecycle rules (683 reference lines across eight suites). The socket syscalls and the
remaining OS/service layers are still open.

## Verification commands

```sh
bun tools/test-native.mjs       # Linux native/rejection corpus
bun tools/abi-test.mjs          # runtime C ABI and cross-target symbol audit
bun tools/windows.mjs check     # Windows COFF/PE and Wine execution
bun tools/test-ffi.mjs          # extern "C" ABI through a C shim
bun tools/test-macos.mjs        # Mach-O objects, images, frameworks, signatures, dylibs
just book-check                 # 45 Grail + 45 Rust comparisons
make -C graphics test           # RHI C ABI, null backend, shader library
make -C graphics shader-check   # DXC/SPIR-V artifacts and reflection
make -C graphics vk-smoke       # Vulkan core, draw/compute path (GPU)
make -C graphics vk-surface     # SDL3 swapchain/present path (GPU)
just abundance-test             # seven Abundance parity programs
just borg-test                  # eight Borg parity suites
```
