# The Grail RHI, as far as it goes today

Grail has a graphics RHI it can call in-process: `extern "C"` declarations against the system
SDL3 and Vulkan loaders, in `abundance/src/`. This page states exactly what that covers, what it
deliberately does not, and what the next increments are. It is the third route into the same
graphics contract (`graphics/include/grail/`), and the three do not overlap:

| Route | Caller | Reaches the GPU by | Today |
| --- | --- | --- | --- |
| In-process FFI (`abundance/src/rhi_sdl3.grl`, `rhi_vulkan.grl`, `rhi_surface.grl`) | any Grail program linked with `-lSDL3` / `-lvulkan` | calling `SDL_*` and `vk*` symbols directly | window created and sized; a real `VkInstance` created with the platform's own instance extension set, and destroyed; physical devices enumerated, named, typed and selected; queue families read; a real `VkSurfaceKHR` created from the window, its capabilities, formats and present modes read back, and the swapchain's format, extent, image count and present mode chosen |
| Wire framing (`abundance/src/rhi_bridge.grl`) | a static Grail ELF with no libc | packing `gr_wire_packet` and writing it to a socket | framing ported and parity-tested; the host side is still to come |
| The C ABI backend (`graphics/`, `GR_BACKEND_NULL`) | C/C++ hosts | the `grail_rhi.h` contract | the contract, a null backend, and a Vulkan device probe in C |

The FFI route is the one that makes Grail the language of the renderer rather than a client of
one. It is also the only route where the *language* is the thing being tested: every limitation
below is a statement about Grail's FFI, not about SDL3 or Vulkan.

The in-process route is four programs, because its four halves need different parts of this machine
to be present. `abundance/tests/rhi_shader_probe.grl` needs nothing at all - the shader blobs are
committed and it links no library, so it runs everywhere, CI included.
`abundance/tests/rhi_vulkan_probe.grl` needs a loader and a driver but no display server;
`abundance/tests/rhi_device_probe.grl` needs a display server and SDL3 but no Vulkan device; and
`abundance/tests/rhi_swapchain_probe.grl` needs all three, because a `VkSurfaceKHR` is the one object
that belongs to both a window and an instance.

## What is real

All four probes run from the suite and print this machine rather than a fixture. The shader probe
needs nothing and is quoted in "Shaders" below; the other three, in order. The window half, unchanged
from the previous increment:

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
  rhi.vulkan.instance.app_info unavailable extern-C-cannot-take-the-address-of-a-record
  rhi.vulkan.devices 2
  rhi.vulkan.device 0 discrete_gpu api 1.4.354 AMD Radeon RX 7900 GRE (RADV NAVI31)
  rhi.vulkan.device 1 integrated_gpu api 1.4.354 AMD Ryzen 9 7900X 12-Core Processor (RADV RAPHAEL_MENDOCINO)
  rhi.vulkan.selected 0 discrete_gpu AMD Radeon RX 7900 GRE (RADV NAVI31)
  rhi.vulkan.queue_families 5
  rhi.vulkan.queue_family.chosen 0 1
  rhi.vulkan.device unavailable extern-C-cannot-take-the-address-of-a-record
  rhi.vulkan.instance.destroyed 1
  rhi.status ok
rhi_vulkan: ok
```

The surface half, new in this increment, on the same host:

```
  rhi.sdl3.version 3.4.18
  rhi.sdl3.video_driver x11
  rhi.window.pixel 1280 720
  rhi.instance.extensions 2
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
  rhi.swapchain.result frames 0 of 3 format VK_FORMAT_B8G8R8A8_SRGB extent 1280x720 present_mode MAILBOX
  rhi.swapchain.created unavailable extern-C-cannot-take-the-address-of-a-record
  rhi.swapchain.render_pass unavailable extern-C-cannot-take-the-address-of-a-record pAttachments-and-pSubpasses
  rhi.swapchain.present unavailable extern-C-cannot-take-the-address-of-a-record
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

### Teardown, and the handle balance

Every path that creates a handle destroys it, in the reverse of the order it was created: the
surface, then the instance, then the window, then SDL's video subsystem - and each exit path in the
probe runs the same two functions (`teardown`, then `report_all`), so no branch can forget half of
it. The program counts what it created and what it destroyed **per handle class**, and prints the
classes and the total:

```
  rhi.surface.destroyed 1
  rhi.instance.destroyed 1
  rhi.window.destroyed 1
  rhi.handles.window created 1 destroyed 1 live 0
  rhi.handles.instance created 1 destroyed 1 live 0
  rhi.handles.surface created 1 destroyed 1 live 0
  rhi.handles.total created 3 destroyed 3 live 0
```

