# The Grail RHI, as far as it goes today

Grail has a graphics RHI it can call in-process: `extern "C"` declarations against the system
SDL3 and Vulkan loaders, in `abundance/src/`. This page states exactly what that covers, what it
deliberately does not, and what the next increments are. It is the third route into the same
graphics contract (`graphics/include/grail/`), and the three do not overlap:

| Route | Caller | Reaches the GPU by | Today |
| --- | --- | --- | --- |
| In-process FFI (`abundance/src/rhi_sdl3.grl`, `rhi_vulkan.grl`, `rhi_surface.grl`, `rhi_device.grl`, `rhi_swapchain.grl`, `rhi_render.grl`, `rhi_pipeline.grl`) | any Grail program linked with `-lSDL3` / `-lvulkan` | calling `SDL_*` and `vk*` symbols directly | the whole path: window, instance, surface, its capabilities, a logical device and queue, a swapchain with its images and views, a render pass that clears, framebuffers, a command buffer, semaphores and a fence, a graphics pipeline from the committed SPIR-V, and N presented frames read back and asserted pixel by pixel |
| Wire framing (`abundance/src/rhi_bridge.grl`) | a static Grail ELF with no libc | packing `gr_wire_packet` and writing it to a socket | framing ported and parity-tested; the host side is still to come |
| The C ABI backend (`graphics/`, `GR_BACKEND_NULL`) | C/C++ hosts | the `grail_rhi.h` contract | the contract, a null backend, and a Vulkan device probe in C |

The FFI route is the one that makes Grail the language of the renderer rather than a client of
one. The first consumer of that route is the editor's UI: `docs/imgui.md` has Dear ImGui called
from Grail over these same modules - the window from `rhi_sdl3`, the device, the swapchain and the
clear render pass from `rhi_device`, `rhi_swapchain` and `rhi_render` - with ImGui's own Vulkan
renderer recording into a command buffer inside that pass. It is also the only route where the *language* is the thing being tested: every limitation
below is a statement about Grail's FFI, not about SDL3 or Vulkan - and the two compiler bugs this
increment walked into ("What the FFI does not do safely") are statements about the language too.

The in-process route is four programs, because its four halves need different parts of this machine
to be present. `abundance/tests/rhi_shader_probe.grl` needs nothing at all - the shader blobs are
committed and it links no library, so it runs everywhere, CI included.
`abundance/tests/rhi_vulkan_probe.grl` needs a loader and a driver but no display server;
`abundance/tests/rhi_device_probe.grl` needs a display server and SDL3 but no Vulkan device; and
`abundance/tests/rhi_swapchain_probe.grl` is the whole path - window, surface, device, swapchain,
frames, readback - so it needs all three, and it is the only one that draws.

## What is real

All four probes run from the suite and print this machine rather than a fixture. The shader probe
needs nothing and is quoted in "Shaders" below; the other three, in order.

The swapchain probe is the one that draws, and this is what increment 4b added to it - one machine's
real numbers, quoted from one run of `bun tools/abundance-test.mjs`:

```
  rhi.device.created 1 extensions 1 api 1.0
  rhi.device.queue 0 family 0
  rhi.swapchain.created 1 images 4 format VK_FORMAT_B8G8R8A8_SRGB extent 1280x720 present_mode MAILBOX usage transfer_src|color_attachment
  rhi.image_views.created 4 format VK_FORMAT_B8G8R8A8_SRGB type 2D
  rhi.render_pass.created 1 attachments 1 subpasses 1 dependencies 1 load clear store store initial UNDEFINED final COLOR_ATTACHMENT_OPTIMAL
  rhi.framebuffers.created 4 1280x720 attachment image_view
  rhi.command_pool.created 1 family 0 level PRIMARY buffers 1
  rhi.semaphores.created 5 available 1 finished 4
  rhi.fence.created 1 unsignalled
  rhi.shader.vertex bytes 876 entry vs_main stage vertex vertex_entry 1
  rhi.shader.fragment bytes 596 entry ps_main stage fragment fragment_entry 1
  rhi.vertex_layout inputs 3 stride 36 offsets 0,12,20 formats VK_FORMAT_R32G32B32_SFLOAT,VK_FORMAT_R32G32_SFLOAT,VK_FORMAT_R32G32B32A32_SFLOAT consistent 1
  rhi.shader_modules.created 2 vertex 876 fragment 596
  rhi.vertex_buffer.created 1 bytes 108 memory 112 memory_type 0 device_local
  rhi.readback_buffer.created 1 pixels 921600 bytes 3686400 memory 3686400 memory_type 2 host_visible|host_coherent
  rhi.pipeline.created 1 stages 2 vertex vs_main fragment ps_main viewport 1280x720 topology triangle_list polygon fill cull none samples 1 blend off depth none dynamic none
  rhi.frame 0 image 0 of 4 clear 0.000,0.000,0.000,1.000 triangle 3 vertices presented VK_SUCCESS
  rhi.pixels 0 0 pixels 921600 clear 626688 triangle 294912 other 0 expected 294912 covered 1
  rhi.pixels 0 0 corner 4,4 0,0,0,255 inside 640,270 0,0,255,255 clear_pixel 1 triangle_pixel 1
  rhi.pixels 0 0 digest 10439646140818629413
  ...the same three lines for frames 1 and 2, same digest...
  rhi.swapchain.result frames 3 of 3 format VK_FORMAT_B8G8R8A8_SRGB extent 1280x720 present_mode MAILBOX
  rhi.handles.total created 35 destroyed 35 live 0
  rhi.status ok
```

The window half, unchanged from the previous increment:

```
$ bun tools/abundance-test.mjs
...
  rhi.sdl3.version 3.4.18
  rhi.sdl3.video_driver x11
  rhi.window.requested 1280 720 flags 268435496
  rhi.window.logical 1280 720
  rhi.window.pixel 1280 720
  rhi.window.destroyed 1
  rhi.status ok
rhi_device: ok
  rhi.vulkan.loader 1.4.363
  rhi.vulkan.extensions 27
  ...
  rhi.vulkan.instance.created 1
  rhi.vulkan.instance.api 1.0.0
  rhi.vulkan.instance.app_info none
  rhi.vulkan.devices 2
  rhi.vulkan.device 0 discrete_gpu api 1.4.354 AMD Radeon RX 7900 GRE (RADV NAVI31)
  rhi.vulkan.device 1 integrated_gpu api 1.4.354 AMD Ryzen 9 7900X 12-Core Processor (RADV RAPHAEL_MENDOCINO)
  rhi.vulkan.selected 0 discrete_gpu AMD Radeon RX 7900 GRE (RADV NAVI31)
  rhi.vulkan.queue_families 5
  rhi.vulkan.queue_family.chosen 0 1
  rhi.vulkan.device by rhi_device
  rhi.vulkan.instance.destroyed 1
  rhi.status ok
rhi_vulkan: ok
```

