# The Grail RHI, as far as it goes today

Grail has a graphics RHI it can call in-process: `extern "C"` declarations against the system
SDL3 and Vulkan loaders, in `abundance/src/`. This page states exactly what that covers, what it
deliberately does not, and what the next increments are. It is the third route into the same
graphics contract (`graphics/include/grail/`), and the three do not overlap:

| Route | Caller | Reaches the GPU by | Today |
| --- | --- | --- | --- |
| In-process FFI (`abundance/src/rhi_sdl3.grl`, `rhi_vulkan.grl`) | any Grail program linked with `-lSDL3` / `-lvulkan` | calling `SDL_*` and `vk*` symbols directly | window created and sized; a real `VkInstance` created and destroyed; physical devices enumerated, named, typed and selected; queue families read |
| Wire framing (`abundance/src/rhi_bridge.grl`) | a static Grail ELF with no libc | packing `gr_wire_packet` and writing it to a socket | framing ported and parity-tested; the host side is still to come |
| The C ABI backend (`graphics/`, `GR_BACKEND_NULL`) | C/C++ hosts | the `grail_rhi.h` contract | the contract, a null backend, and a Vulkan device probe in C |

The FFI route is the one that makes Grail the language of the renderer rather than a client of
one. It is also the only route where the *language* is the thing being tested: every limitation
below is a statement about Grail's FFI, not about SDL3 or Vulkan.

The two halves of the in-process route are two programs, not one, because a Vulkan instance and a
physical device need no display server: `abundance/tests/rhi_vulkan_probe.grl` runs for real on a
headless machine while `abundance/tests/rhi_device_probe.grl` skips there.

## What is real

Both probes run from the suite and print this machine rather than a fixture:

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
  rhi.vulkan.extension VK_KHR_device_group_creation 1
  ...
  rhi.vulkan.layers 8
  rhi.vulkan.layer VK_LAYER_VALVE_steam_overlay_32 4206799
  ...
  rhi.vulkan.instance.created 1
  rhi.vulkan.instance.api 1.0.0
  rhi.vulkan.instance.app_info unavailable extern-C-cannot-take-the-address-of-a-record
  rhi.vulkan.devices 2
  rhi.vulkan.device 0 discrete_gpu api 1.4.354 AMD Radeon RX 7900 GRE (RADV NAVI31)
  rhi.vulkan.device 1 integrated_gpu api 1.4.354 AMD Ryzen 9 7900X 12-Core Processor (RADV RAPHAEL_MENDOCINO)
  rhi.vulkan.selected 0 discrete_gpu AMD Radeon RX 7900 GRE (RADV NAVI31)
  rhi.vulkan.selected_by_name AMD 0
  rhi.vulkan.queue_families 5
  rhi.vulkan.queue_family 0 1 graphics|compute|transfer|sparse
  rhi.vulkan.queue_family 1 4 compute|transfer|sparse
  rhi.vulkan.queue_family 2 1 video_decode
  rhi.vulkan.queue_family 3 1 video_encode
  rhi.vulkan.queue_family 4 1 sparse
  rhi.vulkan.queue_family.chosen 0 1
  rhi.vulkan.device unavailable extern-C-cannot-take-the-address-of-a-record
  rhi.vulkan.instance.destroyed 1
  rhi.status ok
