# Cross-platform status

Last verified: 2026-11-10. The FFI, tooling and language rows were re-checked on `main` at
`ca88104` (`bun tools/book.mjs check`, `bun tools/test-ffi.mjs`, `bun tools/ci.mjs lint`); the target
matrix and graphics numbers are the earlier evidence, which these increments do not change.

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
| Linux AArch64 | ELF cross-image | cross-build and ELF machine checks; qemu-static used for self-host and the FFI fixtures | **Cross-build + qemu checks** |
| Linux RISC-V 64 | ELF cross-image | cross-build and ELF machine checks; qemu-static used for self-host and the FFI fixtures | **Cross-build + qemu checks** |
| Windows x86-64 | PE32+ console images, COFF objects, kernel32 imports, Win32 OS layer, C runtime shims | `bun tools/windows.mjs check` 20/20; the programs in `tests/windows-cases.json` execute under Wine, including thread join, producer/consumer wake, FFI out-parameters, seven-word calls and a C callback abort | **Executed under Wine; not native Windows** |
| Windows AArch64 | ARM64 PE/COFF objects and images, Win64 ARM64 imports | 4 ARM64 images statically verified; no ARM64 runner | **Cross-build only; not executable** |
| macOS x86-64 / AArch64 | Mach-O objects and executables, libSystem layer, platform-module runtime | 4 objects + 4 images, framework links and ad-hoc signatures checked statically; **not executed** | **Cross-build only; not executable** |

Linux x86-64 is the only target with full compiler and runtime execution evidence on this host.
Linux AArch64 and RISC-V 64 build and pass ELF checks; qemu-static was used for both self-hosting
and the FFI fixture instances (18 fixtures, executed on all three when both runners are installed). They still lack a full native-runtime test lane. Windows x86-64 has `.pdata`/`.xdata`, a
Win32 console/files/argv/time layer, Win32 threads and address waits (`CreateThread`, joins through
`WaitForSingleObject`, futex operations mapped to `WaitOnAddress`/`WakeByAddress*`), a
thread-per-task `Scope`/`Task` scheduler (`spawn`, `task_scope`, `parallel_map` execute under Wine),
and executed programs under Wine. Windows AArch64 has PE/COFF images and `.pdata`/`.xdata` frame records,
statically verified. ARM64 thread creation, sockets and an IOCP reactor remain unimplemented. COM is
integrated: `raw_win_local`/`raw_win_call` call a vtable slot through the Win32 ABI, `CoInitializeEx`
and `CoUninitialize` join the import table, and an executed x86-64 case proves AddRef/Release counts,
`E_POINTER`, `E_NOINTERFACE` and a successful `QueryInterface`; `CoCreateInstance`, marshalling and
apartment tests remain open. Grail-internal calls still use the private register convention;
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

The FFI is implemented and executed (`docs/ffi.md` is the contract): `extern "C"` declarations with
`unsafe` calls, symbol renaming and link notes; scalar, float (by call and by callback) and
narrow-integer parameters and results, extended and re-extended per target;
`f32`/`f64` and narrow C-layout record fields written at their own width; byte/string views, `CStr`
and bare `cptr`/`cptr_mut`/`cnull`; opaque handles, nameable across modules and comparable by
identity; C-layout `extern "C" record` values by pointer and as by-value *results* (SysV eightbyte
classes, AAPCS64 HFAs, RV64 flattening, nested records and float fields included); records passed by
value as *arguments* spelled `v: byval R` on SysV x86-64, AAPCS64 and RV64; out-parameter slots
(`slot: &mut H`) for handles and bare pointers; calls of seven to nine word arguments through the
target's registers and then the outgoing stack; variadic C calls; C callbacks and `cfn` function
pointers including the COM-shaped seven-argument slot; and `dlopen`/`dlsym`/`dlclose` on the three
Linux targets through a host-TLS bridge (main thread only) or, on Windows x86-64, through ordinary
`LoadLibraryA`/`GetProcAddress` imports.

`bun tools/test-ffi.mjs` holds 18 executable fixtures; on a host with the qemu runners all 54
fixture instances execute (18 on x86-64 alone, 36 reported link-only without a runner), and the
`ffi-out-params`, `ffi-call-words` and callback-abort sources are also `tests/windows-cases.json`
cases that execute under Wine on Windows x86-64.

Still refused with a diagnostic rather than approximated: `byval` on the Windows x86-64 and ARM64
ABIs (`byval is not implemented for the Windows x86-64 and Windows ARM64 ABIs; pass the record by
pointer`); a `byval` record parameter on a C callback; a by-value record *result* whose embedded
records contain floats; variadic callbacks; callback results that are function pointers; taking the
address of an `extern "C"` record, which is what a create-info struct pointing at another struct
needs; foreign calls and callbacks on threads other than the main thread on Linux; and dynamic
loading on macOS. The C headers under `include/grail` are the runtime ABI contract.

## Graphics and shaders

Implemented and tested: the versioned C RHI ABI, the null and SDL3 window backends, wire
structures, offline HLSL→SPIR-V/DXIL reflection, shader permutation enumeration and real
per-combination compilation, key→bytecode library resolution, a headless Vulkan device probe,
and a Vulkan backend with device/queues, bindless layouts, buffers, textures, command buffers,
submission, graphics and compute pipelines, indexed and indirect draws, depth and MSAA resolves,
offscreen readbacks, and a swapchain with acquire/present and a draw path. `make -C graphics
test` runs 450 host checks; `vk-surface` runs 162 checks on a real 320×240 swapchain, and
`vk-smoke` 613 and `vk-cache` 47 on hardware, with zero validation messages through teardown.

