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

## The live bindless table

Set 0 is allocated once, at the layout's full capacities, from a pool flagged
`UPDATE_AFTER_BIND`, and never reallocated. Resources write their slot as they are created:

- the thirteen fixed samplers are built at device creation and written into sampler slots 0..12,
  so a shader's constant sampler index is always valid;
- `gr_texture_view_create` claims the next sampled-image slot and writes the descriptor
  immediately, so a view and its slot cannot disagree;
- `gr_sampler_create` does the same for a caller's own sampler;
- `gr_cmd_bind_pipeline` binds **both** sets — resources in set 0, frame constants in set 1 with
  the dynamic offset of the selected frame slot. Nothing rebinds per draw.

- `gr_buffer_create` claims a storage-buffer slot for a buffer with `GR_BUFFER_USAGE_STORAGE`,
  and returns a real device address for one with `GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS`
  (`vkGetBufferDeviceAddress` over a buffer created with the matching usage bit);
- a compute pipeline is created from the same bindless layout, so `gr_cmd_dispatch` needs no
  separate descriptor arrangement.

The frame-constant ring is one host-visible buffer with a slot per frame in flight;
`gr_frame_constants_write` fills a slot and `gr_cmd_push_frame_offset` selects which one a
recording reads.

## The window and surface path

`grail_window_set_backend(GR_WINDOW_BACKEND_SDL3)` selects the SDL3 implementation; the default
stays the null backend so every existing window test keeps working without a display. SDL3 is
loaded with `dlopen` and its eight entry points resolved by name, so a machine without it still
builds and a test that needs a window skips.

The instance must carry the platform's surface extensions, and validation needs its layer, so both
are decided before the instance exists: the window is created first, then `gr_device_create` asks
SDL3 for the extension names. `gr_vk_create_surface(device, window, &surface)` makes the
`VkSurfaceKHR` and `gr_vk_destroy_surface` frees it. There is no swapchain yet; the surface is the
last piece before one.

## Swapchain and teardown

`gr_swapchain_create` builds a `VkSwapchainKHR` from the window's surface, choosing format, present
mode and extent from what the surface reports. Each image gets an ABI view handle, so a graph pass
names an acquired image and the graph derives its transition like any other attachment; only the
final step to `PRESENT_SRC` is issued by the caller, because nothing reads a presented image.

Teardown order is load-bearing and was wrong twice:

1. swapchains and their **surfaces were destroyed after `vkDestroyDevice`** — a surface outliving
   its device, which the validation layer reported at exit as a missing device dispatch and which
   aborted the process after every check had passed.
2. the backend never freed device-owned objects at all, so `vkDestroyDevice` reported **5 leaked
   children** (command pool, command buffer, two shader modules, a pipeline). That error appeared
   *after* the in-process counters were read, so the "zero errors" assertion did not see it — a
   reminder that a counter read is only as good as where it is read.

The order is now swapchain views → swapchain → surface → messenger → remaining device objects →
device → instance, with a sweep that destroys anything the caller left in the object table. The
loader is never `dlclose`d, because it and the layers register atexit handlers over their own static
data.

## The vertex and index path

`triangle.vs` reads two attributes where `fullscreen.vs` generates its vertices and binds nothing, so
the pipeline's vertex input state is built from `gr_pipeline_desc.vertex_bindings` /
`vertex_attributes` rather than left empty — leaving it empty made every attribute unreadable however
the buffers were bound. `gr_cmd_bind_vertex_buffer`, `gr_cmd_bind_index_buffer` and
`gr_cmd_draw_indexed` complete the path.

The test draws an indexed triangle through the graph: three vertices (red, green, blue) in one
vertex buffer, three `uint16` indices in another, and one `gr_cmd_draw_indexed`. Deterministic
checks rather than a digest alone: the two corners outside the triangle hold the clear colour, the
centre pixel holds a blend (`59,65,131`), and all three vertex hues appear somewhere in the target —
which only happens if the index buffer selected the right vertices and the rasteriser interpolated
between them. Two runs give the same digest.

That also needed several formats the map lacked (`R32G32_FLOAT`, `R16G16B16A16_UNORM` and others):
a missing entry reported `UNSUPPORTED` at pipeline creation rather than silently producing a broken
pipeline, which is why it surfaced immediately.

## Push constants: no stage mask

`gr_cmd_push_constants` takes an offset and bytes, not a stage mask. The pipeline layout declares
which stages may read which byte range, and Vulkan requires the call to name exactly those stages
for the bytes it writes — narrower is a validation error, wider is meaningless. The backend derives
the mask by intersecting the layout's declared ranges with `[offset, offset + size)`, so the two
cannot disagree. A caller that wants per-stage constants changes the layout, which is the only place
the decision can live without a second source of truth.