rhi_vulkan: ok
```

Every value above is returned by a call: nothing is defaulted, guessed or filled in. The two
`unavailable` lines are the part of this increment that did not land: the FFI can express what they
need now, and `abundance/src/rhi_vulkan.grl` has not been ported onto it - see "What is not there,
and why" below.

The window half (`rhi_sdl3.grl`), unchanged from the previous increment:

- `SDL_GetVersion`, `SDL_Init(SDL_INIT_VIDEO)`, `SDL_GetCurrentVideoDriver` — the video subsystem
  starts for real and names the driver that served it (`x11`, `wayland`, or `dummy`).
- `SDL_CreateWindow` with `SDL_WINDOW_RESIZABLE | SDL_WINDOW_VULKAN | SDL_WINDOW_HIDDEN` — a real
  window, hidden so a probe never takes focus.
- `SDL_GetWindowSize` / `SDL_GetWindowSizeInPixels` — two `int *` out-parameters, declared as
  `extern "C" record IntOut { value: i32 }`: a record parameter is the address of the record's own
  fields, so C's write is visible in `value` afterwards.
- `SDL_GetError` — read back through `strlen` + `memcpy`, because a `CStr` can be handed to C but
  Grail cannot index one. The suite reports SDL's own diagnostic text, not a paraphrase.
- `SDL_DestroyWindow`, `SDL_Quit` — the explicit teardown.

The Vulkan half (`rhi_vulkan.grl`) is new in this increment:

- `vkEnumerateInstanceVersion`, `vkEnumerateInstanceExtensionProperties`,
  `vkEnumerateInstanceLayerProperties` — the loader's API version, and the extension and layer
  lists. `VkExtensionProperties` (260 bytes) and `VkLayerProperties` (520 bytes) contain fixed-size
  `char` arrays, which an `extern "C"` record cannot express, so the probe asks the loader for a
  count, allocates a byte buffer, lets C fill it, and decodes the names and versions at the C
  offsets.
- `vkCreateInstance` — the shape this increment exists to use. The FFI now has an out-parameter
  form (`docs/ffi.md`, "Out-parameters"): a declaration reads `slot: &mut Instance`, the call site
  passes `&mut instance`, and C writes the new handle into the binding's own word.
  `VkInstanceCreateInfo` is an `extern "C" record` with the C layout — 64 bytes, fields at 0, 8,
  16, 24, 32, 40, 48 and 56 — and `vkDestroyInstance` is called on every path that created one,
  including the paths where a later call failed, because a handle is never freed by Grail and the
  pair is the program's to balance.
- `vkEnumeratePhysicalDevices` — three declarations of one symbol, because Grail passes the shape
  the declaration names: a count query (a null data pointer), a single handle slot (`&mut
  PhysicalDevice`), and a fixed-capacity record of handle fields (`PhysicalDeviceSlots`, eight
  slots, `device_capacity`). The record is the array C writes into: a record *parameter* is the
  address of the record's fields, and each field is then a typed handle. A record cannot be built
  without a value in every field and a handle cannot be constructed, so the array is anchored on
  the handle the single-slot call returned; C overwrites the slots it writes, and only indices
  below the count it reports are ever read. The probe cross-checks the two forms — the slot call
  and slot 0 of the array call must be the same handle — and fails the run if they disagree.
- `vkGetPhysicalDeviceProperties` — 824 bytes, no record can express it (`char deviceName[256]`
  sits at offset 20, between the integer fields and the limits). Decoded at apiVersion 0,
  deviceType 16, deviceName 20. On this machine the numbers agree with `graphics/`'s own C probe
  (`make -C graphics vk-probe`), which reports the same loader, the same 2 devices and the same best
  device — `AMD Radeon RX 7900 GRE (RADV NAVI31)`, discrete, API 1.4.354 — and Grail also names the
  second device, the integrated `AMD Ryzen 9 7900X 12-Core Processor (RADV RAPHAEL_MENDOCINO)`,
  which the C probe only counts.
- Selection: every device's type is ranked (discrete first, then integrated, virtual, CPU, and
  finally an unclassified device), an optional name filter is applied as a substring test, and ties
  keep the loader's order. The probe prints the device it picked and why, then repeats the query
  with a name taken from the chosen device's own name (`AMD` here), so the filter path is
  exercised with a value this machine reported rather than one the test assumed.
- `vkGetPhysicalDeviceQueueFamilyProperties` — 24 bytes per family (queueFlags 0, queueCount 4),
  two calls (count, then the buffer). The probe prints each family's queue count and flag names and
  the first family that can run graphics work: family 0, one queue, `graphics|compute|transfer|sparse`
  — the same family `graphics/`'s C probe reports as the graphics family.

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
| a record of `handle` fields | an array of handles: C fills the slots through `&mut`, or the program seeds them from handles it already holds |

With those, `VkInstanceCreateInfo::pApplicationInfo` is a field assignment, `VkApplicationInfo` itself
is a record of scalars and `CStr` fields, `pQueueCreateInfos` is a record of embedded
`VkDeviceQueueCreateInfo` fields, `ppEnabledExtensionNames` is a record of `CStr` fields, and
`VkDeviceQueueCreateInfo`'s `pQueuePriorities` is `cptr` of a float array. An `extern "C"` record
declared without an initializer is `sizeof(struct)` zeroed bytes, so an array of handles can be
created without constructing one; it has no *value* until a call or an assignment wrote it.

What the probe prints has not caught up: `rhi.vulkan.instance.app_info` and `rhi.vulkan.device` still
read `unavailable`, because `abundance/src/rhi_vulkan.grl` has not been ported - it calls
`vkCreateInstance` with `pApplicationInfo` null, does not declare `vkCreateDevice`, and its header
comment still states the old limit. That is a port to do, not a language feature to add.

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

What that costs, concretely:

- **`VkApplicationInfo` is not passed yet.** `vkCreateInstance` is called with `pApplicationInfo`
  null, which is legal - the specification then fixes the instance at API version 1.0 - so
  `rhi.vulkan.instance.api` reads `1.0.0` while the loader is 1.4.363 and the driver supports
  1.4.354. Every call the probe makes is core 1.0, so nothing else is affected; the port is what
  changes the number.
- **`vkCreateDevice` is not declared yet.** `queueCreateInfoCount` must be at least one, so
  `pQueueCreateInfos` cannot be avoided by passing null the way `pApplicationInfo` can - it is the
  first thing the port needs.
- **No instance extension is enabled yet**, because the module has no `ppEnabledExtensionNames` to
  point at. With the forms above that is a record of `CStr` fields and one call.

The alternative this module refuses: laying the create-infos out in `u8[]` byte buffers at
hard-coded offsets, which is what it already does for structs C *writes* (extensions, layers,
properties, queue families - none of which a record can express). Doing it for structs Grail
*builds* would put `sType`, the counts and the pointer slots outside the type system's reach, and the
pointer slots could not be written into a `u8[]` at all. A mis-ordered create-info field has to be a
compile error or a failing check, never a plausible-looking number, so the structs Grail *builds*
stay records.

Also absent by intent, not by limitation: the event pump, input, displays, clipboard
(`grail_window.h`'s other half), debug messengers, device memory and allocations, bindless tables,
and everything downstream of a device.

## Linking, skipping and the GPU lock

- `lib "SDL3"` and `lib "vulkan"` are the linker inputs the compiler emits as `// grail-link:
  SDL3` / `// grail-link: vulkan`; `tools/native.mjs` turns a bare name into `-lNAME` and resolves
  it against `/usr/lib` and `/usr/lib64`. No SDK, no vendored copy, no build system of its own.
