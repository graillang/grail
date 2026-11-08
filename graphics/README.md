# Grail graphics foundation

The RHI and shader-pipeline foundation for Grail: a versioned C ABI for SDL3 window and
input, Vulkan (Linux/Windows), D3D12 (Windows) and Metal (macOS), GPU handles and command
buffers, and offline shader reflection.

Aligned with the real engine this renderer ports — Abundance's own Vulkan engine
(`abundance/engine/`, read-only reference at `/home/shulgin/abundance`) — so that a port is a
translation, not a redesign.

```
include/grail/
  grail_abi.h             version, status, 64-bit tagged handles, descriptors, capabilities
  grail_window.h          SDL3 window, events, input, displays
  grail_rhi.h             device, queues+timelines, resources, command buffers, swapchain, queries
  grail_bindless.h        set 0 table + set 1 frame constants + the cross-backend mapping table
  grail_shader.h          containers, reflection blob format, shader library, pipelines, permutations
  grail_graph.h           render graph: passes, resources, derived order/barriers, culling
  grail_backend_vulkan.h  required features and extensions, SDL3 surface bridge
  grail_backend_d3d12.h   feature levels, root signature layout, DXIL requirements
  grail_backend_metal.h   argument-buffer tier 2, MSL version
  grail_wire.h            out-of-process bridge: framed packets + shared-memory ranges
src/
  grail_core.c            version, status names, format table, permutation keys, object table
  grail_reflect.c         the reflection blob reader and validator
  grail_shader_library.c  permutation key -> bytecode: index, lazy load, cache
  grail_vk_common.c/.h    loader, instance, required-feature evaluation, caps mapping
  grail_vk_probe.c        Vulkan device/feature/limit probe, dlopen-based, no link-time Vulkan
  grail_vulkan.c          the Vulkan backend: device, queues, bindless layout, shaders, pipelines
  grail_graph.c           the render graph: validation, topological order, culling, barrier derivation
  grail_wire.c            framing
  grail_null.c            the null backend: every entry point, validated, no GPU
  grail_null_window.c     the window/input half of the null backend
shaders/
  include/                HLSL mirrors of the C contract (bindless, frame constants, GPU structs)
  core/                   fullscreen.vs, tonemap.ps, frame_setup.cs
tests/                    abi, device, wire, library, graph, vk_probe, vk_backend
tools/                    the offline shader flow (see docs/shader-flow.md)
docs/                     the contract, the shader flow, dependencies, blockers
```

## Status

| Piece | State |
| --- | --- |
| C ABI headers | complete for the documented scope |
| Null backend (all entry points) | implemented, 219 checks passing |
| Reflection blob reader + validation | implemented, tested, and used to verify tool output |
| Wire framing | implemented and tested |
| Shaders (3 stages) | compile and pass `spirv-val` |
| Offline shader tool | written; compiles 3 stages, reflection and permutation ids verified by an independent C reader |
| Vulkan device probe | implemented; this host satisfies every required feature (docs/vulkan-probe.md) |
| Vulkan backend | device, queues, live bindless table (images, samplers, storage buffers), graphics + compute pipelines, offscreen frames and dispatches with verified readbacks |
| D3D12 backend | device, queue/fence, render targets, depth, barriers, clear, buffers, DXIL shaders, graphics pipelines with reflected vertex input, push/frame constants, plain and indexed draws, readback; `make d3d12-smoke` (Wine + vkd3d-proton) |
| Metal backend | **not implemented** (`GR_ERROR_UNSUPPORTED`) |
| Permutations | each combination compiled to its own SPIR-V/DXIL/blob; digests and keys tested |
| Key → bytecode resolution | implemented: library index, lazy cache, miss/mismatch/exhaustion statuses |
| Render graph | passes/resources, derived order and barriers, culling, validation — and driving a real three-pass Vulkan frame |
| Calling this from a Grail program | **blocked** — see `docs/first-renderer-port.md` |

## Build and test

```
make -C graphics test          # needs only a C compiler: 558 checks
make -C graphics shaders       # needs DXC 1.9.2609 (see docs/dependencies.md)
make -C graphics shader-check  # compile, then verify every reflection blob in C
make -C graphics perm-test     # prove each permutation compiles to its own bytecode (bun)
make -C graphics vk-probe      # ask the driver what it is, under the exclusive GPU lock
make -C graphics vk-smoke      # real headless device + pipelines, under the same lock
```

## Documents

- [`docs/rhi-contract.md`](docs/rhi-contract.md) — the contract and why each decision is fixed.
- [`docs/shader-flow.md`](docs/shader-flow.md) — HLSL → DXC → DXIL/SPIR-V → MSL, bindings, permutations.
- [`docs/dependencies.md`](docs/dependencies.md) — exact versions and where they come from.
- [`docs/vulkan-probe.md`](docs/vulkan-probe.md) — what the driver reports, and what each required feature gates.
- [`docs/vulkan-backend.md`](docs/vulkan-backend.md) — the device core: what is implemented, the layout, and the evidence.
- [`docs/render-graph.md`](docs/render-graph.md) — described-not-ordered frames, derived barriers, culling.
- [`docs/first-renderer-port.md`](docs/first-renderer-port.md) — the seven blockers, with evidence.
