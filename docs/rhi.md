# The Grail RHI, as far as it goes today

Grail now has a graphics RHI it can call in-process: `extern "C"` declarations against the
system SDL3 and Vulkan loaders, in `abundance/src/`. This page states exactly what that covers,
what it deliberately does not, and what the next increments are. It is the third route into the
same graphics contract (`graphics/include/grail/`), and the three do not overlap:

| Route | Caller | Reaches the GPU by | Today |
| --- | --- | --- | --- |
| In-process FFI (`abundance/src/rhi_sdl3.grl`, `rhi_vulkan.grl`) | any Grail program linked with `-lSDL3` / `-lvulkan` | calling `SDL_*` and `vk*` symbols directly | window created and sized; Vulkan loader, instance extensions and layers enumerated |
| Wire framing (`abundance/src/rhi_bridge.grl`) | a static Grail ELF with no libc | packing `gr_wire_packet` and writing it to a socket | framing ported and parity-tested; the host side is still to come |
| The C ABI backend (`graphics/`, `GR_BACKEND_NULL`) | C/C++ hosts | the `grail_rhi.h` contract | the contract, a null backend, and a Vulkan device probe in C |

The FFI route is the one that makes Grail the language of the renderer rather than a client of
one. It is also the only route where the *language* is the thing being tested: every limitation
below is a statement about Grail's FFI, not about SDL3 or Vulkan.

## What is real

`abundance/tests/rhi_device_probe.grl` is the program that proves the bindings, and its output is
this machine rather than a fixture. Run it through the suite:

```
$ bun tools/abundance-test.mjs
...
  rhi.sdl3.version 3.4.18
  rhi.sdl3.video_driver x11
  rhi.window.requested 1280 720 flags 268435496
  rhi.window.logical 1280 720
  rhi.window.pixel 1280 720
  rhi.window.destroyed 1
  rhi.vulkan.loader 1.4.363
  rhi.vulkan.extensions 27
  rhi.vulkan.extension VK_KHR_surface 25
  ...
  rhi.vulkan.layers 8
  rhi.vulkan.layer VK_LAYER_MESA_device_select 4210991
  ...
  rhi.vulkan.instance unavailable extern-C-cannot-take-a-handle-out-parameter
  rhi.vulkan.devices unavailable instance-required
  rhi.status ok
rhi_device: ok
```

The calls behind those lines, in order:

- `SDL_GetVersion`, `SDL_Init(SDL_INIT_VIDEO)`, `SDL_GetCurrentVideoDriver` — the video subsystem
  starts for real and names the driver that served it (`x11`, `wayland`, or `dummy`).
- `SDL_CreateWindow` with `SDL_WINDOW_RESIZABLE | SDL_WINDOW_VULKAN | SDL_WINDOW_HIDDEN` — a real
  window, hidden so a probe never takes focus. The handle is an opaque `Window`: it comes back
  from C, is passed to C, and Grail never inspects or frees it.
- `SDL_GetWindowSize` / `SDL_GetWindowSizeInPixels` — two `int *` out-parameters, declared as
  `extern "C" record IntOut { value: i32 }`. A record parameter is the address of the record's
  own fields, so C's write is visible in `value` afterwards; the port prints logical and pixel
  size separately because `grail_window.h` requires the distinction on a HiDPI display.
- `SDL_GetError` — read back through `strlen` + `memcpy`, because a `CStr` can be handed to C but
  Grail cannot index one. The suite reports SDL's own diagnostic text, not a paraphrase.
- `SDL_DestroyWindow`, `SDL_Quit` — the explicit teardown. Handles are not linear, so create and
  destroy are a pair the program balances; a leaked window is an explicit leak.
- `vkEnumerateInstanceVersion`, `vkEnumerateInstanceExtensionProperties`,
  `vkEnumerateInstanceLayerProperties` — real loader calls. `VkExtensionProperties` (260 bytes)
  and `VkLayerProperties` (520 bytes) contain fixed-size `char` arrays, which an `extern "C"`
  record cannot express, so the probe asks the loader for a count, allocates a byte buffer, lets
  C fill it, and decodes the names and versions at the C offsets (`rhi_vulkan.grl`).

Every line above is a value some call returned; nothing is defaulted, guessed or filled in. In
particular there is no device line, because no call in this increment can produce one.

## What is not there, and why

**No `VkInstance`, so no physical devices, no device name or type, no surface, no swapchain.**
Vulkan creates every object through an out-parameter:

```c
VkResult vkCreateInstance(const VkInstanceCreateInfo *pCreateInfo,
                          const VkAllocationCallbacks *pAllocator,
                          VkInstance *pInstance);
```

Grail's FFI has no out-parameter form that yields a *handle* or a *pointer*. `handle H` and
`CPtr` values enter Grail only as a foreign call's result (`docs/ffi.md`, "Opaque handles"); a
record parameter passes the address of the record's fields, and a `CMutPtr` out-parameter is a
write-only byte sink. The obvious spelling of the slot does not compile, and both refusals are
pinned in `tests/native-cases.json` so the limit cannot quietly change:

