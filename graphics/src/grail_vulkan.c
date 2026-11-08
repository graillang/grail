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
#include "grail_sdl.h"
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
    PFN_vkCreateImage create_image;
    PFN_vkDestroyImage destroy_image;
    PFN_vkGetImageMemoryRequirements get_image_requirements;
    PFN_vkAllocateMemory allocate_memory;
    PFN_vkFreeMemory free_memory;
    PFN_vkBindImageMemory bind_image_memory;
    PFN_vkCreateImageView create_image_view;
    PFN_vkDestroyImageView destroy_image_view;
    PFN_vkCreateCommandPool create_command_pool;
    PFN_vkDestroyCommandPool destroy_command_pool;
    PFN_vkAllocateCommandBuffers allocate_command_buffers;
    PFN_vkFreeCommandBuffers free_command_buffers;
    PFN_vkBeginCommandBuffer begin_command_buffer;
    PFN_vkEndCommandBuffer end_command_buffer;
    PFN_vkResetCommandBuffer reset_command_buffer;
    PFN_vkCmdPipelineBarrier cmd_pipeline_barrier;
    PFN_vkCmdBeginRendering cmd_begin_rendering;
    PFN_vkCmdEndRendering cmd_end_rendering;
    PFN_vkCmdSetViewport cmd_set_viewport;
    PFN_vkCmdSetScissor cmd_set_scissor;
    PFN_vkCmdBindPipeline cmd_bind_pipeline;
    PFN_vkCmdPushConstants cmd_push_constants;
    PFN_vkCmdDraw cmd_draw;
    PFN_vkCmdCopyImageToBuffer cmd_copy_image_to_buffer;
    PFN_vkQueueSubmit queue_submit;
    PFN_vkQueueWaitIdle queue_wait_idle;
    PFN_vkWaitSemaphores wait_semaphores;
    PFN_vkCreateBuffer create_buffer;
    PFN_vkDestroyBuffer destroy_buffer;
    PFN_vkGetBufferMemoryRequirements get_buffer_requirements;
    PFN_vkBindBufferMemory bind_buffer_memory;
    PFN_vkMapMemory map_memory;
    PFN_vkUnmapMemory unmap_memory;
    uint32_t memory_type_bits;
    /* The live table. Set 0 is allocated once for the whole device and written per resource;
     * set 1 is one dynamic uniform buffer with a slot per frame in flight. */
    VkDescriptorPool descriptor_pool;
    VkDescriptorSet desc_set0;   /* the allocated set 0; set0 is its layout */
    VkDescriptorSet desc_set1;
    VkSampler samplers[GR_SAMPLER_SLOT_COUNT];
    uint32_t sampled_next;
    uint32_t storage_next;
    uint32_t sampler_next;
    VkBuffer frame_buffer;
    VkDeviceMemory frame_memory;
    void *frame_mapped;
    uint32_t frame_slots;
    PFN_vkUpdateDescriptorSets update_descriptor_sets;
    PFN_vkCmdBindDescriptorSets cmd_bind_descriptor_sets;
    PFN_vkCreateSampler create_sampler;
    PFN_vkDestroySampler destroy_sampler;
    PFN_vkCmdCopyBufferToImage cmd_copy_buffer_to_image;
    PFN_vkGetBufferDeviceAddress get_buffer_address;
    PFN_vkCreateComputePipelines create_compute_pipelines;
    PFN_vkCmdDispatch cmd_dispatch;
} gr_vk_dev;

typedef struct gr_vk_buffer {
    gr_vk_dev *device;
    VkBuffer buffer;
    VkDeviceMemory memory;
    uint64_t size;
    uint32_t usage;
    void *mapped;
    uint32_t bindless_index;
} gr_vk_buffer;

typedef struct gr_vk_tex {
    gr_vk_dev *device;
    VkImage image;
    VkDeviceMemory memory;
    VkFormat format;
    gr_format gr_format;
    uint32_t width, height;
    uint32_t usage;
} gr_vk_tex;

typedef struct gr_vk_viewobj {
    gr_vk_dev *device;
    VkImageView view;
    gr_vk_tex *texture;
    uint32_t sampled_index;
} gr_vk_viewobj;

typedef struct gr_vk_cmdpool {
    gr_vk_dev *device;
    VkCommandPool pool;
} gr_vk_cmdpool;

typedef struct gr_vk_cmdbuf {
    gr_vk_dev *device;
    VkCommandBuffer cb;
    uint32_t recording;
    uint32_t ended;
    uint32_t frame_slot;
} gr_vk_cmdbuf;

typedef struct gr_vk_fence_obj {
    gr_vk_dev *device;
    uint64_t value;
} gr_vk_fence_obj;

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
    VkPipelineBindPoint bind_point;
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

/* Defined with the buffer path below; the barrier code needs it before then. */
static gr_vk_buffer *vk_buffer_of(gr_handle handle);

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
 * The live descriptor table
 *
 * Set 0 is allocated once with the layout's full capacities and never reallocated; resources
 * write their slot as they are created. That is what "binding never changes between passes"
 * means in practice: the set is bound with the pipeline and its contents are what change.
 * --------------------------------------------------------------------------------------- */
static VkSamplerAddressMode vk_address(gr_address_mode mode)
{
    switch (mode) {
    case GR_ADDRESS_CLAMP: return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    case GR_ADDRESS_MIRROR: return VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT;
    case GR_ADDRESS_BORDER: return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER;
    default: return VK_SAMPLER_ADDRESS_MODE_REPEAT;
    }
}

