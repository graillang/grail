# Cross-platform status

Last verified: 2026-11-08 on `main` with the `42efb7f` seed set and later non-compiler increments.

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
| Linux AArch64 | ELF cross-image | cross-build and ELF machine checks; qemu-static used for self-host and the 4 FFI fixtures | **Cross-build + qemu checks** |
| Linux RISC-V 64 | ELF cross-image | cross-build and ELF machine checks; qemu-static used for self-host and the 4 FFI fixtures | **Cross-build + qemu checks** |
| Windows x86-64 | PE32+ console images, COFF objects, kernel32 imports, Win32 OS layer, C runtime shims | `bun tools/windows.mjs check` 20/20; **10 programs executed under Wine**, including thread join and producer/consumer wake | **Executed under Wine; not native Windows** |
| Windows AArch64 | ARM64 PE/COFF objects and images, Win64 ARM64 imports | 4 ARM64 images statically verified; no ARM64 runner | **Cross-build only; not executable** |
| macOS x86-64 / AArch64 | Mach-O objects and executables, libSystem layer, platform-module runtime | 4 objects + 4 images, framework links and ad-hoc signatures checked statically; **not executed** | **Cross-build only; not executable** |

Linux x86-64 is the only target with full compiler and runtime execution evidence on this host.
Linux AArch64 and RISC-V 64 build and pass ELF checks; qemu-static was used for both self-hosting
and the 12 executed FFI fixture instances. They still lack a full native-runtime test lane. Windows x86-64 has `.pdata`/`.xdata`, a
Win32 console/files/argv/time layer, Win32 threads and address waits (`CreateThread`, joins through
`WaitForSingleObject`, futex operations mapped to `WaitOnAddress`/`WakeByAddress*`), and 10 executed
programs under Wine. Windows AArch64 has PE/COFF images and `.pdata`/`.xdata` frame records,
statically verified. ARM64 thread creation, sockets and epoll remain unimplemented. COM has a
22-check/11-Wine branch implementation that is not yet integrated on `main`; its remaining limits
stay open. Grail-internal calls still use the private register convention;
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
backend. All **95 public ABI functions** are now defined on Windows and macOS; the fail-closed
stub translation units are gone. `bun tools/abi-test.mjs` cross-compiles seven objects per target
with 95/95 symbols and pinned layouts. A C harness executes 47 Windows metadata, symlink,
non-blocking and DNS checks under Wine; 11 COM checks execute separately; macOS calls remain compile-only.

`lib/sys/grail_ffi.grl` is the first Grail-language wrapper over this ABI: explicit `File` handles,
`FileStat`, byte views, `CStr`, `T|?Error`, and stat/time/env plus loopback TCP socket calls, executed on x86-64 and
assembly-checked on AArch64/RISC-V by `bun tools/test-ffi-runtime.mjs`. It is explicit-import,
not auto-loaded.

## FFI and v3 ABI

Four FFI increments are implemented and executed: `extern "C"` declarations with `unsafe` calls,
scalar `i64`/`u64` parameters and results, symbol renaming and link notes; byte/string views and
`CStr`; opaque handles; C-layout `extern "C" record` values with C padding and field widths; and
C callbacks and `cfn` function pointers. `bun tools/test-ffi.mjs` links and executes all four fixtures on x86-64, AArch64 and RISC-V
(13 executed, 0 linked-only), including `dlopen`/`dlsym`/`dlclose` on Linux x86-64 through a
host-TLS bridge (main thread only). Still open:
dynamic loading on other targets, variadic C functions and variadic callbacks,
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
test` runs 450 host checks; `vk-surface` runs 162 checks on a real 320×240 swapchain, and
`vk-smoke` 613 and `vk-cache` 47 on hardware, with zero validation messages through teardown.

D3D12: a first slice, built for x86_64-windows with `zig cc` (MinGW-w64 headers) and executed by
`make -C graphics d3d12-smoke` under Wine, whose `d3d12.dll` is vkd3d on the host GPU. It
covers a headless device and its reported feature level, one direct queue and its fence
timeline, 2D render-target textures and views, command lists, tracked-state barriers, clears,
viewport/scissor, submit and texture readback: 47 checks, including exact clear readbacks
(64 128 191 255 and 255 0 128 0 on every pixel) and the NOT_READY/UNSUPPORTED refusals.
Buffers, shaders, pipelines, draws, bindless, swapchains, semaphores and compute/copy queues
return `GR_ERROR_UNSUPPORTED`; Wine's vkd3d stops at feature level 11_1, so the test asks for
11_0. No real Windows host has run it.

Not implemented: Metal (returns `GR_ERROR_UNSUPPORTED`), mesh and ray-tracing pipelines, and a
complete renderer. The null backend validates contracts only.

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
job executor, asset dependency ordering and the RHI wire framing and a Vulkan host that returns an exact 64/128/191/255 clear readback are ported with bit-exact C++ parity:
**313 exact values across nine programs**
(the older 237 figure covered the increments before the job executor). Borg Agent has JSON,
wire, TOML/config, local-session ownership, JSON-RPC dispatch and local-IPC
addressing/lifecycle rules and journal persistence/cursor rules: **921 reference lines across eleven suites**; the socket syscalls themselves are still open. RHI/renderer/editor and remaining Borg OS services are still open.

## Bootstrap seed set

The compiler/bootstrap seed set `42efb7f` is published and verify-green. The increments after it
on `main` are non-compiler work (ports, graphics, tooling and docs), so the hosted surface below
can be re-checked without regenerating the seed set.

## Verification commands

```sh
bun tools/test-native.mjs       # Linux native/rejection corpus
bun tools/abi-test.mjs          # runtime C ABI and reference backend
bun tools/windows.mjs check     # Windows COFF/PE static checks + 10 Wine executions
bun tools/test-macos.mjs        # Mach-O objects/images, frameworks, signatures (static)
bun tools/test-ffi.mjs          # extern "C" records/handles/callbacks (12 executed)
bun tools/test-ffi-runtime.mjs  # Grail File/Error wrapper over the C ABI
bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs
bun tools/test-debug-lines.mjs  # Linux x86-64 DWARF line rows and `grail debug lines`
make -C graphics test           # RHI C ABI, null/SDL window, shader library, graph (450)
make -C graphics vk-surface     # swapchain, acquire, draw, present (GPU; 162)
make -C graphics vk-smoke       # Vulkan device core, shader modules, pipeline cache (GPU)
make -C graphics vk-probe       # Vulkan device/capability probe (GPU)
make -C graphics shader-check   # real DXC/SPIR-V artifacts and reflection
make -C graphics perm-test      # shader permutations
just abundance-test             # Abundance bit-exact parity (313 values, 9 programs)
just borg-test                  # Borg reference-line parity (921 lines, 11 suites)
```
