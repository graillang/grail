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

Everything else on a Vulkan device returns `GR_ERROR_UNSUPPORTED`: buffers, textures, command
buffers, submission and the swapchain are the next increments.

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

## Evidence

`make -C graphics vk-smoke`, under the exclusive GPU lock:

```
vk-backend: device AMD Radeon RX 7900 GRE (RADV NAVI31), API 1.4.354, push constants 256, 16368 MiB
vk-backend: 5 tonemap shader modules created by the driver
vk-backend: pipeline cache 2456 bytes
vk-backend: 51 checks passed
```

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
