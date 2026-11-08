# Cross-platform status

Last verified: 2026-11-08 on `main` at `c149c06`.

This page distinguishes what has actually been built and executed from scaffolding and
static inspection. A cross-built object is not platform support. A header parsing is not a
backend. A project that has a port plan is not a port.

## Hosted compiler and runtime

| Target | Compiler output | Execution evidence | Status |
| --- | --- | --- | --- |
| Linux x86-64 | ELF | 604 native/rejection tests, 174 CLI checks, 45 Grail + 45 Rust book checks, byte-identical self-host | **Supported** |
| Linux AArch64 | ELF cross-image, refreshed bootstrap | Cross-build and ELF architecture checks only; no qemu runner here | Cross-build only |
| Linux RISC-V64 | ELF cross-image, refreshed bootstrap | Cross-build and ELF architecture checks only; no qemu runner here | Cross-build only |
| Windows x86-64 | PE32+ console image, COFF objects, kernel32 short-import objects | `bun tools/windows.mjs check` 7/7 statically verifies object and image; **not executed** | Compiler output only |
| Windows AArch64 | None | None | Not started |
| macOS x86-64 / AArch64 | Mach-O objects and executables, `LC_BUILD_VERSION`/`LC_MAIN`/libSystem imports | `bun tools/test-macos.mjs` statically verifies 4 objects and 4 images; **not executed** | Compiler output only |

Windows x86-64 currently has no `.pdata`/SEH, no Win32 OS layer (console, files, arguments,
threads), and no Windows execution. macOS has a libSystem layer for files, console, clock,
processes and directory records, but no threads, readiness reactor or sockets (they return
`ENOSYS`), no framework or SDK-backed link, and no execution. Grail-internal calls still use the private register
convention; Win64 is used only at import boundaries. The images must not be run.

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

The v3 FFI is **not complete**. Extern-C declarations, callbacks, by-value struct passing,
ownership transfer across the boundary, unsafe scopes and dynamic symbol loading remain in an
isolated implementation lane. The C headers under `include/grail` are the runtime ABI contract,
not proof that Grail programs can call arbitrary C yet.

## Graphics and shaders

Implemented and tested: versioned C RHI ABI, null backend, wire structures, offline
HLSL→SPIR-V/DXIL reflection, shader permutation enumeration and real per-combination
compilation, and key→bytecode library resolution. `make -C graphics test` has 319 checks;
`make -C graphics shader-check` verifies real artifacts and adds 122 checks; `perm-test` has
8 tests.

Not implemented: Vulkan device/backend, D3D12, Metal, SDL3 window backend, swapchain execution
and a renderer. The null backend validates contracts only.

## Tooling

Implemented: deterministic native/cross build runner, platform matrix, packaging and checksums,
signing hooks, install script, and CI plan/lint. Not implemented: LSP server, debugger,
profiler, and Windows/macOS release artifacts (their compiler backends do not exist yet).

## Applications

Abundance and Borg Agent have landed port inventories and staged boundaries. The first
Abundance CPU-common port increment is in progress; no RHI/renderer/editor or Borg Agent
service port is claimed.

## Verification commands

```sh
bun tools/test-native.mjs       # Linux native/rejection corpus
bun tools/abi-test.mjs          # runtime C ABI and reference backend
bun tools/windows.mjs check     # Windows COFF/PE static checks, no execution
make -C graphics test           # RHI C ABI, null backend, shader library
make -C graphics shader-check   # real DXC/SPIR-V artifacts and reflection
make -C graphics perm-test      # shader permutations
bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs
```
