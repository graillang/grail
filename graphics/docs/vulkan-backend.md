# The Vulkan backend: device core

`graphics/src/grail_vulkan.c` implements the RHI ABI on Vulkan 1.3+. This increment is the device
core — instance, physical and logical device, queues, the bindless pipeline layout, shader modules
and graphics pipelines for dynamic rendering. There is no swapchain, no window, no resource
allocation and no submission yet: a headless device that can compile shaders and build pipelines.

## What is implemented

| ABI | Vulkan |
| --- | --- |
| `gr_device_create(GR_BACKEND_VULKAN)` | instance at 1.3, first physical device satisfying `GR_VK_REQ_ALL`, logical device with exactly those features enabled |
| `gr_device_get_caps` | the driver's own properties, limits and memory heaps |
| `gr_device_queue` x3 | graphics / compute / transfer queue handles |
| `gr_queue_timeline` | a real `VK_SEMAPHORE_TYPE_TIMELINE` |
| `gr_queue_submitted` / `gr_queue_completed` | the queue counter and `vkGetSemaphoreCounterValue` |
| `gr_device_bindless` / `gr_bindless_get_info` | one `VkDescriptorSetLayout` (set 0) with four partially-bound, update-after-bind arrays, plus set 1 for frame constants |
| `gr_shader_create` | `vkCreateShaderModule` from the SPIR-V the offline tool produced |
| `gr_pipeline_create` | `vkCreateGraphicsPipelines` with `VkPipelineRenderingCreateInfo` (dynamic rendering) into one `VkPipelineCache` |
| `gr_pipeline_commit` / `gr_pipeline_stats` | closes the registry; reports the cache's byte size |
| `gr_texture_create` / `gr_texture_view_create` | a 2D colour image with its own memory, and a view of it |
| `gr_cmd_pool_create` / `gr_cmd_alloc` / `begin` / `end` / `reset` | a primary command buffer |
| `gr_cmd_barrier` | image layout transitions, mapped from `gr_resource_state` |
| `gr_cmd_begin_render` / `gr_cmd_end_render` | `vkCmdBeginRendering` with clear and store ops |
| `gr_cmd_set_viewport` / `set_scissor` / `bind_pipeline` / `push_constants` / `draw` | the draw path |
| `gr_submit_commands` | one `vkQueueSubmit` that signals the timeline |
| `gr_fence_create` / `gr_fence_wait` / `gr_fence_value` | a real `vkWaitSemaphores` on that timeline |
| `gr_texture_read` | a one-shot copy to a host-visible buffer and a map |

Still `GR_ERROR_UNSUPPORTED` on a Vulkan device: buffers, descriptor set allocation (so the
bindless table is declared but not yet populated), compute and mesh pipelines, and the swapchain.

## The pipeline layout, concretely

One layout for every pipeline, built once at device creation (`grail_bindless.h` fixes the
numbers):

- set 0: `SAMPLED_IMAGE[65536]`, `STORAGE_IMAGE[16384]`, `SAMPLER[256]`, `STORAGE_BUFFER[65536]`,
  each with `PARTIALLY_BOUND` and `UPDATE_AFTER_BIND`, and the set layout flagged
  `UPDATE_AFTER_BIND_POOL`
- set 1: `UNIFORM_BUFFER_DYNAMIC` for the frame constants
- push constants: 128 bytes, all stages

Acceleration structures are deliberately absent: declaring a binding the device cannot use would
fail layout creation on hardware without the ray-tracing extension, and nothing in this increment
needs it.

## One real offscreen frame

The first increment whose evidence is pixels. A 64x64 RGBA8 texture is created as a colour
attachment and transfer source; a command buffer transitions it from `UNDEFINED` to
`COLOR_ATTACHMENT`, begins dynamic rendering with a clear, sets viewport and scissor, binds the
`fullscreen.vs` + `solid.ps` pipeline, pushes a 16-byte tint, draws the fullscreen triangle, ends
rendering, transitions to `TRANSFER_SRC`, and submits. A timeline fence waits for the submitted
value, and the image is copied back to host memory.