| Attempt | Result | Case |
| --- | --- | --- |
| `mut slot: Slot;` then `slot.instance` | `use of moved, borrowed or partially initialized value` | `ffi-reject-handle-out-slot` |
| `Slot{instance: cnull()}` to seed it | `generic argument shape mismatch` | `ffi-reject-handle-null-seed` |
| `File{}` to construct one | `opaque handles cannot be constructed` | `ffi-reject-handle-construction` |

The standard library hits the same wall and answers it on the C side: `runtime/abi/ffi/grail_ffi_shim.c`
stashes the handle it just created in a static and `grail_ffi_file_handle()` *returns* it, so
`lib/sys/grail_ffi.grl` can bind a real `open(2)`. That idiom is a C helper in the port, which is
exactly what an "RHI in Grail" increment is trying not to add, so this increment stops at the
loader instead. The probe says so on its own output line rather than printing a plausible device.

Also absent by intent, not by limitation: the event pump, input, displays, clipboard
(`grail_window.h`'s other half), instance extensions being *enabled*, debug messengers, and
everything downstream of a device — queues, memory, bindless tables, pipelines, render targets.

## Linking, skipping and the GPU lock

- `lib "SDL3"` and `lib "vulkan"` are the linker inputs the compiler emits as
  `// grail-link: SDL3` / `// grail-link: vulkan`; `tools/native.mjs` turns a bare name into
  `-lNAME` and resolves it against `/usr/lib` and `/usr/lib64`. No SDK, no vendored copy, no
  build system of its own.
- Those two modules are the only ones in `abundance/src` that name a system library. The port
  parity suite keeps them out of its link (`ffiModules` in `tools/abundance-test.mjs`), so the
  ports still build on a machine with neither loader, and only the probe links them.
- Being absent is said four different ways: no `libSDL3.so`/`libvulkan.so` to link and the probe
  is skipped before it compiles; no display server and `SDL_Init` fails, so SDL's own message is
  printed and the probe ends with `rhi.status skipped platform-or-driver-missing`; a loader that
  will not answer `vkEnumerateInstanceVersion` prints its `VkResult` by name; and a busy GPU lock
  skips the probe with the lock path. Exit status is 0 for `ok` and `skipped` and 1 only for
  `failed`, a call that contradicted its own contract — the one thing that should ever fail a
  headless machine's run.
- The instance extension and layer lists come from the loader itself, so they are reported with or
  without an ICD installed. Nothing in this increment claims a device exists: the only two lines
  about devices say why there is none.
- Enumerating a driver is not free, and this host serialises every program that talks to one, so
  the probe runs under the same exclusive lock as `graphics/Makefile`: `flock` on
  `/run/user/<uid>/ab-engine-gpu.lock`. Without `flock` or a lock directory it runs unlocked and
  the suite says so; when the lock stays busy for the whole ten-minute wait — a game is running —
  the probe is skipped with that reason rather than failed, because no probe ran to contradict
  itself.
- A Vulkan window needs a video driver that can back one, and SDL's `dummy` driver cannot: it
  answers `Vulkan support is either not configured in SDL or not available in current SDL video
  driver (dummy)`, which the probe prints before ending with `skipped`. A headless machine
  therefore needs a display server it can reach — `xvfb-run -a bun tools/abundance-test.mjs`
  supplies one, and the probe then reports the whole window path with `video_driver x11` — or it
  skips. The driver name is always printed, so a dummy window is never mistaken for a real one.

## The next three increments

1. **An out-parameter form for handles and pointers in the FFI** — the one thing everything else
   waits on. The narrow shape that unlocks Vulkan: a `handle`/`CPtr` local that C may write
   through, or `&mut` of a record whose fields C fills, plus a defined null token to seed it
   (`cnull()` is the natural spelling). With it, `vkCreateInstance`, `vkEnumeratePhysicalDevices`
   and `vkGetPhysicalDeviceProperties` complete in this module, and the probe's device-name and
   device-type lines stop being "unavailable", and the property offsets are already known from the
   same header check (VkPhysicalDeviceProperties is 824 bytes: apiVersion 0, deviceType 16,
   deviceName 20), with `graphics/docs/vulkan-probe.md` showing the shape a full report takes.
2. **A `VkSurfaceKHR` and a swapchain from the window this increment already creates**:
   `SDL_Vulkan_CreateSurface` from the `Window` handle, `VK_KHR_surface` + the platform extension
   the loader reports (`VK_KHR_xlib_surface`, `VK_KHR_wayland_surface`), surface capabilities and
   formats, and a present loop that at minimum clears the image. Still no pipelines — this is the
   frame that proves the window and the device meet.
3. **The device and its queues**: `vkCreateDevice` with the feature set
   `grail_backend_vulkan.h` requires (dynamic rendering, synchronization2, timeline semaphore,
   buffer device address, scalar block layout, descriptor indexing), queue families, and
   `gr_device_caps`-shaped reporting, cross-checked against `graphics/`'s own
   `gr_vk_probe_run()` so the Grail and C sides agree on the same machine.

The order is not arbitrary: (1) is a language change with no graphics in it, (2) is the first
frame, (3) is the first frame that can be drawn into. Anything built before (1) would have to be
expressed in C, which is the boundary this increment is moving.
