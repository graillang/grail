/* grail_vk_probe.c - can this machine run the Vulkan backend, and if not, what is missing.
 *
 * The loader is resolved with dlopen and every entry point with vkGetInstanceProcAddr, so this
 * file needs no link-time Vulkan and compiles on a machine that has neither the loader nor a
 * driver. It creates an instance, enumerates physical devices and their features and limits, and
 * destroys the instance. It creates no device, allocates no memory and submits nothing: the only
 * driver calls it makes are queries.
 *
 * The feature list is not an opinion about what would be nice. Every bit in GR_VK_REQ_ALL is
 * load-bearing for the bindless contract in grail_bindless.h or for the command model in
 * grail_rhi.h, and a device missing one cannot run the renderer at all — which is why the probe
 * reports the exact missing bits rather than a single "unsupported".
 */
#include "grail_vk_common.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* dlopen and the Vulkan headers are both optional: a build machine may have either, both or
 * neither, and the library must still compile. */
#if !defined(_WIN32) && defined(__has_include)
#  include <dlfcn.h>
#  if __has_include(<vulkan/vulkan.h>)
#    define GRAIL_HAVE_VULKAN 1
#    include <vulkan/vulkan.h>
#  endif
#endif

const char *gr_vk_required_name(uint32_t bit)
{
    switch (bit) {
    case GR_VK_REQ_DESCRIPTOR_INDEXING: return "descriptorIndexing";
    case GR_VK_REQ_RUNTIME_DESCRIPTOR_ARRAY: return "runtimeDescriptorArray";
    case GR_VK_REQ_UPDATE_AFTER_BIND: return "descriptorBindingSampledImageUpdateAfterBind";
    case GR_VK_REQ_PARTIALLY_BOUND: return "descriptorBindingPartiallyBound";
    case GR_VK_REQ_VARIABLE_DESCRIPTOR_COUNT: return "descriptorBindingVariableDescriptorCount";
    case GR_VK_REQ_NON_UNIFORM_INDEXING: return "shaderSampledImageArrayNonUniformIndexing";
    case GR_VK_REQ_BUFFER_DEVICE_ADDRESS: return "bufferDeviceAddress";
    case GR_VK_REQ_DYNAMIC_RENDERING: return "dynamicRendering";
    case GR_VK_REQ_SYNCHRONIZATION2: return "synchronization2";
    case GR_VK_REQ_TIMELINE_SEMAPHORE: return "timelineSemaphore";
    case GR_VK_REQ_SCALAR_BLOCK_LAYOUT: return "scalarBlockLayout";
    case GR_VK_REQ_SHADER_INT16: return "shaderInt16";
    case GR_VK_REQ_SHADER_INT64: return "shaderInt64";
    default: return "unknown";
    }
}

#if defined(GRAIL_HAVE_VULKAN)

#define GR_VK_LOAD(loader, instance, name) ((PFN_##name)(loader).gipa((instance), #name))

/* Device-local heap size. Lives here rather than in the shared module because only the probe
 * reports it; gr_vk_fill_caps() computes the same value for the ABI. */
static uint64_t device_local_bytes(const VkPhysicalDeviceMemoryProperties *memory)
{
    uint64_t best = 0;
    uint32_t i;
    for (i = 0; i < memory->memoryHeapCount; ++i)
        if ((memory->memoryHeaps[i].flags & VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) &&
            memory->memoryHeaps[i].size > best)
            best = memory->memoryHeaps[i].size;
    return best;
}

#endif /* GRAIL_HAVE_VULKAN */