`gr_push_constant_stage_mask` is pure C over plain integers, so the derivation is tested without a
GPU against three layouts: the real one (a single range covering every stage), a two-range layout
with disjoint vertex/compute stages where each half names exactly its own stage and a spanning write
names both, and a three-range layout where the result is the union over all overlapping ranges. A
write falling outside every range names nothing, and the backend refuses it as a programming error
rather than writing bytes no stage can read. `GR_ABI_VERSION_MINOR` is 3 for the signature change.

## Indirect draws

`gr_cmd_draw_indexed_indirect` takes an argument buffer, an offset, a count and a stride. The stride
is validated against the 20-byte `VkDrawIndexedIndirectCommand` (index count, instance count, first
index, vertex offset, first instance) and must be a multiple of 4, and the range must lie inside the
buffer — a stride that would read into the next command is refused rather than followed. The buffer
must also carry `GR_BUFFER_USAGE_INDIRECT`.

The test issues the same triangle three times: twice directly and once indirectly, and the third
readback digest is **identical** to the first. That is the check that matters — an indirect path can
easily draw nothing and still "succeed", and a digest that merely differs from the clear colour
would not tell you whether the argument block was read as the command it holds.

## Indirect draws and dispatches

`gr_cmd_draw_indexed_indirect` and `gr_cmd_dispatch_indirect` both validate their argument block
against the buffer's size and require `GR_BUFFER_USAGE_INDIRECT`: 20 bytes per indexed draw command
with a stride that is a multiple of 4, and 12 bytes for a dispatch (`groupCountX/Y/Z`).

## Presentation without stalling the queue

Present no longer waits the queue idle. The handoff is the standard one:

- `vkAcquireNextImageKHR` signals a per-swapchain `image_available` and waits nothing;
- the next submission waits `image_available` at `COLOR_ATTACHMENT_OUTPUT` and signals
  `render_finished[image]`;
- `vkQueuePresentKHR` waits `render_finished[image]`.

`render_finished` is indexed **by swapchain image**, not one per swapchain: present waits it
asynchronously, so re-signalling the same semaphore on the next frame is illegal until the
presentation engine has consumed it. One per swapchain produced exactly that error
(`pSignalSemaphores[1] ... but it may still be in use`); one per image gives each frame a semaphore
whose previous use is a full cycle behind.

Removing the idle also exposed a caller-side requirement that the idle had been hiding: a single
command buffer cannot be re-recorded while its previous submission is in flight
(`vkResetCommandBuffer: is in use (pending state)`). The test now paces itself with a bounded ring
of one frame in flight — it waits the previous frame's timeline value before re-recording — which is
the caller's choice, and what allows present to stop draining the queue.

## Evidence

`make -C graphics vk-smoke`, under the exclusive GPU lock:

```
vk-backend: device AMD Radeon RX 7900 GRE (RADV NAVI31), API 1.4.354, push constants 256, 16368 MiB
vk-backend: 5 tonemap shader modules created by the driver
vk-backend: pipeline cache 3500 bytes
vk-backend: frame 64x64, digest 0xcf939f3accc07d25
vk-backend: 256 distinct colours, corner rgba 2,253,128,255 / 253,2,128,255
vk-backend: source texture at sampled slot 0
vk-backend: bindless frame digest 0xf1d66d442c5f1c86 (same source twice), 0xcf359a052ee62325 (other source)
vk-backend: storage buffer at slot 0, device address 0xffff800100140000
vk-backend: compute digest seed 12345 = 0x702232ac4eca826f (twice), seed 999 = 0x3a7a79cf4e5149d5
vk-backend: 241 checks passed
```

`make -C graphics vk-surface`, under the exclusive GPU lock, with the validation layer pointed at
the pinned SDK (`VK_LAYER_PATH`/`LD_LIBRARY_PATH`, since it is not installed system-wide):

```
vk-surface: platform asks for 2 instance extension(s): VK_KHR_surface ...
vk-surface: VkSurfaceKHR 0x180000000018 from a hidden SDL3 window
vk-surface: 19 checks passed
```

19 assertions: the SDL3 backend loads, a hidden 320x240 window reports that framebuffer size, the
device is created with `GR_DEVICE_VALIDATION` and a window (so the instance carries the platform
extensions and the validation layer resolved — a missing layer or extension fails instance
creation), the instance and physical device are published, two extensions are requested with real
names, the surface is created, destroyed, created again and destroyed, and a null window is refused
rather than built on a fabricated pointer.

### Validation as an assertion

`gr_vk_validation(device, &report)` returns the layer's counters and `gr_vk_validation_message`
returns the retained messages, so a test asserts on validation instead of a human reading stderr.
`vk-surface` now asserts `errors == 0` **and** `warnings == 0`.

