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
  grail_shader.h          containers, reflection blob format, pipelines, permutations
  grail_backend_vulkan.h  required features and extensions, SDL3 surface bridge
  grail_backend_d3d12.h   feature levels, root signature layout, DXIL requirements
  grail_backend_metal.h   argument-buffer tier 2, MSL version
  grail_wire.h            out-of-process bridge: framed packets + shared-memory ranges
src/
  grail_core.c            version, status names, format table, permutation keys, object table
  grail_reflect.c         the reflection blob reader and validator
  grail_wire.c            framing
  grail_null.c            the null backend: every entry point, validated, no GPU
  grail_null_window.c     the window/input half of the null backend
shaders/
  include/                HLSL mirrors of the C contract (bindless, frame constants, GPU structs)
  core/                   fullscreen.vs, tonemap.ps, frame_setup.cs
tests/                    abi, device, wire
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
| Vulkan / D3D12 / Metal backends | **not implemented** (`GR_ERROR_UNSUPPORTED`) |
| Permutation enumeration | implemented: directives, blob records, keys, id cross-check |
| Calling this from a Grail program | **blocked** — see `docs/first-renderer-port.md` |

## Build and test

```
make -C graphics test          # needs only a C compiler: 219 checks
make -C graphics shaders       # needs DXC 1.9.2609 (see docs/dependencies.md)
make -C graphics shader-check  # compile, then verify every reflection blob in C
```

## Documents

- [`docs/rhi-contract.md`](docs/rhi-contract.md) — the contract and why each decision is fixed.
- [`docs/shader-flow.md`](docs/shader-flow.md) — HLSL → DXC → DXIL/SPIR-V → MSL, bindings, permutations.
- [`docs/dependencies.md`](docs/dependencies.md) — exact versions and where they come from.
- [`docs/first-renderer-port.md`](docs/first-renderer-port.md) — the seven blockers, with evidence.
