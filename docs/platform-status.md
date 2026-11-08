# Cross-platform status

Last verified: 2026-11-08 on `main` at `cd5f617`.

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
| Windows x86-64 | PE32+ console images, COFF objects, kernel32 imports, Win32 OS layer, C runtime shims | `bun tools/windows.mjs check` 20/20; **10 programs executed under Wine**, including thread join and producer/consumer wake | **Executed under Wine; not native Windows** |
| Windows AArch64 | ARM64 PE/COFF objects and images, Win64 ARM64 imports | 4 ARM64 images statically verified; no ARM64 runner | **Cross-build only; not executable** |
| macOS x86-64 / AArch64 | Mach-O objects and executables, libSystem layer, platform-module runtime | 4 objects + 4 images, framework links and ad-hoc signatures checked statically; **not executed** | **Cross-build only; not executable** |

Linux x86-64 is the only target with full compiler and runtime execution evidence on this host.
Linux AArch64 and RISC-V 64 build and pass ELF checks; CI defines qemu-user lanes, but no qemu
runner is installed here, so they are not executed here. Windows x86-64 has `.pdata`/`.xdata`, a
Win32 console/files/argv/time layer, Win32 threads and address waits (`CreateThread`, joins through
`WaitForSingleObject`, futex operations mapped to `WaitOnAddress`/`WakeByAddress*`), and 10 executed
programs under Wine. Windows AArch64 has PE/COFF images and `.pdata`/`.xdata` frame records,
statically verified. ARM64 thread creation, sockets, epoll and COM remain unimplemented.
Grail-internal calls still use the private register convention;
Win64 is used at import boundaries. This is Wine verification, not Windows hardware verification,
and the Windows release artifacts are non-executable object bundles, not a hosted Windows
toolchain.

macOS has a libSystem layer and a platform-module runtime, and links frameworks and ad-hoc
signatures with static LC_LOAD_DYLIB/CodeDirectory verification. It also emits shared Mach-O
dylibs with explicit `--export` symbol lists, `@rpath/...` install names and `LC_RPATH` entries;
`tools/macos.mjs` reads back `LC_ID_DYLIB`, the export/import sets and RPATHs. There is still no
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

Four FFI increments are implemented and executed: `extern "C"` declarations with `unsafe` calls,
scalar `i64`/`u64` parameters and results, symbol renaming and link notes; byte/string views and
`CStr`; opaque handles; C-layout `extern "C" record` values with C padding and field widths; and
C callbacks and `cfn` function pointers. `bun tools/test-ffi.mjs` links and executes the scalar,
views/handles, records and callback programs, and cross-links on AArch64/RISC-V. Still open:
dynamic library loading (`dlopen`/`dlsym` hooks), variadic C functions and variadic callbacks,
callback results, record results and by-value struct passing, nested records, float and narrow
integer parameters, and stack arguments beyond six words. The C headers under `include/grail`
are the runtime ABI contract.

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
signing hooks, install scripts, CI plan/lint, an LSP MVP with compiler-sourced diagnostics, and
DWARF `.debug_line` tables for Linux x86-64 (`grail build --debug`, inspected with `grail debug
lines`). Not implemented: debugger attach (`.debug_info` variable DIEs, breakpoints, DAP),
profiler, and hosted macOS release artifacts.

## Applications

Abundance and Borg Agent have landed port inventories and staged boundaries. Abundance CPU
math, FNV-1a, world envelope, landscape digest, ABWCACH8/9 containers, full cache-body decode,
the ABCP2 checkpoint container, the entity table, the job-priority policy and the deterministic
job executor and asset package dependency ordering are ported with bit-exact C++ parity:
**283 exact values across eight programs**
(the older 237 figure covered the increments before the job executor). Borg Agent has JSON,
wire, TOML/config, local-session ownership, JSON-RPC dispatch and local-IPC
addressing/lifecycle rules and journal persistence/cursor rules: **890 reference lines across ten suites**; the socket syscalls themselves are still open. RHI/renderer/editor and remaining Borg OS services are still open.

## Verification commands

```sh
bun tools/test-native.mjs       # Linux native/rejection corpus
bun tools/abi-test.mjs          # runtime C ABI and reference backend
bun tools/windows.mjs check     # Windows COFF/PE static checks + 10 Wine executions
bun tools/test-macos.mjs        # Mach-O objects/images, frameworks, signatures (static)
bun tools/test-ffi.mjs          # extern "C" scalar ABI through a C shim (3 executed)
bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs
bun tools/test-debug-lines.mjs  # Linux x86-64 DWARF line rows and `grail debug lines`
make -C graphics test           # RHI C ABI, null/SDL window, shader library, graph (450)
make -C graphics vk-surface     # swapchain, acquire, draw, present (GPU; 162)
make -C graphics vk-smoke       # Vulkan device core, shader modules, pipeline cache (GPU)
make -C graphics vk-probe       # Vulkan device/capability probe (GPU)
make -C graphics shader-check   # real DXC/SPIR-V artifacts and reflection
make -C graphics perm-test      # shader permutations
just abundance-test             # Abundance bit-exact parity (283 values, 8 programs)
just borg-test                  # Borg reference-line parity (890 lines, 10 suites)
```
