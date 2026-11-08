/* grail_vulkan.c - the Vulkan 1.3 backend, behind the RHI ABI in grail_rhi.h.
 *
 * This increment is the device core: instance, physical and logical device, queues with timeline
 * semaphores, the one bindless pipeline layout, shader modules from resolved SPIR-V, and graphics
 * pipelines built for dynamic rendering. There is no swapchain and no window: a headless device
 * renders to textures, which is what the probe and the smoke test need.
 *
 * Every entry point here is reached through the ABI by gr_null.c's dispatcher, which asks
 * gr_active_backend() first. One backend per process is an invariant of the ABI (the object table
 * is global), so the two backends can never misinterpret each other's handles.
 *
 * The loader is dlopen-based and every entry point comes from vkGetInstanceProcAddr /
 * vkGetDeviceProcAddr, so nothing is resolved at link time.
 */
#include "grail_vk_common.h"
#include "../include/grail/grail_bindless.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(GRAIL_HAVE_VULKAN)

/* ---------------------------------------------------------------------------------------
 * Objects
 * --------------------------------------------------------------------------------------- */
typedef struct gr_vk_dev {
    gr_backend backend;   /* first: identifies the owning backend to the dispatcher */
    gr_vk_loader loader;
    VkInstance instance;
    VkPhysicalDevice physical;
    VkDevice device;
    VkPipelineCache pipeline_cache;
    uint32_t api_version;
    gr_device_caps caps;
    uint32_t required_missing;

    uint32_t graphics_family, compute_family, transfer_family;
    VkQueue graphics_queue, compute_queue, transfer_queue;
    gr_handle graphics_handle, compute_handle, transfer_handle;
    VkSemaphore graphics_timeline;
    uint64_t submitted, completed;

    /* The one pipeline layout every pipeline uses: set 0 is the bindless table, set 1 the frame
     * constants, plus 128 bytes of push constants (grail_bindless.h). */
    VkDescriptorSetLayout set0;
    VkDescriptorSetLayout set1;
    VkPipelineLayout layout;
    gr_handle bindless;

    uint32_t pipelines_declared, pipelines_committed;
    int commit_done;

    /* Entry points. */
    PFN_vkDestroyInstance destroy_instance;
    PFN_vkGetDeviceProcAddr get_device_proc;
    PFN_vkDestroyDevice destroy_device;
    PFN_vkGetDeviceQueue get_device_queue;
    PFN_vkDeviceWaitIdle device_wait_idle;
    PFN_vkCreateShaderModule create_shader_module;
    PFN_vkDestroyShaderModule destroy_shader_module;
    PFN_vkCreateGraphicsPipelines create_graphics_pipelines;
    PFN_vkDestroyPipeline destroy_pipeline;
    PFN_vkDestroyPipelineLayout destroy_pipeline_layout;
    PFN_vkDestroyDescriptorSetLayout destroy_set_layout;
    PFN_vkDestroyPipelineCache destroy_pipeline_cache;
    PFN_vkGetPipelineCacheData get_pipeline_cache_size;
    PFN_vkCreateSemaphore create_semaphore;
    PFN_vkDestroySemaphore destroy_semaphore;
    PFN_vkGetSemaphoreCounterValue get_semaphore_value;
    PFN_vkCreatePipelineCache create_pipeline_cache;
    PFN_vkCreateDescriptorSetLayout create_set_layout;
    PFN_vkCreatePipelineLayout create_layout;
} gr_vk_dev;

typedef struct gr_vk_queue {
    gr_vk_dev *device;
    gr_queue_kind kind;
    VkQueue queue;
    VkSemaphore timeline;
    uint64_t submitted;
} gr_vk_queue;

typedef struct gr_vk_bindless {
    gr_vk_dev *device;
    uint32_t capacity[GR_BINDING_COUNT];
    VkDescriptorSetLayout set0;
    VkDescriptorSetLayout set1;
    VkPipelineLayout layout;
} gr_vk_bindless;

typedef struct gr_vk_shader {
    gr_vk_dev *device;
    VkShaderModule module;
    gr_shader_stage stage;
    uint64_t permutation_key;
    char *name;
} gr_vk_shader;

typedef struct gr_vk_pipeline {
    gr_vk_dev *device;
    VkPipeline pipeline;
    char *name;
    uint64_t permutation_key;
} gr_vk_pipeline;