static gr_result vk_create_table(gr_vk_dev *dev)
{
    VkDescriptorPoolSize sizes[4];
    VkDescriptorPoolCreateInfo pool_info;
    VkDescriptorSetAllocateInfo allocate;
    VkDescriptorSetLayout layouts[2];
    VkSamplerCreateInfo sampler_info;
    VkBufferCreateInfo buffer_info;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo memory_info;
    uint32_t i;

    sizes[0].type = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
    sizes[0].descriptorCount = GR_BINDLESS_CAP_SAMPLED_IMAGES;
    sizes[1].type = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    sizes[1].descriptorCount = GR_BINDLESS_CAP_STORAGE_IMAGES;
    sizes[2].type = VK_DESCRIPTOR_TYPE_SAMPLER;
    sizes[2].descriptorCount = GR_BINDLESS_CAP_SAMPLERS;
    sizes[3].type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    sizes[3].descriptorCount = GR_BINDLESS_CAP_STORAGE_BUFFERS;

    memset(&pool_info, 0, sizeof(pool_info));
    pool_info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    pool_info.flags = VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT;
    pool_info.maxSets = 3;
    pool_info.poolSizeCount = 4;
    pool_info.pPoolSizes = sizes;

    /* Full-capacity allocation needs a pool that can hold every slot. A driver may refuse the
     * combined total; that is reported rather than silently shrinking the table, because a
     * smaller table would change what a shader index means. */
    {
        PFN_vkCreateDescriptorPool create_pool =
            GR_VK_DEVICE_LOAD(dev, vkCreateDescriptorPool);
        if (!create_pool || create_pool(dev->device, &pool_info, NULL, &dev->descriptor_pool) != VK_SUCCESS)
            return GR_ERROR_UNSUPPORTED;
    }

    layouts[0] = dev->set0;
    layouts[1] = dev->set1;
    memset(&allocate, 0, sizeof(allocate));
    allocate.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
    allocate.descriptorPool = dev->descriptor_pool;
    allocate.descriptorSetCount = 1;
    allocate.pSetLayouts = &layouts[0];
    if (GR_VK_DEVICE_LOAD(dev, vkAllocateDescriptorSets)(dev->device, &allocate, &dev->desc_set0) != VK_SUCCESS)
        return GR_ERROR_UNSUPPORTED;
    allocate.pSetLayouts = &layouts[1];
    if (GR_VK_DEVICE_LOAD(dev, vkAllocateDescriptorSets)(dev->device, &allocate, &dev->desc_set1) != VK_SUCCESS)
        return GR_ERROR_UNSUPPORTED;

    /* The thirteen fixed samplers, written into slots 0..12 so a shader's constant index is
     * always valid (grail_rhi.h "gr_sampler_slot"). */
    for (i = 0; i < (uint32_t)GR_SAMPLER_SLOT_COUNT; ++i) {
        const int compare = i == (uint32_t)GR_SAMPLER_SHADOW_COMPARE;
        const int reduce = i == (uint32_t)GR_SAMPLER_MIN_REDUCE || i == (uint32_t)GR_SAMPLER_MAX_REDUCE;
        const int point = i == (uint32_t)GR_SAMPLER_POINT_CLAMP || i == (uint32_t)GR_SAMPLER_POINT_WRAP;
        const int aniso = i == (uint32_t)GR_SAMPLER_ANISO_WRAP || i == (uint32_t)GR_SAMPLER_ANISO_CLAMP ||
                          i == (uint32_t)GR_SAMPLER_ANISO_CLAMP_U_WRAP_V ||
                          i == (uint32_t)GR_SAMPLER_ANISO_WRAP_U_CLAMP_V;
        const int clamp_v = i == (uint32_t)GR_SAMPLER_LINEAR_CLAMP_U_WRAP_V ||
                            i == (uint32_t)GR_SAMPLER_ANISO_CLAMP_U_WRAP_V;
        const int wrap_u = i == (uint32_t)GR_SAMPLER_LINEAR_WRAP_U_CLAMP_V ||
                           i == (uint32_t)GR_SAMPLER_ANISO_WRAP_U_CLAMP_V;
        memset(&sampler_info, 0, sizeof(sampler_info));
        sampler_info.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        sampler_info.magFilter = point ? VK_FILTER_NEAREST : VK_FILTER_LINEAR;
        sampler_info.minFilter = point ? VK_FILTER_NEAREST : VK_FILTER_LINEAR;
        sampler_info.mipmapMode = reduce ? VK_SAMPLER_MIPMAP_MODE_NEAREST : VK_SAMPLER_MIPMAP_MODE_LINEAR;
        sampler_info.addressModeU = wrap_u ? VK_SAMPLER_ADDRESS_MODE_REPEAT : VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_info.addressModeV = clamp_v ? VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE : VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_info.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_info.maxLod = 1000.0f;
        if (compare) {
            sampler_info.compareEnable = VK_TRUE;
            sampler_info.compareOp = VK_COMPARE_OP_GREATER_OR_EQUAL; /* reverse-Z */
        }
        if (aniso) {
            sampler_info.anisotropyEnable = VK_TRUE;
            sampler_info.maxAnisotropy = 16.0f;
        }
        if (dev->create_sampler(dev->device, &sampler_info, NULL, &dev->samplers[i]) != VK_SUCCESS)
            return GR_ERROR_BACKEND;
    }
    {
        VkDescriptorImageInfo infos[GR_SAMPLER_SLOT_COUNT];
        VkWriteDescriptorSet writes[GR_SAMPLER_SLOT_COUNT];
        memset(infos, 0, sizeof(infos));
        memset(writes, 0, sizeof(writes));
        for (i = 0; i < (uint32_t)GR_SAMPLER_SLOT_COUNT; ++i) {
            infos[i].sampler = dev->samplers[i];
            writes[i].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writes[i].dstSet = dev->desc_set0;
            writes[i].dstBinding = GR_BINDING_SAMPLERS;
            writes[i].dstArrayElement = i;
            writes[i].descriptorCount = 1;
            writes[i].descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER;
            writes[i].pImageInfo = &infos[i];
        }
        dev->update_descriptor_sets(dev->device, GR_SAMPLER_SLOT_COUNT, writes, 0, NULL);
        dev->sampler_next = (uint32_t)GR_SAMPLER_SLOT_COUNT;
    }

    /* The frame-constant ring: one slot per frame in flight, host-visible and coherent so a
     * caller writes straight into it. */
    dev->frame_slots = 2;
    memset(&buffer_info, 0, sizeof(buffer_info));
    buffer_info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    buffer_info.size = (uint64_t)sizeof(gr_frame_constants) * dev->frame_slots;
    buffer_info.usage = VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
    if (dev->create_buffer(dev->device, &buffer_info, NULL, &dev->frame_buffer) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    dev->get_buffer_requirements(dev->device, dev->frame_buffer, &requirements);
    {
        VkPhysicalDeviceMemoryProperties memory_properties;
        PFN_vkGetPhysicalDeviceMemoryProperties get_memory =
            (PFN_vkGetPhysicalDeviceMemoryProperties)dev->loader.gipa(dev->instance, "vkGetPhysicalDeviceMemoryProperties");
        uint32_t type = ~0u;
        if (get_memory) {
            get_memory(dev->physical, &memory_properties);
            for (i = 0; i < memory_properties.memoryTypeCount; ++i) {
                if ((requirements.memoryTypeBits & (1u << i)) &&
                    (memory_properties.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) &&
                    (memory_properties.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) {
                    type = i;
                    break;
                }
            }
        }
        if (type == ~0u)
            return GR_ERROR_UNSUPPORTED;
        memset(&memory_info, 0, sizeof(memory_info));
        memory_info.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
        memory_info.allocationSize = requirements.size;
        memory_info.memoryTypeIndex = type;
    }
    if (dev->allocate_memory(dev->device, &memory_info, NULL, &dev->frame_memory) != VK_SUCCESS ||
        dev->bind_buffer_memory(dev->device, dev->frame_buffer, dev->frame_memory, 0) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    if (dev->map_memory(dev->device, dev->frame_memory, 0, VK_WHOLE_SIZE, 0, &dev->frame_mapped) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    {
        VkDescriptorBufferInfo info;
        VkWriteDescriptorSet write;
        memset(&info, 0, sizeof(info));
        info.buffer = dev->frame_buffer;
        info.offset = 0;
        info.range = sizeof(gr_frame_constants);
        memset(&write, 0, sizeof(write));
        write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        write.dstSet = dev->desc_set1;
        write.dstBinding = GR_BINDING_FRAME_CONSTANTS;
        write.descriptorCount = 1;
        write.descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
        write.pBufferInfo = &info;
        dev->update_descriptor_sets(dev->device, 1, &write, 0, NULL);
    }
    return GR_OK;
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
    /* A window needs the platform's surface extensions, and validation needs its layer. Both are
     * decided before the instance exists, which is why the window is created first. */
    {
        const char *layers[1];
        const char *extensions[8];
        const char *const *surface_extensions = NULL;
        uint32_t layer_count = 0, extension_count = 0, surface_count = 0;

        if (desc->flags & GR_DEVICE_VALIDATION) {
            layers[layer_count++] = "VK_LAYER_KHRONOS_validation";
            extensions[extension_count++] = "VK_EXT_debug_utils";
        }
        if (!gr_handle_is_null(desc->window)) {
            if (gr_sdl_vulkan_extensions(&surface_count, &surface_extensions) != GR_OK ||
                surface_count > 6u) {
                vk_log(desc, "no platform surface extensions available for the window");
                gr_vk_loader_close(&dev->loader);
                free(dev);
                return GR_ERROR_UNSUPPORTED;
            }
            /* Indexed by the surface list, not by extension_count: the validation extensions are
             * already in front of it, so using the same counter for both would copy the wrong
             * entry — and incrementing it inside its own subscript is undefined. */
            {
                uint32_t surface_index;
                for (surface_index = 0; surface_index < surface_count && extension_count < 8u;
                     ++surface_index)
                    extensions[extension_count++] = surface_extensions[surface_index];
            }
        }
        if (gr_vk_instance_create(&dev->loader, VK_API_VERSION_1_3, layers, layer_count, extensions,
                                  extension_count, &dev->instance, &api) != GR_OK) {
            vk_log(desc, "no Vulkan instance could be created (a requested layer or extension is "
                         "not available)");
            gr_vk_loader_close(&dev->loader);
            free(dev);
            return GR_ERROR_UNSUPPORTED;
        }
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
    /* The thirteen fixed samplers include four anisotropic ones, so the feature must be on the
     * device: validation flagged exactly this (VUID-VkSamplerCreateInfo-anisotropyEnable-01070)
     * the first time the layer was enabled. */
    enable_features.features.samplerAnisotropy = features.features.samplerAnisotropy;
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
    dev->create_image = GR_VK_DEVICE_LOAD(dev, vkCreateImage);
    dev->destroy_image = GR_VK_DEVICE_LOAD(dev, vkDestroyImage);
    dev->get_image_requirements = GR_VK_DEVICE_LOAD(dev, vkGetImageMemoryRequirements);
    dev->allocate_memory = GR_VK_DEVICE_LOAD(dev, vkAllocateMemory);
    dev->free_memory = GR_VK_DEVICE_LOAD(dev, vkFreeMemory);
    dev->bind_image_memory = GR_VK_DEVICE_LOAD(dev, vkBindImageMemory);
    dev->create_image_view = GR_VK_DEVICE_LOAD(dev, vkCreateImageView);
    dev->destroy_image_view = GR_VK_DEVICE_LOAD(dev, vkDestroyImageView);
    dev->create_command_pool = GR_VK_DEVICE_LOAD(dev, vkCreateCommandPool);
    dev->destroy_command_pool = GR_VK_DEVICE_LOAD(dev, vkDestroyCommandPool);
    dev->allocate_command_buffers = GR_VK_DEVICE_LOAD(dev, vkAllocateCommandBuffers);
    dev->free_command_buffers = GR_VK_DEVICE_LOAD(dev, vkFreeCommandBuffers);
    dev->begin_command_buffer = GR_VK_DEVICE_LOAD(dev, vkBeginCommandBuffer);
    dev->end_command_buffer = GR_VK_DEVICE_LOAD(dev, vkEndCommandBuffer);
    dev->reset_command_buffer = GR_VK_DEVICE_LOAD(dev, vkResetCommandBuffer);
    dev->cmd_pipeline_barrier = GR_VK_DEVICE_LOAD(dev, vkCmdPipelineBarrier);
    dev->cmd_begin_rendering = GR_VK_DEVICE_LOAD(dev, vkCmdBeginRendering);
    dev->cmd_end_rendering = GR_VK_DEVICE_LOAD(dev, vkCmdEndRendering);
    dev->cmd_set_viewport = GR_VK_DEVICE_LOAD(dev, vkCmdSetViewport);
    dev->cmd_set_scissor = GR_VK_DEVICE_LOAD(dev, vkCmdSetScissor);
    dev->cmd_bind_pipeline = GR_VK_DEVICE_LOAD(dev, vkCmdBindPipeline);
    dev->cmd_push_constants = GR_VK_DEVICE_LOAD(dev, vkCmdPushConstants);
    dev->cmd_draw = GR_VK_DEVICE_LOAD(dev, vkCmdDraw);
    dev->cmd_copy_image_to_buffer = GR_VK_DEVICE_LOAD(dev, vkCmdCopyImageToBuffer);
    dev->queue_submit = GR_VK_DEVICE_LOAD(dev, vkQueueSubmit);
    dev->queue_wait_idle = GR_VK_DEVICE_LOAD(dev, vkQueueWaitIdle);
    dev->wait_semaphores = GR_VK_DEVICE_LOAD(dev, vkWaitSemaphores);
    dev->create_buffer = GR_VK_DEVICE_LOAD(dev, vkCreateBuffer);
    dev->destroy_buffer = GR_VK_DEVICE_LOAD(dev, vkDestroyBuffer);
    dev->get_buffer_requirements = GR_VK_DEVICE_LOAD(dev, vkGetBufferMemoryRequirements);
    dev->bind_buffer_memory = GR_VK_DEVICE_LOAD(dev, vkBindBufferMemory);
    dev->map_memory = GR_VK_DEVICE_LOAD(dev, vkMapMemory);
    dev->unmap_memory = GR_VK_DEVICE_LOAD(dev, vkUnmapMemory);
    dev->update_descriptor_sets = GR_VK_DEVICE_LOAD(dev, vkUpdateDescriptorSets);
    dev->cmd_bind_descriptor_sets = GR_VK_DEVICE_LOAD(dev, vkCmdBindDescriptorSets);
    dev->create_sampler = GR_VK_DEVICE_LOAD(dev, vkCreateSampler);
    dev->destroy_sampler = GR_VK_DEVICE_LOAD(dev, vkDestroySampler);
    dev->cmd_copy_buffer_to_image = GR_VK_DEVICE_LOAD(dev, vkCmdCopyBufferToImage);
    dev->get_buffer_address = GR_VK_DEVICE_LOAD(dev, vkGetBufferDeviceAddress);
    dev->create_compute_pipelines = GR_VK_DEVICE_LOAD(dev, vkCreateComputePipelines);
    dev->cmd_dispatch = GR_VK_DEVICE_LOAD(dev, vkCmdDispatch);
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

    /* Device-local memory type for images and buffers. Selected once; a device with no
     * device-local heap would be unusual enough to be worth a log rather than a guess. */
    {
        uint32_t t;
        dev->memory_type_bits = ~0u;
        for (t = 0; t < memory.memoryTypeCount; ++t) {
            if ((memory.memoryTypes[t].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) &&
                (memory.memoryTypes[t].propertyFlags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) == 0) {
                dev->memory_type_bits = t;
                break;
            }
        }
        if (dev->memory_type_bits == ~0u)
            dev->memory_type_bits = 0;
    }

    if (!dev->create_set_layout || !dev->create_layout || vk_create_layout(dev) != GR_OK) {
        vk_log(desc, "could not create the bindless descriptor set layouts");
        gr_vk_abi_device_destroy_impl(dev);
        return GR_ERROR_BACKEND;
    }
    if (!dev->create_buffer || !dev->allocate_memory || vk_create_table(dev) != GR_OK) {
        vk_log(desc, "could not create the descriptor pool or the frame-constant ring");
        gr_vk_abi_device_destroy_impl(dev);
        return GR_ERROR_UNSUPPORTED;
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
        /* The device keeps its own copy: submissions use it without going through the object
         * table, and an unset field here is a NULL VkQueue handed to the driver. */
        dev->graphics_queue = queue->queue;
        dev->graphics_handle = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
        if (dev->graphics_handle == GR_NULL_HANDLE) { free(queue); gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
    }
    {
        gr_vk_queue *queue = (gr_vk_queue *)calloc(1, sizeof(*queue));
        if (!queue) { gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
        queue->device = dev;
        queue->kind = GR_QUEUE_COMPUTE;
        dev->get_device_queue(dev->device, dev->compute_family, 0, &queue->queue);
        dev->compute_queue = queue->queue;
        dev->compute_handle = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
        if (dev->compute_handle == GR_NULL_HANDLE) { free(queue); gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
    }
    {
        gr_vk_queue *queue = (gr_vk_queue *)calloc(1, sizeof(*queue));
        if (!queue) { gr_vk_abi_device_destroy_impl(dev); return GR_ERROR_OUT_OF_MEMORY; }
        queue->device = dev;
        queue->kind = GR_QUEUE_TRANSFER;
        dev->get_device_queue(dev->device, dev->transfer_family, 0, &queue->queue);
        dev->transfer_queue = queue->queue;
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
        if (dev->frame_mapped && dev->unmap_memory)
            dev->unmap_memory(dev->device, dev->frame_memory);
        if (dev->frame_buffer && dev->destroy_buffer)
            dev->destroy_buffer(dev->device, dev->frame_buffer, NULL);
        if (dev->frame_memory && dev->free_memory)
            dev->free_memory(dev->device, dev->frame_memory, NULL);
        {
            uint32_t i;
            for (i = 0; i < (uint32_t)GR_SAMPLER_SLOT_COUNT; ++i)
                if (dev->samplers[i] && dev->destroy_sampler)
                    dev->destroy_sampler(dev->device, dev->samplers[i], NULL);
        }
        if (dev->descriptor_pool) {
            PFN_vkDestroyDescriptorPool destroy_pool = GR_VK_DEVICE_LOAD(dev, vkDestroyDescriptorPool);
            if (destroy_pool)
                destroy_pool(dev->device, dev->descriptor_pool, NULL);
        }
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

    /* Compute first: a compute pipeline has no vertex stage, no attachments and no raster state. */
    if (desc->shaders[GR_SHADER_STAGE_COMPUTE] != GR_NULL_HANDLE) {
        gr_vk_shader *compute = (gr_vk_shader *)gr_object_lookup(gr_objects(),
                                                                 desc->shaders[GR_SHADER_STAGE_COMPUTE],
                                                                 GR_HANDLE_SHADER, NULL);
        VkComputePipelineCreateInfo compute_info;
        VkPipelineShaderStageCreateInfo stage;
        VkPipeline compute_pipeline = VK_NULL_HANDLE;
        gr_vk_pipeline *object;
        gr_handle handle;

        if (!compute || compute->stage != GR_SHADER_STAGE_COMPUTE)
            return GR_ERROR_INVALID_HANDLE;
        if (desc->shaders[GR_SHADER_STAGE_VERTEX] != GR_NULL_HANDLE)
            return GR_ERROR_INVALID_ARGUMENT; /* a pipeline is compute or graphics, not both */
        if (desc->permutation_key != 0 && compute->permutation_key != desc->permutation_key)
            return GR_ERROR_INVALID_ARGUMENT;

        memset(&stage, 0, sizeof(stage));
        stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
        stage.module = compute->module;
        stage.pName = "main";
        memset(&compute_info, 0, sizeof(compute_info));
        compute_info.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
        compute_info.stage = stage;
        compute_info.layout = dev->layout;
        if (!dev->create_compute_pipelines)
            return GR_ERROR_UNSUPPORTED;
        if (dev->create_compute_pipelines(dev->device, dev->pipeline_cache, 1, &compute_info, NULL,
                                          &compute_pipeline) != VK_SUCCESS)
            return GR_ERROR_BACKEND;

        object = (gr_vk_pipeline *)calloc(1, sizeof(*object));
        if (!object) {
            dev->destroy_pipeline(dev->device, compute_pipeline, NULL);
            return GR_ERROR_OUT_OF_MEMORY;
        }
        object->device = dev;
        object->pipeline = compute_pipeline;
        object->bind_point = VK_PIPELINE_BIND_POINT_COMPUTE;
        object->name = gr_str_dup(desc->name);
        object->permutation_key = desc->permutation_key;
        handle = gr_object_insert(gr_objects(), GR_HANDLE_PIPELINE, object);
        if (handle == GR_NULL_HANDLE) {
            dev->destroy_pipeline(dev->device, compute_pipeline, NULL);
            free(object->name);
            free(object);
            return GR_ERROR_OUT_OF_MEMORY;
        }
        dev->pipelines_declared++;
        *out_pipeline = handle;
        return GR_OK;
    }

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
    pipeline->bind_point = VK_PIPELINE_BIND_POINT_GRAPHICS;
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

/* ---------------------------------------------------------------------------------------
 * The SDL3 surface bridge
 *
 * SDL3 needs the instance to create a VkSurfaceKHR and the backend owns the instance, so these
 * publish both sides of that handshake. Nothing here keeps the surface: the caller creates and
 * destroys it, and a swapchain built on it comes later.
 * --------------------------------------------------------------------------------------- */
gr_result gr_vk_instance(gr_handle device_handle, void **out_instance, void **out_physical)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (out_instance) *out_instance = (void *)dev->instance;
    if (out_physical) *out_physical = (void *)dev->physical;
    return GR_OK;
}

gr_result gr_vk_window_extensions(uint32_t *out_count, const char *const **out_names)
{
    return gr_sdl_vulkan_extensions(out_count, out_names);
}

gr_result gr_vk_create_surface(gr_handle device_handle, gr_handle window, void **out_surface)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_window_native native;
    uint64_t surface = 0;

    if (!dev || !out_surface)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_surface = NULL;
    if (gr_window_get_native(window, &native) != GR_OK)
        return GR_ERROR_INVALID_HANDLE;
    if (!native.handle_a)
        return GR_ERROR_UNSUPPORTED; /* a null-backend window has no platform handle */
    if (gr_sdl_vulkan_create_surface((uint64_t)(uintptr_t)dev->instance,
                                     (uint64_t)(uintptr_t)native.handle_a, &surface) != GR_OK)
        return GR_ERROR_BACKEND;
    *out_surface = (void *)(uintptr_t)surface;
    return GR_OK;
}

gr_result gr_vk_destroy_surface(gr_handle device_handle, void *surface)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (surface)
        gr_sdl_vulkan_destroy_surface((uint64_t)(uintptr_t)dev->instance,
                                      (uint64_t)(uintptr_t)surface);
    return GR_OK;
}

/* ---------------------------------------------------------------------------------------
 * Resources
 * --------------------------------------------------------------------------------------- */
static VkImageUsageFlags vk_image_usage(uint32_t usage)
{
    VkImageUsageFlags flags = 0;
    if (usage & GR_TEXTURE_USAGE_SAMPLED) flags |= VK_IMAGE_USAGE_SAMPLED_BIT;
    if (usage & GR_TEXTURE_USAGE_STORAGE) flags |= VK_IMAGE_USAGE_STORAGE_BIT;
    if (usage & GR_TEXTURE_USAGE_COLOR_ATTACHMENT) flags |= VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    if (usage & GR_TEXTURE_USAGE_DEPTH_ATTACHMENT) flags |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
    if (usage & GR_TEXTURE_USAGE_TRANSFER_SRC) flags |= VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    if (usage & GR_TEXTURE_USAGE_TRANSFER_DST) flags |= VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    return flags;
}

gr_result gr_vk_abi_texture_create(gr_handle device_handle, const gr_texture_desc *desc,
                                   gr_handle *out_texture)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_vk_tex *texture;
    VkImageCreateInfo info;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo allocate;
    gr_handle handle;

    if (!dev || !desc || !out_texture)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_texture = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_texture_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->type != GR_TEXTURE_2D || desc->samples > 1u)
        return GR_ERROR_UNSUPPORTED; /* arrays, 3D and MSAA are later increments */
    if (desc->width == 0 || desc->height == 0)
        return GR_ERROR_INVALID_ARGUMENT;

    texture = (gr_vk_tex *)calloc(1, sizeof(*texture));
    if (!texture)
        return GR_ERROR_OUT_OF_MEMORY;
    texture->device = dev;
    texture->format = vk_format(desc->format);
    texture->gr_format = desc->format;
    texture->width = desc->width;
    texture->height = desc->height;
    texture->usage = desc->usage;
    if (texture->format == VK_FORMAT_UNDEFINED) {
        free(texture);
        return GR_ERROR_UNSUPPORTED;
    }

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    info.imageType = VK_IMAGE_TYPE_2D;
    info.format = texture->format;
    info.extent.width = desc->width;
    info.extent.height = desc->height;
    info.extent.depth = 1;
    info.mipLevels = 1;
    info.arrayLayers = 1;
    info.samples = VK_SAMPLE_COUNT_1_BIT;
    info.tiling = VK_IMAGE_TILING_OPTIMAL;
    info.usage = vk_image_usage(desc->usage);
    info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    if (dev->create_image(dev->device, &info, NULL, &texture->image) != VK_SUCCESS) {
        free(texture);
        return GR_ERROR_BACKEND;
    }
    dev->get_image_requirements(dev->device, texture->image, &requirements);
    memset(&allocate, 0, sizeof(allocate));
    allocate.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocate.allocationSize = requirements.size;
    allocate.memoryTypeIndex = dev->memory_type_bits;
    if (dev->allocate_memory(dev->device, &allocate, NULL, &texture->memory) != VK_SUCCESS ||
        dev->bind_image_memory(dev->device, texture->image, texture->memory, 0) != VK_SUCCESS) {
        if (texture->memory) dev->free_memory(dev->device, texture->memory, NULL);
        dev->destroy_image(dev->device, texture->image, NULL);
        free(texture);
        return GR_ERROR_BACKEND;
    }

    handle = gr_object_insert(gr_objects(), GR_HANDLE_TEXTURE, texture);
    if (handle == GR_NULL_HANDLE) {
        dev->free_memory(dev->device, texture->memory, NULL);
        dev->destroy_image(dev->device, texture->image, NULL);
        free(texture);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_texture = handle;
    return GR_OK;
}

gr_result gr_vk_abi_texture_view_create(gr_handle device_handle, const gr_texture_view_desc *desc,
                                        gr_handle *out_view)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_vk_tex *texture;
    gr_vk_viewobj *view;
    VkImageViewCreateInfo info;
    gr_handle handle;

    if (!dev || !desc || !out_view)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_view = GR_NULL_HANDLE;
    texture = (gr_vk_tex *)gr_object_lookup(gr_objects(), desc->texture, GR_HANDLE_TEXTURE, NULL);
    if (!texture)
        return GR_ERROR_INVALID_HANDLE;

    view = (gr_vk_viewobj *)calloc(1, sizeof(*view));
    if (!view)
        return GR_ERROR_OUT_OF_MEMORY;
    view->device = dev;
    view->texture = texture;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    info.image = texture->image;
    info.viewType = VK_IMAGE_VIEW_TYPE_2D;
    info.format = texture->format;
    info.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    info.subresourceRange.levelCount = 1;
    info.subresourceRange.layerCount = 1;
    if (dev->create_image_view(dev->device, &info, NULL, &view->view) != VK_SUCCESS) {
        free(view);
        return GR_ERROR_BACKEND;
    }
    /* The view claims a slot in the sampled-image table and writes it immediately: a resource
     * and its slot are created together, so they cannot disagree. */
    if ((texture->usage & GR_TEXTURE_USAGE_SAMPLED) && dev->sampled_next < GR_BINDLESS_CAP_SAMPLED_IMAGES) {
        VkDescriptorImageInfo image_info;
        VkWriteDescriptorSet write;
        view->sampled_index = dev->sampled_next++;
        memset(&image_info, 0, sizeof(image_info));
        image_info.imageView = view->view;
        image_info.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
        memset(&write, 0, sizeof(write));
        write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        write.dstSet = dev->desc_set0;
        write.dstBinding = GR_BINDING_SAMPLED_IMAGES;
        write.dstArrayElement = view->sampled_index;
        write.descriptorCount = 1;
        write.descriptorType = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
        write.pImageInfo = &image_info;
        dev->update_descriptor_sets(dev->device, 1, &write, 0, NULL);
    } else {
        view->sampled_index = GR_BINDLESS_INDEX_NONE;
    }

    handle = gr_object_insert(gr_objects(), GR_HANDLE_TEXTURE_VIEW, view);
    if (handle == GR_NULL_HANDLE) {
        dev->destroy_image_view(dev->device, view->view, NULL);
        free(view);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_view = handle;
    return GR_OK;
}

/* A one-shot submission, waited before returning: the readback path, which is what gr_texture_read
 * means and why it is allowed to block. */
static void vk_oneshot(gr_vk_dev *dev, void (*record)(VkCommandBuffer, void *), void *user)
{
    VkCommandPoolCreateInfo pool_info;
    VkCommandPool pool = VK_NULL_HANDLE;
    VkCommandBufferAllocateInfo alloc;
    VkCommandBuffer cb = VK_NULL_HANDLE;
    VkCommandBufferBeginInfo begin;
    VkSubmitInfo submit;

    memset(&pool_info, 0, sizeof(pool_info));
    pool_info.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pool_info.queueFamilyIndex = dev->graphics_family;
    if (dev->create_command_pool(dev->device, &pool_info, NULL, &pool) != VK_SUCCESS)
        return;
    memset(&alloc, 0, sizeof(alloc));
    alloc.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc.commandPool = pool;
    alloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc.commandBufferCount = 1;
    if (dev->allocate_command_buffers(dev->device, &alloc, &cb) != VK_SUCCESS) {
        dev->destroy_command_pool(dev->device, pool, NULL);
        return;
    }
    memset(&begin, 0, sizeof(begin));
    begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    dev->begin_command_buffer(cb, &begin);
    record(cb, user);
    dev->end_command_buffer(cb);
    memset(&submit, 0, sizeof(submit));
    submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit.commandBufferCount = 1;
    submit.pCommandBuffers = &cb;
    dev->queue_submit(dev->graphics_queue, 1, &submit, VK_NULL_HANDLE);
    dev->queue_wait_idle(dev->graphics_queue);
    dev->destroy_command_pool(dev->device, pool, NULL);
}

typedef struct readback_state {
    gr_vk_tex *texture;
    VkBuffer buffer;
} readback_state;

static void vk_record_readback(VkCommandBuffer cb, void *user)
{
    readback_state *state = (readback_state *)user;
    VkBufferImageCopy region;
    VkImageMemoryBarrier barrier;
    gr_vk_dev *dev = state->texture->device;

    /* The caller has already moved the image to TRANSFER_SRC through gr_cmd_barrier; this only
     * has to make the copy visible to the host afterwards. */
    memset(&region, 0, sizeof(region));
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.layerCount = 1;
    region.imageExtent.width = state->texture->width;
    region.imageExtent.height = state->texture->height;
    region.imageExtent.depth = 1;
    dev->cmd_copy_image_to_buffer(cb, state->texture->image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                                  state->buffer, 1, &region);

    memset(&barrier, 0, sizeof(barrier));
    barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    barrier.dstAccessMask = VK_ACCESS_HOST_READ_BIT;
    barrier.image = state->texture->image;
    barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.layerCount = 1;
    dev->cmd_pipeline_barrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT,
                              VK_PIPELINE_STAGE_HOST_BIT, 0, 0, NULL, 0, NULL, 1, &barrier);
}

gr_result gr_vk_abi_texture_read(gr_handle texture_handle, uint32_t mip, uint32_t layer,
                                 uint32_t x, uint32_t y, uint32_t width, uint32_t height,
                                 gr_mut_span_u8 out)
{
    gr_vk_tex *texture = (gr_vk_tex *)gr_object_lookup(gr_objects(), texture_handle,
                                                       GR_HANDLE_TEXTURE, NULL);
    gr_vk_dev *dev;
    VkBufferCreateInfo buffer_info;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo allocate;
    VkBuffer buffer = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    readback_state state;
    void *mapped = NULL;
    uint64_t size;
    uint32_t type_index;

    if (!texture || !out.data)
        return GR_ERROR_INVALID_ARGUMENT;
    if (mip != 0 || layer != 0 || x != 0 || y != 0 || width != texture->width ||
        height != texture->height)
        return GR_ERROR_UNSUPPORTED; /* whole-image readback only, for now */
    dev = texture->device;
    size = (uint64_t)width * (uint64_t)height * 4ull;
    if (out.len < (size_t)size)
        return GR_ERROR_INVALID_ARGUMENT;

    memset(&buffer_info, 0, sizeof(buffer_info));
    buffer_info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    buffer_info.size = size;
    buffer_info.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    if (dev->create_buffer(dev->device, &buffer_info, NULL, &buffer) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    dev->get_buffer_requirements(dev->device, buffer, &requirements);
    /* This one must be host-visible, which is the whole point of a readback buffer. */
    type_index = dev->memory_type_bits;
    {
        VkPhysicalDeviceMemoryProperties memory_properties;
        PFN_vkGetPhysicalDeviceMemoryProperties get_memory =
            (PFN_vkGetPhysicalDeviceMemoryProperties)dev->loader.gipa(dev->instance,
                                                                     "vkGetPhysicalDeviceMemoryProperties");
        uint32_t t;
        if (get_memory) {
            get_memory(dev->physical, &memory_properties);
            for (t = 0; t < memory_properties.memoryTypeCount; ++t) {
                if ((requirements.memoryTypeBits & (1u << t)) &&
                    (memory_properties.memoryTypes[t].propertyFlags &
                     VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)) {
                    type_index = t;
                    break;
                }
            }
        }
    }
    memset(&allocate, 0, sizeof(allocate));
    allocate.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocate.allocationSize = requirements.size;
    allocate.memoryTypeIndex = type_index;
    if (dev->allocate_memory(dev->device, &allocate, NULL, &memory) != VK_SUCCESS ||
        dev->bind_buffer_memory(dev->device, buffer, memory, 0) != VK_SUCCESS) {
        if (memory) dev->free_memory(dev->device, memory, NULL);
        dev->destroy_buffer(dev->device, buffer, NULL);
        return GR_ERROR_BACKEND;
    }

    state.texture = texture;
    state.buffer = buffer;
    vk_oneshot(dev, vk_record_readback, &state);

    if (dev->map_memory(dev->device, memory, 0, VK_WHOLE_SIZE, 0, &mapped) == VK_SUCCESS) {
        memcpy(out.data, mapped, (size_t)size);
        dev->unmap_memory(dev->device, memory);
    }
    dev->free_memory(dev->device, memory, NULL);
    dev->destroy_buffer(dev->device, buffer, NULL);
    return mapped ? GR_OK : GR_ERROR_BACKEND;
}

/* ---------------------------------------------------------------------------------------
 * Command buffers
 * --------------------------------------------------------------------------------------- */


gr_result gr_vk_abi_cmd_pool_create(gr_handle device_handle, const gr_cmd_pool_desc *desc,
                                    gr_handle *out_pool)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_vk_cmdpool *pool;
    VkCommandPoolCreateInfo info;
    gr_handle handle;

    if (!dev || !desc || !out_pool)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pool = GR_NULL_HANDLE;
    pool = (gr_vk_cmdpool *)calloc(1, sizeof(*pool));
    if (!pool)
        return GR_ERROR_OUT_OF_MEMORY;
    pool->device = dev;
    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    info.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    info.queueFamilyIndex = dev->graphics_family;
    if (dev->create_command_pool(dev->device, &info, NULL, &pool->pool) != VK_SUCCESS) {
        free(pool);
        return GR_ERROR_BACKEND;
    }
    handle = gr_object_insert(gr_objects(), GR_HANDLE_CMD_POOL, pool);
    if (handle == GR_NULL_HANDLE) {
        dev->destroy_command_pool(dev->device, pool->pool, NULL);
        free(pool);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_pool = handle;
    return GR_OK;
}

gr_result gr_vk_abi_cmd_alloc(const gr_cmd_alloc_info *info, gr_handle *out_cmd)
{
    gr_vk_cmdpool *pool;
    gr_vk_cmdbuf *cmd;
    VkCommandBufferAllocateInfo alloc;
    gr_handle handle;

    if (!info || !out_cmd)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_cmd = GR_NULL_HANDLE;
    pool = (gr_vk_cmdpool *)gr_object_lookup(gr_objects(), info->pool, GR_HANDLE_CMD_POOL, NULL);
    if (!pool)
        return GR_ERROR_INVALID_HANDLE;
    cmd = (gr_vk_cmdbuf *)calloc(1, sizeof(*cmd));
    if (!cmd)
        return GR_ERROR_OUT_OF_MEMORY;
    cmd->device = pool->device;
    memset(&alloc, 0, sizeof(alloc));
    alloc.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc.commandPool = pool->pool;
    alloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc.commandBufferCount = 1;
    if (pool->device->allocate_command_buffers(pool->device->device, &alloc, &cmd->cb) != VK_SUCCESS) {
        free(cmd);
        return GR_ERROR_BACKEND;
    }
    handle = gr_object_insert(gr_objects(), GR_HANDLE_CMD_BUFFER, cmd);
    if (handle == GR_NULL_HANDLE) {
        free(cmd);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_cmd = handle;
    return GR_OK;
}

gr_result gr_vk_abi_cmd_begin(gr_handle cmd_handle)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    VkCommandBufferBeginInfo info;
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (cmd->recording)
        return GR_ERROR_NOT_READY;
    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    info.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    if (cmd->device->begin_command_buffer(cmd->cb, &info) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    cmd->recording = 1;
    cmd->ended = 0;
    return GR_OK;
}

gr_result gr_vk_abi_cmd_end(gr_handle cmd_handle)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if (cmd->device->end_command_buffer(cmd->cb) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    cmd->recording = 0;
    cmd->ended = 1;
    return GR_OK;
}

gr_result gr_vk_abi_cmd_push_frame_offset(gr_handle cmd_handle, uint32_t frame_slot)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if (frame_slot >= cmd->device->frame_slots)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->frame_slot = frame_slot;
    return GR_OK;
}

gr_result gr_vk_abi_cmd_reset(gr_handle cmd_handle)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (cmd->recording)
        return GR_ERROR_NOT_READY;
    if (cmd->device->reset_command_buffer(cmd->cb, 0) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    cmd->ended = 0;
    return GR_OK;
}

static VkImageLayout vk_layout(uint32_t state)
{
    switch ((gr_resource_state)state) {
    case GR_STATE_GENERAL: return VK_IMAGE_LAYOUT_GENERAL;
    case GR_STATE_SHADER_READ: return VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    case GR_STATE_COLOR_ATTACHMENT: return VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    case GR_STATE_DEPTH_ATTACHMENT_WRITE:
    case GR_STATE_DEPTH_ATTACHMENT_READ: return VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;
    case GR_STATE_TRANSFER_SRC: return VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    case GR_STATE_TRANSFER_DST: return VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    case GR_STATE_COPY_SOURCE_HOST: return VK_IMAGE_LAYOUT_GENERAL;
    default: return VK_IMAGE_LAYOUT_UNDEFINED;
    }
}

gr_result gr_vk_abi_cmd_barrier(gr_handle cmd_handle, const gr_barrier *barriers, uint32_t count)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    uint32_t i;
    if (!cmd || !barriers || count == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    for (i = 0; i < count; ++i) {
        gr_vk_tex *texture = (gr_vk_tex *)gr_object_lookup(gr_objects(), barriers[i].resource,
                                                           GR_HANDLE_TEXTURE, NULL);
        VkImageMemoryBarrier barrier;
        if (!texture) {
            /* A buffer has no layout, but it still needs the execution and access dependency:
             * without it a compute write and the host read that follows are unordered. */
            gr_vk_buffer *buffer = vk_buffer_of(barriers[i].resource);
            if (buffer) {
                VkBufferMemoryBarrier buffer_barrier;
                memset(&buffer_barrier, 0, sizeof(buffer_barrier));
                buffer_barrier.sType = VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER;
                buffer_barrier.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT;
                buffer_barrier.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
                buffer_barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                buffer_barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
                buffer_barrier.buffer = buffer->buffer;
                buffer_barrier.offset = 0;
                buffer_barrier.size = VK_WHOLE_SIZE;
                cmd->device->cmd_pipeline_barrier(cmd->cb, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                                                  VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0, NULL, 1,
                                                  &buffer_barrier, 0, NULL);
            }
            continue;
        }
        memset(&barrier, 0, sizeof(barrier));
        barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
        barrier.oldLayout = vk_layout(barriers[i].src_state);
        barrier.newLayout = vk_layout(barriers[i].dst_state);
        /* Conservative access masks: correctness first, and this is a headless test path rather
         * than a hot one. The stage masks follow the contract's pipeline-stage bits. */
        barrier.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT | VK_ACCESS_MEMORY_READ_BIT;
        barrier.dstAccessMask = VK_ACCESS_MEMORY_WRITE_BIT | VK_ACCESS_MEMORY_READ_BIT;
        barrier.image = texture->image;
        barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        barrier.subresourceRange.levelCount = 1;
        barrier.subresourceRange.layerCount = 1;
        cmd->device->cmd_pipeline_barrier(cmd->cb, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                                          VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0, NULL, 0, NULL,
                                          1, &barrier);
    }
    return GR_OK;
}

gr_result gr_vk_abi_cmd_begin_render(gr_handle cmd_handle, const gr_render_begin *info)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    VkRenderingAttachmentInfo attachments[4];
    VkRenderingInfo rendering;
    uint32_t i;
    if (!cmd || !info)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if (info->color_count == 0 || info->color_count > 4u)
        return GR_ERROR_INVALID_ARGUMENT;

    memset(attachments, 0, sizeof(attachments));
    for (i = 0; i < info->color_count; ++i) {
        gr_vk_viewobj *view = (gr_vk_viewobj *)gr_object_lookup(gr_objects(), info->colors[i].view,
                                                                GR_HANDLE_TEXTURE_VIEW, NULL);
        if (!view)
            return GR_ERROR_INVALID_HANDLE;
        attachments[i].sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
        attachments[i].imageView = view->view;
        attachments[i].imageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        attachments[i].loadOp = info->colors[i].load_op == GR_LOAD_CLEAR ? VK_ATTACHMENT_LOAD_OP_CLEAR
                                : info->colors[i].load_op == GR_LOAD_LOAD ? VK_ATTACHMENT_LOAD_OP_LOAD
                                                                          : VK_ATTACHMENT_LOAD_OP_DONT_CARE;
        attachments[i].storeOp = info->colors[i].store_op == GR_STORE_DISCARD
                                     ? VK_ATTACHMENT_STORE_OP_DONT_CARE
                                     : VK_ATTACHMENT_STORE_OP_STORE;
        attachments[i].clearValue.color.float32[0] = info->colors[i].clear[0];
        attachments[i].clearValue.color.float32[1] = info->colors[i].clear[1];
        attachments[i].clearValue.color.float32[2] = info->colors[i].clear[2];
        attachments[i].clearValue.color.float32[3] = info->colors[i].clear[3];
    }
    memset(&rendering, 0, sizeof(rendering));
    rendering.sType = VK_STRUCTURE_TYPE_RENDERING_INFO;
    rendering.renderArea.offset.x = info->render_x;
    rendering.renderArea.offset.y = info->render_y;
    rendering.renderArea.extent.width = info->render_w;
    rendering.renderArea.extent.height = info->render_h;
    rendering.layerCount = 1;
    rendering.colorAttachmentCount = info->color_count;
    rendering.pColorAttachments = attachments;
    cmd->device->cmd_begin_rendering(cmd->cb, &rendering);
    return GR_OK;
}

gr_result gr_vk_abi_cmd_end_render(gr_handle cmd_handle)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    cmd->device->cmd_end_rendering(cmd->cb);
    return GR_OK;
}

gr_result gr_vk_abi_cmd_set_viewport(gr_handle cmd_handle, float x, float y, float width,
                                     float height, float min_depth, float max_depth)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    VkViewport viewport;
    if (!cmd || !cmd->recording)
        return GR_ERROR_NOT_READY;
    viewport.x = x;
    viewport.y = y;
    viewport.width = width;
    viewport.height = height;
    viewport.minDepth = min_depth;
    viewport.maxDepth = max_depth;
    cmd->device->cmd_set_viewport(cmd->cb, 0, 1, &viewport);
    return GR_OK;
}

gr_result gr_vk_abi_cmd_set_scissor(gr_handle cmd_handle, int32_t x, int32_t y, uint32_t width,
                                    uint32_t height)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    VkRect2D scissor;
    if (!cmd || !cmd->recording)
        return GR_ERROR_NOT_READY;
    scissor.offset.x = x;
    scissor.offset.y = y;
    scissor.extent.width = width;
    scissor.extent.height = height;
    cmd->device->cmd_set_scissor(cmd->cb, 0, 1, &scissor);
    return GR_OK;
}

gr_result gr_vk_abi_cmd_bind_pipeline(gr_handle cmd_handle, gr_handle pipeline_handle)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    gr_vk_pipeline *pipeline = (gr_vk_pipeline *)gr_object_lookup(gr_objects(), pipeline_handle,
                                                                 GR_HANDLE_PIPELINE, NULL);
    if (!cmd || !pipeline)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    cmd->device->cmd_bind_pipeline(cmd->cb, pipeline->bind_point, pipeline->pipeline);
    /* Both sets are bound with the pipeline, never per draw: that is the contract's "binding
     * never changes between passes". Set 1's dynamic offset selects the frame slot. */
    {
        VkDescriptorSet sets[2];
        uint32_t offset = cmd->frame_slot * (uint32_t)sizeof(gr_frame_constants);
        sets[0] = cmd->device->desc_set0;
        sets[1] = cmd->device->desc_set1;
        cmd->device->cmd_bind_descriptor_sets(cmd->cb, pipeline->bind_point,
                                              cmd->device->layout, 0, 2, sets, 1, &offset);
    }
    return GR_OK;
}

gr_result gr_vk_abi_cmd_push_constants(gr_handle cmd_handle, uint32_t stage_mask, uint32_t offset,
                                       gr_span_u8 data)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    VkShaderStageFlags stages = 0;
    if (!cmd || !data.data)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if (offset + data.len > GR_PUSH_CONSTANT_BYTES)
        return GR_ERROR_INVALID_ARGUMENT;
    if (stage_mask & 1u) stages |= VK_SHADER_STAGE_VERTEX_BIT;   /* bit 0: vertex */
    if (stage_mask & 2u) stages |= VK_SHADER_STAGE_FRAGMENT_BIT; /* bit 1: fragment */
    if (stage_mask & 4u) stages |= VK_SHADER_STAGE_COMPUTE_BIT;
    if (stages == 0)
        stages = VK_SHADER_STAGE_ALL;
    cmd->device->cmd_push_constants(cmd->cb, cmd->device->layout, stages, offset,
                                    (uint32_t)data.len, data.data);
    return GR_OK;
}