gr_result gr_vk_probe_run(gr_vk_probe_report *out)
{
    if (!out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (out->head.size != 0 && out->head.size < sizeof(gr_vk_probe_report))
        return GR_ERROR_VERSION_MISMATCH;
    memset(out, 0, sizeof(*out));
    out->head.size = (uint32_t)sizeof(*out);
    out->graphics_family = ~0u;
    out->compute_family = ~0u;
    out->transfer_family = ~0u;

#if !defined(GRAIL_HAVE_VULKAN)
    /* Built without the Vulkan headers: no loader can be used, and the reason is specific. */
    snprintf(out->loader_path, sizeof(out->loader_path), "%s", "not built against Vulkan headers");
    return GR_ERROR_UNSUPPORTED;
#else
    {
        gr_vk_loader loader;
        PFN_vkEnumerateInstanceVersion enumerate_version;
        PFN_vkDestroyInstance destroy_instance;
        PFN_vkEnumeratePhysicalDevices enumerate_devices;
        PFN_vkGetPhysicalDeviceProperties get_properties;
        PFN_vkGetPhysicalDeviceProperties2 get_properties2;
        PFN_vkGetPhysicalDeviceFeatures2 get_features2;
        PFN_vkGetPhysicalDeviceQueueFamilyProperties get_queues;
        PFN_vkGetPhysicalDeviceMemoryProperties get_memory;
        VkInstance instance = VK_NULL_HANDLE;
        VkResult result;
        uint32_t loader_version = 0;
        uint32_t device_count = 0;
        uint32_t i;

        if (gr_vk_loader_open(&loader) != GR_OK) {
            snprintf(out->loader_path, sizeof(out->loader_path), "%s", loader.path);
            return GR_ERROR_UNSUPPORTED;
        }
        out->loader_found = 1;
        snprintf(out->loader_path, sizeof(out->loader_path), "%s", loader.path);

        enumerate_version = (PFN_vkEnumerateInstanceVersion)loader.gipa(NULL, "vkEnumerateInstanceVersion");
        if (enumerate_version)
            enumerate_version(&loader_version);
        else
            loader_version = VK_API_VERSION_1_0; /* a loader that cannot answer is a 1.0 loader */
        out->loader_api_major = VK_API_VERSION_MAJOR(loader_version);
        out->loader_api_minor = VK_API_VERSION_MINOR(loader_version);
        out->loader_api_patch = VK_API_VERSION_PATCH(loader_version);

        {
            uint32_t obtained = 0;
            if (gr_vk_instance_create(&loader, VK_API_VERSION_1_3, NULL, 0, NULL, 0, &instance,
                                      &obtained) != GR_OK) {
                gr_vk_loader_close(&loader);
                return GR_ERROR_UNSUPPORTED;
            }
            out->instance_api_major = VK_API_VERSION_MAJOR(obtained);
            out->instance_api_minor = VK_API_VERSION_MINOR(obtained);
        }

        enumerate_devices = GR_VK_LOAD(loader, instance, vkEnumeratePhysicalDevices);
        get_properties = GR_VK_LOAD(loader, instance, vkGetPhysicalDeviceProperties);
        get_properties2 = GR_VK_LOAD(loader, instance, vkGetPhysicalDeviceProperties2);
        get_features2 = GR_VK_LOAD(loader, instance, vkGetPhysicalDeviceFeatures2);
        get_queues = GR_VK_LOAD(loader, instance, vkGetPhysicalDeviceQueueFamilyProperties);
        get_memory = GR_VK_LOAD(loader, instance, vkGetPhysicalDeviceMemoryProperties);
        destroy_instance = GR_VK_LOAD(loader, instance, vkDestroyInstance);

        result = enumerate_devices ? enumerate_devices(instance, &device_count, NULL)
                                   : VK_ERROR_INITIALIZATION_FAILED;
        if (result == VK_SUCCESS && device_count > 0) {
            VkPhysicalDevice devices[16];
            uint32_t want = device_count > 16u ? 16u : device_count;
            device_count = want;
            if (enumerate_devices(instance, &device_count, devices) != VK_SUCCESS)
                device_count = 0;

            out->device_count = device_count;
            /* Prefer a device that satisfies the contract; fall back to the first so a failure
             * report still describes real hardware. */
            for (i = 0; i < device_count; ++i) {
                VkPhysicalDeviceProperties properties;
                VkPhysicalDeviceVulkan12Features f12;
                VkPhysicalDeviceVulkan13Features f13;
                VkPhysicalDeviceFeatures2 features;
                VkPhysicalDeviceDriverProperties driver;
                VkPhysicalDeviceSubgroupProperties subgroup;
                VkPhysicalDeviceProperties2 properties2;
                uint32_t missing;
                uint32_t maj, min;

                get_properties(devices[i], &properties);
                maj = VK_API_VERSION_MAJOR(properties.apiVersion);
                min = VK_API_VERSION_MINOR(properties.apiVersion);

                memset(&f12, 0, sizeof(f12));
                memset(&f13, 0, sizeof(f13));
                memset(&features, 0, sizeof(features));
                f12.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
                f12.pNext = &f13;
                f13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
                features.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
                features.pNext = &f12;
                (void)features;
                (void)f12;
                (void)f13;
                (void)get_features2;
                missing = gr_vk_evaluate_required(&loader, instance, devices[i], &properties);

                if (out->device_name[0] && missing >= out->required_missing)
                    continue; /* a better device was already chosen */

                out->required_missing = missing;
                snprintf(out->device_name, sizeof(out->device_name), "%s", properties.deviceName);
                out->vendor_id = properties.vendorID;
                out->device_id = properties.deviceID;
                out->device_type = (uint32_t)properties.deviceType;
                out->discrete_gpu = properties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
                out->api_major = maj;
                out->api_minor = min;
                out->api_patch = VK_API_VERSION_PATCH(properties.apiVersion);
                out->driver_version = properties.driverVersion;
                out->max_push_constants = properties.limits.maxPushConstantsSize;
                out->max_image_dimension_2d = properties.limits.maxImageDimension2D;
                out->max_compute_workgroup_invocations = properties.limits.maxComputeWorkGroupInvocations;
                out->max_per_stage_sampled_images = properties.limits.maxPerStageDescriptorSampledImages;
                out->max_per_stage_samplers = properties.limits.maxPerStageDescriptorSamplers;
                out->max_per_stage_storage_buffers = properties.limits.maxPerStageDescriptorStorageBuffers;
                out->max_descriptor_set_sampled_images =
                    properties.limits.maxDescriptorSetSampledImages;
                
                out->timestamp_period_ns = properties.limits.timestampPeriod;

                /* Subgroup size is 1.1+, driver identity is 1.2+: query what the device's own
                 * version allows and leave the rest zero rather than guessing. */
                memset(&driver, 0, sizeof(driver));
                memset(&subgroup, 0, sizeof(subgroup));
                memset(&properties2, 0, sizeof(properties2));
                if (get_properties2 && (maj > 1u || (maj == 1u && min >= 1u))) {
                    subgroup.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES;
                    properties2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
                    properties2.pNext = &subgroup;
                    if (maj > 1u || min >= 2u) {
                        driver.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES;
                        subgroup.pNext = &driver;
                    }
                    get_properties2(devices[i], &properties2);
                    out->subgroup_size = subgroup.subgroupSize;
                    if (driver.driverName[0]) {
                        snprintf(out->driver_name, sizeof(out->driver_name), "%s", driver.driverName);
                        snprintf(out->driver_info, sizeof(out->driver_info), "%s", driver.driverInfo);
                    }
                }

                if (get_queues && get_memory) {
                    VkQueueFamilyProperties queues[16];
                    uint32_t queue_count = 16;
                    VkPhysicalDeviceMemoryProperties memory;
                    uint32_t q;
                    get_queues(devices[i], &queue_count, queues);
                    if (queue_count > 16u) queue_count = 16u;
                    out->queue_family_count = queue_count;
                    for (q = 0; q < queue_count; ++q) {
                        if ((queues[q].queueFlags & VK_QUEUE_GRAPHICS_BIT) &&
                            out->graphics_family == ~0u)
                            out->graphics_family = q;
                        if ((queues[q].queueFlags & VK_QUEUE_COMPUTE_BIT) &&
                            out->compute_family == ~0u)
                            out->compute_family = q;
                        if ((queues[q].queueFlags & VK_QUEUE_TRANSFER_BIT) &&
                            out->transfer_family == ~0u)
                            out->transfer_family = q;
                    }
                    get_memory(devices[i], &memory);
                    out->device_local_heap_bytes = (uint32_t)(device_local_bytes(&memory) / (1024u * 1024u));
                }

                if (missing == 0)
                    break; /* a device that satisfies the contract is the answer */
            }
        }

        if (destroy_instance)
            destroy_instance(instance, NULL);
        gr_vk_loader_close(&loader);

        if (out->device_count == 0 || out->device_name[0] == '\0')
            return GR_ERROR_UNSUPPORTED;
        return GR_OK;
    }
#endif
}