D3D12: built for x86_64-windows with `zig cc` (MinGW-w64 headers) and executed by
`make -C graphics d3d12-smoke` under Wine with vkd3d-proton on the host GPU (Wine's built-in
vkd3d stops at shader model 6.2; the offline DXIL is 6.6). It covers a headless device and its
feature level, one direct queue and its fence timeline, 2D render-target textures and views,
command lists, tracked-state barriers, clears, viewport/scissor, submit, texture readback, DXIL
shaders, graphics pipelines on the contract root signature (push constants as root constants,
frame constants as a root CBV), frame-constant slots, upload/readback/device buffers, vertex
and index buffers with input layouts matched to the shader's reflected semantics, reverse-Z
depth attachments and depth state, and plain and indexed draws: 162 checks, including exact
clear readbacks, a 64x64 draw of the offline `core/fullscreen` + `core/solid` DXIL that matches
the shader on every pixel, and an indexed `core/triangle` drawn near then far where the depth
test keeps the near colour and the depth buffer reads back exactly 0.75. The bindless tables
are one shader-visible resource heap (sampled images, storage buffers) and one sampler heap
holding the thirteen fixed samplers; `core/frame_setup` runs as a compute pipeline and writes
all 256 storage-buffer words exactly, and `core/tonemap` samples an uploaded HDR texture within
1/255 of ACES: 221 checks. Flip-model swapchains on an SDL3 window's HWND: `make -C graphics d3d12-present` (on a
display, with DXVK's DXGI) acquires, clears, reads back exactly, presents and resizes: 319 checks.
4x MSAA with a resolve at end of pass matches the single-sample draw byte for byte (241 checks
in the smoke test). Storage
images, indirect draws and dispatches, mesh pipelines, semaphores and compute/copy
queues return `GR_ERROR_UNSUPPORTED`. No real Windows host has run it.

Not implemented: Metal (returns `GR_ERROR_UNSUPPORTED`), mesh and ray-tracing pipelines, and a
complete renderer. The null backend validates contracts only.

## Tooling

Implemented: deterministic native/cross build runner, platform matrix, packaging and checksums,
signing hooks, install scripts, CI plan/lint; DWARF `.debug_line` tables plus typed parameter and
local locations for Linux x86-64 and CodeView line tables with typed symbols for Windows x86-64
(`grail build --debug`, read back with `grail debug lines` and `grail debug info`); the language
server `tools/lsp/main.grl` (JSON-RPC over stdio, full-text sync, compiler-sourced diagnostics,
same-file definition) with its stdio test; the sampling profiler `grail profile` for Linux x86-64
(ITIMER_PROF in the program's own runtime, ELF `.symtab` attribution, no `perf`); `grail build
--split` for per-module emission on Linux x86-64; and the authority model (`lib/authority.grl`,
`--deny-ambient-host`). Not implemented: debugger attach, breakpoints and DAP; profiling on other
targets; hosted macOS release artifacts.

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

The compiler/bootstrap seed set `42efb7f` is published and verify-green, but it predates the
compiler increments that landed on 2026-11-10 (strict bool, `FnMut`, `byval`, out-parameters, the
sampler, per-module emission), so a refresh is in progress before it can be called current. Until it
lands, every suite builds stage 0 from that seed and recompiles the current `compiler/` sources, which
is what the verification commands below do.

## Verification commands

```sh
bun tools/test-native.mjs       # Linux native/rejection corpus
bun tools/abi-test.mjs          # runtime C ABI and reference backend
bun tools/windows.mjs check     # Windows COFF/PE static checks + 10 Wine executions
bun tools/test-macos.mjs        # Mach-O objects/images, frameworks, signatures (static)
bun tools/test-ffi.mjs          # extern "C" records/handles/callbacks/byval/out-params
bun tools/test-ffi-runtime.mjs  # Grail File/Error wrapper over the C ABI
bun test tools/platforms.test.mjs tools/archive.test.mjs tools/sign.test.mjs
bun tools/test-debug-lines.mjs  # Linux x86-64 DWARF line rows and `grail debug lines`
bun tools/book.mjs check        # every book example, Grail and Rust, with expected output
bun tools/test-authority.mjs    # capability values and `--deny-ambient-host`
bun tools/lsp-test.mjs          # the language server over stdio
bun tools/test-profile.mjs      # sampling profiler attribution (Linux x86-64)
bun tools/split-test.mjs        # per-module emission agrees with the whole-program build
make -C graphics test           # RHI C ABI, null/SDL window, shader library, graph (450)
make -C graphics vk-surface     # swapchain, acquire, draw, present (GPU; 162)
make -C graphics vk-smoke       # Vulkan device core, shader modules, pipeline cache (GPU)
make -C graphics vk-probe       # Vulkan device/capability probe (GPU)
make -C graphics shader-check   # real DXC/SPIR-V artifacts and reflection
make -C graphics perm-test      # shader permutations
just abundance-test             # Abundance bit-exact parity (313 values, 9 programs)
just borg-test                  # Borg reference-line parity (921 lines, 11 suites)
```
