/* grail_backend_vulkan.h - what the Vulkan backend requires and provides (Linux, Windows).
 *
 * This header declares no Vulkan types on purpose: a caller that only uses grail_rhi.h must
 * not need the Vulkan headers. It states the floor the backend enforces at device creation
 * and the one place where the caller and Vulkan cannot be kept apart - surface creation,
 * which needs the instance the backend owns.
 */
#ifndef GRAIL_BACKEND_VULKAN_H
#define GRAIL_BACKEND_VULKAN_H

#include "grail_abi.h"
#include "grail_window.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Vulkan 1.3 is the floor; 1.4 features are used when present. Matches Abundance's
 * engine/core/device.hpp, which requires the same version and the same core feature set. */
#define GR_VK_MIN_API_MAJOR 1
#define GR_VK_MIN_API_MINOR 3
/* SPIR-V the offline compiler must target (-fspv-target-env=vulkan1.3). */
#define GR_VK_SPIRV_TARGET "vulkan1.3"
#define GR_VK_SHADER_PROFILE "6_6"

/* Required core features. A device without any of these is refused with
 * GR_ERROR_UNSUPPORTED and a log line naming the missing feature, never a silent
 * fallback: every one of them is load-bearing for the bindless contract.
 *
 *   descriptorIndexing         the table itself; update-after-bind + partially bound +
 *                              non-uniform indexing on sampled and storage descriptors
 *   bufferDeviceAddress        buffers reached by address through push constants
 *   dynamicRendering           gr_cmd_begin_render with no render-pass object
 *   synchronization2           gr_cmd_barrier as VkDependencyInfo
 *   timelineSemaphore          gr_queue_timeline; there are no binary semaphores
 *   scalarBlockLayout          the frame constants layout
 *   shaderInt16 / shaderInt64  16-bit and 64-bit integer types in shaders
 *   descriptorBindingVariableDescriptorCount  the unbounded arrays
 *
 * Optional, reported through gr_device_caps: meshShader + taskShader (EXT), and
 * shaderImageAtomicInt64, shaderBufferFloat32Atomics, conservativeRasterization,
 * calibrated timestamps, memory budget, subgroup size control.
 */
gr_result gr_vk_required_features(gr_mut_span_u8 out_json, size_t *out_used);
gr_result gr_vk_optional_features(gr_mut_span_u8 out_json, size_t *out_used);

/* Extensions the backend enables when the device offers them, as a NUL-separated list. */
gr_result gr_vk_device_extensions(gr_mut_span_u8 out_list, size_t *out_used);

/* ---------------------------------------------------------------------------------------
 * Surface bridge.
 *
 * SDL3 needs the instance to create a VkSurfaceKHR, and the backend owns the instance. So
 * the backend publishes both sides of that handshake. The caller never sees a VkInstance
 * unless it asks here, and it must pass the same value back unchanged.
 *
 *   gr_vk_instance(device, &instance, &physical)
 *   gr_vk_window_extensions(&count, names)      SDL_Vulkan_GetInstanceExtensions
 *   gr_vk_create_surface(device, window, &out)  SDL_Vulkan_CreateSurface
 *   gr_vk_destroy_surface(device, surface)
 *
 * The instance extension list the backend enables must be a superset of what the window
 * layer reports; device creation checks this and fails with GR_ERROR_VERSION_MISMATCH
 * rather than creating an instance SDL cannot make a surface from.
 * --------------------------------------------------------------------------------------- */
gr_result gr_vk_instance(gr_handle device, void **out_instance, void **out_physical);
gr_result gr_vk_window_extensions(uint32_t *out_count, const char *const **out_names);
gr_result gr_vk_create_surface(gr_handle device, gr_handle window, void **out_surface);
gr_result gr_vk_destroy_surface(gr_handle device, void *surface);

/* The VkDevice, for an interop path (a capture tool, a video decoder) that needs it. Borrowed. */
gr_result gr_vk_device(gr_handle device, void **out_device);

/* The queue family indices chosen, so an interop path can match them. */
typedef struct gr_vk_queue_families {
    uint32_t graphics;
    uint32_t compute;
    uint32_t transfer;
    uint32_t present;
} gr_vk_queue_families;

gr_result gr_vk_queue_families(gr_handle device, gr_vk_queue_families *out);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_BACKEND_VULKAN_H */
