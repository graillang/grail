#include "grail_vk_common.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(GRAIL_HAVE_VULKAN)

gr_result gr_vk_loader_open(gr_vk_loader *loader)
{
    static const char *kCandidates[] = { "libvulkan.so.1", "libvulkan.so", NULL };
    int i;

    if (!loader)
        return GR_ERROR_INVALID_ARGUMENT;
    memset(loader, 0, sizeof(*loader));
    /* GRAIL_VK_FORCE_NONE=1 pretends no loader exists, so the skip path every other machine
     * takes is exercised by a test rather than asserted in a comment. */
    if (getenv("GRAIL_VK_FORCE_NONE")) {
        snprintf(loader->path, sizeof(loader->path), "%s", "suppressed by GRAIL_VK_FORCE_NONE");
        return GR_ERROR_UNSUPPORTED;
    }
    for (i = 0; kCandidates[i]; ++i) {
        void *handle = dlopen(kCandidates[i], RTLD_NOW | RTLD_LOCAL);
        void *symbol;
        PFN_vkGetInstanceProcAddr gipa;
        if (!handle)
            continue;
        symbol = dlsym(handle, "vkGetInstanceProcAddr");
        /* ISO C forbids casting an object pointer to a function pointer; a byte copy through
         * same-sized objects is the portable spelling. */
        if (sizeof(symbol) != sizeof(gipa)) {
            dlclose(handle);
            continue;
        }
        memcpy(&gipa, &symbol, sizeof(gipa));
        if (!gipa) {
            dlclose(handle);
            continue;
        }
        loader->library = handle;
        loader->gipa = gipa;
        snprintf(loader->path, sizeof(loader->path), "%s", kCandidates[i]);
        return GR_OK;
    }
    snprintf(loader->path, sizeof(loader->path), "%s", "no libvulkan.so.1");
    return GR_ERROR_UNSUPPORTED;
}

void gr_vk_loader_close(gr_vk_loader *loader)
{
    if (loader && loader->library) {
        dlclose(loader->library);
        loader->library = NULL;
        loader->gipa = NULL;
    }
}

gr_result gr_vk_instance_create(gr_vk_loader *loader, uint32_t requested_api,
                                VkInstance *out_instance, uint32_t *out_api)
{
    PFN_vkCreateInstance create_instance;
    VkApplicationInfo app;
    VkInstanceCreateInfo create_info;
    static const uint32_t kFallbacks[] = { VK_API_VERSION_1_3, VK_API_VERSION_1_0 };
    uint32_t i;

    if (!loader || !loader->gipa || !out_instance)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_instance = VK_NULL_HANDLE;
    create_instance = (PFN_vkCreateInstance)loader->gipa(NULL, "vkCreateInstance");
    if (!create_instance)
        return GR_ERROR_UNSUPPORTED;

    memset(&app, 0, sizeof(app));
    app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app.pApplicationName = "grail";
    app.applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0);
    app.pEngineName = "grail";
    app.engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0);

    memset(&create_info, 0, sizeof(create_info));
    create_info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = &app;

    /* Try what the caller asked for, then the two versions that matter: 1.3 is the contract's
     * floor, 1.0 is what any loader accepts. A 1.2 device then gets a report with its real API
     * version instead of the instance failing outright. */
    for (i = 0; i < 3u; ++i) {
        uint32_t api = (i == 0 && requested_api) ? requested_api : kFallbacks[i ? i - 1u : 0];
        VkResult result;
        app.apiVersion = api;
        result = create_instance(&create_info, NULL, out_instance);
        if (result == VK_SUCCESS) {
            if (out_api)
                *out_api = api;
            return GR_OK;
        }
        *out_instance = VK_NULL_HANDLE;
    }
    return GR_ERROR_UNSUPPORTED;
}