gr_result gr_vk_abi_cmd_dispatch(gr_handle cmd_handle, uint32_t x, uint32_t y, uint32_t z)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if (x == 0 || y == 0 || z == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->device->cmd_dispatch(cmd->cb, x, y, z);
    return GR_OK;
}

gr_result gr_vk_abi_cmd_draw(gr_handle cmd_handle, const gr_draw *draw)
{
    gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), cmd_handle,
                                                         GR_HANDLE_CMD_BUFFER, NULL);
    if (!cmd || !draw)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    cmd->device->cmd_draw(cmd->cb, draw->vertex_count, draw->instance_count, draw->first_vertex,
                          draw->first_instance);
    return GR_OK;
}

/* ---------------------------------------------------------------------------------------
 * Submission and fences
 * --------------------------------------------------------------------------------------- */
gr_result gr_vk_abi_submit(const gr_submit *submit, uint64_t *out_value)
{
    gr_vk_dev *dev;
    VkSubmitInfo info;
    VkTimelineSemaphoreSubmitInfo timeline;
    VkSemaphore wait_semaphores[4];
    uint64_t wait_values[4];
    VkPipelineStageFlags wait_stages[4];
    VkCommandBuffer buffers[8];
    uint32_t i;
    uint64_t value;
    gr_vk_queue *queue;

    if (!submit)
        return GR_ERROR_INVALID_ARGUMENT;
    queue = (gr_vk_queue *)gr_object_lookup(gr_objects(), submit->queue, GR_HANDLE_QUEUE, NULL);
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    dev = queue->device;
    if (submit->cmd_count > 8u || submit->wait_count > 4u)
        return GR_ERROR_INVALID_ARGUMENT;

    for (i = 0; i < submit->cmd_count; ++i) {
        gr_vk_cmdbuf *cmd = (gr_vk_cmdbuf *)gr_object_lookup(gr_objects(), submit->cmds[i],
                                                             GR_HANDLE_CMD_BUFFER, NULL);
        if (!cmd)
            return GR_ERROR_INVALID_HANDLE;
        if (!cmd->ended)
            return GR_ERROR_NOT_READY;
        buffers[i] = cmd->cb;
    }
    for (i = 0; i < submit->wait_count; ++i) {
        wait_semaphores[i] = dev->graphics_timeline;
        wait_values[i] = submit->waits[i].value;
        wait_stages[i] = VK_PIPELINE_STAGE_ALL_COMMANDS_BIT;
    }

    value = dev->submitted + 1u;
    memset(&timeline, 0, sizeof(timeline));
    timeline.sType = VK_STRUCTURE_TYPE_TIMELINE_SEMAPHORE_SUBMIT_INFO;
    timeline.waitSemaphoreValueCount = submit->wait_count;
    timeline.pWaitSemaphoreValues = submit->wait_count ? wait_values : NULL;
    timeline.signalSemaphoreValueCount = 1;
    timeline.pSignalSemaphoreValues = &value;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    info.pNext = &timeline;
    info.waitSemaphoreCount = submit->wait_count;
    info.pWaitSemaphores = submit->wait_count ? wait_semaphores : NULL;
    info.pWaitDstStageMask = submit->wait_count ? wait_stages : NULL;
    info.commandBufferCount = submit->cmd_count;
    info.pCommandBuffers = submit->cmd_count ? buffers : NULL;
    info.signalSemaphoreCount = 1;
    info.pSignalSemaphores = &dev->graphics_timeline;

    if (dev->queue_submit(queue->queue, 1, &info, VK_NULL_HANDLE) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    dev->submitted = value;
    queue->submitted = value;
    if (out_value)
        *out_value = value;
    return GR_OK;
}

gr_result gr_vk_abi_fence_create(gr_handle device_handle, uint64_t initial_value,
                                 gr_handle *out_fence)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_vk_fence_obj *fence;
    gr_handle handle;
    if (!dev || !out_fence)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_fence = GR_NULL_HANDLE;
    fence = (gr_vk_fence_obj *)calloc(1, sizeof(*fence));
    if (!fence)
        return GR_ERROR_OUT_OF_MEMORY;
    fence->device = dev;
    fence->value = initial_value;
    handle = gr_object_insert(gr_objects(), GR_HANDLE_FENCE, fence);
    if (handle == GR_NULL_HANDLE) {
        free(fence);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_fence = handle;
    return GR_OK;
}

gr_result gr_vk_abi_fence_wait(gr_handle fence_handle, uint64_t value, uint64_t timeout_ns,
                               gr_result *out_status)
{
    gr_vk_fence_obj *fence = (gr_vk_fence_obj *)gr_object_lookup(gr_objects(), fence_handle,
                                                                 GR_HANDLE_FENCE, NULL);
    VkSemaphoreWaitInfo info;
    VkResult result;
    if (!fence)
        return GR_ERROR_INVALID_HANDLE;
    /* A real timeline wait: vkWaitSemaphores on the queue's timeline, which is the mechanism the
     * ABI exposes instead of binary semaphores. */
    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_SEMAPHORE_WAIT_INFO;
    info.semaphoreCount = 1;
    info.pSemaphores = &fence->device->graphics_timeline;
    info.pValues = &value;
    result = fence->device->wait_semaphores(fence->device->device, &info, timeout_ns);
    if (result == VK_TIMEOUT) {
        if (out_status) *out_status = GR_TIMEOUT;
        return GR_TIMEOUT;
    }
    if (result != VK_SUCCESS) {
        if (out_status) *out_status = GR_ERROR_BACKEND;
        return GR_ERROR_BACKEND;
    }
    fence->value = value;
    if (out_status) *out_status = GR_OK;
    return GR_OK;
}

uint64_t gr_vk_abi_fence_value(gr_handle fence_handle)
{
    gr_vk_fence_obj *fence = (gr_vk_fence_obj *)gr_object_lookup(gr_objects(), fence_handle,
                                                                 GR_HANDLE_FENCE, NULL);
    return fence ? fence->value : 0;
}


/* ---------------------------------------------------------------------------------------
 * Buffers, samplers, upload, and the descriptor writes that make the table live
 * --------------------------------------------------------------------------------------- */
static uint32_t vk_find_memory_type(gr_vk_dev *dev, uint32_t bits, VkMemoryPropertyFlags want)
{
    VkPhysicalDeviceMemoryProperties properties;
    PFN_vkGetPhysicalDeviceMemoryProperties get_memory =
        (PFN_vkGetPhysicalDeviceMemoryProperties)dev->loader.gipa(dev->instance,
                                                                 "vkGetPhysicalDeviceMemoryProperties");
    uint32_t i;
    if (!get_memory)
        return 0;
    get_memory(dev->physical, &properties);
    for (i = 0; i < properties.memoryTypeCount; ++i)
        if ((bits & (1u << i)) && (properties.memoryTypes[i].propertyFlags & want) == want)
            return i;
    return 0;
}

gr_result gr_vk_abi_buffer_create(gr_handle device_handle, const gr_buffer_desc *desc,
                                  gr_handle *out_buffer)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    gr_vk_buffer *buffer;
    VkBufferCreateInfo info;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo allocate;
    VkMemoryPropertyFlags properties;
    gr_handle handle;

    if (!dev || !desc || !out_buffer)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_buffer = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_buffer_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->size == 0)
        return GR_ERROR_INVALID_ARGUMENT;

    buffer = (gr_vk_buffer *)calloc(1, sizeof(*buffer));
    if (!buffer)
        return GR_ERROR_OUT_OF_MEMORY;
    buffer->device = dev;
    buffer->size = desc->size;
    buffer->usage = desc->usage;
    buffer->bindless_index = GR_BINDLESS_INDEX_NONE;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    info.size = desc->size;
    if (desc->usage & GR_BUFFER_USAGE_UNIFORM) info.usage |= VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
    if (desc->usage & GR_BUFFER_USAGE_STORAGE) info.usage |= VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
    if (desc->usage & GR_BUFFER_USAGE_VERTEX) info.usage |= VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
    if (desc->usage & GR_BUFFER_USAGE_INDEX) info.usage |= VK_BUFFER_USAGE_INDEX_BUFFER_BIT;
    if (desc->usage & GR_BUFFER_USAGE_INDIRECT) info.usage |= VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT;
    if (desc->usage & GR_BUFFER_USAGE_TRANSFER_SRC) info.usage |= VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
    if (desc->usage & GR_BUFFER_USAGE_TRANSFER_DST) info.usage |= VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    if (desc->usage & GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS)
        info.usage |= VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
    if (info.usage == 0)
        info.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    if (dev->create_buffer(dev->device, &info, NULL, &buffer->buffer) != VK_SUCCESS) {
        free(buffer);
        return GR_ERROR_BACKEND;
    }
    dev->get_buffer_requirements(dev->device, buffer->buffer, &requirements);
    properties = desc->memory == GR_MEMORY_DEVICE
                     ? VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
                     : (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    memset(&allocate, 0, sizeof(allocate));
    allocate.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocate.allocationSize = requirements.size;
    allocate.memoryTypeIndex = vk_find_memory_type(dev, requirements.memoryTypeBits, properties);
    if (dev->allocate_memory(dev->device, &allocate, NULL, &buffer->memory) != VK_SUCCESS ||
        dev->bind_buffer_memory(dev->device, buffer->buffer, buffer->memory, 0) != VK_SUCCESS) {
        if (buffer->memory) dev->free_memory(dev->device, buffer->memory, NULL);
        dev->destroy_buffer(dev->device, buffer->buffer, NULL);
        free(buffer);
        return GR_ERROR_BACKEND;
    }
    if (desc->memory != GR_MEMORY_DEVICE)
        dev->map_memory(dev->device, buffer->memory, 0, VK_WHOLE_SIZE, 0, &buffer->mapped);

    handle = gr_object_insert(gr_objects(), GR_HANDLE_BUFFER, buffer);
    if (handle == GR_NULL_HANDLE) {
        dev->free_memory(dev->device, buffer->memory, NULL);
        dev->destroy_buffer(dev->device, buffer->buffer, NULL);
        free(buffer);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    /* A buffer that can be written by a shader claims its storage-buffer slot now, exactly as a
     * sampled view claims its sampled-image slot. */
    if ((desc->usage & GR_BUFFER_USAGE_STORAGE) && dev->storage_next < GR_BINDLESS_CAP_STORAGE_BUFFERS) {
        VkDescriptorBufferInfo buffer_info;
        VkWriteDescriptorSet write;
        buffer->bindless_index = dev->storage_next++;
        memset(&buffer_info, 0, sizeof(buffer_info));
        buffer_info.buffer = buffer->buffer;
        buffer_info.offset = 0;
        buffer_info.range = desc->size;
        memset(&write, 0, sizeof(write));
        write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        write.dstSet = dev->desc_set0;
        write.dstBinding = GR_BINDING_STORAGE_BUFFERS;
        write.dstArrayElement = buffer->bindless_index;
        write.descriptorCount = 1;
        write.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        write.pBufferInfo = &buffer_info;
        dev->update_descriptor_sets(dev->device, 1, &write, 0, NULL);
    }

    *out_buffer = handle;
    return GR_OK;
}

static gr_vk_buffer *vk_buffer_of(gr_handle handle)
{
    return (gr_vk_buffer *)gr_object_lookup(gr_objects(), handle, GR_HANDLE_BUFFER, NULL);
}

gr_result gr_vk_abi_buffer_write(gr_handle buffer_handle, uint64_t offset, gr_span_u8 data)
{
    gr_vk_buffer *buffer = vk_buffer_of(buffer_handle);
    if (!buffer || (!data.data && data.len))
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset > buffer->size || (uint64_t)data.len > buffer->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->mapped)
        return GR_ERROR_UNSUPPORTED; /* device memory: needs a staging copy */
    memcpy((uint8_t *)buffer->mapped + offset, data.data, data.len);
    return GR_OK;
}

