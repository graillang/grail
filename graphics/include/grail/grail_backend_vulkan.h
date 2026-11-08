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
 * Required-feature evaluation and the device probe
 *
 * The probe answers one question: can this machine run the Vulkan backend at all, and if not,
 * exactly which requirement is missing. It creates an instance, enumerates physical devices and
 * their features and limits, and destroys the instance again. It creates NO device and submits
 * no work, which is why it is safe to run while the GPU is otherwise busy — but it is still run
 * under the host's exclusive GPU lock by `make -C graphics vk-probe`, because enumerating a
 * driver is not free and this host serialises every program that talks to one.
 *
 * It loads libvulkan with dlopen at run time rather than linking it, so a build machine with the
 * headers and no loader still compiles the library and gets GR_ERROR_UNSUPPORTED instead of a
 * link failure.
 * --------------------------------------------------------------------------------------- */
typedef enum gr_vk_required {
    GR_VK_REQ_DESCRIPTOR_INDEXING = 1u << 0,
    GR_VK_REQ_RUNTIME_DESCRIPTOR_ARRAY = 1u << 1,   /* unbounded arrays: the bindless table */
    GR_VK_REQ_UPDATE_AFTER_BIND = 1u << 2,
    GR_VK_REQ_PARTIALLY_BOUND = 1u << 3,
    GR_VK_REQ_VARIABLE_DESCRIPTOR_COUNT = 1u << 4,
    GR_VK_REQ_NON_UNIFORM_INDEXING = 1u << 5,
    GR_VK_REQ_BUFFER_DEVICE_ADDRESS = 1u << 6,
    GR_VK_REQ_DYNAMIC_RENDERING = 1u << 7,
    GR_VK_REQ_SYNCHRONIZATION2 = 1u << 8,
    GR_VK_REQ_TIMELINE_SEMAPHORE = 1u << 9,
    GR_VK_REQ_SCALAR_BLOCK_LAYOUT = 1u << 10,
    GR_VK_REQ_SHADER_INT16 = 1u << 11,
    GR_VK_REQ_SHADER_INT64 = 1u << 12
} gr_vk_required;

#define GR_VK_REQ_ALL ((uint32_t)(GR_VK_REQ_DESCRIPTOR_INDEXING | GR_VK_REQ_RUNTIME_DESCRIPTOR_ARRAY | \
    GR_VK_REQ_UPDATE_AFTER_BIND | GR_VK_REQ_PARTIALLY_BOUND | GR_VK_REQ_VARIABLE_DESCRIPTOR_COUNT | \
    GR_VK_REQ_NON_UNIFORM_INDEXING | GR_VK_REQ_BUFFER_DEVICE_ADDRESS | GR_VK_REQ_DYNAMIC_RENDERING | \
    GR_VK_REQ_SYNCHRONIZATION2 | GR_VK_REQ_TIMELINE_SEMAPHORE | GR_VK_REQ_SCALAR_BLOCK_LAYOUT | \
    GR_VK_REQ_SHADER_INT16 | GR_VK_REQ_SHADER_INT64))

/* The name of one required-feature bit, for a log or a report. Never NULL. */
const char *gr_vk_required_name(uint32_t bit);

typedef struct gr_vk_probe_report {
    gr_desc_head head;
    uint32_t loader_found;          /* libvulkan was loaded */
    uint32_t has_icd;               /* at least one physical device answered */
    uint32_t device_count;
    uint32_t loader_api_major, loader_api_minor, loader_api_patch;
    uint32_t instance_api_major, instance_api_minor;
    /* The bits of GR_VK_REQ_ALL this device does NOT provide. Zero means the backend can run. */
    uint32_t required_missing;
    char loader_path[128];
    /* The chosen device: the first one that provides every requirement, else the first device,
     * so a failure report still names real hardware. */
    char device_name[256];
    char driver_name[256];          /* empty when VK_KHR_driver_properties is unavailable */
    char driver_info[256];
    uint32_t vendor_id, device_id, device_type;
    uint32_t api_major, api_minor, api_patch;
    uint32_t driver_version;
    uint32_t queue_family_count;
    uint32_t graphics_family, compute_family, transfer_family; /* ~0u when absent */
    uint32_t discrete_gpu;
    uint32_t device_local_heap_bytes;
    uint32_t max_push_constants;
    uint32_t max_image_dimension_2d;
    uint32_t max_compute_workgroup_invocations;
    uint32_t max_per_stage_sampled_images;
    uint32_t max_per_stage_samplers;
    uint32_t max_per_stage_storage_buffers;
    uint32_t max_descriptor_set_sampled_images;
    uint32_t subgroup_size;
    float timestamp_period_ns;
} gr_vk_probe_report;

/* Runs the probe.
 *
 *   GR_OK                  a device was found; read required_missing to see if it can run the
 *                          backend. GR_OK with required_missing != 0 is a real answer, not a
 *                          failure of the probe.
 *   GR_ERROR_UNSUPPORTED   no loader, no ICD, or no Vulkan 1.0 instance could be created. The
 *                          report's loader_found/has_icd say which.
 *   GR_ERROR_OUT_OF_MEMORY
 *
 * A caller treats GR_ERROR_UNSUPPORTED as "skip": a machine without Vulkan is a supported state
 * for every test in this repository.
 */
gr_result gr_vk_probe_run(gr_vk_probe_report *out);

/* ---------------------------------------------------------------------------------------
 * Validation
 *
 * A device created with GR_DEVICE_VALIDATION instantiates VK_EXT_debug_utils and records what the
 * layer says, so a test can assert on it instead of on a human reading stderr. The counters are
 * cumulative for the device's lifetime; the first few messages are retained verbatim.
 *
 * This exists because a validation error is invisible to every functional check: the twelve
 * anisotropic samplers were created without the samplerAnisotropy feature for several increments
 * and nothing noticed until the layer was enabled.
 * --------------------------------------------------------------------------------------- */
#define GR_VK_VALIDATION_MESSAGES 8
#define GR_VK_VALIDATION_MESSAGE_LEN 384

typedef struct gr_vk_validation_report {
    gr_desc_head head;
    uint32_t error_count;
    uint32_t warning_count;
    uint32_t info_count;
    uint32_t message_count;  /* retained, at most GR_VK_VALIDATION_MESSAGES */
    uint32_t enabled;        /* 1 when the messenger exists (validation was requested) */
    uint32_t _reserved;
} gr_vk_validation_report;

gr_result gr_vk_validation(gr_handle device, gr_vk_validation_report *out);
/* A retained message, borrowed from the device: valid until the device is destroyed. Messages are
 * in arrival order, errors and warnings alike. */
gr_result gr_vk_validation_message(gr_handle device, uint32_t index, gr_str *out_message);

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

gr_result gr_vk_get_queue_families(gr_handle device, gr_vk_queue_families *out);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_BACKEND_VULKAN_H */
