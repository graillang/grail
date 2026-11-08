# Cross-platform status

Last verified: 2026-11-08 on `main` at `565dee6`.

This page distinguishes what has actually been built and executed from scaffolding and
static inspection. A cross-built object is not platform support. A header parsing is not a
backend. A project that has a port plan is not a port.

## Target matrix

The compiler emits for the six target rows below: the three Linux ELF targets, Windows x86-64,
Windows AArch64, and macOS x86-64/AArch64. Only Linux x86-64 executes natively here; Windows
x86-64 executes under Wine. Linux AArch64 and RISC-V 64 are runnable targets whose qemu lanes need
a runner, Windows AArch64 has no ARM64 runner and its release lane is planned, and both macOS
targets are static-only.

| Target | Compiler output | Execution evidence | Status |
| --- | --- | --- | --- |
| Linux x86-64 | ELF | native tests, CLI checks, book checks, byte-identical self-host | **Executed (native)** |
| Linux AArch64 | ELF cross-image | cross-build and ELF machine checks; qemu lane when a runner is installed (none on this host) | **Cross-build only; runnable target** |
| Linux RISC-V 64 | ELF cross-image | cross-build and ELF machine checks; qemu lane when a runner is installed (none on this host) | **Cross-build only; runnable target** |
| Windows x86-64 | PE32+ console images, COFF objects, kernel32 imports, Win32 OS layer, C runtime shims | `bun tools/windows.mjs check` 16/16; **8 programs executed under Wine** | **Executed under Wine; not native Windows** |
| Windows AArch64 | ARM64 PE/COFF objects and images, Win64 ARM64 imports | 4 ARM64 images statically verified; no ARM64 runner | **Cross-build only; not executable** |
| macOS x86-64 / AArch64 | Mach-O objects and executables, libSystem layer, platform-module runtime | 4 objects + 4 images, framework links and ad-hoc signatures checked statically; **not executed** | **Cross-build only; not executable** |

Linux x86-64 is the only target with full compiler and runtime execution evidence on this host.
Linux AArch64 and RISC-V 64 build and pass ELF checks; CI defines qemu-user lanes, but no qemu
runner is installed here, so they are not executed here. Windows x86-64 has `.pdata`/`.xdata`, a
Win32 console/files/argv/time layer, and 8 executed programs under Wine. Windows AArch64 has
PE/COFF images and `.pdata`/`.xdata` frame records, statically verified. Worker threads and COM
remain unimplemented on both. Grail-internal calls still use the private register convention;
Win64 is used at import boundaries. This is Wine verification, not Windows hardware verification,
and the Windows release artifacts are non-executable object bundles, not a hosted Windows
toolchain.

macOS has a libSystem layer and a platform-module runtime, and links frameworks and ad-hoc
signatures with static LC_LOAD_DYLIB/CodeDirectory verification. There is still no
Apple-hardware execution, and signing proves integrity, not trust or notarization. Grail-internal
calls still use the private register convention; the C ABI is used at imports. The macOS images
must not be run on Linux.

## Runtime ABI

`runtime/abi` has a versioned C contract for errors, handles, paths, files, directories, time,
environment, processes, sockets, threads and dynamic loading, plus a tested Linux reference
backend. Windows and macOS backends are fail-closed skeletons: they return explicit
`UNSUPPORTED`/`NOT_IMPLEMENTED` instead of pretending to succeed. `bun tools/abi-test.mjs`
passes all checks across core, handles, POSIX/Windows path semantics, process/socket skeletons
and the Linux backend.

This is an ABI and reference-runtime layer, not yet a Grail-language standard library binding.

## FFI and v3 ABI

The first FFI increment is implemented and executed: `extern "C"` declarations with `unsafe`
calls, scalar `i64`/`u64` parameters and results (up to six), symbol renaming and link notes.
`bun tools/test-ffi.mjs` links and executes 3 programs, and the C shim tests cross-link on
AArch64/RISC-V. The wider v3 C ABI is still in review: callbacks, opaque handles, byte/string
views, records/struct layout, by-value structs, stack arguments, variadics and dynamic loading
are not implemented. The C headers under `include/grail` are the runtime ABI contract.

## Graphics and shaders

Implemented and tested: the versioned C RHI ABI, the null and SDL3 window backends, wire
structures, offline HLSL→SPIR-V/DXIL reflection, shader permutation enumeration and real
per-combination compilation, key→bytecode library resolution, a headless Vulkan device probe,
and a Vulkan backend with device/queues, bindless layouts, buffers, textures, command buffers,
submission, graphics and compute pipelines, indexed and indirect draws, depth and MSAA resolves,
offscreen readbacks, and a swapchain with acquire/present and a draw path. `make -C graphics
test` runs 450 checks (ABI 72, device 137, wire 22, library 100, graph 119); `make -C graphics
vk-surface` runs 162 checks on a real 320×240 swapchain with acquire, draw and present and no
validation errors, and `make -C graphics vk-smoke` and `vk-probe` add hardware checks.

Not implemented: D3D12 and Metal (both return `GR_ERROR_UNSUPPORTED`), mesh and ray-tracing
pipelines, and a complete renderer. The null backend validates contracts only.

## Tooling

Implemented: deterministic native/cross build runner, platform matrix, packaging and checksums,
signing hooks, install scripts, CI plan/lint, and an LSP MVP with compiler-sourced diagnostics.
Not implemented: debugger, profiler, and hosted macOS release artifacts.

## Applications

Abundance and Borg Agent have landed port inventories and staged boundaries. Abundance CPU
math, FNV-1a, world envelope, landscape digest, ABWCACH8/9 containers, full cache-body decode,
the ABCP2 checkpoint container, the entity table, the job-priority policy and the deterministic
job executor and asset package dependency ordering are ported with bit-exact C++ parity:
**283 exact values across eight programs**
(the older 237 figure covered the increments before the job executor). Borg Agent has JSON,
wire, TOML/config, local-session ownership, JSON-RPC dispatch and local-IPC
addressing/lifecycle rules and journal persistence/cursor rules: **783 reference lines across
nine suites**; the socket syscalls themselves are still open. RHI/renderer/editor and remaining Borg OS services are still open.

## Verification commands

```sh
bun tools/test-native.mjs       # Linux native/rejection corpus
bun tools/abi-test.mjs          # runtime C ABI and reference backend
bun tools/windows.mjs check     # Windows COFF/PE static checks + 8 Wine executions
bun tools/test-macos.mjs        # Mach-O objects/images, frameworks, signatures (static)
bun tools/test-ffi.mjs          # extern "C" scalar ABI through a C shim (3 executed)
bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs
make -C graphics test           # RHI C ABI, null/SDL window, shader library, graph (450)
make -C graphics vk-surface     # swapchain, acquire, draw, present (GPU; 162)
make -C graphics vk-smoke       # Vulkan device core, shader modules, pipeline cache (GPU)
make -C graphics vk-probe       # Vulkan device/capability probe (GPU)
make -C graphics shader-check   # real DXC/SPIR-V artifacts and reflection
make -C graphics perm-test      # shader permutations
just abundance-test             # Abundance bit-exact parity (283 values, 8 programs)
just borg-test                  # Borg reference-line parity (783 lines, 162 documents, 9 suites)
```