Two design points learned by getting them wrong: only errors and warnings are retained, because the
loader emits dozens of INFO messages about physical-device sorting that filled every slot and hid
the one warning that mattered; and the messenger is created immediately after the instance, since
one created later cannot report what happened in between.

Enabling it turned up the descriptor-pool bug behind the earlier warning: set 1's frame constants
are `UNIFORM_BUFFER_DYNAMIC` and the pool never reserved that type, so the allocation was refused.
Fixed by reserving it.

### Open: the frame path under validation

Turning the layer on in `vk-smoke` originally reported **12 errors**. It now reports **zero errors
and zero warnings**, and the target asserts both.

The causes, and what each taught:

1. **`vkCmdPushConstants` stage flags (6).** The bindless layout declares one push-constant range
   covering every stage, and the spec requires the call's `stageFlags` to include every stage the
   overlapping range declares — so a call naming only `FRAGMENT` is illegal. The ABI's abstract
   `stage_mask` therefore cannot narrow the call without per-pipeline layouts, which the one-layout
   contract forbids; the backend now names the layout's stages and treats the mask as advisory.
2. **`vkBindBufferMemory` device address (1).** A buffer created with `SHADER_DEVICE_ADDRESS` needs
   `VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT` on its memory; the allocation now chains
   `VkMemoryAllocateFlagsInfo`.
3. **Image layout (5).** Two separate mistakes, both from the backend guessing state:
   - `gr_texture_read` assumed `TRANSFER_SRC`. It now **takes the source state from the caller** —
     the graph is already the authority on transitions, so per-image tracking in the backend was
     duplicated state, and it was wrong. The transition and the copy are recorded into **one**
     command buffer, so recording order equals submission order; the earlier attempt put the
     transition in a different submission and could never be correct.
   - the readback then transitioned the image to `GENERAL` "for the host read", but the host reads
     the *buffer* the copy wrote, not the image. That stray `GENERAL` was what the next caller's
     `TRANSFER_SRC` assumption tripped over. Removed.

Historical note on the old causes:

1. **`vkCmdPushConstants` stage flags (6 of the 12).** The bindless layout declares one push-constant
   range covering every stage, and the spec requires the call's `stageFlags` to include every stage
   the overlapping range declares — so a call naming only `FRAGMENT` is illegal. The ABI's abstract
   `stage_mask` therefore cannot narrow the call without per-pipeline layouts, which the one-layout
   contract forbids; the backend now names the layout's stages.
2. **`vkBindBufferMemory` device address (1 of the 12).** A buffer created with
   `SHADER_DEVICE_ADDRESS` needs `VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT` on its memory; the
   allocation now chains `VkMemoryAllocateFlagsInfo`.
3. **Image layout (5 of the 12, one left).** `gr_texture_read` assumed the image was already in
   `TRANSFER_SRC`; a second readback of the same image found `GENERAL`, which the previous readback
   had left it in. The backend now tracks each texture's layout and transitions from it. **One error
   remains**, reported at `vkQueueSubmit` as an image expected in `TRANSFER_SRC` but found in
   `GENERAL`, and is not yet diagnosed.

Each was a genuine spec violation that every functional check passed straight through.

**Validation paid for itself on its first run**: it reported
`VUID-VkSamplerCreateInfo-anisotropyEnable-01070` — the thirteen fixed samplers include four
anisotropic ones, but `samplerAnisotropy` had never been enabled on the device. That was a latent
spec violation in code that had been passing every check we had, because none of our checks could
see it. It is fixed. One **warning** remains
(`WARNING-CoreValidation-AllocateDescriptorSets-WrongType`) and is not yet diagnosed.


The compute half: a 256-byte storage buffer is created (claiming storage slot 0 and a device
address of `0xffff800100140000`), `frame_setup.cs` is dispatched as one 64-thread group, and the
result is read back. Every one of the 64 words equals the hash evaluated independently in C
(`seed ^ (i * 0x9E3779B9)`, xor-shift, multiply, xor-shift), so the shader ran over the right
buffer; the same seed twice gives `0x702232ac4eca826f` both times and a different seed gives
`0x3a7a79cf4e5149d5`, so the dispatch is deterministic and its input is live.

The bindless half of that output is the increment: an 8x8 texture of four flat quadrants is
uploaded through a staging buffer and copied into a sampled image, its view claims slot 0, and
`tonemap.ps` samples it through `g_tex2d_f4[slot]` with `grail_sampler(0)`, reading the frame
constants from set 1. Three passes: the same source twice (digests must match — determinism), then
a source overwritten with one flat colour (the digest must move — proof the sample is live and not
a cached or unbound descriptor). Both hold. The four quadrant colours also appear at the values
`aces_tonemap(texel)` predicts, within ±3/255.

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