A disagreement in any class, or in the total, fails the run (`rhi.status failed handles-leaked`,
exit 1), so a leaked instance, a leaked surface or a leaked window cannot pass quietly. The classes
are separate rather than one count because increment 4b adds a device, a swapchain, its images and
views, and the semaphores and fences of a frame: each is a class, and a leak in one cannot hide
inside a total that happens to balance. This is the assertion, not the validation
layer: the layer is not installed on this host (the loader reports 8 layers, none of them
`VK_LAYER_KHRONOS_validation`), and enabling it from here would need
`VkInstanceCreateInfo::ppEnabledLayerNames` - another array of C strings Grail would have to build.
Where the layer *is* installed, the suite forces it on through the loader
(`VK_LOADER_LAYERS_ENABLE`/`VK_INSTANCE_LAYERS`) for a second run of the probe and fails on any
validation message, and it requires the layer's manifest to name a real ELF shared object before it
claims anything was validated, because the loader skips a broken layer without a word. On this host
that variant reports `validation skipped (no VK_LAYER_KHRONOS_validation library on this host)`, and
the probe says `rhi.vulkan.validation unavailable not-installed`.

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
their data pointer. `vkCreateShaderModule` itself needs a device, so it is not called yet; the probe
builds the create info, sets `pCode` from the bytes, and asserts that `codeSize` is the blob's own
length.

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

**No device, no swapchain, no images, no render pass, no clear, no present.** All of it waits on one
missing FFI feature, unchanged since the previous increment (the shader side does not, and is
described above):

> **There is no expression whose value is the address of an owned `extern "C"` record.**

A record *parameter* is the address of the record's fields, so a call that takes a struct by
pointer already works - that is how `VkInstanceCreateInfo`, the surface capability record and the
slot arrays cross. What Grail cannot do is *name* that address as a value, which is what a struct
that **contains pointers** needs, and every remaining call is that shape:

| Call | What it needs | Blocked by |
| --- | --- | --- |
| `vkCreateDevice` | `pQueueCreateInfos` -> array of `VkDeviceQueueCreateInfo` | address of a record |
| device extensions | `ppEnabledExtensionNames` -> array of `const char *` (`VK_KHR_swapchain`) | address of an array of strings |
| `vkCreateSwapchainKHR` | `pQueueFamilyIndices` for concurrent sharing (exclusive needs nothing) | address of an array |
| `vkCreateRenderPass` | `pAttachments` -> `VkAttachmentDescription`, `pSubpasses` -> `VkSubpassDescription`, which itself points at `VkAttachmentReference` | address of a record |
| `vkCreateFramebuffer` | `pAttachments` -> array of `VkImageView` **handles** | address of a record, *and* a handle it cannot construct |
| `vkCmdBeginRenderPass` | `pClearValues` -> `VkClearValue` | address of a record |
| `vkQueueSubmit` | `pWaitSemaphores`, `pSignalSemaphores` -> arrays of **handles** | both |
| `vkQueuePresentKHR` | `pWaitSemaphores`, `pSwapchains`, `pImageIndices` -> arrays of **handles** | both |

The last four rows are why the swapchain increment cannot be half-built: a handle cannot be
constructed in Grail at all (`cnull()` is a `CPtr`, and a record field typed `handle` is a type
mismatch), so an array *of handles* cannot even be seeded - the record-of-handles idiom in this RHI
works only when C is the writer, which is true of `vkEnumeratePhysicalDevices` and
`vkGetSwapchainImagesKHR` and false of every array in `VkSubmitInfo` and `VkPresentInfoKHR`. The
refusals are pinned as cases in `tests/native-cases.json` so the limit cannot quietly change:

| Attempt | Result | Case |
| --- | --- | --- |
| `cptr(&app)` for an extern record `app` | `cptr requires a byte sequence or view` | `ffi-reject-record-address` |
| `CreateInfo{ p_app: app }` | `generic argument shape mismatch` | — |
| `extern "C" fn f(p: &mut AppInfo)` | `an extern C out-parameter must be &mut a handle, CPtr or CMutPtr` | `ffi-reject-record-out-param` |
| `PresentInfo{ swapchain: Swapchain {} }` | `opaque handles cannot be constructed` | `ffi-reject-handle-construction` |
| `mut slot: Slot;` then `slot.instance` | `use of moved, borrowed or partially initialized value` | `ffi-reject-handle-out-slot` |

What this costs, concretely, in this increment: nothing that already works, and the whole frame.
`VkCreateSwapchainKHR`, `vkCreateImageView`, `vkCreateCommandPool`, `vkAllocateCommandBuffers`,
`vkCreateFence` and `vkCmdClearColorImage` are all reachable in shape (no pointer fields, or a null
one) *once a device exists* - and a device cannot be created, so none of them can be called either.
That is why `rhi.swapchain.result` reports zero frames presented while the configuration it reports
is a real one: the surface answered every question the swapchain would be built from.