`solid.ps` exists for this: `tonemap.ps` samples the bindless table, and until the backend
allocates a descriptor set any sample is undefined. `solid.ps` reads only its interpolated
position and one push constant, so the frame exercises the whole path — rendering, binding, push
constants, rasterisation, readback — while producing values that can be checked.

The frame is rendered **twice**, and the two readbacks must be byte-identical: a digest that
merely happened to repeat within one run would be an observation, not evidence.

## Evidence

`make -C graphics vk-smoke`, under the exclusive GPU lock:

```
vk-backend: device AMD Radeon RX 7900 GRE (RADV NAVI31), API 1.4.354, push constants 256, 16368 MiB
vk-backend: 5 tonemap shader modules created by the driver
vk-backend: pipeline cache 3500 bytes
vk-backend: frame 64x64, digest 0xcf939f3accc07d25
vk-backend: 256 distinct colours, corner rgba 2,253,128,255 / 253,2,128,255
vk-backend: 105 checks passed
```

The corners are the shader's formula, not the clear colour: `r = uv.x`, `g = uv.y`, `b = tint.b`
(0.5 → 128), `a = 1`. Top-left reads `2,253` and bottom-right `253,2` because each axis is
sampled at a pixel centre rather than at the edge, and the two are swapped, which is exactly the
gradient the fragment stage computes. 256 distinct colours confirms the draw covered the target
rather than leaving the clear colour behind.

51 assertions: capabilities match the driver (device name, API 1.4.354, 256-byte push constants,
16368 MiB, and the `BINDLESS` / `DYNAMIC_RENDERING` / `TIMELINE_SEMAPHORE` /
`BUFFER_DEVICE_ADDRESS` bits); three distinct queue handles; bindless capacities as specified; the
library resolves the five tonemap artifacts and **the driver compiles all five into
`VkShaderModule`s**; a graphics pipeline is created from the bindless layout with reverse-Z depth
and dynamic rendering; the descriptor's permutation key is enforced; commit closes the registry and
the pipeline cache holds 2456 bytes of driver-compiled code.

## Two defects this increment found in its own work

**A refactor broke feature detection silently.** `vkGetPhysicalDeviceFeatures2` is an
*instance-level* command, so `vkGetInstanceProcAddr(NULL, …)` returns NULL for it. When the probe's
feature check was moved into the shared module, the instance handle was dropped, every feature
looked absent, and device creation reported "missing a required Vulkan feature" on a GPU that
satisfies all of them. The fix passes the instance; the lesson is that the failure mode of a NULL
entry point here is indistinguishable from an incapable device, which is why the probe and the
backend now share one function rather than two similar ones.

**The dispatcher ignored which backend was asked for.** `gr_device_create(GR_BACKEND_D3D12)`
returned a working Vulkan device, because the non-null route went straight to the Vulkan creator.
The existing `test_device` assertion caught it. The Vulkan creator now refuses any backend but
Vulkan.

## Limits and open ends

- One queue per kind; the graphics queue's timeline is the only one. A second submission queue and
  real multi-queue overlap arrive with the render graph.
- `gr_device_retire` / `gr_device_collect` are accepted and do nothing: the only objects so far are
  shaders and pipelines, which the caller destroys explicitly. Deferred release needs resources.
- The pipeline cache is in memory only. Persisting it at
  `~/.cache/grail/pso/<device uuid>.bin`, as Abundance does, needs the resources path.
- `gr_pipeline_commit` reports 0 seconds because the pipeline was already built by
  `vkCreateGraphicsPipelines` at `gr_pipeline_create`. Building all pipelines in parallel at commit
  — Abundance's `PipelineRegistry::build_all()` — is a follow-up; until then the registry closes
  after the first commit without having batched anything.
- Mesh, compute and ray-tracing pipelines are not implemented.
