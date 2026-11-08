# The Grail RHI contract

The graphics foundation is a versioned C ABI (`graphics/include/grail/`) plus one
implemented backend (`GR_BACKEND_NULL`) that exercises it. This document states the
contract; `shader-flow.md` states the shader pipeline; `dependencies.md` lists what a host
must install; `first-renderer-port.md` lists what still blocks a real renderer.

## Who owns what

| Layer | Owns | Does not own |
| --- | --- | --- |
| SDL3 (`grail_window.h`) | the platform window, the event queue, input, the display list | surfaces, swapchains, GPU objects |
| RHI (`grail_rhi.h`) | the device, queues, resources, command buffers, swapchain, queries | the window, input, shader source |
| Bindless (`grail_bindless.h`) | the only resource namespace a shader sees | allocation policy inside a table |
| Shaders (`grail_shader.h`) | containers, reflection blobs, pipeline descriptors, permutation keys | compilation (that is offline) |
| Backend headers | what one API must provide, and its interop escape hatches | any behaviour the shared contract already fixes |

SDL3 appears in exactly one value: `gr_window_native`, which the backend turns into a
`VkSurfaceKHR`, an HWND or a `CAMetalLayer`. A headless process never includes
`grail_window.h`.

## The decisions, and why they are fixed rather than options

Each of these is inherited from Abundance's own engine (`abundance/engine/core/`), which is
the engine the first renderer ports, so that a port is a translation and not a redesign.

**Dynamic rendering, no render-pass objects.** `gr_cmd_begin_render` names attachment views
directly. Abundance's `DeviceCaps` requires dynamic rendering and `PipelineRegistry` takes
`VkFormat`/`GrFormat` lists rather than a render-pass handle. Fewer objects means fewer states
to keep in step across three APIs; D3D12 and Metal have no render-pass object to model.

**One pipeline layout for every pipeline.** Set 0 is the bindless table, set 1 is the frame
constants, and there are 128 bytes of push constants. Binding never changes between passes.
This is Abundance's `Bindless` design, restated in `grail_bindless.h` with the mapping table
for all three backends.

**128-byte push constants.** The Vulkan minimum every conformant device guarantees, and
exactly what D3D12 root constants hold. Anything larger would drop a device from support.

**Queue timelines, not binary semaphores.** `gr_queue_submitted` / `gr_queue_completed` are
the only cross-queue and cross-frame dependency. D3D12 has no timeline semaphore and Metal
has none, so each backend emulates one with a fence or `MTLEvent`; exposing binary
semaphores would make the three APIs diverge at the call site.

**Retire then collect, never destroy synchronously.** `gr_device_retire(device, object,
after_value)` and `gr_device_collect`. There is no frame the GPU may still be reading when
memory is freed, because the API gives no way to express it. This is `Device::defer`.

**Pipelines are built before the first frame.** `gr_pipeline_commit` closes the registry and
`gr_pipeline_create` returns `GR_ERROR_NOT_READY` afterwards, so a mid-frame pipeline stall
cannot exist by construction. This is Abundance's `PipelineRegistry::build_all()`.

**Fixed conventions that are never per-pipeline:** reverse-Z with an infinite far plane
(`GR_COMPARE_GREATER_EQUAL`), counter-clockwise front faces, row-major matrices acting on
column vectors, and scalar block layout. `gr_device_caps.depth_range_zero_to_one` reports the
one backend difference (D3D12 uses [0,1]) so the caller's projection can account for it; the
convention itself does not move.

## Handles

A `gr_handle` is 64 bits: a 16-bit type tag, a 16-bit generation, a 32-bit index. Zero is
null. Two properties follow, and both are tested:

- **A stale handle is refused, not dereferenced.** `gr_object_remove` bumps the generation,
  so a handle from before a slot was reused fails `gr_object_lookup` with
  `GR_ERROR_INVALID_HANDLE` (test: `test_device.c`, retire then read).
- **A handle is a value.** It can be logged, hashed into a cache key, or sent to another
  process. Nothing in the ABI crosses a boundary as a pointer.

## Capabilities

`gr_device_caps.caps` is the `gr_caps` bit set. A caller asks once after device creation.
The important ones for the bindless contract are `GR_CAP_BINDLESS`,
`GR_CAP_DESCRIPTOR_UPDATE_AFTER_BIND`, `GR_CAP_BUFFER_DEVICE_ADDRESS` and
`GR_CAP_DYNAMIC_RENDERING`; a device without them is refused with `GR_ERROR_UNSUPPORTED`
rather than silently falling back to per-draw descriptor writes.

`GR_CAP_WIRE_BRIDGE` says the backend may be driven over `grail_wire.h`.

## Status codes

`GR_OK` is 0, positive values are non-errors, negative values are errors. Two are part of the
contract's safety story rather than mere error reporting:

- `GR_ERROR_EXHAUSTED` — a bindless table or pool is full. Recoverable refusal: the resource
  is not created, so a caller never holds something it cannot bind.
- `GR_ERROR_LAYOUT_MISMATCH` — host and shader disagree about a GPU struct layout. The
  renderer must refuse to run, not read another layout's memory as its own.

## Frame constants

`gr_frame_constants` (set 1, binding 0) is 416 bytes with every field 16-byte aligned.
Its exact offsets are asserted in `test_abi.c`:

| offset | field |
| ---: | --- |
| 0 | `view` |
| 64 | `proj` |
| 128 | `view_proj` |
| 192 | `inv_view_proj` |
| 256 | `origin` |
| 272 | `viewport` |
| 288 | `time` |
| 304 | `sun_direction` |
| 320 | `sun_illuminance` |
| 336 | `camera_forward` |
| 352 | `jitter` |
| 368 | `exposure` |
| 384 | `frame_index` |
| 396 | `version` |
| 400 | `light_count` |

`exposure` is declared before the scalars on purpose. HLSL's scalar layout aligns a `float4`
to 16 bytes while C aligns a `float[4]` to 4; the order above produces the same offsets and
the same total under both, so no compiler inserts padding the other does not.

## What the tests prove

`make -C graphics test` builds the implementation and runs 219 checks:

- `test_abi` — version gate, handle encoding and tags, struct sizes and the offsets above,
  format facts, stage suffixes, permutation key stability under reordering.
- `test_device` — a window with distinct logical and pixel sizes, a resize and a minimise
  through the event drain, device creation and capability reporting, a refused backend, a
  refused descriptor size, buffer and texture write/read round trips, out-of-range refusal,
  bindless slot allocation, sampler slots after the thirteen fixed ones, retirement then
  stale-handle refusal, recording order (draw before pipeline is `NOT_READY`, nested render
  scope is `VALIDATION_FAILED`, unbalanced scope caught at `end`), submission advancing the
  timeline, double-submit refused, pipeline commit closing the registry, and a headless
  swapchain.
- `test_wire` — pack/unpack round trip, empty payload, truncated and over-long messages,
  bad magic, version mismatch, unknown op, sender-side payload limit, and a name table.