gr_result gr_vk_abi_buffer_read(gr_handle buffer_handle, uint64_t offset, gr_mut_span_u8 out)
{
    gr_vk_buffer *buffer = vk_buffer_of(buffer_handle);
    if (!buffer || (!out.data && out.len))
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset > buffer->size || (uint64_t)out.len > buffer->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->mapped)
        return GR_ERROR_UNSUPPORTED;
    memcpy(out.data, (const uint8_t *)buffer->mapped + offset, out.len);
    return GR_OK;
}

gr_result gr_vk_abi_buffer_map(gr_handle buffer_handle, void **out_ptr)
{
    gr_vk_buffer *buffer = vk_buffer_of(buffer_handle);
    if (!buffer || !out_ptr)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->mapped)
        return GR_ERROR_UNSUPPORTED;
    *out_ptr = buffer->mapped;
    return GR_OK;
}

uint64_t gr_vk_abi_buffer_device_address(gr_handle buffer_handle)
{
    gr_vk_buffer *buffer = vk_buffer_of(buffer_handle);
    VkBufferDeviceAddressInfo info;
    if (!buffer || !(buffer->usage & GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS))
        return 0;
    if (!buffer->device->get_buffer_address)
        return 0;
    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO;
    info.buffer = buffer->buffer;
    return (uint64_t)buffer->device->get_buffer_address(buffer->device->device, &info);
}

