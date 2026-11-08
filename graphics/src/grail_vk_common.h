/* grail_vk_common.h - the Vulkan plumbing shared by the probe and the backend.
 *
 * Both need the same four things: resolve the loader with dlopen, create an instance, decide
 * whether a physical device satisfies grail_backend_vulkan.h, and map a device's limits onto
 * gr_device_caps. Keeping them here means the probe's "this device is suitable" and the
 * backend's "this device is what I will use" cannot disagree.
 *
 * Not part of the ABI; nothing outside graphics/src/ includes it.
 */
#ifndef GRAIL_VK_COMMON_H
#define GRAIL_VK_COMMON_H

#include "grail_internal.h"
#include "../include/grail/grail_backend_vulkan.h"

#if !defined(_WIN32) && defined(__has_include)
#  include <dlfcn.h>
#  if __has_include(<vulkan/vulkan.h>)
#    define GRAIL_HAVE_VULKAN 1
#    include <vulkan/vulkan.h>
#  endif
#endif

/* Everything below names Vulkan types; a build without the headers (Windows cross builds,
 * hosts without the SDK) sees only the ABI stubs in grail_vulkan.c. */
#if defined(GRAIL_HAVE_VULKAN)

typedef struct gr_vk_loader {
    void *library;
    PFN_vkGetInstanceProcAddr gipa;
    char path[128];
} gr_vk_loader;

/* Loads libvulkan at run time. GR_ERROR_UNSUPPORTED when no loader is present, which is a
 * supported state, not a defect. GRAIL_VK_FORCE_NONE=1 pretends there is none. */
gr_result gr_vk_loader_open(gr_vk_loader *loader);
void gr_vk_loader_close(gr_vk_loader *loader);

/* Creates an instance at the highest of {requested, 1.3, 1.0} the loader accepts, with no
 * extensions: the backend is headless and there is no surface yet. `out_api` receives the
 * version actually obtained. */
/* `layers` and `extensions` are the caller's; a window needs the platform surface extensions and
 * validation needs its layer. Passing none gives the same minimal instance as before. */
gr_result gr_vk_instance_create(gr_vk_loader *loader, uint32_t requested_api,
                                const char *const *layers, uint32_t layer_count,
                                const char *const *extensions, uint32_t extension_count,
                                VkInstance *out_instance, uint32_t *out_api);

/* The bits of GR_VK_REQ_ALL a device does not provide. Zero means the backend can run.
 *
 * The instance is required, not optional: vkGetPhysicalDeviceFeatures2 is an instance-level
 * command, and vkGetInstanceProcAddr(NULL, ...) returns only the handful of global commands — a
 * NULL instance here silently reports every feature absent, which looks exactly like a device that
 * cannot run the backend. */
uint32_t gr_vk_evaluate_required(gr_vk_loader *loader, VkInstance instance,
                                VkPhysicalDevice device, const VkPhysicalDeviceProperties *props);

/* Copies a device's identity, limits and memory into the ABI's capability struct, so that what
 * gr_device_get_caps reports is exactly what the driver said. */
void gr_vk_fill_caps(gr_device_caps *caps, const VkPhysicalDeviceProperties *props,
                     const VkPhysicalDeviceMemoryProperties *memory, uint32_t required_missing,
                     uint32_t api_major, uint32_t api_minor, uint32_t subgroup_size,
                     uint32_t timestamp_valid_bits);

#endif /* GRAIL_HAVE_VULKAN */

#endif /* GRAIL_VK_COMMON_H */