Every value above is returned by a call: nothing is defaulted, guessed or filled in.
The surface half, new in this increment, on the same host:

```
  rhi.sdl3.version 3.4.18
  rhi.sdl3.video_driver x11
  rhi.window.pixel 1280 720
  rhi.instance.extensions 2
  rhi.instance.extension VK_KHR_surface
  rhi.instance.extension VK_KHR_xlib_surface
  rhi.vulkan.instance_extension VK_KHR_surface 1
  rhi.vulkan.instance_extension VK_KHR_xlib_surface 1
  rhi.vulkan.instance_extension VK_KHR_wayland_surface 1
  rhi.vulkan.instance_extension VK_KHR_win32_surface 0
  rhi.instance.created 1
  rhi.surface.created 1
  rhi.devices 2
  rhi.device 0 discrete_gpu AMD Radeon RX 7900 GRE (RADV NAVI31) present_family 0
  rhi.device 1 integrated_gpu AMD Ryzen 9 7900X 12-Core Processor (RADV RAPHAEL_MENDOCINO) present_family 0
  rhi.device.chosen 0 present_family 0
  rhi.surface.capabilities images 3..unbounded current 1280x720 min 1280x720 max 1280x720 layers 1
  rhi.surface.capabilities alpha opaque|inherit transforms identity current identity usage transfer_src|transfer_dst|sampled|storage|color_attachment|input_attachment
  rhi.surface.formats 2
  rhi.surface.format 0 VK_FORMAT_B8G8R8A8_SRGB color_space SRGB_NONLINEAR
  rhi.surface.format 1 VK_FORMAT_B8G8R8A8_UNORM color_space SRGB_NONLINEAR
  rhi.surface.present_modes 4
  rhi.surface.present_mode 0 IMMEDIATE
  rhi.surface.present_mode 1 MAILBOX
  rhi.surface.present_mode 2 FIFO
  rhi.surface.present_mode 3 FIFO_RELAXED
  rhi.swapchain.choice format_by surface present_mode_by surface
  rhi.swapchain.config format 50 VK_FORMAT_B8G8R8A8_SRGB color_space 0 SRGB_NONLINEAR extent 1280x720 images 4 present_mode 1 MAILBOX
  rhi.swapchain.created 1 images 5 format VK_FORMAT_B8G8R8A8_SRGB extent 1280x720 present_mode MAILBOX usage transfer_src|color_attachment
  ...
  rhi.swapchain.result frames 3 of 3 format VK_FORMAT_B8G8R8A8_SRGB extent 1280x720 present_mode MAILBOX
  rhi.vulkan.validation unavailable not-installed
  rhi.surface.destroyed 1
  rhi.instance.destroyed 1
  rhi.window.destroyed 1
  rhi.handles created 3 destroyed 3 live 0
  rhi.status ok
rhi_swapchain: ok (frames 0 of 3 format VK_FORMAT_B8G8R8A8_SRGB extent 1280x720 present_mode MAILBOX)
```

Every value above is returned by a call: nothing is defaulted, guessed or filled in. The
`unavailable` lines are the parts of the increment that did not land, and they are the subject of
"What is not there, and why" below.

### The surface, and the four decisions a swapchain needs

`abundance/src/rhi_surface.grl` is new, and it is where the window half and the instance half meet:

- **`SDL_Vulkan_CreateSurface` creates the platform surface.** This is how the module reaches the
  platform-specific `vkCreate*SurfaceKHR` without naming one: SDL3 picks the entry point for the
  video driver that served the window - `vkCreateXlibSurfaceKHR` under x11,
  `vkCreateWaylandSurfaceKHR` under wayland, `vkCreateWin32SurfaceKHR` on Windows - and calls it
  through the loader with the caller's `VkInstance`. `VkSurfaceKHR *` is an out-parameter slot, so
  creation writes into the caller's binding, exactly like `vkCreateInstance`.
- **`VkInstanceCreateInfo` now carries an extension set.** `abundance_rhi_vulkan::
  instance_create_info_with(extensions, count)` fills `ppEnabledExtensionNames` from a `CPtr`, and
  the array SDL3 returns from `SDL_Vulkan_GetInstanceExtensions` is exactly that shape: C's own
  `const char *const *`, so the pointer is C's memory and Grail never has to build an array of
  strings. On this host SDL asks for 2 extensions for the `x11` driver, and the loader offers
  `VK_KHR_surface`, `VK_KHR_xlib_surface` and `VK_KHR_wayland_surface` (all named in the report).
  The names in SDL's own array are not readable - an array of pointers cannot be indexed from
  Grail - so the report names the loader's list instead and the *call* is what proves the set:
  `vkCreateInstance` returns `VK_SUCCESS` for it and then SDL creates a surface with it.
- **`VkSurfaceCapabilitiesKHR` is an `extern "C" record`, not a byte buffer.** It is 52 bytes of
  scalars with no `char` array in it, so unlike `VkPhysicalDeviceProperties` the driver writes it
  into the record's own fields and the report reads typed `u32`s. Size 52 and the field offsets
  were checked with a C program against `offsetof`/`sizeof` (minImageCount 0, maxImageCount 4,
  currentExtent 8/12, minImageExtent 16/20, maxImageExtent 24/28, maxImageArrayLayers 32,
  supportedTransforms 36, currentTransform 40, supportedCompositeAlpha 44, supportedUsageFlags 48).
- **A format list and a present-mode list are fixed-capacity records of scalars.**
  `VkSurfaceFormatKHR` is 8 bytes (format 0, colorSpace 4), so `FormatSlots` is 16 embedded records
  and `PresentModeSlots` is 8 `u32`s. Their bytes are contiguous, so the record *is* the array: the
  count query, the fill call seeded with the capacity, and a clamp afterwards - the same idiom the
  physical device list uses, with a `SurfaceFormat` per entry instead of a handle.