uint32_t gr_vk_abi_buffer_bindless_index(gr_handle buffer_handle)
{
    gr_vk_buffer *buffer = vk_buffer_of(buffer_handle);
    return buffer ? buffer->bindless_index : GR_BINDLESS_INDEX_NONE;
}

void gr_vk_abi_buffer_unmap(gr_handle buffer_handle)
{
    /* The mapping is the allocation and stays; unmapping a coherent upload buffer per write
     * would be a flush per frame for no benefit. */
    (void)buffer_handle;
}

gr_result gr_vk_abi_sampler_create(gr_handle device_handle, const gr_sampler_desc *desc,
                                   gr_handle *out_sampler, uint32_t *out_slot)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    VkSamplerCreateInfo info;
    VkSampler sampler = VK_NULL_HANDLE;
    VkDescriptorImageInfo image_info;
    VkWriteDescriptorSet write;
    uint32_t slot;

    if (!dev || !desc || !out_sampler)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_sampler = GR_NULL_HANDLE;
    if (out_slot)
        *out_slot = GR_BINDLESS_INDEX_NONE;
    if (dev->sampler_next >= GR_BINDLESS_CAP_SAMPLERS)
        return GR_ERROR_EXHAUSTED;
    slot = dev->sampler_next++;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    info.magFilter = desc->mag_filter == GR_FILTER_NEAREST ? VK_FILTER_NEAREST : VK_FILTER_LINEAR;
    info.minFilter = desc->min_filter == GR_FILTER_NEAREST ? VK_FILTER_NEAREST : VK_FILTER_LINEAR;
    info.mipmapMode = desc->mip_filter == GR_FILTER_NEAREST ? VK_SAMPLER_MIPMAP_MODE_NEAREST
                                                          : VK_SAMPLER_MIPMAP_MODE_LINEAR;
    info.addressModeU = vk_address(desc->address_u);
    info.addressModeV = vk_address(desc->address_v);
    info.addressModeW = vk_address(desc->address_w);
    info.maxLod = desc->max_lod > 0.0f ? desc->max_lod : 1000.0f;
    if (desc->max_anisotropy > 1.0f) {
        info.anisotropyEnable = VK_TRUE;
        info.maxAnisotropy = desc->max_anisotropy;
    }
    if (desc->reduction == GR_REDUCTION_COMPARE) {
        info.compareEnable = VK_TRUE;
        info.compareOp = VK_COMPARE_OP_GREATER_OR_EQUAL;
    }
    if (dev->create_sampler(dev->device, &info, NULL, &sampler) != VK_SUCCESS)
        return GR_ERROR_BACKEND;

    memset(&image_info, 0, sizeof(image_info));
    image_info.sampler = sampler;
    memset(&write, 0, sizeof(write));
    write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    write.dstSet = dev->desc_set0;
    write.dstBinding = GR_BINDING_SAMPLERS;
    write.dstArrayElement = slot;
    write.descriptorCount = 1;
    write.descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER;
    write.pImageInfo = &image_info;
    dev->update_descriptor_sets(dev->device, 1, &write, 0, NULL);

    /* The handle is the device's; the slot is what a shader uses. */
    *out_sampler = dev->graphics_handle; /* a stable non-null handle for the caller */
    if (out_slot)
        *out_slot = slot;
    return GR_OK;
}