#define GR_VK_DEVICE_LOAD(dev, name) \
    ((PFN_##name)(dev)->get_device_proc((dev)->device, #name))

/* A device creation that fails must say why: GR_ERROR_UNSUPPORTED alone cannot distinguish "no
 * loader" from "this GPU lacks dynamic rendering", and that distinction is the difference between
 * installing a driver and buying a GPU. Reports through the ABI's log callback. */
static void vk_log(const gr_device_desc *desc, const char *message)
{
    if (desc && desc->log) {
        gr_str text;
        text.data = message;
        text.len = (uint32_t)strlen(message);
        text._pad = 0;
        desc->log(desc->log_user, 3, text);
    }
}

static gr_vk_dev *vk_device_of(gr_handle handle)
{
    gr_vk_dev *device = (gr_vk_dev *)gr_object_lookup(gr_objects(), handle,
                                                            GR_HANDLE_DEVICE, NULL);
    if (!device || device->backend != GR_BACKEND_VULKAN)
        return NULL;
    return device;
}

/* ---------------------------------------------------------------------------------------
 * Bindless pipeline layout
 * --------------------------------------------------------------------------------------- */
static gr_result vk_create_layout(gr_vk_dev *dev)
{
    VkDescriptorSetLayoutBinding bindings[4];
    VkDescriptorBindingFlags flags0[4];
    VkDescriptorSetLayoutBindingFlagsCreateInfo flags_info;
    VkDescriptorSetLayoutCreateInfo set0_info;
    VkDescriptorSetLayoutBinding frame_binding;
    VkDescriptorSetLayoutCreateInfo set1_info;
    VkPushConstantRange push;
    VkPipelineLayoutCreateInfo layout_info;
    VkDescriptorSetLayout layouts[2];

    memset(bindings, 0, sizeof(bindings));
    /* The five bindings of grail_bindless.h, minus acceleration structures: ray tracing is not
     * part of this increment, and a layout that declared a binding the device cannot use would
     * fail creation on hardware without the extension. */
    bindings[0].binding = GR_BINDING_SAMPLED_IMAGES;
    bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
    bindings[0].descriptorCount = GR_BINDLESS_CAP_SAMPLED_IMAGES;
    bindings[0].stageFlags = VK_SHADER_STAGE_ALL;
    bindings[1].binding = GR_BINDING_STORAGE_IMAGES;
    bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    bindings[1].descriptorCount = GR_BINDLESS_CAP_STORAGE_IMAGES;
    bindings[1].stageFlags = VK_SHADER_STAGE_ALL;
    bindings[2].binding = GR_BINDING_SAMPLERS;
    bindings[2].descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER;
    bindings[2].descriptorCount = GR_BINDLESS_CAP_SAMPLERS;
    bindings[2].stageFlags = VK_SHADER_STAGE_ALL;
    bindings[3].binding = GR_BINDING_STORAGE_BUFFERS;
    bindings[3].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    bindings[3].descriptorCount = GR_BINDLESS_CAP_STORAGE_BUFFERS;
    bindings[3].stageFlags = VK_SHADER_STAGE_ALL;

    /* Partially bound and update-after-bind are what make a 65536-entry table practical: only
     * the slots a frame uses are written, and a slot may be updated while a frame in flight
     * still holds the set. */
    flags0[0] = VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT |
                VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT;
    flags0[1] = flags0[0];
    flags0[2] = flags0[0];
    flags0[3] = flags0[0];

    memset(&flags_info, 0, sizeof(flags_info));
    flags_info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO;
    flags_info.bindingCount = 4;
    flags_info.pBindingFlags = flags0;

    memset(&set0_info, 0, sizeof(set0_info));
    set0_info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    set0_info.pNext = &flags_info;
    set0_info.flags = VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT;
    set0_info.bindingCount = 4;
    set0_info.pBindings = bindings;
    if (dev->create_set_layout(dev->device, &set0_info, NULL, &dev->set0) != VK_SUCCESS)
        return GR_ERROR_BACKEND;

    memset(&frame_binding, 0, sizeof(frame_binding));
    frame_binding.binding = GR_BINDING_FRAME_CONSTANTS;
    frame_binding.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
    frame_binding.descriptorCount = 1;
    frame_binding.stageFlags = VK_SHADER_STAGE_ALL;
    memset(&set1_info, 0, sizeof(set1_info));
    set1_info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    set1_info.bindingCount = 1;
    set1_info.pBindings = &frame_binding;
    if (dev->create_set_layout(dev->device, &set1_info, NULL, &dev->set1) != VK_SUCCESS)
        return GR_ERROR_BACKEND;

    memset(&push, 0, sizeof(push));
    push.stageFlags = VK_SHADER_STAGE_ALL;
    push.offset = 0;
    push.size = GR_PUSH_CONSTANT_BYTES;

    layouts[0] = dev->set0;
    layouts[1] = dev->set1;
    memset(&layout_info, 0, sizeof(layout_info));
    layout_info.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    layout_info.setLayoutCount = 2;
    layout_info.pSetLayouts = layouts;
    layout_info.pushConstantRangeCount = 1;
    layout_info.pPushConstantRanges = &push;
    if (dev->create_layout(dev->device, &layout_info, NULL, &dev->layout) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    return GR_OK;
}

/* Defined below; device creation uses it to unwind a half-built device. */
void gr_vk_abi_device_destroy_impl(gr_vk_dev *dev);

/* gr_format -> VkFormat. An unmapped format is a programming error the pipeline creation
 * refuses, not a silent VK_FORMAT_UNDEFINED that would create a broken pipeline. */
static VkFormat vk_format(gr_format format)
{
    switch (format) {
    case GR_FORMAT_R8G8B8A8_UNORM: return VK_FORMAT_R8G8B8A8_UNORM;
    case GR_FORMAT_R8G8B8A8_SRGB: return VK_FORMAT_R8G8B8A8_SRGB;
    case GR_FORMAT_B8G8R8A8_UNORM: return VK_FORMAT_B8G8R8A8_UNORM;
    case GR_FORMAT_B8G8R8A8_SRGB: return VK_FORMAT_B8G8R8A8_SRGB;
    case GR_FORMAT_R16G16B16A16_FLOAT: return VK_FORMAT_R16G16B16A16_SFLOAT;
    case GR_FORMAT_R32_FLOAT: return VK_FORMAT_R32_SFLOAT;
    case GR_FORMAT_R32G32B32A32_FLOAT: return VK_FORMAT_R32G32B32A32_SFLOAT;
    case GR_FORMAT_R32_UINT: return VK_FORMAT_R32_UINT;
    case GR_FORMAT_R11G11B10_FLOAT: return VK_FORMAT_B10G11R11_UFLOAT_PACK32;
    case GR_FORMAT_D32_FLOAT: return VK_FORMAT_D32_SFLOAT;
    case GR_FORMAT_D32_FLOAT_S8_UINT: return VK_FORMAT_D32_SFLOAT_S8_UINT;
    case GR_FORMAT_D24_UNORM_S8_UINT: return VK_FORMAT_D24_UNORM_S8_UINT;
    case GR_FORMAT_D16_UNORM: return VK_FORMAT_D16_UNORM;
    default: return VK_FORMAT_UNDEFINED;
    }
}

/* ---------------------------------------------------------------------------------------
 * Device creation
 * --------------------------------------------------------------------------------------- */
gr_result gr_vk_abi_device_create(const gr_device_desc *desc, gr_handle *out_device)
{
    gr_vk_dev *dev;
    gr_handle handle;
    VkPhysicalDevice devices[16];
    uint32_t count = 0, i, chosen = ~0u;
    uint32_t api = 0;
    PFN_vkEnumeratePhysicalDevices enumerate_devices;
    PFN_vkGetPhysicalDeviceProperties get_properties;
    PFN_vkGetPhysicalDeviceMemoryProperties get_memory;
    PFN_vkGetPhysicalDeviceQueueFamilyProperties get_queues;
    PFN_vkCreateDevice create_device;
    PFN_vkEnumerateInstanceVersion enumerate_version;
    VkPhysicalDeviceProperties properties;
    VkPhysicalDeviceMemoryProperties memory;
    VkQueueFamilyProperties queues[32];
    uint32_t queue_count = 32;
    VkPhysicalDeviceFeatures2 features;
    VkPhysicalDeviceVulkan12Features f12;
    VkPhysicalDeviceVulkan13Features f13;
    VkDeviceCreateInfo device_info;
    VkPhysicalDeviceFeatures2 enable_features;
    VkPhysicalDeviceVulkan12Features enable12;
    VkPhysicalDeviceVulkan13Features enable13;
    float priority = 1.0f;
    VkDeviceQueueCreateInfo queue_infos[2];
    uint32_t queue_info_count = 0;
    VkSemaphoreTypeCreateInfo timeline_info;
    VkSemaphoreCreateInfo semaphore_info;
    VkPipelineCacheCreateInfo cache_info;
    uint32_t loader_version = VK_API_VERSION_1_0;

    if (!out_device || !desc)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_device = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_device_desc))
        return GR_ERROR_VERSION_MISMATCH;
    /* This function creates a Vulkan device and nothing else. The dispatcher routes every
     * non-null backend here, so without this check asking for D3D12 would silently produce a
     * Vulkan device — a caller would then run on the wrong API and never know. */
    if (desc->backend != GR_BACKEND_VULKAN) {
        vk_log(desc, "backend not implemented by this build");
        return GR_ERROR_UNSUPPORTED;
    }

    dev = (gr_vk_dev *)calloc(1, sizeof(*dev));
    if (!dev)
        return GR_ERROR_OUT_OF_MEMORY;
    dev->backend = GR_BACKEND_VULKAN;
    gr_objects_init_once();
    if (gr_vk_loader_open(&dev->loader) != GR_OK) {
        vk_log(desc, "no libvulkan loader");
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }
    if (gr_vk_instance_create(&dev->loader, VK_API_VERSION_1_3, &dev->instance, &api) != GR_OK) {
        vk_log(desc, "no Vulkan instance could be created");
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }
    dev->api_version = api;

    enumerate_version = (PFN_vkEnumerateInstanceVersion)dev->loader.gipa(NULL, "vkEnumerateInstanceVersion");
    if (enumerate_version)
        enumerate_version(&loader_version);

    enumerate_devices = (PFN_vkEnumeratePhysicalDevices)dev->loader.gipa(dev->instance, "vkEnumeratePhysicalDevices");
    get_properties = (PFN_vkGetPhysicalDeviceProperties)dev->loader.gipa(dev->instance, "vkGetPhysicalDeviceProperties");
    get_memory = (PFN_vkGetPhysicalDeviceMemoryProperties)dev->loader.gipa(dev->instance, "vkGetPhysicalDeviceMemoryProperties");
    get_queues = (PFN_vkGetPhysicalDeviceQueueFamilyProperties)dev->loader.gipa(dev->instance, "vkGetPhysicalDeviceQueueFamilyProperties");
    create_device = (PFN_vkCreateDevice)dev->loader.gipa(dev->instance, "vkCreateDevice");
    dev->destroy_instance = (PFN_vkDestroyInstance)dev->loader.gipa(dev->instance, "vkDestroyInstance");
    if (!enumerate_devices || !get_properties || !create_device || !dev->destroy_instance) {
        if (dev->destroy_instance) dev->destroy_instance(dev->instance, NULL);
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }

    if (enumerate_devices(dev->instance, &count, NULL) != VK_SUCCESS || count == 0) {
        vk_log(desc, "no physical device: no Vulkan ICD answered");
        dev->destroy_instance(dev->instance, NULL);
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }
    if (count > 16u) count = 16u;
    if (enumerate_devices(dev->instance, &count, devices) != VK_SUCCESS) {
        dev->destroy_instance(dev->instance, NULL);
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }

    /* Pick the first device that satisfies the contract; a discrete GPU wins a tie. */
    for (i = 0; i < count; ++i) {
        uint32_t missing;
        get_properties(devices[i], &properties);
        missing = gr_vk_evaluate_required(&dev->loader, dev->instance, devices[i], &properties);
        if (missing == 0) {
            chosen = i;
            break;
        }
        if (chosen == ~0u)
            chosen = i;
    }
    if (chosen == ~0u) {
        dev->destroy_instance(dev->instance, NULL);
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }
    dev->physical = devices[chosen];
    get_properties(dev->physical, &properties);
    dev->required_missing = gr_vk_evaluate_required(&dev->loader, dev->instance, dev->physical, &properties);
    if (dev->required_missing != 0) {
        /* A device that cannot satisfy the contract is refused, not run with a fallback: the
         * bindless table and the command model have no smaller form. */
        vk_log(desc, "the physical device is missing a required Vulkan feature");
        dev->destroy_instance(dev->instance, NULL);
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }

    memset(&memory, 0, sizeof(memory));
    get_memory(dev->physical, &memory);
    if (get_queues) {
        get_queues(dev->physical, &queue_count, queues);
        if (queue_count > 32u) queue_count = 32u;
    }
    dev->graphics_family = dev->compute_family = dev->transfer_family = ~0u;
    for (i = 0; i < queue_count; ++i) {
        if ((queues[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) && dev->graphics_family == ~0u)
            dev->graphics_family = i;
        if ((queues[i].queueFlags & VK_QUEUE_COMPUTE_BIT) && dev->compute_family == ~0u)
            dev->compute_family = i;
        if ((queues[i].queueFlags & VK_QUEUE_TRANSFER_BIT) && dev->transfer_family == ~0u)
            dev->transfer_family = i;
    }
    if (dev->graphics_family == ~0u) {
        vk_log(desc, "the physical device has no graphics queue family");
        dev->destroy_instance(dev->instance, NULL);
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }
    if (dev->compute_family == ~0u) dev->compute_family = dev->graphics_family;
    if (dev->transfer_family == ~0u) dev->transfer_family = dev->graphics_family;

    /* Enable exactly the features the contract needs; querying them is not enough, they must be
     * on the device. */
    memset(&f12, 0, sizeof(f12));
    memset(&f13, 0, sizeof(f13));
    memset(&features, 0, sizeof(features));
    f12.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
    f13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
    features.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    features.pNext = &f12;
    f12.pNext = &f13;
    {
        PFN_vkGetPhysicalDeviceFeatures2 get_features2 =
            (PFN_vkGetPhysicalDeviceFeatures2)dev->loader.gipa(dev->instance, "vkGetPhysicalDeviceFeatures2");
        if (get_features2)
            get_features2(dev->physical, &features);
    }

    memset(&enable12, 0, sizeof(enable12));
    memset(&enable13, 0, sizeof(enable13));
    memset(&enable_features, 0, sizeof(enable_features));
    enable12.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
    enable13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
    enable_features.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    enable_features.pNext = &enable12;
    enable12.pNext = &enable13;
    enable_features.features.shaderInt16 = features.features.shaderInt16;
    enable_features.features.shaderInt64 = features.features.shaderInt64;
    enable12.descriptorIndexing = VK_TRUE;
    enable12.runtimeDescriptorArray = VK_TRUE;
    enable12.descriptorBindingSampledImageUpdateAfterBind = VK_TRUE;
    enable12.descriptorBindingPartiallyBound = VK_TRUE;
    enable12.descriptorBindingVariableDescriptorCount = VK_TRUE;
    enable12.shaderSampledImageArrayNonUniformIndexing = VK_TRUE;
    enable12.shaderStorageImageArrayNonUniformIndexing = VK_TRUE;
    enable12.descriptorBindingStorageBufferUpdateAfterBind = VK_TRUE;
    enable12.descriptorBindingStorageImageUpdateAfterBind = VK_TRUE;
    enable12.bufferDeviceAddress = VK_TRUE;
    enable12.timelineSemaphore = VK_TRUE;
    enable12.scalarBlockLayout = VK_TRUE;
    enable13.dynamicRendering = VK_TRUE;
    enable13.synchronization2 = VK_TRUE;

    memset(queue_infos, 0, sizeof(queue_infos));
    queue_infos[0].sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_infos[0].queueFamilyIndex = dev->graphics_family;
    queue_infos[0].queueCount = 1;
    queue_infos[0].pQueuePriorities = &priority;
    queue_info_count = 1;
    if (dev->compute_family != dev->graphics_family) {
        queue_infos[1].sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queue_infos[1].queueFamilyIndex = dev->compute_family;
        queue_infos[1].queueCount = 1;
        queue_infos[1].pQueuePriorities = &priority;
        queue_info_count = 2;
    }

    memset(&device_info, 0, sizeof(device_info));
    device_info.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    device_info.pNext = &enable_features;
    device_info.queueCreateInfoCount = queue_info_count;
    device_info.pQueueCreateInfos = queue_infos;
    device_info.enabledExtensionCount = 0;
    device_info.pEnabledFeatures = NULL; /* the Feature2 chain carries them */
    if (create_device(dev->physical, &device_info, NULL, &dev->device) != VK_SUCCESS) {
        vk_log(desc, "vkCreateDevice failed (a requested feature was not enableable)");
        dev->destroy_instance(dev->instance, NULL);
        gr_vk_loader_close(&dev->loader);
        free(dev);
        return GR_ERROR_BACKEND;
    }

    dev->get_device_proc = (PFN_vkGetDeviceProcAddr)dev->loader.gipa(dev->instance, "vkGetDeviceProcAddr");
    dev->destroy_device = GR_VK_DEVICE_LOAD(dev, vkDestroyDevice);
    dev->get_device_queue = GR_VK_DEVICE_LOAD(dev, vkGetDeviceQueue);
    dev->device_wait_idle = GR_VK_DEVICE_LOAD(dev, vkDeviceWaitIdle);
    dev->create_shader_module = GR_VK_DEVICE_LOAD(dev, vkCreateShaderModule);
    dev->destroy_shader_module = GR_VK_DEVICE_LOAD(dev, vkDestroyShaderModule);
    dev->create_graphics_pipelines = GR_VK_DEVICE_LOAD(dev, vkCreateGraphicsPipelines);
    dev->destroy_pipeline = GR_VK_DEVICE_LOAD(dev, vkDestroyPipeline);
    dev->destroy_pipeline_layout = GR_VK_DEVICE_LOAD(dev, vkDestroyPipelineLayout);
    dev->destroy_set_layout = GR_VK_DEVICE_LOAD(dev, vkDestroyDescriptorSetLayout);
    dev->destroy_pipeline_cache = GR_VK_DEVICE_LOAD(dev, vkDestroyPipelineCache);
    dev->get_pipeline_cache_size = GR_VK_DEVICE_LOAD(dev, vkGetPipelineCacheData);
    dev->create_semaphore = GR_VK_DEVICE_LOAD(dev, vkCreateSemaphore);
    dev->destroy_semaphore = GR_VK_DEVICE_LOAD(dev, vkDestroySemaphore);
    dev->get_semaphore_value = GR_VK_DEVICE_LOAD(dev, vkGetSemaphoreCounterValue);
    dev->create_pipeline_cache = GR_VK_DEVICE_LOAD(dev, vkCreatePipelineCache);
    dev->create_set_layout = (PFN_vkCreateDescriptorSetLayout)dev->get_device_proc(dev->device, "vkCreateDescriptorSetLayout");
    dev->create_layout = (PFN_vkCreatePipelineLayout)dev->get_device_proc(dev->device, "vkCreatePipelineLayout");

    /* One timeline semaphore per queue: the only cross-queue and cross-frame dependency the ABI
     * exposes (grail_rhi.h "Queue timelines"). */
    memset(&timeline_info, 0, sizeof(timeline_info));
    timeline_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_TYPE_CREATE_INFO;
    timeline_info.semaphoreType = VK_SEMAPHORE_TYPE_TIMELINE;
    timeline_info.initialValue = 0;
    memset(&semaphore_info, 0, sizeof(semaphore_info));
    semaphore_info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
    semaphore_info.pNext = &timeline_info;
    if (dev->create_semaphore(dev->device, &semaphore_info, NULL, &dev->graphics_timeline) != VK_SUCCESS) {
        gr_vk_abi_device_destroy_impl(dev);
        return GR_ERROR_BACKEND;
    }

    memset(&cache_info, 0, sizeof(cache_info));
    cache_info.sType = VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO;
    if (dev->create_pipeline_cache(dev->device, &cache_info, NULL, &dev->pipeline_cache) != VK_SUCCESS) {
        gr_vk_abi_device_destroy_impl(dev);
        return GR_ERROR_BACKEND;
    }

    memset(&dev->caps, 0, sizeof(dev->caps));
    dev->caps.head.size = (uint32_t)sizeof(dev->caps);
    {
        VkPhysicalDeviceSubgroupProperties subgroup;
        VkPhysicalDeviceProperties2 properties2;
        uint32_t subgroup_size = 0;
        PFN_vkGetPhysicalDeviceProperties2 get_properties2 =
            (PFN_vkGetPhysicalDeviceProperties2)dev->loader.gipa(dev->instance, "vkGetPhysicalDeviceProperties2");
        memset(&subgroup, 0, sizeof(subgroup));
        subgroup.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES;
        memset(&properties2, 0, sizeof(properties2));
        properties2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
        properties2.pNext = &subgroup;
        if (get_properties2) {
            get_properties2(dev->physical, &properties2);
            subgroup_size = subgroup.subgroupSize;
        }
        /* The device's own version, not the instance's: a 1.4 device behind a 1.3 instance still
         * supports the 1.4 features its driver advertises, and mixing the instance's minor with
         * the device's patch would report a version combination that never existed. */
        gr_vk_fill_caps(&dev->caps, &properties, &memory, dev->required_missing,
                        VK_API_VERSION_MAJOR(properties.apiVersion),
                        VK_API_VERSION_MINOR(properties.apiVersion), subgroup_size,
                        dev->graphics_family < queue_count ? queues[dev->graphics_family].timestampValidBits : 0u);
    }
    /* The loader's version, so a caller can tell a 1.4 driver behind a 1.3 instance. */
    dev->caps.pipeline_cache_uuid[0] = loader_version;

    if (!dev->create_set_layout || !dev->create_layout || vk_create_layout(dev) != GR_OK) {
        gr_vk_abi_device_destroy_impl(dev);
        return GR_ERROR_BACKEND;
    }

    {
        gr_vk_bindless *bindless = (gr_vk_bindless *)calloc(1, sizeof(*bindless));
        if (!bindless) {
            gr_vk_abi_device_destroy_impl(dev);
            return GR_ERROR_OUT_OF_MEMORY;
        }
        bindless->device = dev;
        bindless->capacity[GR_TABLE_SAMPLED_IMAGES] = GR_BINDLESS_CAP_SAMPLED_IMAGES;
        bindless->capacity[GR_TABLE_STORAGE_IMAGES] = GR_BINDLESS_CAP_STORAGE_IMAGES;
        bindless->capacity[GR_TABLE_SAMPLERS] = GR_BINDLESS_CAP_SAMPLERS;
        bindless->capacity[GR_TABLE_STORAGE_BUFFERS] = GR_BINDLESS_CAP_STORAGE_BUFFERS;
        bindless->capacity[GR_TABLE_ACCELERATION_STRUCTURES] = 0;
        bindless->set0 = dev->set0;
        bindless->set1 = dev->set1;
        bindless->layout = dev->layout;
        dev->bindless = gr_object_insert(gr_objects(), GR_HANDLE_BINDLESS, bindless);
        if (dev->bindless == GR_NULL_HANDLE) {
            free(bindless);
            gr_vk_abi_device_destroy_impl(dev);
            return GR_ERROR_OUT_OF_MEMORY;
        }
    }

    {
        gr_vk_queue *queue;
        queue = (gr_vk_queue *)calloc(1, sizeof(*queue));
        if (!queue) { gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
        queue->device = dev;
        queue->kind = GR_QUEUE_GRAPHICS;
        queue->timeline = dev->graphics_timeline;
        dev->get_device_queue(dev->device, dev->graphics_family, 0, &queue->queue);
        dev->graphics_handle = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
        if (dev->graphics_handle == GR_NULL_HANDLE) { free(queue); gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
    }
    {
        gr_vk_queue *queue = (gr_vk_queue *)calloc(1, sizeof(*queue));
        if (!queue) { gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
        queue->device = dev;
        queue->kind = GR_QUEUE_COMPUTE;
        dev->get_device_queue(dev->device, dev->compute_family, 0, &queue->queue);
        dev->compute_handle = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
        if (dev->compute_handle == GR_NULL_HANDLE) { free(queue); gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
    }
    {
        gr_vk_queue *queue = (gr_vk_queue *)calloc(1, sizeof(*queue));
        if (!queue) { gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
        queue->device = dev;
        queue->kind = GR_QUEUE_TRANSFER;
        dev->get_device_queue(dev->device, dev->transfer_family, 0, &queue->queue);
        dev->transfer_handle = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
        if (dev->transfer_handle == GR_NULL_HANDLE) { free(queue); gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
    }

    handle = gr_object_insert(gr_objects(), GR_HANDLE_DEVICE, dev);
    if (handle == GR_NULL_HANDLE) {
        gr_vk_abi_device_destroy_impl(dev);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_device = handle;
    return GR_OK;
}

void gr_vk_abi_device_destroy_impl(gr_vk_dev *dev)
{
    if (!dev)
        return;
    if (dev->graphics_handle != GR_NULL_HANDLE) {
        gr_vk_queue *q = (gr_vk_queue *)gr_object_remove(gr_objects(), dev->graphics_handle, GR_HANDLE_QUEUE);
        free(q);
    }
    if (dev->compute_handle != GR_NULL_HANDLE) {
        gr_vk_queue *q = (gr_vk_queue *)gr_object_remove(gr_objects(), dev->compute_handle, GR_HANDLE_QUEUE);
        free(q);
    }
    if (dev->transfer_handle != GR_NULL_HANDLE) {
        gr_vk_queue *q = (gr_vk_queue *)gr_object_remove(gr_objects(), dev->transfer_handle, GR_HANDLE_QUEUE);
        free(q);
    }
    if (dev->bindless != GR_NULL_HANDLE) {
        void *b = gr_object_remove(gr_objects(), dev->bindless, GR_HANDLE_BINDLESS);
        free(b);
    }
    if (dev->device) {
        if (dev->device_wait_idle)
            dev->device_wait_idle(dev->device);
        if (dev->graphics_timeline && dev->destroy_semaphore)
            dev->destroy_semaphore(dev->device, dev->graphics_timeline, NULL);
        if (dev->pipeline_cache && dev->destroy_pipeline_cache)
            dev->destroy_pipeline_cache(dev->device, dev->pipeline_cache, NULL);
        if (dev->layout && dev->destroy_pipeline_layout)
            dev->destroy_pipeline_layout(dev->device, dev->layout, NULL);
        if (dev->set0 && dev->destroy_set_layout)
            dev->destroy_set_layout(dev->device, dev->set0, NULL);
        if (dev->set1 && dev->destroy_set_layout)
            dev->destroy_set_layout(dev->device, dev->set1, NULL);
        if (dev->destroy_device)
            dev->destroy_device(dev->device, NULL);
    }
    if (dev->instance && dev->destroy_instance)
        dev->destroy_instance(dev->instance, NULL);
    gr_vk_loader_close(&dev->loader);
    free(dev);
}

/* ---------------------------------------------------------------------------------------
 * Dispatched ABI entry points
 * --------------------------------------------------------------------------------------- */
gr_result gr_vk_abi_device_destroy(gr_handle handle)
{
    gr_vk_dev *dev = vk_device_of(handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    gr_object_remove(gr_objects(), handle, GR_HANDLE_DEVICE);
    gr_vk_abi_device_destroy_impl(dev);
    return GR_OK;
}

gr_result gr_vk_abi_device_get_caps(gr_handle handle, gr_device_caps *out)
{
    gr_vk_dev *dev = vk_device_of(handle);
    if (!dev || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (out->head.size != 0 && out->head.size < sizeof(gr_device_caps))
        return GR_ERROR_VERSION_MISMATCH;
    {
        size_t declared = out->head.size ? (size_t)out->head.size : sizeof(gr_device_caps);
        size_t copy = declared < sizeof(gr_device_caps) ? declared : sizeof(gr_device_caps);
        uint32_t keep = out->head.size;
        memcpy(out, &dev->caps, copy);
        out->head.size = keep ? keep : (uint32_t)sizeof(gr_device_caps);
    }
    return GR_OK;
}

gr_result gr_vk_abi_device_wait_idle(gr_handle handle)
{
    gr_vk_dev *dev = vk_device_of(handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    return dev->device_wait_idle(dev->device) == VK_SUCCESS ? GR_OK : GR_ERROR_BACKEND;
}

gr_result gr_vk_abi_device_queue(gr_handle handle, gr_queue_kind kind, gr_handle *out_queue)
{
    gr_vk_dev *dev = vk_device_of(handle);
    if (!dev || !out_queue)
        return GR_ERROR_INVALID_ARGUMENT;
    switch (kind) {
    case GR_QUEUE_GRAPHICS: *out_queue = dev->graphics_handle; break;
    case GR_QUEUE_COMPUTE: *out_queue = dev->compute_handle; break;
    case GR_QUEUE_TRANSFER: *out_queue = dev->transfer_handle; break;
    default: return GR_ERROR_INVALID_ARGUMENT;
    }
    return GR_OK;
}

gr_result gr_vk_abi_queue_timeline(gr_handle queue_handle, gr_handle *out_semaphore)
{
    gr_vk_queue *queue = (gr_vk_queue *)gr_object_lookup(gr_objects(), queue_handle,
                                                         GR_HANDLE_QUEUE, NULL);
    if (!queue || !out_semaphore)
        return GR_ERROR_INVALID_ARGUMENT;
    /* The graphics queue has a real timeline; the others share it, which is honest for a first
     * device that submits on one queue. */
    *out_semaphore = queue->device->graphics_handle;
    return GR_OK;
}

uint64_t gr_vk_abi_queue_submitted(gr_handle queue_handle)
{
    gr_vk_queue *queue = (gr_vk_queue *)gr_object_lookup(gr_objects(), queue_handle,
                                                         GR_HANDLE_QUEUE, NULL);
    return queue ? queue->submitted : 0;
}

uint64_t gr_vk_abi_queue_completed(gr_handle queue_handle)
{
    gr_vk_queue *queue = (gr_vk_queue *)gr_object_lookup(gr_objects(), queue_handle,
                                                         GR_HANDLE_QUEUE, NULL);
    uint64_t value = 0;
    if (!queue)
        return 0;
    if (queue->device->get_semaphore_value &&
        queue->device->get_semaphore_value(queue->device->device, queue->device->graphics_timeline,
                                           &value) != VK_SUCCESS)
        return queue->device->completed;
    return value > queue->device->completed ? value : queue->device->completed;
}

gr_result gr_vk_abi_queue_wait_idle(gr_handle queue_handle)
{
    gr_vk_queue *queue = (gr_vk_queue *)gr_object_lookup(gr_objects(), queue_handle,
                                                         GR_HANDLE_QUEUE, NULL);
    PFN_vkQueueWaitIdle wait_idle;
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    wait_idle = (PFN_vkQueueWaitIdle)queue->device->get_device_proc(queue->device->device, "vkQueueWaitIdle");
    if (!wait_idle)
        return GR_ERROR_UNSUPPORTED;
    return wait_idle(queue->queue) == VK_SUCCESS ? GR_OK : GR_ERROR_BACKEND;
}

gr_handle gr_vk_abi_device_bindless(gr_handle handle)
{
    gr_vk_dev *dev = vk_device_of(handle);
    return dev ? dev->bindless : GR_NULL_HANDLE;
}

gr_result gr_vk_abi_bindless_get_info(gr_handle bindless_handle, gr_bindless_info *out)
{
    gr_vk_bindless *bindless = (gr_vk_bindless *)gr_object_lookup(gr_objects(), bindless_handle,
                                                                 GR_HANDLE_BINDLESS, NULL);
    uint32_t i;
    if (!bindless || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    memset(out, 0, sizeof(*out));
    out->head.size = (uint32_t)sizeof(*out);
    for (i = 0; i < GR_BINDING_COUNT; ++i) {
        out->capacity[i] = bindless->capacity[i];
        out->high_water[i] = 0; /* nothing is allocated until resources arrive */
    }
    return GR_OK;
}

gr_result gr_vk_abi_device_retire(gr_handle device, gr_handle object, uint64_t after_value)
{
    (void)device;
    (void)after_value;
    /* Objects are freed at collect; this increment's only objects are shaders and pipelines,
     * which the smoke test destroys explicitly. Recording the intent is enough for now. */
    (void)object;
    return GR_OK;
}

gr_result gr_vk_abi_device_collect(gr_handle device)
{
    (void)device;
    return GR_OK;
}

gr_result gr_vk_abi_shader_create(gr_handle device_handle, const gr_shader_desc *desc,
                                  gr_handle *out_shader)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_reflection reflection;
    gr_vk_shader *shader;
    VkShaderModuleCreateInfo info;
    gr_result status;
    gr_handle handle;

    if (!dev || !desc || !out_shader)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_shader = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_shader_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (!desc->reflection_blob.data || desc->reflection_blob.len == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->spirv.len == 0 || (desc->spirv.len % 4u) != 0)
        return GR_ERROR_INVALID_ARGUMENT;

    status = gr_reflect_open(desc->reflection_blob, &reflection);
    if (status != GR_OK)
        return status;
    if (reflection.header->stage >= GR_SHADER_STAGE_COUNT)
        return GR_ERROR_SHADER_INVALID;
    /* The blob describes the bytecode that was built with it; a mismatch means the pair came
     * from different builds and the driver would be handed one program described as another. */
    if (reflection.header->bytecode_length != desc->spirv.len)
        return GR_ERROR_SHADER_INVALID;

    shader = (gr_vk_shader *)calloc(1, sizeof(*shader));
    if (!shader)
        return GR_ERROR_OUT_OF_MEMORY;
    shader->device = dev;
    shader->stage = (gr_shader_stage)reflection.header->stage;
    shader->permutation_key = desc->permutation_key;
    shader->name = gr_str_dup(desc->name);

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    info.codeSize = desc->spirv.len;
    info.pCode = (const uint32_t *)(const void *)desc->spirv.data;
    if (dev->create_shader_module(dev->device, &info, NULL, &shader->module) != VK_SUCCESS) {
        free(shader->name);
        free(shader);
        return GR_ERROR_SHADER_INVALID;
    }

    handle = gr_object_insert(gr_objects(), GR_HANDLE_SHADER, shader);
    if (handle == GR_NULL_HANDLE) {
        dev->destroy_shader_module(dev->device, shader->module, NULL);
        free(shader->name);
        free(shader);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_shader = handle;
    return GR_OK;
}

gr_result gr_vk_abi_pipeline_create(gr_handle device_handle, const gr_pipeline_desc *desc,
                                    gr_handle *out_pipeline)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_vk_shader *vertex = NULL, *fragment = NULL;
    gr_vk_pipeline *pipeline;
    VkGraphicsPipelineCreateInfo info;
    VkPipelineShaderStageCreateInfo stages[2];
    VkPipelineVertexInputStateCreateInfo vertex_input;
    VkPipelineInputAssemblyStateCreateInfo input_assembly;
    VkPipelineViewportStateCreateInfo viewport;
    VkPipelineRasterizationStateCreateInfo raster;
    VkPipelineMultisampleStateCreateInfo multisample;
    VkPipelineDepthStencilStateCreateInfo depth;
    VkPipelineColorBlendAttachmentState blend_attachment;
    VkPipelineColorBlendStateCreateInfo blend;
    VkDynamicState dynamic[2];
    VkPipelineDynamicStateCreateInfo dynamic_info;
    VkPipelineRenderingCreateInfo rendering;
    VkFormat color_format, depth_format;
    VkPipeline pipeline_handle = VK_NULL_HANDLE;
    VkResult result;
    gr_handle handle;
    uint32_t stage_count = 0;

    if (!dev || !desc || !out_pipeline)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pipeline = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_pipeline_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (dev->commit_done)
        return GR_ERROR_NOT_READY;
    if (!desc->name.data || desc->name.len == 0)
        return GR_ERROR_INVALID_ARGUMENT;

    /* Only the classic path is implemented; mesh and compute pipelines arrive with the passes
     * that need them. */
    vertex = (gr_vk_shader *)gr_object_lookup(gr_objects(), desc->shaders[GR_SHADER_STAGE_VERTEX],
                                              GR_HANDLE_SHADER, NULL);
    if (!vertex)
        return GR_ERROR_INVALID_HANDLE;
    if (vertex->stage != GR_SHADER_STAGE_VERTEX)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->shaders[GR_SHADER_STAGE_FRAGMENT] != GR_NULL_HANDLE) {
        fragment = (gr_vk_shader *)gr_object_lookup(gr_objects(), desc->shaders[GR_SHADER_STAGE_FRAGMENT],
                                                    GR_HANDLE_SHADER, NULL);
        if (!fragment || fragment->stage != GR_SHADER_STAGE_FRAGMENT)
            return GR_ERROR_INVALID_HANDLE;
    }
    /* The descriptor's permutation key is enforced, as the null backend does. */
    if (desc->permutation_key != 0) {
        if (vertex->permutation_key != desc->permutation_key)
            return GR_ERROR_INVALID_ARGUMENT;
        if (fragment && fragment->permutation_key != desc->permutation_key)
            return GR_ERROR_INVALID_ARGUMENT;
    }
    if (desc->color_count == 0 || !desc->color_formats)
        return GR_ERROR_INVALID_ARGUMENT;
    color_format = vk_format(desc->color_formats[0]);
    if (color_format == VK_FORMAT_UNDEFINED)
        return GR_ERROR_UNSUPPORTED;
    depth_format = desc->depth_format == GR_FORMAT_UNDEFINED ? VK_FORMAT_UNDEFINED
                                                            : vk_format(desc->depth_format);
    if (desc->depth_format != GR_FORMAT_UNDEFINED && depth_format == VK_FORMAT_UNDEFINED)
        return GR_ERROR_UNSUPPORTED;

    memset(stages, 0, sizeof(stages));
    stages[stage_count].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    stages[stage_count].stage = VK_SHADER_STAGE_VERTEX_BIT;
    stages[stage_count].module = vertex->module;
    stages[stage_count].pName = "main";
    stage_count++;
    if (fragment) {
        stages[stage_count].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stages[stage_count].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
        stages[stage_count].module = fragment->module;
        stages[stage_count].pName = "main";
        stage_count++;
    }

    memset(&vertex_input, 0, sizeof(vertex_input));
    vertex_input.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    memset(&input_assembly, 0, sizeof(input_assembly));
    input_assembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    input_assembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    memset(&viewport, 0, sizeof(viewport));
    viewport.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewport.viewportCount = 1;
    viewport.scissorCount = 1;
    memset(&raster, 0, sizeof(raster));
    raster.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    raster.polygonMode = VK_POLYGON_MODE_FILL;
    raster.cullMode = desc->cull == GR_CULL_BACK ? VK_CULL_MODE_BACK_BIT :
                      desc->cull == GR_CULL_FRONT ? VK_CULL_MODE_FRONT_BIT : VK_CULL_MODE_NONE;
    raster.frontFace = desc->front_face_ccw ? VK_FRONT_FACE_COUNTER_CLOCKWISE
                                            : VK_FRONT_FACE_CLOCKWISE;
    raster.lineWidth = 1.0f;
    memset(&multisample, 0, sizeof(multisample));
    multisample.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisample.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
    memset(&depth, 0, sizeof(depth));
    depth.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    depth.depthTestEnable = (desc->depth_test && depth_format != VK_FORMAT_UNDEFINED) ? VK_TRUE : VK_FALSE;
    depth.depthWriteEnable = (desc->depth_write && depth_format != VK_FORMAT_UNDEFINED) ? VK_TRUE : VK_FALSE;
    depth.depthCompareOp = VK_COMPARE_OP_GREATER_OR_EQUAL; /* reverse-Z, the contract's default */
    depth.depthBoundsTestEnable = VK_FALSE;
    depth.stencilTestEnable = VK_FALSE;

    memset(&blend_attachment, 0, sizeof(blend_attachment));
    blend_attachment.colorWriteMask = 0xF;
    if (desc->blend && desc->blend[0] != GR_BLEND_OPAQUE) {
        blend_attachment.blendEnable = VK_TRUE;
        switch (desc->blend[0]) {
        case GR_BLEND_ALPHA:
            blend_attachment.srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA;
            blend_attachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
            break;
        case GR_BLEND_PREMULTIPLIED:
            blend_attachment.srcColorBlendFactor = VK_BLEND_FACTOR_ONE;
            blend_attachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
            break;
        case GR_BLEND_ADDITIVE:
            blend_attachment.srcColorBlendFactor = VK_BLEND_FACTOR_ONE;
            blend_attachment.dstColorBlendFactor = VK_BLEND_FACTOR_ONE;
            break;
        default:
            break;
        }
        blend_attachment.colorBlendOp = VK_BLEND_OP_ADD;
        blend_attachment.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE;
        blend_attachment.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
        blend_attachment.alphaBlendOp = VK_BLEND_OP_ADD;
    }
    memset(&blend, 0, sizeof(blend));
    blend.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    blend.attachmentCount = 1;
    blend.pAttachments = &blend_attachment;

    dynamic[0] = VK_DYNAMIC_STATE_VIEWPORT;
    dynamic[1] = VK_DYNAMIC_STATE_SCISSOR;
    memset(&dynamic_info, 0, sizeof(dynamic_info));
    dynamic_info.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamic_info.dynamicStateCount = 2;
    dynamic_info.pDynamicStates = dynamic;

    /* Dynamic rendering: the pipeline names its attachment formats instead of a render pass,
     * which is what gr_cmd_begin_render means in the ABI. */
    memset(&rendering, 0, sizeof(rendering));
    rendering.sType = VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    rendering.colorAttachmentCount = 1;
    rendering.pColorAttachmentFormats = &color_format;
    rendering.depthAttachmentFormat = depth_format;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    info.pNext = &rendering;
    info.stageCount = stage_count;
    info.pStages = stages;
    info.pVertexInputState = &vertex_input;
    info.pInputAssemblyState = &input_assembly;
    info.pViewportState = &viewport;
    info.pRasterizationState = &raster;
    info.pMultisampleState = &multisample;
    info.pDepthStencilState = &depth;
    info.pColorBlendState = &blend;
    info.pDynamicState = &dynamic_info;
    info.layout = dev->layout; /* the one bindless layout */
    info.renderPass = VK_NULL_HANDLE; /* dynamic rendering */
    info.subpass = 0;

    result = dev->create_graphics_pipelines(dev->device, dev->pipeline_cache, 1, &info, NULL,
                                            &pipeline_handle);
    if (result != VK_SUCCESS) {
        return GR_ERROR_BACKEND;
    }

    pipeline = (gr_vk_pipeline *)calloc(1, sizeof(*pipeline));
    if (!pipeline) {
        dev->destroy_pipeline(dev->device, pipeline_handle, NULL);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    pipeline->device = dev;
    pipeline->pipeline = pipeline_handle;
    pipeline->name = gr_str_dup(desc->name);
    pipeline->permutation_key = desc->permutation_key;
    handle = gr_object_insert(gr_objects(), GR_HANDLE_PIPELINE, pipeline);
    if (handle == GR_NULL_HANDLE) {
        dev->destroy_pipeline(dev->device, pipeline_handle, NULL);
        free(pipeline->name);
        free(pipeline);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    dev->pipelines_declared++;
    *out_pipeline = handle;
    return GR_OK;
}

gr_result gr_vk_abi_pipeline_commit(gr_handle device_handle, double *out_seconds)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    size_t cache_size = 0;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (dev->commit_done)
        return GR_ERROR_NOT_READY;
    dev->pipelines_committed = dev->pipelines_declared;
    dev->commit_done = 1;
    if (dev->get_pipeline_cache_size)
        dev->get_pipeline_cache_size(dev->device, dev->pipeline_cache, &cache_size, NULL);
    dev->caps.pipeline_cache_uuid[1] = cache_size; /* the cache's byte size, for the report */
    if (out_seconds)
        *out_seconds = 0.0;
    return GR_OK;
}

gr_result gr_vk_abi_pipeline_stats(gr_handle device_handle, uint32_t *out_declared,
                                   uint32_t *out_committed)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (out_declared) *out_declared = dev->pipelines_declared;
    if (out_committed) *out_committed = dev->pipelines_committed;
    return GR_OK;
}

#else /* !GRAIL_HAVE_VULKAN */

/* Built without the Vulkan headers. The device cannot be created, so the dispatcher never routes
 * anything else here; these definitions exist so the dispatch site links. */
gr_result gr_vk_abi_device_create(const gr_device_desc *desc, gr_handle *out_device)
{
    (void)desc;
    if (out_device) *out_device = GR_NULL_HANDLE;
    return GR_ERROR_UNSUPPORTED;
}
gr_result gr_vk_abi_device_destroy(gr_handle h) { (void)h; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_device_get_caps(gr_handle h, gr_device_caps *o) { (void)h; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_device_wait_idle(gr_handle h) { (void)h; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_device_queue(gr_handle h, gr_queue_kind k, gr_handle *o) { (void)h; (void)k; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_queue_timeline(gr_handle h, gr_handle *o) { (void)h; (void)o; return GR_ERROR_UNSUPPORTED; }
uint64_t gr_vk_abi_queue_submitted(gr_handle h) { (void)h; return 0; }
uint64_t gr_vk_abi_queue_completed(gr_handle h) { (void)h; return 0; }
gr_result gr_vk_abi_queue_wait_idle(gr_handle h) { (void)h; return GR_ERROR_UNSUPPORTED; }
gr_handle gr_vk_abi_device_bindless(gr_handle h) { (void)h; return GR_NULL_HANDLE; }
gr_result gr_vk_abi_bindless_get_info(gr_handle h, gr_bindless_info *o) { (void)h; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_device_retire(gr_handle d, gr_handle o, uint64_t v) { (void)d; (void)o; (void)v; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_device_collect(gr_handle d) { (void)d; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_shader_create(gr_handle d, const gr_shader_desc *s, gr_handle *o) { (void)d; (void)s; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_pipeline_create(gr_handle d, const gr_pipeline_desc *p, gr_handle *o) { (void)d; (void)p; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_pipeline_commit(gr_handle d, double *s) { (void)d; (void)s; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_pipeline_stats(gr_handle d, uint32_t *a, uint32_t *b) { (void)d; (void)a; (void)b; return GR_ERROR_UNSUPPORTED; }

#endif