- **The device is the highest-ranked one that can present to this surface.** Not the highest-ranked
  one on the machine: `present_family` walks a device's queue families for one that has the
  graphics bit, at least one queue, and `VK_TRUE` from `vkGetPhysicalDeviceSurfaceSupportKHR`, and
  a device with none is not a candidate however fast it is. Both devices here answer family 0.

Then the four decisions, each a stated rule rather than a constant:

- **Format**: the best-ranked of what the surface offers - `B8G8R8A8_SRGB` (6), `R8G8B8A8_SRGB`
  (5), `B8G8R8A8_UNORM` (4), `R8G8B8A8_UNORM` (3), `A2B10G10R10_UNORM_PACK32` (2),
  `R16G16B16A16_SFLOAT` (1), anything else 0 - ties keeping the surface's own order. sRGB first
  because the render pass clears and blends in linear space and the presentation engine expects an
  sRGB-encoded image; an UNORM target would need the clear colour encoded by hand every frame. A
  surface that reports no preference (one entry, `VK_FORMAT_UNDEFINED`) lets the application choose,
  so the report says `format_by application` and picks the same format instead of printing a format
  the surface never offered. Here it is offered: `format_by surface`, `VK_FORMAT_B8G8R8A8_SRGB`.
- **Present mode**: `MAILBOX` (3) over `FIFO` (2) over `FIFO_RELAXED` (1) over `IMMEDIATE` and the
  shared modes (0). MAILBOX tears never and returns from `vkQueuePresentKHR` without waiting for
  the display, so a frame loop is not throttled to the refresh rate; FIFO is the fallback every
  surface is required to support. This surface offers all four, and MAILBOX wins.
- **Extent**: `currentExtent` when the surface defines it (`UINT32_MAX` means the swapchain decides
  the size), otherwise the window's pixel size clamped into `[minImageExtent, maxImageExtent]`,
  because an extent outside that range is refused by `vkCreateSwapchainKHR`. Here 1280x720 both
  ways.
- **Image count**: `minImageCount + 1`, clamped to `maxImageCount` unless that is 0 ("no limit"):
  the driver's minimum is the least that can present without stalling, and one more gives the
  renderer an image to draw into while the presentation engine holds another. `3 + 1 = 4` here.

### The device, and the queue a frame is submitted on

`abundance/src/rhi_device.grl` is new, and it is the first module that could only exist because the
FFI grew a record pointer. `vkCreateDevice`'s `pQueueCreateInfos` is unavoidable -
`queueCreateInfoCount` must be at least one - so the queue create info is an `extern "C"` record and
`cptr(&queue_info)` is the pointer:

- `VkDeviceQueueCreateInfo` (40 bytes: sType 0, pNext 8, flags 16, queueFamilyIndex 20, queueCount 24,
  pQueuePriorities 32) has exactly one pointer that matters, `pQueuePriorities`, and it points at
  `Priorities` - a one-field record whose single `f32` *is* the `const float *` C wants. A record is
  the only way this language hands out the address of a scalar.
- `VkDeviceCreateInfo` (72 bytes) also has `ppEnabledExtensionNames`, which is `const char *const *`
  and is a record of `CStr` fields: with one name in it, the record's bytes are the one-element array
  of pointers, which is how `VK_KHR_swapchain` is enabled without a byte buffer anywhere.
- `pEnabledFeatures` is null on purpose: nothing here needs a feature past core 1.0, and enabling one
  the pipeline does not use would be a claim the program cannot check.
- The queue is `vkGetDeviceQueue`'s out-parameter, and it is not destroyed individually: it goes with
  the device, and the ledger counts it at `vkDestroyDevice`.

The device is the highest-ranked physical device that has a queue family which both runs graphics
work and presents to the surface (`present_family`), so the family in the create info is the family
the frames are submitted on.

### The swapchain, its images and their views

`abundance/src/rhi_swapchain.grl` is new. It creates `VkSwapchainCreateInfoKHR` (104 bytes) from the
four decisions `abundance_rhi_surface` already made - it does not choose anything twice - and it
checks nothing the surface has not already answered. Three details are worth stating:

- `oldSwapchain` is a **null handle**, and a handle binding declared without an initializer *is*
  `VK_NULL_HANDLE`, so the null crosses as a value the language already has. There is no resize in
  this increment: one swapchain is created per run and destroyed at the end.
- The images come back as an array of *handles* C writes. `vkGetSwapchainImagesKHR` is declared twice:
  a count query with a null data pointer, and a fill call whose `VkImage *` is `&mut ImageSlots`
  (`i0..i7`). The count the driver writes back is clamped into the record's capacity before any slot
  is read, and a driver reporting more images than that is reported as truncated rather than read past.