/* Uploads pixel data through a staging buffer. */
typedef struct upload_state {
    gr_vk_tex *texture;
    VkBuffer staging;
    uint32_t width, height;
} upload_state;

static void vk_record_upload(VkCommandBuffer cb, void *user)
{
    upload_state *state = (upload_state *)user;
    VkImageMemoryBarrier barrier;
    VkBufferImageCopy region;
    gr_vk_dev *dev = state->texture->device;

    memset(&barrier, 0, sizeof(barrier));
    barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
    barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.srcAccessMask = 0;
    barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.image = state->texture->image;
    barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.layerCount = 1;
    dev->cmd_pipeline_barrier(cb, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                              VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, NULL, 0, NULL, 1, &barrier);

    memset(&region, 0, sizeof(region));
    region.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    region.imageSubresource.layerCount = 1;
    region.imageExtent.width = state->width;
    region.imageExtent.height = state->height;
    region.imageExtent.depth = 1;
    dev->cmd_copy_buffer_to_image(cb, state->staging, state->texture->image,
                                  VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);

    /* Leave it readable: the sample happens after this submission completes. */
    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    dev->cmd_pipeline_barrier(cb, VK_PIPELINE_STAGE_TRANSFER_BIT,
                              VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT, 0, 0, NULL, 0, NULL, 1,
                              &barrier);
}

