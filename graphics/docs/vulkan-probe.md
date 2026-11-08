# The Vulkan device probe

`gr_vk_probe_run()` answers one question before any backend work is worth doing: can this machine
run the Vulkan backend at all, and if not, exactly which requirement is missing. It creates an
instance, enumerates physical devices with their features, limits and queues, and destroys the
instance. It creates **no device**, allocates no memory and submits no work — every driver call it
makes is a query.

The loader is resolved with `dlopen` and every entry point through `vkGetInstanceProcAddr`, so
this file needs no link-time Vulkan: a machine with neither loader nor driver still compiles the
library and gets `GR_ERROR_UNSUPPORTED` instead of a link failure.

```
make -C graphics vk-probe
```

runs it under this host's exclusive GPU lock and refuses while the game is running. Exit status
is the machine-readable part: **0** a device satisfies the contract, **2** Vulkan present but a
required feature is missing (named in the output), **3** no loader, no ICD, or no instance — which
every other test in this repository treats as a skip.

## Captured on this host

```
grail-vk-probe
  loader      libvulkan.so.1, Vulkan 1.4.363
  instance    Vulkan 1.3
  devices     2
  device      AMD Radeon RX 7900 GRE (RADV NAVI31)
  type        discrete
  API         1.4.354  vendor 0x1002 device 0x744c  driver 0x06802006
  driver      radv (Mesa 26.2.6-arch1.1)
  queues      5 families: graphics 0, compute 0, transfer 0
  memory      16368 MiB device-local
  limits      push constants 256, image 2D 16384, workgroup 1024
              per stage: 8388606 sampled, 8388606 samplers, 8388606 storage buffers; per set: 8388606 sampled
              subgroup 64, timestamp period 10.0 ns
  required    all present
```

16 assertions pass alongside it (`make vk-probe` runs `test_vk_probe` too): loader found, at least
one device, a plausible API version, and limits that are real values rather than zeroed fields —
a probe that silently reported a device with no push constants would be worse than one that
failed.

**Conclusion: this host satisfies `grail_backend_vulkan.h` completely.** Vulkan 1.3 is the floor
and RADV reports 1.4.354; the 256-byte push-constant limit is twice the 128 the contract requires;
the descriptor limits are effectively unbounded, which is what the bindless table needs.

## What each required bit gates

Every bit is load-bearing for `grail_bindless.h` or `grail_rhi.h`; the probe reports the missing
ones by name rather than a single "unsupported", because "this device cannot run the renderer" is
useless without knowing which promise broke.

| bit | without it |
| --- | --- |
| `descriptorIndexing` | no bindless table at all |
| `runtimeDescriptorArray` | no unbounded arrays — every table would need a fixed size |
| `descriptorBindingSampledImageUpdateAfterBind` | a descriptor rewrite per draw, and a stall |
| `descriptorBindingPartiallyBound` | every one of 65536 slots would have to be written |
| `descriptorBindingVariableDescriptorCount` | the table could not shrink to what a frame actually uses |
| `shaderSampledImageArrayNonUniformIndexing` | an index that varies within a wave would be undefined |
| `bufferDeviceAddress` | no buffer reached by address through push constants |
| `dynamicRendering` | a render-pass object per pass, which D3D12 and Metal do not have |
| `synchronization2` | `gr_cmd_barrier` could not map to a dependency info |
| `timelineSemaphore` | no queue timelines, and the public interface has no binary semaphores |
| `scalarBlockLayout` | `gr_frame_constants` offsets would be wrong |
| `shaderInt16` / `shaderInt64` | packed vertex data and 64-bit ids in shaders |

## Limits worth noting

`maxPushConstantsSize` is 256 here, and the contract uses 128 — the Vulkan minimum every
conformant device guarantees and exactly what D3D12 root constants hold. Taking 256 would work on
this device and drop others, so the contract does not.

The per-stage descriptor limits report 8388606, effectively unbounded. The reference bindless
capacities (`grail_bindless.h`: 65536 sampled images, 16384 storage images, 256 samplers, 65536
storage buffers) are therefore device-supported as written, and a device reporting fewer is
refused rather than silently given a smaller table.