- Each image gets one `VkImageView`, a 2D colour view of mip 0 layer 0 in the swapchain's format.
  Creation writes one handle at a time through `&mut ImageView` and stores it in the slot record -
  which is why the probe keeps each slot record as its *own* binding (see "What the FFI does not do
  safely").
- The usage asked for is `COLOR_ATTACHMENT` plus `TRANSFER_SRC` when the surface's
  `supportedUsageFlags` allows both, because the readback in step 4 needs the second. The probe prints
  which usage it got, so a surface that could not be a transfer source would say so rather than fail
  later.

On this machine: 4 images (the surface's `minImageCount` 3 plus one), `VK_FORMAT_B8G8R8A8_SRGB`,
1280x720, `MAILBOX`.

### The render pass, the clear, and the present loop

`abundance/src/rhi_render.grl` is new. It is the module where the frame happens, and every pointer in
it is the address of a record:

- `VkRenderPassCreateInfo` points at `VkAttachmentDescription` (36 bytes), `VkSubpassDescription`
  (72) and `VkSubpassDependency` (28); the subpass points at an `VkAttachmentReference` (8). One
  colour attachment, 1 sample, `loadOp = CLEAR`, `storeOp = STORE`, `initialLayout = UNDEFINED`
  (the image was just acquired and its contents are the previous frame's), `finalLayout =
  COLOR_ATTACHMENT_OPTIMAL`. The dependency is `EXTERNAL -> subpass 0` at
  `COLOR_ATTACHMENT_OUTPUT`, which orders the layout transition before the writes that need it.
- One `VkFramebuffer` per image view, `pAttachments` being a record of one `ImageView` field - the
  one-element array.
- One command pool on the drawing family, with
  `VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT`, and one command buffer reused every frame.
  *That flag is not cosmetic*: beginning a command buffer that has already been executed is only
  legal after a reset, and without the bit RADV segfaults on the second `vkBeginCommandBuffer`.
- `VkRenderPassBeginInfo`'s `pClearValues` points at a `ClearValue` record - four floats, 16 bytes,
  which is the colour arm of the `VkClearValue` union - and the render area is a `VkRect2D` record.
- `VkSubmitInfo` and `VkPresentInfoKHR` need arrays of handles and an array of `u32`:
  `pWaitSemaphores`, `pSignalSemaphores`, `pCommandBuffers`, `pSwapchains` and `pImageIndices` are
  each a one-field record seeded from the handle or index the frame already holds.
- The frame is: acquire with `vkAcquireNextImageKHR` (one image-available semaphore, one null fence),
  record the clear and the draw, barrier `COLOR_ATTACHMENT_OPTIMAL -> TRANSFER_SRC_OPTIMAL` and copy
  the image out (step 4), barrier on to `PRESENT_SRC_KHR`, submit waiting on the acquire semaphore and
  signalling a *per-image* render-finished semaphore, wait on the fence, then present.

One image-available semaphore is enough because exactly one frame is in flight: nothing is submitted
again until the fence is signalled. Render-finished semaphores are per image, because a binary
semaphore must not be signalled again until the present that waited on it has finished - and only
re-acquiring that image proves it has.

Frame count is the probe's argument (`GRAIL_RHI_FRAMES`, default 3):
`rhi.swapchain.result frames 3 of 3` on this machine.

### The pipeline, and the triangle

`abundance/src/rhi_pipeline.grl` is new. `VkGraphicsPipelineCreateInfo` (144 bytes) is the struct
that listed nine pointers, and each is now a record address:

| Field | What it points at |
| --- | --- |
| `pStages` | a record of two `VkPipelineShaderStageCreateInfo` (48 bytes each), `pName` a `CStr` field |
| `pVertexInputState` | a record holding one `VkVertexInputBindingDescription` (12) and one `VertexAttributes` (three 16-byte records) |
| `pInputAssemblyState` | triangle list, no primitive restart |
| `pViewportState` | a record pointing at a `VkViewport` (24) and a `VkRect2D` (16) - static, so `pDynamicState` is null |
| `pRasterizationState` | fill, no culling, clockwise front face, no depth bias, lineWidth 1 |
| `pMultisampleState` | one sample, no sample shading, no alpha-to-coverage |
| `pColorBlendState` | one attachment, blending off, all four channels written |
| `pDepthStencilState` | null: no depth attachment, no depth test |
| `pTessellationState` | null |

The vertex input is the layout `abundance/tools/build-shaders.mjs` extracted from the compiled vertex
stage, not a transcription: `vertex_input_count`, `vertex_stride` and location/offset/format per
input come from `abundance_rhi_shader_blob`, and `vertex_input_consistent()` checks the two things
that admit without a driver - the offsets are contiguous in declaration order, and the stride is the
sum of the widths (0 + 12 + 8 + 16 = 36).

The vertex data is a record of three 36-byte vertices, and it reaches the GPU with `vkCmdUpdateBuffer`
from `cptr(&triangle)` - a `const void *` and a size, no staging buffer, no mapped memory and no byte
layout. A `VkMemoryBarrier` then orders that transfer write before the vertex fetch. The vertex buffer
itself is device-local memory chosen from `VkPhysicalDeviceMemoryProperties` - which is 520 bytes with
32 memory types and 16 heaps inside it, and is therefore a record of embedded records rather than a
byte buffer.

The triangle is flat red on black: all three vertices carry colour (1,0,0,1) and uv (1,1), so the
pixel shader's `color * float4(uv, 1, 1)` is (1,0,0,1) everywhere inside it. Both 0.0 and 1.0 are
fixed points of the sRGB encoding the swapchain format applies, so the bytes a frame produces are
exact rather than approximate - which is what makes the next section an assertion.

### The readback, and what a frame's bytes are

"It presented" is not evidence. Every frame is copied out of its swapchain image
(`vkCmdCopyImageToBuffer`, one `VkBufferImageCopy` region record), into a host-visible coherent
buffer, and after the fence that buffer is mapped, `memcpy`'d into Grail bytes and inspected. A mapped
`void *` cannot be indexed here, so `memcpy` is the bridge - the same one the window probe uses for
SDL's error text.

On this machine, per frame:

```
  rhi.frame 0 image 0 of 4 clear 0.000,0.000,0.000,1.000 triangle 3 vertices presented VK_SUCCESS
  rhi.pixels 0 0 pixels 921600 clear 626688 triangle 294912 other 0 expected 294912 covered 1
  rhi.pixels 0 0 corner 4,4 0,0,0,255 inside 640,270 0,0,255,255 clear_pixel 1 triangle_pixel 1
  rhi.pixels 0 0 digest 10439646140818629413
```

and the same three lines for frames 1 and 2, with the same digest. The assertions behind those lines:

- every pixel is either the clear colour or the triangle's - `other 0` - so no blending, filtering or
  stray draw is happening;
- the cleared and covered counts add up to the extent (`626688 + 294912 = 921600`);
- the covered count equals the triangle's own area, `0.32 x width x height` (the triangle spans 1.6
  in x and 1.6 in y of normalised device coordinates), to within a row of pixels - which is a check on
  the pipeline's rasterisation and not just on the colour;
- the corner (4,4) reads `0,0,0,255` and the centre (640,270) reads `0,0,255,255`, in the
  `B8G8R8A8_SRGB` byte order the swapchain actually has - so the clear colour *and* the channel order
  are asserted, not assumed;
- all frames hash the same, which is the steady-state claim: the same commands produce the same
  bytes.

### Teardown, and the handle balance

Every path that creates a handle destroys it, in the reverse of the order it was created, and each
exit path in the probe runs the same two functions (`teardown`, then `report_all`) so no branch can
forget half of it. The program counts what it created and what it destroyed **per handle class**:

```
  rhi.fence.destroyed 1
  rhi.semaphores.destroyed 5
  rhi.command_pool.destroyed 1 buffers 1
  rhi.framebuffers.destroyed 4
  rhi.render_pass.destroyed 1
  rhi.image_views.destroyed 4
  rhi.swapchain.destroyed 1 images 4
  rhi.device.destroyed 1
  rhi.surface.destroyed 1
  rhi.instance.destroyed 1
  rhi.window.destroyed 1
  rhi.handles.window created 1 destroyed 1 live 0
  ...
  rhi.handles.buffer created 2 destroyed 2 live 0
  rhi.handles.device_memory created 2 destroyed 2 live 0
  rhi.handles.total created 35 destroyed 35 live 0
```

Nineteen classes: window, instance, surface, device, queue, swapchain, image, image view, render
pass, framebuffer, command pool, command buffer, semaphore, fence, shader module, pipeline layout,
pipeline, buffer and device memory. Three are closed by their owner rather than by a call of their
own, and the ledger counts them at the moment the owner goes: the queue with `vkDestroyDevice`, the
swapchain's images with `vkDestroySwapchainKHR`, and the command buffer with `vkDestroyCommandPool`.

A disagreement in any class, or in the total, fails the run (`rhi.status failed handles-leaked`,
exit 1), so a leaked device, a leaked framebuffer or a leaked semaphore cannot pass quietly. This is
the assertion, not the validation layer: the layer is not installed on this host (the loader reports
8 layers, none of them `VK_LAYER_KHRONOS_validation`), and enabling it from here would need
`VkInstanceCreateInfo::ppEnabledLayerNames` - an array of C strings Grail would have to build, which
the device create info's `ppEnabledExtensionNames` shows is now possible but is not wired up for
layers. Where the layer *is* installed, the suite forces it on through the loader
(`VK_LOADER_LAYERS_ENABLE`/`VK_INSTANCE_LAYERS`) for a second run and fails on any validation message,
and it requires the layer's manifest to name a real ELF shared object before it claims anything was
validated. On this host that variant reports `validation skipped (no VK_LAYER_KHRONOS_validation
library on this host)`.

## Shaders

The shader side of the pipeline is done, because none of it needs a device: HLSL compiles offline to
SPIR-V, the bytes are committed, and the one create info that carries them has a pointer the FFI can
already fill. This is what a Grail renderer will do, and what it proves today.

**Three committed artifacts and one generator.** The HLSL is the source of truth:

| File | Role |
| --- | --- |
| `abundance/tests/shaders/rhi_triangle.hlsl` | the source of truth: one vertex and one pixel stage, in HLSL |
| `abundance/tests/shaders/rhi_triangle.{vert,frag}.spv` | what glslang made of it, committed so nothing needs glslang to build |
| `abundance/tests/shaders/shaders.json` | the manifest: compiler version, exact flags per stage, entry points, sizes, hashes, layout, cross-check status |
| `abundance/src/rhi_shader_blob.grl` | generated: the bytes as constants, plus the vertex layout, as Grail |

`bun abundance/tools/build-shaders.mjs` regenerates the last three from the first and refuses to run
without `glslangValidator` (that is the only thing that needs it). `bun abundance/tools/build-shaders.mjs
--check` verifies them, and `bun tools/abundance-test.mjs` runs that check in the default suite. The
generator is a maintenance tool, not a build step: a clean checkout compiles, tests and renders with
no shader compiler installed.

**The toolchain on this host**: `glslangValidator` 11:16.6.0 (`-D -V --target-env vulkan1.2 -S vert
-e vs_main`, and `-S frag -e ps_main` for the pixel stage), with `spirv-val` (SPIRV-Tools v2026.4)
run on every module the generator writes - it refuses to write anything the validator rejects.
`spirv-cross` is *not* installed here, which is why the extraction is cross-checked against the
compiled stage's own decorations instead of a second reflector: the generator reads `OpName`,
`OpDecorate Location` and the `OpTypeVector`/`OpTypeFloat` chain out of the vertex module and
requires them to agree with what it read out of the HLSL. The manifest records both facts, so a
reader can tell "not cross-checked because the tool is absent" from "cross-checked and agreed":

```json
"crosscheck": {
  "reflector": "spir-v decorations",
  "available": true,
  "spirv_cross": { "available": false, "version": null }
}
```

**The vertex-layout grammar**, and nothing outside it: one `struct VertexIn { ... };` block, one
field per line, each `<type> <name> : <SEMANTIC>;`, with the type one of `float`, `float2`,
`float3`, `float4` (→ `VK_FORMAT_R32_SFLOAT` 100, `R32G32_SFLOAT` 103, `R32G32B32_SFLOAT` 106,
`R32G32B32A32_SFLOAT` 109) and any semantic text. Anything else - another type, a `register`
annotation, a comment on the field line, a second struct, a line without a semantic - is a hard
error that names the file, the line and the accepted list, because a type this tool does not know
must never become a guessed `VkFormat`.

A field's **location is its declaration order**, and that is a claim the generator does not take on
trust: the compiled vertex stage's `OpDecorate Location` has to agree, or the generator fails. So
reordering the fields in the HLSL is safe to *do* (regenerate, and the locations follow the order,
which the check confirms) and never safe to *assume* (a stage that disagrees with the struct is an
error, not a silent remap).

**The loader shape.** `VkShaderModuleCreateInfo` is an `extern "C"` record - 40 bytes, `sType` 0,
`pNext` 8, `flags` 16, `codeSize` 24, `pCode` 32 - and `pCode` is the one pointer inside a Vulkan
create info that Grail can already fill: the bytes are a Grail `u8[]` and `unsafe cptr(&bytes)` is
their data pointer. `vkCreateShaderModule` itself needs a device, so the *probe* does not call it - it
builds the create info, sets `pCode` from the bytes, and asserts that `codeSize` is the blob's own
length. The call itself is `abundance_rhi_pipeline::create_shader_module`, which the swapchain probe
reaches with a real device.

**What the probe proves**, on a machine with no device, no display, no driver and no shader
compiler - it links nothing but the Grail runtime:

```
  rhi.shader.vertex bytes 876 words 219 hash 3815826166499406854 spv 1.5 generator 8 11 bound 80 schema 0 status ok stage vertex entry vs_main
  rhi.shader.fragment bytes 596 words 149 hash 10699842479919998103 spv 1.5 generator 8 11 bound 59 schema 0 status ok stage fragment entry ps_main
  rhi.shader.module s_type 16 code_size 876 bytes 876
  rhi.shader.layout count 3 stride 36
  rhi.shader.input 0 location 0 offset 0 format 106 VK_FORMAT_R32G32B32_SFLOAT semantic POSITION
  rhi.shader.input 1 location 1 offset 12 format 103 VK_FORMAT_R32G32_SFLOAT semantic TEXCOORD0
  rhi.shader.input 2 location 2 offset 20 format 109 VK_FORMAT_R32G32B32A32_SFLOAT semantic COLOR0
  rhi.shader.result stages 2 bytes 1472 inputs 3
  rhi.status ok
```

The Grail side reconstructs the bytes from the generated constants and hashes them with Abundance's
own `fnv1a64`; the hash must equal the one recorded for the committed `.spv`, and the suite compares
the probe's printed hash against the manifest - two committed artifacts that have to agree, with no
compiler anywhere in the loop. `abundance_rhi_shader::inspect` then checks the module as a module:
magic, version, generator, bound and schema, and the first `OpEntryPoint`'s execution model and
name, which must be the stage and the entry point the HLSL declares. The layout is checked as a
layout: declaration-order locations, contiguous offsets, formats with a known component count, and a
stride that is their sum.

**The check is two-tiered, on purpose.** Tier 1 needs no tools at all and always runs: the committed
`.spv` against the manifest, the HLSL extraction against the manifest *and* against the `.spv`'s
decorations, and the generated module against the manifest and against what the committed bytes
describe. Tier 2 recompiles the HLSL and demands identical bytes, but only when the `glslangValidator`
on the machine is the version the manifest records; otherwise it prints

```
shader hash differs (glslang 11:16.6.0 recorded, 11:99.0.0 present): not compared
```

and exits 0. A newer glslang emits different SPIR-V for the same source, and that is not this
repository's bug: a toolchain upgrade must not turn a green build red. With no glslang at all the
same check reports `not recompiled (glslangValidator is not installed; the committed .spv files were
verified against the manifest and the HLSL)` and passes, which is what makes the default suite work
on every machine.

## What is not there, and why

**No logical device, so no queues, no surface, no swapchain, no pipelines.** The probe still stops
here, but the reason has changed: the FFI gap this section used to describe is closed, and what is
missing now is the port.

Until this increment the language had no expression whose value is the address of an owned
`extern "C"` record, and Vulkan create-info graphs are built out of exactly that. The FFI now has the
three forms it needs (`docs/ffi.md`, "Records by pointer" and "Out-parameters"):

| shape | meaning |
| --- | --- |
| `unsafe cptr(&r)` / `cptr_mut(&mut r)` | the address of an `extern "C"` record's own fields, as a `CPtr` / `CMutPtr`; a field, a binding and a `const void *`/`void *` parameter all take it |
| `p: &mut R` in a declaration | the C `R *` the callee writes; the typed fields are read afterwards |
| a `[handle; N]` field | an array of handles: C fills the slots through the record, or the program seeds them from handles it already holds (`PhysicalDeviceSlots`) |

With those, `VkInstanceCreateInfo::pApplicationInfo` is a field assignment, `VkApplicationInfo` itself
is a record of scalars and `CStr` fields, `pQueueCreateInfos` is a record of embedded
`VkDeviceQueueCreateInfo` fields, `ppEnabledExtensionNames` is a record of `CStr` fields, and
`VkDeviceQueueCreateInfo`'s `pQueuePriorities` is `cptr` of a float array. An `extern "C"` record
declared without an initializer is `sizeof(struct)` zeroed bytes, so an array of handles can be
created without constructing one; it has no *value* until a call or an assignment wrote it.

The instance probe now says what it does: `rhi.vulkan.instance.app_info none` (the instance asks
for API 1.0 by leaving `pApplicationInfo` null, and every call this RHI makes is 1.0) and
`rhi.vulkan.device by rhi_device` (the logical device is `abundance_rhi_device`'s, created by
`rhi_device_probe`). C arrays are read with `[T; N]` record fields and `cslice` (docs/ffi.md, "C
arrays"): `VkPhysicalDeviceProperties` is a record with its `char deviceName[256]` inline, and the
swapchain probe prints the extension names SDL asks for.

What the language still refuses, with the diagnostic for each (all but the last are pinned in
`tests/native-cases.json`):

| Attempt | Result |
| --- | --- |
| `cptr(&AppInfo { ... })` - the address of a temporary | `cptr needs a named record: the address of a temporary would not outlive the pointer` |
| `c_two(cptr(&r), cptr_mut(&mut r))` - the same record twice in one expression | `the value handed to C as a writable pointer is already borrowed in this expression` |
| `c_fill(&mut Slots { ... })` - an out-parameter with no binding to write into | `an extern C out-parameter needs a binding to write into; a temporary record would be discarded` |
| `extern "C" fn f(p: &mut i64)` - an out-parameter that is not a handle, `CPtr`/`CMutPtr` or extern record | `an extern C out-parameter must be &mut a handle, CPtr, CMutPtr or extern "C" record` |
| `Slot { instance: cnull() }` - seeding a handle field from a `CPtr` | `generic argument shape mismatch` |
| `mut slot: Slot;` then `slot.instance`, before anything wrote it | `use of moved, borrowed or partially initialized value` |
Increment 4b closed the gap this page was written around. A Vulkan create-info graph is now a graph of
`extern "C"` records, and the pointers in it are `cptr(&record)` / `cptr_mut(&mut record)` or the
addresses of records inside records - so `VkDeviceCreateInfo`, `VkSwapchainCreateInfoKHR`,
`VkRenderPassCreateInfo`, `VkFramebufferCreateInfo`, `VkRenderPassBeginInfo`, `VkSubmitInfo`,
`VkPresentInfoKHR` and `VkGraphicsPipelineCreateInfo` are all real calls on this branch, and the
frames they produce are asserted byte for byte. Nothing in this RHI lays a struct out in a `u8[]`:
the only byte sequences are a shader's SPIR-V (which is bytes by definition), a mapped frame (which is
copied, not interpreted) and the loader's own C-written property blocks, which a record cannot express
because they contain `char` arrays.

What is *not* here, by intent rather than by limitation:

- **resize.** One swapchain per run; `oldSwapchain` is always null, and a `VK_ERROR_OUT_OF_DATE_KHR`
  from acquire or present fails the run instead of rebuilding the swapchain. The window is created
  hidden and never resized, so nothing in this increment needs it.
- **more than one frame in flight.** One command buffer, one image-available semaphore, one fence, and
  a CPU wait per frame. That is a steady loop - the same commands and the same pixels every frame - but
  not a pipelined one: `N` frames take `N` round trips.
- **depth, MSAA, blending, textures, descriptor sets.** The pipeline has no depth attachment, one
  sample, blending off and no descriptor sets; the render pass has one colour attachment and one
  subpass. `VkPipelineLayout` is created with zero sets and zero push-constant ranges.
- **the validation layer.** Not installable from here (see the teardown section): it needs
  `ppEnabledLayerNames`, which means an array of `CStr` on the *instance* create info. The device
  create info already does exactly that for extensions, so this is a small increment, not a gap.
- **vertex and index buffers that are mapped rather than updated.** The triangle goes in through
  `vkCmdUpdateBuffer`, which is capped at 64 KiB per call and is not what a mesh with tens of
  thousands of vertices would use; a real upload path wants a staging buffer and
  `vkCmdCopyBuffer`, and then `vkMapMemory`/`memcpy` to fill it - the FFI has no way to *write*
  through a mapped `void *`, only to copy from it.
- **anything downstream of a frame**: input, the event pump, displays, clipboard, debug messengers,
  bindless tables, timeline semaphores, swapchain recreation, presentation timing.

## What the FFI does not do safely

Two defects in the record-pointer work surfaced while building the early increments. Both were
compiler bugs, both are fixed, and both are kept here with their minimal cases for the history.

`vkCreateInstance` is still called with `pApplicationInfo` null by choice - the instance then asks
for API 1.0, and every call the RHI makes is core 1.0 - so `rhi.vulkan.instance.api` reads `1.0.0`
while the loader is newer. `vkCreateDevice`, the device's queue create infos and the enabled
extension names are records built in Grail and passed with `cptr(&record)` (`rhi_device.grl`).

The rule this module keeps: the structs Grail *builds* are `extern "C"` records, never byte buffers
at hard-coded offsets, so a mis-ordered create-info field is a compile error or a failing check
rather than a plausible-looking number. Structs C fills in as an array in one buffer (extensions,
layers, queue families) are still read from bytes at their C offsets; a single struct C fills in is
a record with its arrays inline (`[T; N]`).

**1. Fixed: `&mut` of an extern record field of a plain record now reaches the field's storage.** A
place made from an interior extern record used to be wrapped in the proxy slot an *embedded* C-layout
field needs, even when the container was a plain record whose field already is a word holding the
record's address, so a write through the reference landed in the container's next word and was lost
there. A slot array written through such a reference was a record of null handles, and a null
framebuffer handle is a segfault inside the driver - which is how it was found. Minimal case:

```grail
extern "C" record Pair { x: i64, y: i64 }
struct Bag { pair: Pair, count: i64 }
fn set_y(pair: &mut Pair, value: i64) -> unit { pair.y = value; }

mut bag = Bag { pair: Pair { x: 0, y: 0 }, count: 0 };
set_y(&mut bag.pair, 7);
println(format("{} {}", bag.pair.x, bag.pair.y));   // "0 7"; it printed "0 0" and set `count`
```

The proxy is now made only for a C-layout container, and `tests/ffi/record_field_refs.grl` executes
the shape with a Grail callee and with a C callee that checksums the fields before writing them. The
RHI still keeps each slot record as its own binding; that remains sound and need not change.

**2. (fixed) a `CStr` taken from a string literal used to dangle after its statement.** `cstr("...\0")` now points into static read-only storage, so it may be kept in a binding or a record field, and `cstr(bytes)` holds a loan on `bytes` like `cptr` does (pinned by `ffi-cstr-literal-kept-in-binding` and `ffi-reject-cstr-bytes-modified-while-live`). The original report, kept for the history: `cstr(value)`
is zero-copy, and for a literal the bytes are a temporary: keeping the `CStr` in a binding and using it
in a later statement reads freed memory. It reads *correctly* often enough to be missed - it did here -
which is why the pipeline's entry-point names are copied out of the SPIR-V into byte-sequence bindings
and `cstr` is taken of those bytes (as a view, so they are not moved):

```grail
mut bytes = u8[118, 115, 95, 109, 97, 105, 110, 0];   // "vs_main\0"
mut name: CStr;
unsafe { name = cstr(&bytes); }                       // the bytes are the binding's, not a temporary's
```

`SDL_CreateWindow(cstr("..."))` is fine for the same reason in reverse: the pointer is used inside the
statement that made it.

The three diagnostics the previous increment was written around -
`cptr requires a byte sequence or view`, `an extern C out-parameter must be &mut a handle, CPtr or
CMutPtr` and `opaque handles cannot be constructed` - are gone: `cptr(&record)`, `&mut Record` and
`Slot { handle: h }` from a handle the program holds all compile and run. `tests/native-cases.json`
pins the new refusals in their place (a `cptr` of a temporary, a `cptr` of a non-extern record, two
pointers to one record in one call, an out-parameter without a binding).

### One record, one call

Fixed. Passing one count record to two declarations of the same symbol (`vkEnumeratePhysicalDevices`
as a count query, then as the slot-filling form) used to abort at exit inside the runtime's free
path. It no longer does: one `Count` record through both declarations runs clean, so a record per
call is a style choice now, not a workaround.

## Linking, skipping and the GPU lock

- `lib "SDL3"` and `lib "vulkan"` are the linker inputs the compiler emits as `// grail-link:
  SDL3` / `// grail-link: vulkan`; `tools/native.mjs` turns a bare name into `-lNAME` and resolves
  it against `/usr/lib` and `/usr/lib64`. No SDK, no vendored copy, no build system of its own.
- Each probe names only the modules it needs, so the link is one library per probe - the window
  probe `-lSDL3`, the Vulkan probe `-lvulkan`, the surface probe both, and the shader probe nothing
  beyond the Grail runtime. A machine with no display server still runs the Vulkan probe and the
  shader probe.
- The shader artifacts are checked before any probe runs: `bun tools/abundance-test.mjs` invokes
  `bun abundance/tools/build-shaders.mjs --check`, which verifies the committed `.spv` files, the
  generated Grail module and the HLSL against each other and only recompiles when this machine's
  glslang is the version the manifest records. The complete proof that none of it needs a toolchain:
  with `DISPLAY` and `WAYLAND_DISPLAY` unset, `VK_ICD_FILENAMES` pointing at nothing and a `PATH`
  without `glslangValidator`, `spirv-val` or `spirv-dis`, the suite prints

  ```
    shaders: 2 stages, 1472 bytes, 3 vertex inputs (self-consistent; manifest records glslang 11:16.6.0)
    shaders: not recompiled (glslangValidator is not installed; the committed .spv files were verified against the manifest and the HLSL)
  rhi_shader: ok (stages 2 bytes 1472 inputs 3)
  rhi_device: skipped platform-or-driver-missing
  rhi_vulkan: skipped loader-or-driver-missing
  rhi_swapchain: skipped no-display
  10 test program(s) passed, 4 RHI probe(s) run
  ```

  and the shader probe alone runs under `env -i` with no environment at all.
- Those three modules are the only ones in `abundance/src` that name a system library. The port
  parity suite keeps them out of its link (`ffiModules` in `tools/abundance-test.mjs`), so the ports
  still build on a machine with neither loader.
- Being absent is said five different ways (and the shader probe has no `skipped` state on purpose:
  nothing about it depends on the machine, so a machine where it does not run is a machine where it
  was not wired in): no `libSDL3.so`/`libvulkan.so` to link and that probe is
  skipped before it compiles; no display server and `SDL_Init` fails, so SDL's own message is
  printed and the probe ends with `rhi.status skipped no-display`; a video driver that cannot back
  a Vulkan window (SDL's `dummy`) prints SDL's reason and skips; a loader with no ICD answers
  `vkCreateInstance` with `VK_ERROR_INCOMPATIBLE_DRIVER` and the probe skips by name; and a machine
  with no device that has a present-capable queue family skips with that reason. Exit status is 0
  for `ok` and `skipped` and 1 only for `failed`, a call that contradicted its own contract.
- The surface probe takes the frame count as its argument (`argv[1]`, the language's one entry
  parameter): `GRAIL_RHI_FRAMES=12 bun tools/abundance-test.mjs` asks for twelve frames, and the
  suite passes 3 unless told otherwise. A non-decimal argument falls back to the default rather than
  parsing up to the first non-digit.
- Enumerating a driver is not free, and this host serialises every program that talks to one, so
  each probe runs under the same exclusive lock as `graphics/Makefile`: `flock` on
  `/run/user/<uid>/ab-engine-gpu.lock`. Without `flock` or a lock directory a probe runs unlocked
  and the suite says so; when the lock stays busy for the whole ten-minute wait, the probe is
  skipped with that reason rather than failed.

## The next increments

1. **Port `abundance/src/rhi_vulkan.grl` onto the FFI that exists now.** The feature this increment
   waited on has landed (`docs/ffi.md`, "Records by pointer"): a record's address as a value, a
   record out-parameter C writes, and a record of handle fields as an array. The port is
   `VkApplicationInfo` as a record and `pApplicationInfo = cptr(&app)` for a 1.4 instance,
   `ppEnabledExtensionNames` as a record of `CStr` fields with `VK_KHR_surface`, `vkCreateDevice`
   with `pQueueCreateInfos`, then `vkGetDeviceQueue` and `vkDestroyDevice`. The declaration for the
   device is already written down in `graphics/include/grail/grail_backend_vulkan.h`'s feature set
   (dynamic rendering, synchronization2, timeline semaphore, buffer device address, scalar block
   layout, descriptor indexing), and this increment's queue family selection is what feeds it.
2. **A `VkSurfaceKHR` and a swapchain from the window the previous increment already creates**:
   `SDL_Vulkan_CreateSurface` from the `Window` handle, the platform surface extension, surface
   capabilities and formats (`VkSurfaceCapabilitiesKHR` is 52 bytes and `VkSurfaceFormatKHR` 8, so
   these stay records or byte buffers depending on whether Grail builds them or C fills them), and a
   present loop that at minimum clears the image. This needs increment 1 for the extension-name array
   and for `VkSwapchainCreateInfoKHR`'s own pointers (`pNext`, `pQueueFamilyIndices`);
   `vkCreateSwapchainKHR`, `vkCreateImageView` and the `vkGetSwapchainImagesKHR` handle array are
   reachable today - the swapchain images come back through the same record-of-handles idiom this
   increment introduced for physical devices, which C can now fill directly.
3. **Pipelines, and the first frame drawn into**: `vkCreateShaderModule` already works - its
   `pCode` is `const uint32_t *` and a shader's bytes *are* addressable through `cptr` - but
   `VkGraphicsPipelineCreateInfo` points at `pStages`, `pVertexInputState`,
   `pInputAssemblyState`, `pViewportState`, `pRasterizationState`, `pMultisampleState`,
   `pDepthStencilState`, `pColorBlendState` and `pDynamicState`, so it needs increment 1 as well.
   Queues and the command pool/command buffer pair come from increment 2. The cross-check to keep is
   `graphics/`'s own `gr_vk_probe_run()` and its test suite: the Grail and C sides have to agree on
   the same machine, which is how this increment's device name, type, API version and graphics
   family were verified.
The path these increments were ordered along is finished: the FFI can pass records to C, and a Grail
program now creates a device, presents N frames with a pipeline in them, and reads the pixels back.
What is worth building next, in the order the RHI would feel it:

1. **Two frames in flight, and swapchain recreation.** Two command buffers, two fences, two
   image-available semaphores, and a `VK_ERROR_OUT_OF_DATE_KHR` path that rebuilds the swapchain from
   the surface's new answers (`create_swapchain` already takes every decision as a parameter, so this
   is a caller change and a `oldSwapchain` that is no longer null).
2. **A staging buffer, and a mapped upload path.** `vkMapMemory` returns `void *` and this language can
   copy *from* it but not write *through* it; a vertex upload larger than `vkCmdUpdateBuffer`'s 64 KiB
   needs a `vkCmdCopyBuffer` from a host-visible staging buffer that something filled. The missing
   piece is a writable byte view of a mapped range - a small FFI addition, and the same shape a
   texture upload would need.
3. **The validation layer.** `ppEnabledLayerNames` on `VkInstanceCreateInfo` is now expressible (a
   record of `CStr` fields, exactly like the device's extension names), so the suite's validated
   variant could stop saying `not-installed` and start finding things on this machine.
4. **Depth, and a second attachment.** The render pass takes more than one attachment and the pipeline
   takes a `VkPipelineDepthStencilStateCreateInfo`; both are the same records with more fields.
5. **Descriptors and a uniform buffer.** `VkDescriptorSetLayoutCreateInfo`,
   `VkDescriptorPoolCreateInfo` and `VkWriteDescriptorSet` are the first create infos whose pointers
   point at *arrays of structs built by Grail* rather than at one struct - which is a record of
   embedded records, i.e. the shape this increment already uses for `ShaderStages` and
   `VertexAttributes`. No new FFI feature is expected.