gr_result gr_vk_abi_texture_write(gr_handle texture_handle, uint32_t mip, uint32_t layer,
                                  uint32_t x, uint32_t y, uint32_t width, uint32_t height,
                                  gr_span_u8 rows)
{
    gr_vk_tex *texture = (gr_vk_tex *)gr_object_lookup(gr_objects(), texture_handle,
                                                       GR_HANDLE_TEXTURE, NULL);
    gr_vk_dev *dev;
    VkBufferCreateInfo info;
    VkMemoryRequirements requirements;
    VkMemoryAllocateInfo allocate;
    VkBuffer staging = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    upload_state state;
    void *mapped = NULL;
    uint64_t bytes;

    if (!texture || !rows.data)
        return GR_ERROR_INVALID_ARGUMENT;
    if (mip != 0 || layer != 0 || x != 0 || y != 0 || width != texture->width ||
        height != texture->height)
        return GR_ERROR_UNSUPPORTED;
    bytes = (uint64_t)width * (uint64_t)height * 4ull;
    if (rows.len < (size_t)bytes)
        return GR_ERROR_INVALID_ARGUMENT;
    dev = texture->device;

    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    info.size = bytes;
    info.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
    if (dev->create_buffer(dev->device, &info, NULL, &staging) != VK_SUCCESS)
        return GR_ERROR_BACKEND;
    dev->get_buffer_requirements(dev->device, staging, &requirements);
    memset(&allocate, 0, sizeof(allocate));
    allocate.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocate.allocationSize = requirements.size;
    allocate.memoryTypeIndex = vk_find_memory_type(dev, requirements.memoryTypeBits,
                                                   VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                                                       VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    if (dev->allocate_memory(dev->device, &allocate, NULL, &memory) != VK_SUCCESS ||
        dev->bind_buffer_memory(dev->device, staging, memory, 0) != VK_SUCCESS ||
        dev->map_memory(dev->device, memory, 0, VK_WHOLE_SIZE, 0, &mapped) != VK_SUCCESS) {
        if (memory) dev->free_memory(dev->device, memory, NULL);
        dev->destroy_buffer(dev->device, staging, NULL);
        return GR_ERROR_BACKEND;
    }
    memcpy(mapped, rows.data, (size_t)bytes);
    dev->unmap_memory(dev->device, memory);

    state.texture = texture;
    state.staging = staging;
    state.width = width;
    state.height = height;
    vk_oneshot(dev, vk_record_upload, &state);

    dev->free_memory(dev->device, memory, NULL);
    dev->destroy_buffer(dev->device, staging, NULL);
    return GR_OK;
}

uint32_t gr_vk_abi_texture_view_bindless_sampled(gr_handle view_handle)
{
    gr_vk_viewobj *view = (gr_vk_viewobj *)gr_object_lookup(gr_objects(), view_handle,
                                                            GR_HANDLE_TEXTURE_VIEW, NULL);
    return view ? view->sampled_index : GR_BINDLESS_INDEX_NONE;
}

gr_result gr_vk_abi_frame_constants_write(gr_handle device_handle, uint32_t slot,
                                          const gr_frame_constants *constants)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    if (!dev || !constants)
        return GR_ERROR_INVALID_ARGUMENT;
    if (slot >= dev->frame_slots)
        return GR_ERROR_INVALID_ARGUMENT;
    memcpy((uint8_t *)dev->frame_mapped + (size_t)slot * sizeof(gr_frame_constants), constants,
           sizeof(gr_frame_constants));
    return GR_OK;
}