uint32_t gr_vk_evaluate_required(gr_vk_loader *loader, VkInstance instance,
                                VkPhysicalDevice device, const VkPhysicalDeviceProperties *props)
{
    uint32_t maj, min, missing = 0;
    VkPhysicalDeviceFeatures2 features;
    VkPhysicalDeviceVulkan12Features f12;
    VkPhysicalDeviceVulkan13Features f13;
    PFN_vkGetPhysicalDeviceFeatures2 get_features2 = NULL;

    if (loader && loader->gipa && instance != VK_NULL_HANDLE)
        get_features2 = (PFN_vkGetPhysicalDeviceFeatures2)loader->gipa(instance,
                                                                      "vkGetPhysicalDeviceFeatures2");

    memset(&f12, 0, sizeof(f12));
    memset(&f13, 0, sizeof(f13));
    memset(&features, 0, sizeof(features));
    f12.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
    f13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
    features.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    if (get_features2) {
        features.pNext = &f12;
        f12.pNext = &f13;
        get_features2(device, &features);
    }

    maj = VK_API_VERSION_MAJOR(props->apiVersion);
    min = VK_API_VERSION_MINOR(props->apiVersion);

    if (!features.features.shaderInt16) missing |= GR_VK_REQ_SHADER_INT16;
    if (!features.features.shaderInt64) missing |= GR_VK_REQ_SHADER_INT64;

    if (maj < 1u || (maj == 1u && min < 2u)) {
        missing |= GR_VK_REQ_DESCRIPTOR_INDEXING | GR_VK_REQ_RUNTIME_DESCRIPTOR_ARRAY |
                   GR_VK_REQ_UPDATE_AFTER_BIND | GR_VK_REQ_PARTIALLY_BOUND |
                   GR_VK_REQ_VARIABLE_DESCRIPTOR_COUNT | GR_VK_REQ_NON_UNIFORM_INDEXING |
                   GR_VK_REQ_BUFFER_DEVICE_ADDRESS | GR_VK_REQ_TIMELINE_SEMAPHORE |
                   GR_VK_REQ_SCALAR_BLOCK_LAYOUT;
    } else {
        if (!f12.descriptorIndexing) missing |= GR_VK_REQ_DESCRIPTOR_INDEXING;
        if (!f12.runtimeDescriptorArray) missing |= GR_VK_REQ_RUNTIME_DESCRIPTOR_ARRAY;
        if (!f12.descriptorBindingSampledImageUpdateAfterBind) missing |= GR_VK_REQ_UPDATE_AFTER_BIND;
        if (!f12.descriptorBindingPartiallyBound) missing |= GR_VK_REQ_PARTIALLY_BOUND;
        if (!f12.descriptorBindingVariableDescriptorCount) missing |= GR_VK_REQ_VARIABLE_DESCRIPTOR_COUNT;
        if (!f12.shaderSampledImageArrayNonUniformIndexing) missing |= GR_VK_REQ_NON_UNIFORM_INDEXING;
        if (!f12.bufferDeviceAddress) missing |= GR_VK_REQ_BUFFER_DEVICE_ADDRESS;
        if (!f12.timelineSemaphore) missing |= GR_VK_REQ_TIMELINE_SEMAPHORE;
        if (!f12.scalarBlockLayout) missing |= GR_VK_REQ_SCALAR_BLOCK_LAYOUT;
    }

    if (maj < 1u || (maj == 1u && min < 3u)) {
        missing |= GR_VK_REQ_DYNAMIC_RENDERING | GR_VK_REQ_SYNCHRONIZATION2;
    } else {
        if (!f13.dynamicRendering) missing |= GR_VK_REQ_DYNAMIC_RENDERING;
        if (!f13.synchronization2) missing |= GR_VK_REQ_SYNCHRONIZATION2;
    }
    return missing;
}

void gr_vk_fill_caps(gr_device_caps *caps, const VkPhysicalDeviceProperties *props,
                     const VkPhysicalDeviceMemoryProperties *memory, uint32_t required_missing,
                     uint32_t api_major, uint32_t api_minor, uint32_t subgroup_size,
                     uint32_t timestamp_valid_bits)
{
    uint64_t best_heap = 0;
    uint32_t i;

    caps->backend = GR_BACKEND_VULKAN;
    caps->api_major = api_major;
    caps->api_minor = api_minor;
    caps->api_patch = VK_API_VERSION_PATCH(props->apiVersion);
    caps->vendor_id = props->vendorID;
    caps->device_id = props->deviceID;
    snprintf(caps->device_name, sizeof(caps->device_name), "%.*s",
             (int)(sizeof(caps->device_name) - 1u), props->deviceName);
    snprintf(caps->driver_name, sizeof(caps->driver_name), "%s", "vulkan");
    caps->max_push_constant_bytes = props->limits.maxPushConstantsSize;
    /* Neither is in VkPhysicalDeviceLimits: subgroup size comes from
     * VkPhysicalDeviceSubgroupProperties and the timestamp bit count from the queue family. The
     * caller queries both and passes them in, so this function invents nothing. */
    caps->subgroup_size = subgroup_size;
    caps->timestamp_period_ns = props->limits.timestampPeriod;
    caps->timestamp_valid_bits = timestamp_valid_bits;
    caps->max_descriptor_array_length = props->limits.maxPerStageDescriptorSampledImages;
    caps->buffer_address_min_align = 256;
    caps->max_color_attachments = props->limits.maxColorAttachments;
    caps->depth_range_zero_to_one = 0; /* Vulkan reverse-Z [1,0] */
    caps->max_frames_in_flight = 2;

    for (i = 0; memory && i < memory->memoryHeapCount; ++i)
        if ((memory->memoryHeaps[i].flags & VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) &&
            memory->memoryHeaps[i].size > best_heap)
            best_heap = memory->memoryHeaps[i].size;
    caps->device_memory_bytes = best_heap;

    /* Only claim a capability the device actually provides: the bits are what a caller gates
     * its own paths on, so an optimistic bit is a crash later. */
    caps->caps = GR_CAP_NONE;
    if (!(required_missing & GR_VK_REQ_DESCRIPTOR_INDEXING)) caps->caps |= GR_CAP_BINDLESS;
    if (!(required_missing & GR_VK_REQ_UPDATE_AFTER_BIND)) caps->caps |= GR_CAP_DESCRIPTOR_UPDATE_AFTER_BIND;
    if (!(required_missing & GR_VK_REQ_DYNAMIC_RENDERING)) caps->caps |= GR_CAP_DYNAMIC_RENDERING;
    if (!(required_missing & GR_VK_REQ_TIMELINE_SEMAPHORE)) caps->caps |= GR_CAP_TIMELINE_SEMAPHORE;
    if (!(required_missing & GR_VK_REQ_BUFFER_DEVICE_ADDRESS)) caps->caps |= GR_CAP_BUFFER_DEVICE_ADDRESS;
    if (!(required_missing & GR_VK_REQ_SHADER_INT16)) caps->caps |= GR_CAP_16BIT_TYPES;
    if (!(required_missing & GR_VK_REQ_SHADER_INT64)) caps->caps |= GR_CAP_64BIT_INTEGER;
}

#endif /* GRAIL_HAVE_VULKAN */