The alternative this module refuses, again: laying the create-infos out in `u8[]` byte buffers at
hand-written offsets. It would work for the all-scalar structs and it would move `sType`, every
count and every pointer slot out of the type system's reach, where a mis-ordered field is a
plausible-looking number instead of a diagnostic - and every one of those structs has to be written
as a record anyway when the FFI form lands. The structs Grail *builds* stay records.

### The three messages that define the language work

The gap is one feature - *C needs a pointer to memory Grail owns, in and out* - and these are the
three diagnostics that define it, reproduced from the compiler on this branch. They are the
acceptance tests for whoever closes it:

1. `cptr(&record)` → `cptr requires a byte sequence or view`. There is no way to hand C the address
   of a Grail-owned record as a pointer to a struct, and every `Vk*CreateInfo` with a `pNext` chain
   or a pointer to a further struct needs exactly that.
2. `&mut Record` as an out-parameter → `an extern C out-parameter must be &mut a handle, CPtr or
   CMutPtr`. The out-parameter feature this RHI already uses covers handles and bare pointers, not
   records C fills; the surface capability records get by because a record *parameter* is already
   the address of its fields, which is not the same thing.
3. `PresentInfo { swapchain: Swapchain {} }` → `opaque handles cannot be constructed`. Arrays *of
   handles* cannot be seeded from Grail at all, and `vkQueueSubmit` and `vkQueuePresentKHR` are
   arrays of handles: semaphores, swapchains and image indices. The record-of-handles idiom this RHI
   uses works only where C is the writer.

Also absent by intent, not by limitation: the event pump, input, displays, clipboard
(`grail_window.h`'s other half), debug messengers, device memory and allocations, bindless tables,
and everything downstream of a device.

### One record, one call

A workaround this increment had to make, and the reason it is written down: passing one count
record to two *different declarations of the same symbol* (`vkEnumeratePhysicalDevices` as a count
query, then `vkEnumeratePhysicalDevices` as the single-slot form) made the program abort at exit,
inside the runtime's free path, after it had already printed everything and returned 0 from `main`.
Each call gets its own record now. The two-declaration idiom itself is fine - the probes use it for
the count-then-fill pairs - so this is about one record instance crossing two calls, not about the
shape. It was not chased further because `compiler/` is off limits while a bootstrap reseed runs.

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

1. **A bare pointer to an owned record in the FFI** - still the one feature everything else waits
   on, now with the whole list of what it unblocks in the table above and the three acceptance tests
   below it. The narrow shape: `cptr(&record)` / `cptr_mut(&mut record)` for an `extern "C"` record,
   one word, `unsafe`, with the same call-scoped borrow rules as a view (`docs/ffi.md` would
   document it beside `cptr` of a byte sequence). An array of structs is then a record of embedded
   record fields - their bytes are laid out contiguously, so the record's address *is* the array -
   and an array of `char *` is a record of `CStr` fields. For the arrays of *handles* in
   `VkSubmitInfo` and `VkPresentInfoKHR` the same form has to work over a record of handle fields,
   which is the one part that needs the feature to accept a record whose fields are handles, not
   just scalars.
2. **Device, swapchain, render pass, clear, present** - nothing new in design:
   `abundance_rhi_surface` already picks the format, present mode, extent and image count, and
   `abundance_rhi_vulkan` already picks the device and the queue family. What is new is the
   `VkDeviceQueueCreateInfo` and `VkDeviceCreateInfo` graphs, the `VK_KHR_swapchain` name array, a
   `VkRenderPassCreateInfo` with one colour attachment that loads `CLEAR` and stores to
   `PRESENT_SRC_KHR`, one framebuffer per swapchain image, one command buffer recording
   `vkCmdBeginRenderPass` + `vkCmdEndRenderPass`, one fence waited per frame, and the
   acquire/submit/present loop with a semaphore chain. The clear colour can be a `VkClearValue` in
   the record, so no shader is needed for that frame - and when one is, `vkCreateShaderModule` is
   ready: `pCode`/`codeSize` come from `abundance_rhi_shader` and the committed blobs.
3. **Pipelines, and the first frame drawn into.** `VkGraphicsPipelineCreateInfo` points at
   `pStages`, `pVertexInputState`, `pInputAssemblyState`, `pViewportState`, `pRasterizationState`,
   `pMultisampleState`, `pDepthStencilState`, `pColorBlendState` and `pDynamicState`, so it waits on
   increment 1. The vertex input it needs is already emitted as constants by the shader build
   (`vertex_input_count`, `vertex_stride`, and location/offset/format per input in
   `abundance_rhi_shader_blob`), so no reflection happens at run time; the remaining unknown is
   whether the first pipeline uses push constants or a uniform buffer, which is a design decision
   for that increment rather than a toolchain question.