gr_result gr_vk_abi_frame_slot_count(gr_handle device_handle, uint32_t *out_count)
{
    gr_vk_dev *dev = vk_device_of(device_handle);
    if (!dev || !out_count)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_count = dev->frame_slots;
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
gr_result gr_vk_abi_texture_create(gr_handle d, const gr_texture_desc *x, gr_handle *o) { (void)d; (void)x; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_texture_view_create(gr_handle d, const gr_texture_view_desc *x, gr_handle *o) { (void)d; (void)x; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_texture_read(gr_handle t, uint32_t a, uint32_t b, uint32_t c, uint32_t e, uint32_t f, uint32_t g, gr_mut_span_u8 o) { (void)t; (void)a; (void)b; (void)c; (void)e; (void)f; (void)g; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_pool_create(gr_handle d, const gr_cmd_pool_desc *x, gr_handle *o) { (void)d; (void)x; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_alloc(const gr_cmd_alloc_info *i, gr_handle *o) { (void)i; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_begin(gr_handle c) { (void)c; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_end(gr_handle c) { (void)c; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_reset(gr_handle c) { (void)c; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_barrier(gr_handle c, const gr_barrier *b, uint32_t n) { (void)c; (void)b; (void)n; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_begin_render(gr_handle c, const gr_render_begin *i) { (void)c; (void)i; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_end_render(gr_handle c) { (void)c; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_set_viewport(gr_handle c, float x, float y, float w, float h, float n, float f) { (void)c; (void)x; (void)y; (void)w; (void)h; (void)n; (void)f; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_set_scissor(gr_handle c, int32_t x, int32_t y, uint32_t w, uint32_t h) { (void)c; (void)x; (void)y; (void)w; (void)h; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_bind_pipeline(gr_handle c, gr_handle p) { (void)c; (void)p; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_push_constants(gr_handle c, uint32_t s, uint32_t o, gr_span_u8 d) { (void)c; (void)s; (void)o; (void)d; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_draw(gr_handle c, const gr_draw *d) { (void)c; (void)d; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_cmd_dispatch(gr_handle c, uint32_t x, uint32_t y, uint32_t z) { (void)c; (void)x; (void)y; (void)z; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_submit(const gr_submit *s, uint64_t *v) { (void)s; (void)v; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_fence_create(gr_handle d, uint64_t i, gr_handle *o) { (void)d; (void)i; (void)o; return GR_ERROR_UNSUPPORTED; }
gr_result gr_vk_abi_fence_wait(gr_handle f, uint64_t v, uint64_t t, gr_result *s) { (void)f; (void)v; (void)t; (void)s; return GR_ERROR_UNSUPPORTED; }
uint64_t gr_vk_abi_fence_value(gr_handle f) { (void)f; return 0; }
gr_result gr_vk_abi_cmd_push_frame_offset(gr_handle c, uint32_t s) { (void)c; (void)s; return GR_ERROR_UNSUPPORTED; }
void gr_vk_abi_buffer_unmap(gr_handle b) { (void)b; }

#endif