- Each probe names only the modules it needs, so the link is one library per probe: the window
  probe links `-lSDL3` and the Vulkan probe links `-lvulkan`. A machine with no display server
  therefore still runs the Vulkan probe.
- Those two modules are the only ones in `abundance/src` that name a system library. The port
  parity suite keeps them out of its link (`ffiModules` in `tools/abundance-test.mjs`), so the ports
  still build on a machine with neither loader.
- Being absent is said four different ways: no `libSDL3.so`/`libvulkan.so` to link and that probe is
  skipped before it compiles; no display server and `SDL_Init` fails, so SDL's own message is
  printed and the window probe ends with `rhi.status skipped platform-or-driver-missing`; a loader
  with no ICD answers `vkCreateInstance` with `VK_ERROR_INCOMPATIBLE_DRIVER` and the Vulkan probe
  prints that result by name and skips; and a loader that enumerates no physical device prints
  `rhi.vulkan.devices 0` and skips. Exit status is 0 for `ok` and `skipped` and 1 only for `failed`,
  a call that contradicted its own contract — the one thing that should ever fail a headless
  machine's run.
- Enumerating a driver is not free, and this host serialises every program that talks to one, so
  each probe runs under the same exclusive lock as `graphics/Makefile`: `flock` on
  `/run/user/<uid>/ab-engine-gpu.lock`. Without `flock` or a lock directory a probe runs unlocked
  and the suite says so; when the lock stays busy for the whole ten-minute wait — a game is running
  — the probe is skipped with that reason rather than failed, because no probe ran to contradict
  itself.
- A Vulkan window needs a video driver that can back one, and SDL's `dummy` driver cannot, so a
  headless machine skips the window probe; `xvfb-run -a bun tools/abundance-test.mjs` supplies a
  display and the window path then reports `video_driver x11`. The Vulkan probe needs no such
  wrapper: it creates its instance and reads its devices under X-less conditions too.

## The next three increments

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

The order is not arbitrary: (1) is a language change with no graphics in it, (2) is the first
frame, (3) is the first frame that can be drawn into. Anything built before (1) would have to be
expressed in C, which is the boundary this increment is moving.
