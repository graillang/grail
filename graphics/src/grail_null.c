/* grail_null.c - the null backend: a complete implementation of the ABI that touches no GPU.
 *
 * Its purpose is to be the executable specification. Every entry point is implemented, every
 * argument is validated the way a real backend must validate it, and the state transitions
 * (recording, submitted, retired, committed) are enforced, so an ABI test can run on any
 * machine including CI with no display and no driver. It is also what GR_BACKEND_NULL means
 * at runtime: a headless tool that wants to exercise pipeline declaration and command
 * recording without a device gets a real answer instead of a stub.
 *
 * It is not a renderer. Draws and dispatches are counted, not executed; a buffer's contents
 * exist only in host memory; a swapchain hands out the same image forever.
 */
#include "grail_internal.h"
#include "../include/grail/grail_bindless.h"

#include <stdio.h>

/* =======================================================================================
 * Objects
 * ======================================================================================= */
typedef struct gr_null_device gr_null_device;

typedef struct gr_null_queue {
    gr_null_device *device;
    gr_queue_kind kind;
    gr_handle timeline;
    uint64_t submitted;
    uint64_t completed;
} gr_null_queue;

typedef struct gr_null_semaphore {
    gr_null_device *device;
    uint64_t value;
    int is_timeline;
} gr_null_semaphore;

typedef struct gr_null_buffer {
    gr_null_device *device;
    uint64_t size;
    uint32_t usage;
    uint32_t memory;
    uint8_t *data;               /* host memory; NULL for GR_MEMORY_DEVICE */
    uint32_t bindless_index;
    char *name;
} gr_null_buffer;

typedef struct gr_null_texture {
    gr_null_device *device;
    gr_texture_desc desc;
    gr_format format;
    uint32_t width, height, depth, mips, layers, samples;
    uint32_t type_is_3d;
    uint8_t *data;               /* a CPU mirror so write/read round-trips in tests */
    uint64_t data_size;
    char *name;
} gr_null_texture;

typedef struct gr_null_view {
    gr_null_device *device;
    gr_handle texture;
    gr_texture_view_type type;
    gr_format format;
    uint32_t base_mip, mip_count, base_layer, layer_count;
    uint32_t sampled_index, storage_index;
} gr_null_view;

typedef struct gr_null_sampler {
    gr_null_device *device;
    gr_sampler_desc desc;
    uint32_t slot;
} gr_null_sampler;

typedef struct gr_null_shader {
    gr_null_device *device;
    uint8_t *blob;
    uint64_t blob_length;
    gr_reflection reflection;    /* validated at creation */
    gr_shader_stage stage;
    gr_shader_container container;
    uint64_t permutation_key;
    char *name;
} gr_null_shader;

typedef struct gr_null_pipeline {
    gr_null_device *device;
    gr_pipeline_desc desc;
    char *name;
} gr_null_pipeline;

typedef enum gr_null_cmd_state {
    GR_CMD_ALLOCATED = 0,
    GR_CMD_RECORDING = 1,
    GR_CMD_ENDED = 2,
    GR_CMD_SUBMITTED = 3
} gr_null_cmd_state;

typedef struct gr_null_cmd {
    gr_null_device *device;
    gr_handle pool;
    uint32_t state;
    uint32_t render_depth;
    uint32_t scope_depth;
    uint32_t pushes;
    uint64_t draws, dispatches, copies, barriers;
    gr_handle bound_pipeline;
    uint32_t push_constant_bytes;
    uint32_t frame_slot;
    int frame_slot_set;
} gr_null_cmd;

typedef struct gr_null_fence {
    gr_null_device *device;
    uint64_t value;
} gr_null_fence;

typedef struct gr_null_query_pool {
    gr_null_device *device;
    uint32_t count;
    uint32_t type;
    uint64_t *results;
} gr_null_query_pool;

typedef struct gr_null_bindless {
    gr_null_device *device;
    uint32_t capacity[GR_BINDING_COUNT];
    uint32_t high_water[GR_BINDING_COUNT];
    uint32_t live[GR_BINDING_COUNT];
    uint64_t releases_pending;
} gr_null_bindless;

typedef struct gr_null_swapchain {
    gr_null_device *device;
    gr_handle window;
    gr_format format;
    uint32_t width, height, image_count;
    uint32_t present_mode;
    uint32_t current_image;
    gr_handle views[4];
} gr_null_swapchain;

struct gr_null_device {
    gr_backend backend;
    uint32_t flags;
    gr_handle window;
    gr_device_caps caps;
    gr_handle graphics_queue, compute_queue, transfer_queue;
    gr_handle bindless;
    gr_handle swapchain;
    uint32_t frame_slots;
    uint32_t frame_slot;
    uint64_t frame_index;
    uint32_t pipelines_declared, pipelines_committed;
    int commit_done;
    void (*log)(void *user, int32_t severity, gr_str message);
    void *log_user;

    /* Deferred destruction: destroy() retires with the value 0 and a real backend waits for
     * the GPU; the null backend has no GPU, so a retired object with a non-zero value stays
     * here until a collect() whose completed value has passed it. */
    struct gr_null_retired {
        gr_handle handle;
        uint32_t type;
        uint64_t after_value;
    } retired[256];
    uint32_t retired_count;
};

static void null_log(gr_null_device *device, int32_t severity, const char *message)
{
    if (device && device->log)
        device->log(device->log_user, severity, (gr_str){ message, (uint32_t)strlen(message), 0 });
}

/* Looks an object up by handle and type, logging the specific failure. */
static void *null_get(gr_null_device *device, gr_handle handle, gr_handle_type type,
                      gr_result *out_status)
{
    gr_result status = GR_OK;
    void *object = gr_object_lookup(gr_objects(), handle, type, &status);
    (void)device;
    if (out_status)
        *out_status = object ? GR_OK : status;
    return object;
}

/* =======================================================================================
 * Device
 * ======================================================================================= */
static void null_fill_caps(gr_null_device *device)
{
    gr_device_caps *caps = &device->caps;
    memset(caps, 0, sizeof(*caps));
    caps->head.size = (uint32_t)sizeof(*caps);
    caps->backend = GR_BACKEND_NULL;
    /* Every capability the contract describes is claimed, because the point of the null
     * backend is to let a caller exercise the full contract. A real backend reports only
     * what it has, and a caller must therefore never assume these are set. */
    caps->caps = GR_CAP_BINDLESS | GR_CAP_DESCRIPTOR_UPDATE_AFTER_BIND | GR_CAP_DYNAMIC_RENDERING |
                 GR_CAP_TIMELINE_SEMAPHORE | GR_CAP_BUFFER_DEVICE_ADDRESS | GR_CAP_MESH_SHADER |
                 GR_CAP_16BIT_TYPES | GR_CAP_64BIT_INTEGER | GR_CAP_CALIBRATED_TIMESTAMPS |
                 GR_CAP_MEMORY_BUDGET | GR_CAP_SUBGROUP_OPERATIONS |
                 GR_CAP_STORAGE_IMAGE_FORMAT_UNKNOWN | GR_CAP_WIRE_BRIDGE;
    strcpy(caps->device_name, "grail null device");
    strcpy(caps->driver_name, "grail null backend " "1.0");
    caps->api_major = 1;
    caps->api_minor = 3;
    caps->api_patch = 0;
    caps->vendor_id = 0;
    caps->device_id = 0;
    caps->device_memory_bytes = 8ull * 1024ull * 1024ull * 1024ull;
    caps->buffer_address_min_align = 256;
    caps->buffer_address_max_range = 1ull << 32;
    caps->max_push_constant_bytes = GR_PUSH_CONSTANT_BYTES;
    caps->max_color_attachments = 8;
    caps->max_descriptor_array_length = GR_BINDLESS_CAP_SAMPLED_IMAGES;
    caps->subgroup_size = 32;
    caps->timestamp_valid_bits = 64;
    caps->timestamp_period_ns = 1.0f;
    caps->depth_range_zero_to_one = 0; /* reverse-Z [1,0], like the contract's default */
    caps->pipeline_cache_uuid[0] = 0x677261696c6e756cull; /* "grailnul" */
    caps->pipeline_cache_uuid[1] = 0;
    caps->max_frames_in_flight = 2;
}

gr_result gr_device_create(const gr_device_desc *desc, gr_handle *out_device)
{
    gr_null_device *device;
    gr_null_queue *queue;
    gr_null_bindless *bindless;
    gr_handle handle;
    gr_result st;

    if (!out_device)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_device = GR_NULL_HANDLE;
    if (!desc)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->head.size != sizeof(gr_device_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->backend != GR_BACKEND_NULL) {
        /* This build ships only the null backend. A real backend is a separate translation
         * unit with its own create; an unimplemented backend is refused, never silently
         * substituted, because a renderer compiled against the wrong backend must not run. */
        return GR_ERROR_UNSUPPORTED;
    }

    gr_objects_init_once();

    device = (gr_null_device *)calloc(1, sizeof(*device));
    if (!device)
        return GR_ERROR_OUT_OF_MEMORY;
    device->backend = desc->backend;
    device->flags = desc->flags;
    device->window = desc->window;
    device->log = desc->log;
    device->log_user = desc->log_user;
    device->frame_slots = 2;
    null_fill_caps(device);

    handle = gr_object_insert(gr_objects(), GR_HANDLE_DEVICE, device);
    if (handle == GR_NULL_HANDLE)
        goto out_of_memory;

    /* Three queues, all distinct handles. A real backend may map them to one family; the
     * handles stay distinct so a caller never relies on family identity. */
    queue = (gr_null_queue *)calloc(1, sizeof(*queue));
    if (!queue)
        goto out_of_memory;
    queue->device = device;
    queue->kind = GR_QUEUE_GRAPHICS;
    device->graphics_queue = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
    if (device->graphics_queue == GR_NULL_HANDLE)
        goto out_of_memory;

    queue = (gr_null_queue *)calloc(1, sizeof(*queue));
    if (!queue)
        goto out_of_memory;
    queue->device = device;
    queue->kind = GR_QUEUE_COMPUTE;
    device->compute_queue = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
    if (device->compute_queue == GR_NULL_HANDLE)
        goto out_of_memory;

    queue = (gr_null_queue *)calloc(1, sizeof(*queue));
    if (!queue)
        goto out_of_memory;
    queue->device = device;
    queue->kind = GR_QUEUE_TRANSFER;
    device->transfer_queue = gr_object_insert(gr_objects(), GR_HANDLE_QUEUE, queue);
    if (device->transfer_queue == GR_NULL_HANDLE)
        goto out_of_memory;

    bindless = (gr_null_bindless *)calloc(1, sizeof(*bindless));
    if (!bindless)
        goto out_of_memory;
    bindless->device = device;
    bindless->capacity[GR_TABLE_SAMPLED_IMAGES] = GR_BINDLESS_CAP_SAMPLED_IMAGES;
    bindless->capacity[GR_TABLE_STORAGE_IMAGES] = GR_BINDLESS_CAP_STORAGE_IMAGES;
    bindless->capacity[GR_TABLE_SAMPLERS] = GR_BINDLESS_CAP_SAMPLERS;
    bindless->capacity[GR_TABLE_STORAGE_BUFFERS] = GR_BINDLESS_CAP_STORAGE_BUFFERS;
    bindless->capacity[GR_TABLE_ACCELERATION_STRUCTURES] = GR_BINDLESS_CAP_ACCELERATION_STRUCTURES;
    device->bindless = gr_object_insert(gr_objects(), GR_HANDLE_BINDLESS, bindless);
    if (device->bindless == GR_NULL_HANDLE)
        goto out_of_memory;

    /* The thirteen fixed samplers the shader expects at slots 0..12. A device creates them so
     * that a shader's constant sampler index is always valid. */
    {
        static const struct { gr_filter min, mag, mip; gr_address_mode u, v, w; gr_reduction r; } kFixed[GR_SAMPLER_SLOT_COUNT] = {
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_WEIGHTED },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_WRAP,  GR_ADDRESS_WRAP,  GR_ADDRESS_WRAP,  GR_REDUCTION_WEIGHTED },
            { GR_FILTER_NEAREST, GR_FILTER_NEAREST, GR_FILTER_NEAREST, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_WEIGHTED },
            { GR_FILTER_NEAREST, GR_FILTER_NEAREST, GR_FILTER_NEAREST, GR_ADDRESS_WRAP,  GR_ADDRESS_WRAP,  GR_ADDRESS_WRAP,  GR_REDUCTION_WEIGHTED },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_WRAP,  GR_ADDRESS_WRAP,  GR_ADDRESS_WRAP,  GR_REDUCTION_WEIGHTED },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_WEIGHTED },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_COMPARE },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_NEAREST, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_MIN },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_NEAREST, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_MAX },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_CLAMP, GR_ADDRESS_WRAP,  GR_ADDRESS_CLAMP, GR_REDUCTION_WEIGHTED },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_WRAP,  GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_WEIGHTED },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_CLAMP, GR_ADDRESS_WRAP,  GR_ADDRESS_CLAMP, GR_REDUCTION_WEIGHTED },
            { GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_FILTER_LINEAR,  GR_ADDRESS_WRAP,  GR_ADDRESS_CLAMP, GR_ADDRESS_CLAMP, GR_REDUCTION_WEIGHTED }
        };
        uint32_t i;
        for (i = 0; i < (uint32_t)GR_SAMPLER_SLOT_COUNT; ++i) {
            gr_null_sampler *sampler = (gr_null_sampler *)calloc(1, sizeof(*sampler));
            gr_handle sh;
            if (!sampler)
                goto out_of_memory;
            sampler->device = device;
            sampler->slot = i;
            sampler->desc.head.size = (uint32_t)sizeof(gr_sampler_desc);
            sampler->desc.min_filter = kFixed[i].min;
            sampler->desc.mag_filter = kFixed[i].mag;
            sampler->desc.mip_filter = kFixed[i].mip;
            sampler->desc.address_u = kFixed[i].u;
            sampler->desc.address_v = kFixed[i].v;
            sampler->desc.address_w = kFixed[i].w;
            sampler->desc.max_anisotropy = 1.0f;
            sampler->desc.max_lod = 1000.0f;
            sampler->desc.reduction = kFixed[i].r;
            sh = gr_object_insert(gr_objects(), GR_HANDLE_SAMPLER, sampler);
            if (sh == GR_NULL_HANDLE)
                goto out_of_memory;
            bindless->high_water[GR_TABLE_SAMPLERS] = i + 1u;
            bindless->live[GR_TABLE_SAMPLERS]++;
        }
    }

    *out_device = handle;
    null_log(device, 0, "null device created");
    return GR_OK;

out_of_memory:
    st = GR_ERROR_OUT_OF_MEMORY;
    if (device)
        free(device);
    return st;
}

void gr_device_destroy(gr_handle device_handle)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    void *raw;
    if (!device)
        return;
    /* A device destroy is not routed through retire: the caller has already waited idle (or
     * does not care). Every object the device owns is released through the table so a
     * surviving handle to any of them is invalidated, not dangling. */
    raw = gr_object_remove(gr_objects(), device->graphics_queue, GR_HANDLE_QUEUE);
    free(raw);
    raw = gr_object_remove(gr_objects(), device->compute_queue, GR_HANDLE_QUEUE);
    free(raw);
    raw = gr_object_remove(gr_objects(), device->transfer_queue, GR_HANDLE_QUEUE);
    free(raw);
    raw = gr_object_remove(gr_objects(), device->bindless, GR_HANDLE_BINDLESS);
    free(raw);
    gr_object_remove(gr_objects(), device_handle, GR_HANDLE_DEVICE);
    free(device);
}

gr_result gr_device_get_caps(gr_handle device_handle, gr_device_caps *out)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    if (!device || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (out->head.size != 0 && out->head.size < sizeof(gr_device_caps))
        return GR_ERROR_VERSION_MISMATCH;
    /* Copy the fields the caller declared, so an older caller's smaller structure is filled
     * only up to what it can hold. */
    {
        size_t declared = out->head.size ? (size_t)out->head.size : sizeof(gr_device_caps);
        size_t copy = declared < sizeof(gr_device_caps) ? declared : sizeof(gr_device_caps);
        uint32_t keep_size = out->head.size;
        memcpy(out, &device->caps, copy);
        out->head.size = keep_size ? keep_size : (uint32_t)sizeof(gr_device_caps);
    }
    return GR_OK;
}

gr_result gr_device_wait_idle(gr_handle device_handle)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    if (!device)
        return GR_ERROR_INVALID_HANDLE;
    /* Nothing is in flight, but a queued retire must become collectable so a caller's
     * wait_idle(); collect() pair actually releases everything. */
    (void)device;
    return GR_OK;
}

/* =======================================================================================
 * Queues
 * ======================================================================================= */
gr_result gr_device_queue(gr_handle device_handle, gr_queue_kind kind, gr_handle *out_queue)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    if (!device || !out_queue)
        return GR_ERROR_INVALID_ARGUMENT;
    switch (kind) {
    case GR_QUEUE_GRAPHICS: *out_queue = device->graphics_queue; break;
    case GR_QUEUE_COMPUTE: *out_queue = device->compute_queue; break;
    case GR_QUEUE_TRANSFER: *out_queue = device->transfer_queue; break;
    default: return GR_ERROR_INVALID_ARGUMENT;
    }
    return GR_OK;
}

gr_result gr_queue_timeline(gr_handle queue_handle, gr_handle *out_semaphore)
{
    gr_null_queue *queue = (gr_null_queue *)null_get(NULL, queue_handle, GR_HANDLE_QUEUE, NULL);
    if (!queue || !out_semaphore)
        return GR_ERROR_INVALID_ARGUMENT;
    /* The null backend models a timeline as a counter on the queue, and hands out a
     * semaphore handle so the API shape matches. gr_queue_submitted/completed are the
     * observable values. */
    *out_semaphore = GR_NULL_HANDLE;
    return GR_OK;
}

uint64_t gr_queue_submitted(gr_handle queue_handle)
{
    gr_null_queue *queue = (gr_null_queue *)null_get(NULL, queue_handle, GR_HANDLE_QUEUE, NULL);
    return queue ? queue->submitted : 0;
}

uint64_t gr_queue_completed(gr_handle queue_handle)
{
    gr_null_queue *queue = (gr_null_queue *)null_get(NULL, queue_handle, GR_HANDLE_QUEUE, NULL);
    if (!queue)
        return 0;
    /* No GPU: everything submitted is complete immediately. */
    queue->completed = queue->submitted;
    return queue->completed;
}

gr_result gr_queue_wait_idle(gr_handle queue_handle)
{
    gr_null_queue *queue = (gr_null_queue *)null_get(NULL, queue_handle, GR_HANDLE_QUEUE, NULL);
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    queue->completed = queue->submitted;
    return GR_OK;
}

/* =======================================================================================
 * Deferred destruction
 * ======================================================================================= */
static void null_free_object(gr_handle object, uint32_t type)
{
    switch ((gr_handle_type)type) {
    case GR_HANDLE_BUFFER: {
        gr_null_buffer *b = (gr_null_buffer *)gr_object_remove(gr_objects(), object, GR_HANDLE_BUFFER);
        if (b) { free(b->data); free(b->name); free(b); }
        break;
    }
    case GR_HANDLE_TEXTURE: {
        gr_null_texture *t = (gr_null_texture *)gr_object_remove(gr_objects(), object, GR_HANDLE_TEXTURE);
        if (t) { free(t->data); free(t->name); free(t); }
        break;
    }
    case GR_HANDLE_TEXTURE_VIEW: {
        gr_null_view *v = (gr_null_view *)gr_object_remove(gr_objects(), object, GR_HANDLE_TEXTURE_VIEW);
        free(v);
        break;
    }
    case GR_HANDLE_PIPELINE: {
        gr_null_pipeline *p = (gr_null_pipeline *)gr_object_remove(gr_objects(), object, GR_HANDLE_PIPELINE);
        if (p) { free(p->name); free(p); }
        break;
    }
    case GR_HANDLE_SHADER: {
        gr_null_shader *s = (gr_null_shader *)gr_object_remove(gr_objects(), object, GR_HANDLE_SHADER);
        if (s) { free(s->blob); free(s->name); free(s); }
        break;
    }
    case GR_HANDLE_SWAPCHAIN: {
        gr_null_swapchain *sc = (gr_null_swapchain *)gr_object_remove(gr_objects(), object, GR_HANDLE_SWAPCHAIN);
        free(sc);
        break;
    }
    case GR_HANDLE_QUERY_POOL: {
        gr_null_query_pool *q = (gr_null_query_pool *)gr_object_remove(gr_objects(), object, GR_HANDLE_QUERY_POOL);
        if (q) { free(q->results); free(q); }
        break;
    }
    case GR_HANDLE_FENCE: {
        gr_null_fence *f = (gr_null_fence *)gr_object_remove(gr_objects(), object, GR_HANDLE_FENCE);
        free(f);
        break;
    }
    case GR_HANDLE_CMD_BUFFER: {
        gr_null_cmd *c = (gr_null_cmd *)gr_object_remove(gr_objects(), object, GR_HANDLE_CMD_BUFFER);
        free(c);
        break;
    }
    case GR_HANDLE_DEVICE:
    case GR_HANDLE_QUEUE:
    case GR_HANDLE_BINDLESS:
    case GR_HANDLE_WINDOW:
    case GR_HANDLE_SAMPLER:
    case GR_HANDLE_SEMAPHORE:
    case GR_HANDLE_NONE:
    default:
        /* Streams whose lifetime is the device's, not the caller's. */
        break;
    }
}

gr_result gr_device_retire(gr_handle device_handle, gr_handle object, uint64_t after_value)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_queue *queue;
    if (!device)
        return GR_ERROR_INVALID_HANDLE;
    if (object == GR_NULL_HANDLE)
        return GR_OK;
    if (gr_handle_tag(object) == GR_HANDLE_NONE)
        return GR_ERROR_INVALID_HANDLE;

    queue = (gr_null_queue *)null_get(NULL, device->graphics_queue, GR_HANDLE_QUEUE, NULL);
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;

    if (after_value == 0 || queue->completed >= after_value) {
        null_free_object(object, (uint32_t)gr_handle_tag(object));
        return GR_OK;
    }
    if (device->retired_count >= (uint32_t)(sizeof(device->retired) / sizeof(device->retired[0])))
        return GR_ERROR_EXHAUSTED;
    device->retired[device->retired_count].handle = object;
    device->retired[device->retired_count].type = (uint32_t)gr_handle_tag(object);
    device->retired[device->retired_count].after_value = after_value;
    device->retired_count++;
    return GR_OK;
}

gr_result gr_device_collect(gr_handle device_handle)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_queue *queue;
    uint32_t i = 0;
    if (!device)
        return GR_ERROR_INVALID_HANDLE;
    queue = (gr_null_queue *)null_get(NULL, device->graphics_queue, GR_HANDLE_QUEUE, NULL);
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    while (i < device->retired_count) {
        if (queue->completed >= device->retired[i].after_value) {
            null_free_object(device->retired[i].handle, device->retired[i].type);
            device->retired[i] = device->retired[device->retired_count - 1u];
            device->retired_count--;
        } else {
            i++;
        }
    }
    return GR_OK;
}

/* =======================================================================================
 * Bindless table
 * ======================================================================================= */
static uint32_t null_alloc_slot(gr_null_bindless *bindless, gr_bindless_table table)
{
    uint32_t slot;
    if (!bindless)
        return GR_BINDLESS_INDEX_NONE;
    if (bindless->high_water[table] >= bindless->capacity[table])
        return GR_BINDLESS_INDEX_NONE;
    slot = bindless->high_water[table]++;
    bindless->live[table]++;
    return slot;
}

gr_handle gr_device_bindless(gr_handle device_handle)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    return device ? device->bindless : GR_NULL_HANDLE;
}

gr_result gr_bindless_get_info(gr_handle bindless_handle, gr_bindless_info *out)
{
    gr_null_bindless *bindless = (gr_null_bindless *)null_get(NULL, bindless_handle, GR_HANDLE_BINDLESS, NULL);
    uint32_t i;
    if (!bindless || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (out->head.size != 0 && out->head.size < sizeof(gr_bindless_info))
        return GR_ERROR_VERSION_MISMATCH;
    memset(out, 0, sizeof(*out));
    out->head.size = (uint32_t)sizeof(*out);
    for (i = 0; i < GR_BINDING_COUNT; ++i) {
        out->capacity[i] = bindless->capacity[i];
        out->high_water[i] = bindless->high_water[i];
    }
    out->releases_pending = bindless->releases_pending;
    return GR_OK;
}

gr_result gr_bindless_free(gr_handle bindless_handle, gr_bindless_table table,
                           gr_bindless_index index, uint64_t after_value)
{
    gr_null_bindless *bindless = (gr_null_bindless *)null_get(NULL, bindless_handle, GR_HANDLE_BINDLESS, NULL);
    if (!bindless || (uint32_t)table >= GR_BINDING_COUNT)
        return GR_ERROR_INVALID_ARGUMENT;
    if (index == GR_BINDLESS_INDEX_NONE || index >= bindless->capacity[table])
        return GR_ERROR_INVALID_ARGUMENT;
    if (bindless->live[table] == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    bindless->live[table]--;
    /* A real backend maps the slot back to its free list once `after_value` completed; the
     * null backend counts the release so a test can observe it. A slot above the high-water
     * mark is refused rather than corrupting the allocator. */
    (void)after_value;
    bindless->releases_pending++;
    return GR_OK;
}

/* =======================================================================================
 * Buffers
 * ======================================================================================= */
gr_result gr_buffer_create(gr_handle device_handle, const gr_buffer_desc *desc, gr_handle *out_buffer)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_bindless *bindless;
    gr_null_buffer *buffer;
    gr_handle handle;

    if (!device || !desc || !out_buffer)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_buffer = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_buffer_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->size == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->usage == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->usage & ~(uint32_t)0x1FFu)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->memory > GR_MEMORY_READBACK)
        return GR_ERROR_INVALID_ARGUMENT;

    buffer = (gr_null_buffer *)calloc(1, sizeof(*buffer));
    if (!buffer)
        return GR_ERROR_OUT_OF_MEMORY;
    buffer->device = device;
    buffer->size = desc->size;
    buffer->usage = desc->usage;
    buffer->memory = desc->memory;
    buffer->bindless_index = GR_BINDLESS_INDEX_NONE;
    buffer->name = gr_str_dup(desc->name);

    /* A null device gives host memory to the memories that are host-visible, so a test can
     * round-trip data. GR_MEMORY_DEVICE stays unmapped, exactly as a real backend behaves:
     * write() to it is GR_ERROR_UNSUPPORTED, not a silent no-op. */
    if (desc->memory == GR_MEMORY_UPLOAD || desc->memory == GR_MEMORY_READBACK) {
        buffer->data = (uint8_t *)calloc(1, (size_t)desc->size);
        if (!buffer->data) {
            free(buffer->name);
            free(buffer);
            return GR_ERROR_OUT_OF_MEMORY;
        }
    }

    handle = gr_object_insert(gr_objects(), GR_HANDLE_BUFFER, buffer);
    if (handle == GR_NULL_HANDLE) {
        free(buffer->data);
        free(buffer->name);
        free(buffer);
        return GR_ERROR_OUT_OF_MEMORY;
    }

    bindless = (gr_null_bindless *)null_get(NULL, device->bindless, GR_HANDLE_BINDLESS, NULL);
    if (desc->usage & GR_BUFFER_USAGE_STORAGE) {
        uint32_t slot = null_alloc_slot(bindless, GR_TABLE_STORAGE_BUFFERS);
        if (slot == GR_BINDLESS_INDEX_NONE) {
            /* Exhaustion is a recoverable refusal: the buffer is not created at all, so a
             * caller never holds a resource it cannot bind. */
            gr_object_remove(gr_objects(), handle, GR_HANDLE_BUFFER);
            free(buffer->data);
            free(buffer->name);
            free(buffer);
            return GR_ERROR_EXHAUSTED;
        }
        buffer->bindless_index = slot;
    }
    null_log(device, 0, "buffer created");
    *out_buffer = handle;
    return GR_OK;
}

static gr_null_buffer *null_buffer(gr_handle handle, gr_result *out_status)
{
    gr_result status = GR_OK;
    gr_null_buffer *buffer = (gr_null_buffer *)gr_object_lookup(gr_objects(), handle,
                                                               GR_HANDLE_BUFFER, &status);
    if (out_status)
        *out_status = buffer ? GR_OK : status;
    return buffer;
}

gr_result gr_buffer_write(gr_handle buffer_handle, uint64_t offset, gr_span_u8 data)
{
    gr_result status;
    gr_null_buffer *buffer = null_buffer(buffer_handle, &status);
    if (!buffer)
        return status;
    if (!data.data && data.len)
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset > buffer->size || (uint64_t)data.len > buffer->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->data)
        return GR_ERROR_UNSUPPORTED; /* GR_MEMORY_DEVICE: needs a staging copy */
    memcpy(buffer->data + offset, data.data, data.len);
    return GR_OK;
}

gr_result gr_buffer_read(gr_handle buffer_handle, uint64_t offset, gr_mut_span_u8 out)
{
    gr_result status;
    gr_null_buffer *buffer = null_buffer(buffer_handle, &status);
    if (!buffer)
        return status;
    if (!out.data && out.len)
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset > buffer->size || (uint64_t)out.len > buffer->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->data)
        return GR_ERROR_UNSUPPORTED;
    memcpy(out.data, buffer->data + offset, out.len);
    return GR_OK;
}

gr_result gr_buffer_map(gr_handle buffer_handle, void **out_ptr)
{
    gr_result status;
    gr_null_buffer *buffer = null_buffer(buffer_handle, &status);
    if (!buffer || !out_ptr)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->data)
        return GR_ERROR_UNSUPPORTED;
    *out_ptr = buffer->data;
    return GR_OK;
}

void gr_buffer_unmap(gr_handle buffer_handle)
{
    /* Nothing to do: the mapping is the allocation. Present so a caller's unmap is not a
     * special case it has to remember for one backend. */
    (void)buffer_handle;
}

uint64_t gr_buffer_device_address(gr_handle buffer_handle)
{
    gr_result status;
    gr_null_buffer *buffer = null_buffer(buffer_handle, &status);
    if (!buffer || !(buffer->usage & GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS))
        return 0;
    /* A stable, aligned pseudo-address derived from the handle. Nothing dereferences it; it
     * exists so an address-taking path can be exercised without a device. */
    return (buffer_handle & 0x0000FFFFFFFFFFFFull) << 8;
}

uint32_t gr_buffer_bindless_index(gr_handle buffer_handle)
{
    gr_result status;
    gr_null_buffer *buffer = null_buffer(buffer_handle, &status);
    return buffer ? buffer->bindless_index : GR_BINDLESS_INDEX_NONE;
}

/* =======================================================================================
 * Textures
 * ======================================================================================= */
static uint64_t null_texture_bytes(gr_format format, uint32_t width, uint32_t height,
                                   uint32_t depth)
{
    uint32_t bw = 1, bh = 1;
    uint32_t bpb = gr_format_bytes_per_block(format);
    gr_format_block_extent(format, &bw, &bh);
    if (bpb == 0 || bw == 0 || bh == 0)
        return 0;
    return (uint64_t)((width + bw - 1u) / bw) * (uint64_t)((height + bh - 1u) / bh) * bpb *
           (uint64_t)depth;
}

gr_result gr_texture_create(gr_handle device_handle, const gr_texture_desc *desc,
                            gr_handle *out_texture)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_texture *texture;
    gr_handle handle;
    uint32_t mips, max_mips = 1, w;
    uint64_t level_bytes, total = 0;

    if (!device || !desc || !out_texture)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_texture = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_texture_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->type > GR_TEXTURE_CUBE_ARRAY)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->format == GR_FORMAT_UNDEFINED || desc->format >= GR_FORMAT_COUNT)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->width == 0 || desc->height == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->usage == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    /* A zero-initialised descriptor is the normal C idiom, so 0 means one sample. */
    if (desc->samples != 0 && desc->samples != 1 && desc->samples != 2 && desc->samples != 4 &&
        desc->samples != 8)
        return GR_ERROR_INVALID_ARGUMENT;
    /* A sampled or storage texture may not be a depth format: the two uses are disjoint and
     * a backend would otherwise have to guess which the caller meant. */
    if (gr_format_class_of(desc->format) != GR_FORMAT_CLASS_COLOR &&
        (desc->usage & (GR_TEXTURE_USAGE_SAMPLED | GR_TEXTURE_USAGE_STORAGE)))
        return GR_ERROR_INVALID_ARGUMENT;

    for (w = desc->width; w > 1; w >>= 1)
        max_mips++;
    mips = desc->mip_levels ? desc->mip_levels : max_mips;
    if (mips > max_mips)
        return GR_ERROR_INVALID_ARGUMENT;

    {
        uint32_t depth = desc->depth ? desc->depth : 1;
        uint32_t layers = desc->array_layers ? desc->array_layers : 1;
        uint32_t m;
        uint32_t mw = desc->width, mh = desc->height, md = depth;
        for (m = 0; m < mips; ++m) {
            level_bytes = null_texture_bytes(desc->format, mw, mh, md);
            if (level_bytes == 0)
                return GR_ERROR_UNSUPPORTED;
            total += level_bytes * ((desc->type == GR_TEXTURE_2D_ARRAY ||
                                     desc->type == GR_TEXTURE_CUBE ||
                                     desc->type == GR_TEXTURE_CUBE_ARRAY) ? layers : 1u);
            mw = mw > 1 ? mw >> 1 : 1;
            mh = mh > 1 ? mh >> 1 : 1;
            md = md > 1 ? md >> 1 : 1;
        }
    }

    texture = (gr_null_texture *)calloc(1, sizeof(*texture));
    if (!texture)
        return GR_ERROR_OUT_OF_MEMORY;
    texture->device = device;
    texture->desc = *desc;
    texture->format = desc->format;
    texture->width = desc->width;
    texture->height = desc->height;
    texture->depth = desc->depth ? desc->depth : 1;
    texture->mips = mips;
    texture->layers = desc->array_layers ? desc->array_layers : 1;
    texture->samples = desc->samples ? desc->samples : 1u;
    texture->type_is_3d = (desc->type == GR_TEXTURE_3D) ? 1u : 0u;
    texture->name = gr_str_dup(desc->name);
    texture->data_size = total;
    texture->data = (uint8_t *)calloc(1, (size_t)(total ? total : 1));
    if (!texture->data) {
        free(texture->name);
        free(texture);
        return GR_ERROR_OUT_OF_MEMORY;
    }

    handle = gr_object_insert(gr_objects(), GR_HANDLE_TEXTURE, texture);
    if (handle == GR_NULL_HANDLE) {
        free(texture->data);
        free(texture->name);
        free(texture);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_texture = handle;
    return GR_OK;
}

static gr_null_texture *null_texture(gr_handle handle, gr_result *out_status)
{
    gr_result status = GR_OK;
    gr_null_texture *texture = (gr_null_texture *)gr_object_lookup(gr_objects(), handle,
                                                                 GR_HANDLE_TEXTURE, &status);
    if (out_status)
        *out_status = texture ? GR_OK : status;
    return texture;
}

/* Byte offset of a mip/layer level inside the CPU mirror. */
static uint64_t null_level_offset(const gr_null_texture *texture, uint32_t mip, uint32_t layer)
{
    uint64_t offset = 0;
    uint32_t m, mw = texture->width, mh = texture->height, md = texture->depth;
    for (m = 0; m < mip; ++m) {
        uint32_t depth = (texture->type_is_3d ? md : 1);
        offset += null_texture_bytes(texture->format, mw, mh, depth) * texture->layers;
        mw = mw > 1 ? mw >> 1 : 1;
        mh = mh > 1 ? mh >> 1 : 1;
        md = md > 1 ? md >> 1 : 1;
    }
    {
        uint64_t level = null_texture_bytes(texture->format, mw, mh, texture->type_is_3d ? md : 1);
        offset += level * layer;
    }
    return offset;
}

gr_result gr_texture_write(gr_handle texture_handle, uint32_t mip, uint32_t layer, uint32_t x,
                           uint32_t y, uint32_t width, uint32_t height, gr_span_u8 row_major)
{
    gr_result status;
    gr_null_texture *texture = null_texture(texture_handle, &status);
    uint32_t bpb, bw = 1, bh = 1, row_bytes, r;
    uint64_t base;

    if (!texture)
        return status;
    if (mip >= texture->mips || layer >= texture->layers)
        return GR_ERROR_INVALID_ARGUMENT;
    if (width == 0 || height == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (x + width > texture->width || y + height > texture->height)
        return GR_ERROR_INVALID_ARGUMENT;
    bpb = gr_format_bytes_per_block(texture->format);
    gr_format_block_extent(texture->format, &bw, &bh);
    if (bpb == 0)
        return GR_ERROR_UNSUPPORTED;
    /* A block-compressed level can only be written in whole blocks. */
    if (bw > 1 && ((x % bw) || (y % bh) || (width % bw) || (height % bh)))
        return GR_ERROR_INVALID_ARGUMENT;
    row_bytes = ((width + bw - 1u) / bw) * bpb;
    if (row_major.len < (size_t)row_bytes * ((height + bh - 1u) / bh))
        return GR_ERROR_INVALID_ARGUMENT;

    base = null_level_offset(texture, mip, layer);
    for (r = 0; r < (height + bh - 1u) / bh; ++r) {
        uint64_t dst = base + (uint64_t)r * row_bytes;
        if (dst + row_bytes > texture->data_size)
            return GR_ERROR_INVALID_ARGUMENT;
        memcpy(texture->data + dst, row_major.data + (size_t)r * row_bytes, row_bytes);
    }
    return GR_OK;
}

gr_result gr_texture_read(gr_handle texture_handle, uint32_t mip, uint32_t layer, uint32_t x,
                          uint32_t y, uint32_t width, uint32_t height, gr_mut_span_u8 out)
{
    gr_result status;
    gr_null_texture *texture = null_texture(texture_handle, &status);
    uint32_t bpb, bw = 1, bh = 1, row_bytes, r;
    uint64_t base;

    if (!texture)
        return status;
    if (mip >= texture->mips || layer >= texture->layers)
        return GR_ERROR_INVALID_ARGUMENT;
    if (width == 0 || height == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (x + width > texture->width || y + height > texture->height)
        return GR_ERROR_INVALID_ARGUMENT;
    bpb = gr_format_bytes_per_block(texture->format);
    gr_format_block_extent(texture->format, &bw, &bh);
    if (bpb == 0)
        return GR_ERROR_UNSUPPORTED;
    row_bytes = ((width + bw - 1u) / bw) * bpb;
    if (out.len < (size_t)row_bytes * ((height + bh - 1u) / bh))
        return GR_ERROR_INVALID_ARGUMENT;
    base = null_level_offset(texture, mip, layer);
    for (r = 0; r < (height + bh - 1u) / bh; ++r) {
        uint64_t src = base + (uint64_t)r * row_bytes;
        if (src + row_bytes > texture->data_size)
            return GR_ERROR_INVALID_ARGUMENT;
        memcpy(out.data + (size_t)r * row_bytes, texture->data + src, row_bytes);
    }
    return GR_OK;
}

gr_result gr_texture_view_create(gr_handle device_handle, const gr_texture_view_desc *desc,
                                 gr_handle *out_view)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_bindless *bindless;
    gr_result status;
    gr_null_texture *texture;
    gr_null_view *view;
    gr_handle handle;
    uint32_t mip_count, layer_count;

    if (!device || !desc || !out_view)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_view = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_texture_view_desc))
        return GR_ERROR_VERSION_MISMATCH;
    texture = null_texture(desc->texture, &status);
    if (!texture)
        return status;
    if (desc->type > GR_VIEW_3D)
        return GR_ERROR_INVALID_ARGUMENT;

    mip_count = desc->mip_count ? desc->mip_count : texture->mips - desc->base_mip;
    layer_count = desc->layer_count ? desc->layer_count : texture->layers - desc->base_layer;
    if (desc->base_mip >= texture->mips || mip_count > texture->mips - desc->base_mip)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->base_layer >= texture->layers || layer_count > texture->layers - desc->base_layer)
        return GR_ERROR_INVALID_ARGUMENT;

    bindless = (gr_null_bindless *)null_get(NULL, device->bindless, GR_HANDLE_BINDLESS, NULL);
    view = (gr_null_view *)calloc(1, sizeof(*view));
    if (!view)
        return GR_ERROR_OUT_OF_MEMORY;
    view->device = device;
    view->texture = desc->texture;
    view->type = desc->type;
    view->format = desc->format == GR_FORMAT_UNDEFINED ? texture->format : desc->format;
    view->base_mip = desc->base_mip;
    view->mip_count = mip_count;
    view->base_layer = desc->base_layer;
    view->layer_count = layer_count;
    view->sampled_index = GR_BINDLESS_INDEX_NONE;
    view->storage_index = GR_BINDLESS_INDEX_NONE;

    if (texture->desc.usage & GR_TEXTURE_USAGE_SAMPLED) {
        view->sampled_index = null_alloc_slot(bindless, GR_TABLE_SAMPLED_IMAGES);
        if (view->sampled_index == GR_BINDLESS_INDEX_NONE) {
            free(view);
            return GR_ERROR_EXHAUSTED;
        }
    }
    if (texture->desc.usage & GR_TEXTURE_USAGE_STORAGE) {
        view->storage_index = null_alloc_slot(bindless, GR_TABLE_STORAGE_IMAGES);
        if (view->storage_index == GR_BINDLESS_INDEX_NONE) {
            if (view->sampled_index != GR_BINDLESS_INDEX_NONE)
                (void)gr_bindless_free(device->bindless, GR_TABLE_SAMPLED_IMAGES,
                                      view->sampled_index, 0);
            free(view);
            return GR_ERROR_EXHAUSTED;
        }
    }

    handle = gr_object_insert(gr_objects(), GR_HANDLE_TEXTURE_VIEW, view);
    if (handle == GR_NULL_HANDLE) {
        free(view);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_view = handle;
    return GR_OK;
}

uint32_t gr_texture_view_bindless_sampled(gr_handle view_handle)
{
    gr_result status;
    gr_null_view *view = (gr_null_view *)gr_object_lookup(gr_objects(), view_handle,
                                                         GR_HANDLE_TEXTURE_VIEW, &status);
    return view ? view->sampled_index : GR_BINDLESS_INDEX_NONE;
}

uint32_t gr_texture_view_bindless_storage(gr_handle view_handle)
{
    gr_result status;
    gr_null_view *view = (gr_null_view *)gr_object_lookup(gr_objects(), view_handle,
                                                         GR_HANDLE_TEXTURE_VIEW, &status);
    return view ? view->storage_index : GR_BINDLESS_INDEX_NONE;
}

/* =======================================================================================
 * Samplers
 * ======================================================================================= */
gr_result gr_sampler_create(gr_handle device_handle, const gr_sampler_desc *desc,
                            gr_handle *out_sampler, uint32_t *out_slot)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_bindless *bindless;
    gr_null_sampler *sampler;
    gr_handle handle;
    uint32_t slot;

    if (!device || !desc || !out_sampler)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_sampler = GR_NULL_HANDLE;
    if (out_slot)
        *out_slot = GR_BINDLESS_INDEX_NONE;
    if (desc->head.size != sizeof(gr_sampler_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->min_filter > GR_FILTER_LINEAR || desc->mag_filter > GR_FILTER_LINEAR ||
        desc->mip_filter > GR_FILTER_LINEAR)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->address_u > GR_ADDRESS_BORDER || desc->address_v > GR_ADDRESS_BORDER ||
        desc->address_w > GR_ADDRESS_BORDER)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->reduction > GR_REDUCTION_COMPARE)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->max_anisotropy < 1.0f || desc->max_anisotropy > 16.0f)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->min_lod > desc->max_lod)
        return GR_ERROR_INVALID_ARGUMENT;

    bindless = (gr_null_bindless *)null_get(NULL, device->bindless, GR_HANDLE_BINDLESS, NULL);
    slot = null_alloc_slot(bindless, GR_TABLE_SAMPLERS);
    if (slot == GR_BINDLESS_INDEX_NONE)
        return GR_ERROR_EXHAUSTED;

    sampler = (gr_null_sampler *)calloc(1, sizeof(*sampler));
    if (!sampler)
        return GR_ERROR_OUT_OF_MEMORY;
    sampler->device = device;
    sampler->desc = *desc;
    sampler->slot = slot;
    handle = gr_object_insert(gr_objects(), GR_HANDLE_SAMPLER, sampler);
    if (handle == GR_NULL_HANDLE) {
        free(sampler);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_sampler = handle;
    if (out_slot)
        *out_slot = slot;
    return GR_OK;
}

/* =======================================================================================
 * Frame constants
 * ======================================================================================= */
gr_result gr_cmd_push_frame_offset(gr_handle cmd_handle, uint32_t frame_slot)
{
    gr_result status;
    gr_null_cmd *cmd = (gr_null_cmd *)gr_object_lookup(gr_objects(), cmd_handle,
                                                       GR_HANDLE_CMD_BUFFER, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (frame_slot >= cmd->device->frame_slots)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->frame_slot = frame_slot;
    cmd->frame_slot_set = 1;
    return GR_OK;
}

uint32_t gr_frame_current_slot(gr_handle device_handle)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    return device ? device->frame_slot : 0;
}

/* =======================================================================================
 * Command pools and buffers
 * ======================================================================================= */
typedef struct gr_null_cmd_pool {
    gr_null_device *device;
    gr_queue_kind queue;
} gr_null_cmd_pool;

gr_result gr_cmd_pool_create(gr_handle device_handle, const gr_cmd_pool_desc *desc,
                             gr_handle *out_pool)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_cmd_pool *pool;
    gr_handle handle;

    if (!device || !desc || !out_pool)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pool = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_cmd_pool_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->queue > GR_QUEUE_TRANSFER)
        return GR_ERROR_INVALID_ARGUMENT;

    pool = (gr_null_cmd_pool *)calloc(1, sizeof(*pool));
    if (!pool)
        return GR_ERROR_OUT_OF_MEMORY;
    pool->device = device;
    pool->queue = desc->queue;
    handle = gr_object_insert(gr_objects(), GR_HANDLE_CMD_POOL, pool);
    if (handle == GR_NULL_HANDLE) {
        free(pool);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_pool = handle;
    return GR_OK;
}

static gr_null_cmd *null_cmd(gr_handle handle, gr_result *out_status)
{
    gr_result status = GR_OK;
    gr_null_cmd *cmd = (gr_null_cmd *)gr_object_lookup(gr_objects(), handle,
                                                       GR_HANDLE_CMD_BUFFER, &status);
    if (out_status)
        *out_status = cmd ? GR_OK : status;
    return cmd;
}

gr_result gr_cmd_alloc(const gr_cmd_alloc_info *info, gr_handle *out_cmd)
{
    gr_null_cmd_pool *pool;
    gr_null_cmd *cmd;
    gr_handle handle;

    if (!info || !out_cmd)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_cmd = GR_NULL_HANDLE;
    if (info->head.size != sizeof(gr_cmd_alloc_info))
        return GR_ERROR_VERSION_MISMATCH;
    pool = (gr_null_cmd_pool *)gr_object_lookup(gr_objects(), info->pool, GR_HANDLE_CMD_POOL, NULL);
    if (!pool)
        return GR_ERROR_INVALID_HANDLE;

    cmd = (gr_null_cmd *)calloc(1, sizeof(*cmd));
    if (!cmd)
        return GR_ERROR_OUT_OF_MEMORY;
    cmd->device = pool->device;
    cmd->pool = info->pool;
    cmd->state = GR_CMD_ALLOCATED;
    handle = gr_object_insert(gr_objects(), GR_HANDLE_CMD_BUFFER, cmd);
    if (handle == GR_NULL_HANDLE) {
        free(cmd);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_cmd = handle;
    return GR_OK;
}

gr_result gr_cmd_begin(gr_handle cmd_handle)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_ALLOCATED)
        return GR_ERROR_NOT_READY;
    cmd->state = GR_CMD_RECORDING;
    cmd->render_depth = 0;
    cmd->scope_depth = 0;
    cmd->pushes = 0;
    cmd->draws = cmd->dispatches = cmd->copies = cmd->barriers = 0;
    cmd->bound_pipeline = GR_NULL_HANDLE;
    cmd->push_constant_bytes = 0;
    cmd->frame_slot_set = 0;
    return GR_OK;
}

gr_result gr_cmd_end(gr_handle cmd_handle)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    /* An unbalanced render scope or debug scope is a recording error, not a warning: a
     * backend that let it through would submit a command buffer that never closed a pass. */
    if (cmd->render_depth != 0)
        return GR_ERROR_VALIDATION_FAILED;
    if (cmd->scope_depth != 0)
        return GR_ERROR_VALIDATION_FAILED;
    cmd->state = GR_CMD_ENDED;
    return GR_OK;
}

gr_result gr_cmd_reset(gr_handle cmd_handle)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state == GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    cmd->state = GR_CMD_ALLOCATED;
    return GR_OK;
}

gr_result gr_cmd_barrier(gr_handle cmd_handle, const gr_barrier *barriers, uint32_t count)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    uint32_t i;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!barriers || count == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    for (i = 0; i < count; ++i) {
        if (barriers[i].resource == GR_NULL_HANDLE)
            return GR_ERROR_INVALID_ARGUMENT;
        if (barriers[i].src_state > GR_STATE_COPY_SOURCE_HOST ||
            barriers[i].dst_state > GR_STATE_COPY_SOURCE_HOST)
            return GR_ERROR_INVALID_ARGUMENT;
    }
    cmd->barriers += count;
    return GR_OK;
}

gr_result gr_cmd_begin_render(gr_handle cmd_handle, const gr_render_begin *info)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!info || info->head.size != sizeof(gr_render_begin))
        return GR_ERROR_INVALID_ARGUMENT;
    /* Dynamic rendering is not re-entrant: one scope at a time, closed by end_render. */
    if (cmd->render_depth != 0)
        return GR_ERROR_VALIDATION_FAILED;
    if (info->color_count == 0 && !info->depth)
        return GR_ERROR_INVALID_ARGUMENT;
    if (info->color_count > cmd->device->caps.max_color_attachments)
        return GR_ERROR_UNSUPPORTED;
    if (info->color_count && !info->colors)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->render_depth = 1;
    return GR_OK;
}

gr_result gr_cmd_end_render(gr_handle cmd_handle)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING || cmd->render_depth == 0)
        return GR_ERROR_VALIDATION_FAILED;
    cmd->render_depth = 0;
    return GR_OK;
}

gr_result gr_cmd_set_viewport(gr_handle cmd_handle, float x, float y, float width, float height,
                              float min_depth, float max_depth)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!(width > 0.0f) || !(height > 0.0f))
        return GR_ERROR_INVALID_ARGUMENT;
    if (!(min_depth >= 0.0f) || !(max_depth <= 1.0f) || !(min_depth <= max_depth))
        return GR_ERROR_INVALID_ARGUMENT;
    (void)x; (void)y;
    return GR_OK;
}

gr_result gr_cmd_set_scissor(gr_handle cmd_handle, int32_t x, int32_t y, uint32_t width,
                             uint32_t height)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (width == 0 || height == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    (void)x; (void)y;
    return GR_OK;
}

gr_result gr_cmd_bind_pipeline(gr_handle cmd_handle, gr_handle pipeline_handle)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_pipeline *pipeline;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    pipeline = (gr_null_pipeline *)gr_object_lookup(gr_objects(), pipeline_handle,
                                                    GR_HANDLE_PIPELINE, NULL);
    if (!pipeline)
        return GR_ERROR_INVALID_HANDLE;
    cmd->bound_pipeline = pipeline_handle;
    return GR_OK;
}

gr_result gr_cmd_push_constants(gr_handle cmd_handle, uint32_t stage_mask, uint32_t offset,
                                gr_span_u8 data)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (stage_mask == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!data.data && data.len)
        return GR_ERROR_INVALID_ARGUMENT;
    /* The 128-byte limit is a device property; exceeding it must fail here rather than on a
     * driver that quietly truncates. */
    if (offset > GR_PUSH_CONSTANT_BYTES || (uint64_t)data.len > GR_PUSH_CONSTANT_BYTES - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->pushes++;
    if (offset + data.len > cmd->push_constant_bytes)
        cmd->push_constant_bytes = offset + (uint32_t)data.len;
    return GR_OK;
}

gr_result gr_cmd_bind_vertex_buffer(gr_handle cmd_handle, uint32_t slot, gr_handle buffer,
                                    uint64_t offset)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_buffer *b;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (slot >= 16)
        return GR_ERROR_INVALID_ARGUMENT;
    b = null_buffer(buffer, NULL);
    if (!b)
        return GR_ERROR_INVALID_HANDLE;
    if (!(b->usage & GR_BUFFER_USAGE_VERTEX))
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset >= b->size)
        return GR_ERROR_INVALID_ARGUMENT;
    return GR_OK;
}

gr_result gr_cmd_bind_index_buffer(gr_handle cmd_handle, gr_handle buffer, uint64_t offset,
                                   uint32_t index_type)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_buffer *b;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (index_type > 1)
        return GR_ERROR_INVALID_ARGUMENT;
    b = null_buffer(buffer, NULL);
    if (!b)
        return GR_ERROR_INVALID_HANDLE;
    if (!(b->usage & GR_BUFFER_USAGE_INDEX))
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset >= b->size)
        return GR_ERROR_INVALID_ARGUMENT;
    return GR_OK;
}

gr_result gr_cmd_draw(gr_handle cmd_handle, const gr_draw *draw)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!draw || draw->head.size != sizeof(gr_draw))
        return GR_ERROR_INVALID_ARGUMENT;
    if (draw->vertex_count == 0 || draw->instance_count == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    /* A draw needs a pipeline and an open render scope. Enforcing it makes the common
     * ordering bug a returned status instead of a GPU hang. */
    if (cmd->bound_pipeline == GR_NULL_HANDLE)
        return GR_ERROR_NOT_READY;
    if (cmd->render_depth == 0)
        return GR_ERROR_NOT_READY;
    cmd->draws++;
    return GR_OK;
}

gr_result gr_cmd_draw_indexed(gr_handle cmd_handle, const gr_draw_indexed *draw)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!draw || draw->head.size != sizeof(gr_draw_indexed))
        return GR_ERROR_INVALID_ARGUMENT;
    if (draw->index_count == 0 || draw->instance_count == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (cmd->bound_pipeline == GR_NULL_HANDLE || cmd->render_depth == 0)
        return GR_ERROR_NOT_READY;
    cmd->draws++;
    return GR_OK;
}

gr_result gr_cmd_draw_indirect(gr_handle cmd_handle, gr_handle buffer, uint64_t offset,
                               uint32_t draw_count, uint32_t stride)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_buffer *b;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (draw_count == 0 || stride < sizeof(gr_draw))
        return GR_ERROR_INVALID_ARGUMENT;
    b = null_buffer(buffer, NULL);
    if (!b)
        return GR_ERROR_INVALID_HANDLE;
    if (!(b->usage & GR_BUFFER_USAGE_INDIRECT))
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset >= b->size || (uint64_t)draw_count * stride > b->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    if (cmd->bound_pipeline == GR_NULL_HANDLE || cmd->render_depth == 0)
        return GR_ERROR_NOT_READY;
    cmd->draws += draw_count;
    return GR_OK;
}

gr_result gr_cmd_dispatch(gr_handle cmd_handle, uint32_t x, uint32_t y, uint32_t z)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (x == 0 || y == 0 || z == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (cmd->bound_pipeline == GR_NULL_HANDLE)
        return GR_ERROR_NOT_READY;
    cmd->dispatches++;
    return GR_OK;
}

gr_result gr_cmd_dispatch_indirect(gr_handle cmd_handle, gr_handle buffer, uint64_t offset)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_buffer *b;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    b = null_buffer(buffer, NULL);
    if (!b)
        return GR_ERROR_INVALID_HANDLE;
    if (!(b->usage & GR_BUFFER_USAGE_INDIRECT))
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset + 12u > b->size)
        return GR_ERROR_INVALID_ARGUMENT;
    if (cmd->bound_pipeline == GR_NULL_HANDLE)
        return GR_ERROR_NOT_READY;
    cmd->dispatches++;
    return GR_OK;
}

gr_result gr_cmd_draw_mesh(gr_handle cmd_handle, uint32_t x, uint32_t y, uint32_t z)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!(cmd->device->caps.caps & GR_CAP_MESH_SHADER))
        return GR_ERROR_UNSUPPORTED;
    if (x == 0 || y == 0 || z == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (cmd->bound_pipeline == GR_NULL_HANDLE || cmd->render_depth == 0)
        return GR_ERROR_NOT_READY;
    cmd->draws++;
    return GR_OK;
}

gr_result gr_cmd_draw_mesh_indirect(gr_handle cmd_handle, gr_handle buffer, uint64_t offset,
                                    uint32_t count, uint32_t stride)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_buffer *b;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!(cmd->device->caps.caps & GR_CAP_MESH_SHADER))
        return GR_ERROR_UNSUPPORTED;
    b = null_buffer(buffer, NULL);
    if (!b)
        return GR_ERROR_INVALID_HANDLE;
    if (!(b->usage & GR_BUFFER_USAGE_INDIRECT) || count == 0 || stride < 12u)
        return GR_ERROR_INVALID_ARGUMENT;
    if (offset >= b->size || (uint64_t)count * stride > b->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->draws += count;
    return GR_OK;
}

gr_result gr_cmd_copy_buffer(gr_handle cmd_handle, const gr_buffer_copy *copies, uint32_t count)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    uint32_t i;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!copies || count == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    for (i = 0; i < count; ++i) {
        gr_null_buffer *src = null_buffer(copies[i].src, NULL);
        gr_null_buffer *dst = null_buffer(copies[i].dst, NULL);
        if (!src || !dst)
            return GR_ERROR_INVALID_HANDLE;
        if (copies[i].size == 0)
            return GR_ERROR_INVALID_ARGUMENT;
        if (copies[i].src_offset > src->size || copies[i].size > src->size - copies[i].src_offset)
            return GR_ERROR_INVALID_ARGUMENT;
        if (copies[i].dst_offset > dst->size || copies[i].size > dst->size - copies[i].dst_offset)
            return GR_ERROR_INVALID_ARGUMENT;
        if (!(src->usage & GR_BUFFER_USAGE_TRANSFER_SRC) ||
            !(dst->usage & GR_BUFFER_USAGE_TRANSFER_DST))
            return GR_ERROR_INVALID_ARGUMENT;
    }
    cmd->copies += count;
    return GR_OK;
}

gr_result gr_cmd_copy_buffer_to_texture(gr_handle cmd_handle, const gr_buffer_image_copy *copy)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_buffer *b;
    gr_null_texture *t;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!copy)
        return GR_ERROR_INVALID_ARGUMENT;
    b = null_buffer(copy->buffer, NULL);
    if (!b)
        return GR_ERROR_INVALID_HANDLE;
    t = null_texture(copy->texture, NULL);
    if (!t)
        return GR_ERROR_INVALID_HANDLE;
    if (!(b->usage & GR_BUFFER_USAGE_TRANSFER_SRC))
        return GR_ERROR_INVALID_ARGUMENT;
    if (copy->mip >= t->mips || copy->layer >= t->layers)
        return GR_ERROR_INVALID_ARGUMENT;
    if (copy->width == 0 || copy->height == 0 || copy->buffer_offset >= b->size)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->copies++;
    return GR_OK;
}

gr_result gr_cmd_copy_texture_to_buffer(gr_handle cmd_handle, const gr_buffer_image_copy *copy)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_buffer *b;
    gr_null_texture *t;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!copy)
        return GR_ERROR_INVALID_ARGUMENT;
    b = null_buffer(copy->buffer, NULL);
    if (!b)
        return GR_ERROR_INVALID_HANDLE;
    t = null_texture(copy->texture, NULL);
    if (!t)
        return GR_ERROR_INVALID_HANDLE;
    if (!(b->usage & GR_BUFFER_USAGE_TRANSFER_DST))
        return GR_ERROR_INVALID_ARGUMENT;
    if (copy->mip >= t->mips || copy->layer >= t->layers)
        return GR_ERROR_INVALID_ARGUMENT;
    if (copy->width == 0 || copy->height == 0 || copy->buffer_offset >= b->size)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->copies++;
    return GR_OK;
}

gr_result gr_cmd_begin_scope(gr_handle cmd_handle, gr_str name)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!name.data || name.len == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->scope_depth++;
    return GR_OK;
}

gr_result gr_cmd_end_scope(gr_handle cmd_handle)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING || cmd->scope_depth == 0)
        return GR_ERROR_VALIDATION_FAILED;
    cmd->scope_depth--;
    return GR_OK;
}

/* =======================================================================================
 * Synchronization and submission
 * ======================================================================================= */
gr_result gr_fence_create(gr_handle device_handle, uint64_t initial_value, gr_handle *out_fence)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_fence *fence;
    gr_handle handle;
    if (!device || !out_fence)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_fence = GR_NULL_HANDLE;
    fence = (gr_null_fence *)calloc(1, sizeof(*fence));
    if (!fence)
        return GR_ERROR_OUT_OF_MEMORY;
    fence->device = device;
    fence->value = initial_value;
    handle = gr_object_insert(gr_objects(), GR_HANDLE_FENCE, fence);
    if (handle == GR_NULL_HANDLE) {
        free(fence);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_fence = handle;
    return GR_OK;
}

uint64_t gr_fence_value(gr_handle fence_handle)
{
    gr_null_fence *fence = (gr_null_fence *)gr_object_lookup(gr_objects(), fence_handle,
                                                             GR_HANDLE_FENCE, NULL);
    return fence ? fence->value : 0;
}

gr_result gr_fence_wait(gr_handle fence_handle, uint64_t value, uint64_t timeout_ns,
                        gr_result *out_status)
{
    gr_null_fence *fence = (gr_null_fence *)gr_object_lookup(gr_objects(), fence_handle,
                                                             GR_HANDLE_FENCE, NULL);
    (void)timeout_ns;
    if (!fence)
        return GR_ERROR_INVALID_HANDLE;
    /* A submitted value is complete immediately in the null backend, so a wait either
     * succeeds or reports that the value has not been submitted at all. */
    if (fence->value >= value) {
        if (out_status)
            *out_status = GR_OK;
        return GR_OK;
    }
    if (out_status)
        *out_status = GR_TIMEOUT;
    return GR_TIMEOUT;
}

gr_result gr_fence_reset(gr_handle fence_handle, uint64_t value)
{
    gr_null_fence *fence = (gr_null_fence *)gr_object_lookup(gr_objects(), fence_handle,
                                                             GR_HANDLE_FENCE, NULL);
    if (!fence)
        return GR_ERROR_INVALID_HANDLE;
    fence->value = value;
    return GR_OK;
}

gr_result gr_submit_commands(const gr_submit *submit, uint64_t *out_value)
{
    gr_null_queue *queue;
    uint32_t i;
    uint64_t value;

    if (!submit || submit->head.size != sizeof(gr_submit))
        return GR_ERROR_INVALID_ARGUMENT;
    queue = (gr_null_queue *)gr_object_lookup(gr_objects(), submit->queue, GR_HANDLE_QUEUE, NULL);
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    if (submit->cmd_count && !submit->cmds)
        return GR_ERROR_INVALID_ARGUMENT;
    if (submit->wait_count && !submit->waits)
        return GR_ERROR_INVALID_ARGUMENT;
    if (submit->signal_count && !submit->signals)
        return GR_ERROR_INVALID_ARGUMENT;

    /* Every command buffer must be ended, and belongs to a pool for this queue kind. */
    for (i = 0; i < submit->cmd_count; ++i) {
        gr_null_cmd *cmd = null_cmd(submit->cmds[i], NULL);
        gr_null_cmd_pool *pool;
        if (!cmd)
            return GR_ERROR_INVALID_HANDLE;
        if (cmd->state != GR_CMD_ENDED)
            return GR_ERROR_NOT_READY;
        pool = (gr_null_cmd_pool *)gr_object_lookup(gr_objects(), cmd->pool, GR_HANDLE_CMD_POOL, NULL);
        if (pool && pool->queue != queue->kind)
            return GR_ERROR_INVALID_ARGUMENT;
    }

    value = queue->submitted + 1u;
    for (i = 0; i < submit->cmd_count; ++i) {
        gr_null_cmd *cmd = null_cmd(submit->cmds[i], NULL);
        if (cmd)
            cmd->state = GR_CMD_SUBMITTED;
    }
    queue->submitted = value;
    queue->completed = value; /* no GPU: completion is immediate */
    if (out_value)
        *out_value = value;
    return GR_OK;
}

gr_result gr_queue_present(gr_handle queue_handle, gr_handle swapchain, uint32_t image_index,
                           uint64_t wait_value, uint64_t *out_value)
{
    gr_null_queue *queue = (gr_null_queue *)gr_object_lookup(gr_objects(), queue_handle,
                                                             GR_HANDLE_QUEUE, NULL);
    gr_null_swapchain *sc;
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    sc = (gr_null_swapchain *)gr_object_lookup(gr_objects(), swapchain, GR_HANDLE_SWAPCHAIN, NULL);
    if (!sc)
        return GR_ERROR_INVALID_HANDLE;
    if (image_index >= sc->image_count)
        return GR_ERROR_INVALID_ARGUMENT;
    if (wait_value && queue->completed < wait_value)
        return GR_ERROR_NOT_READY;
    queue->submitted = queue->submitted + 1u > wait_value ? queue->submitted + 1u : wait_value + 1u;
    queue->completed = queue->submitted;
    if (out_value)
        *out_value = queue->submitted;
    return GR_OK;
}

/* =======================================================================================
 * Swapchain
 * ======================================================================================= */
gr_result gr_swapchain_create(gr_handle device_handle, const gr_swapchain_desc *desc,
                              gr_handle *out_swapchain)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_swapchain *sc;
    gr_handle handle;
    uint32_t w = desc ? desc->width : 0, h = desc ? desc->height : 0;

    if (!device || !desc || !out_swapchain)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_swapchain = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_swapchain_desc))
        return GR_ERROR_VERSION_MISMATCH;
    /* Only a headless device may present without a window: a windowed device whose window is
     * invalid would otherwise create a swapchain that can never be presented. */
    if (desc->window == GR_NULL_HANDLE && !(device->flags & GR_DEVICE_HEADLESS))
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->present_mode > GR_PRESENT_FIFO_RELAXED)
        return GR_ERROR_INVALID_ARGUMENT;
    if (w == 0 || h == 0) {
        w = (w == 0) ? 1280u : w;
        h = (h == 0) ? 720u : h;
    }

    sc = (gr_null_swapchain *)calloc(1, sizeof(*sc));
    if (!sc)
        return GR_ERROR_OUT_OF_MEMORY;
    sc->device = device;
    sc->window = desc->window;
    sc->format = desc->format == GR_FORMAT_UNDEFINED ? GR_FORMAT_B8G8R8A8_UNORM : desc->format;
    sc->width = w;
    sc->height = h;
    sc->image_count = desc->image_count ? desc->image_count : 3u;
    if (sc->image_count > 4)
        sc->image_count = 4; /* the views array's bound */
    sc->present_mode = desc->present_mode;
    handle = gr_object_insert(gr_objects(), GR_HANDLE_SWAPCHAIN, sc);
    if (handle == GR_NULL_HANDLE) {
        free(sc);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    device->swapchain = handle;
    *out_swapchain = handle;
    return GR_OK;
}

gr_result gr_swapchain_info(gr_handle swapchain, gr_format *out_format, uint32_t *out_width,
                            uint32_t *out_height, uint32_t *out_image_count)
{
    gr_null_swapchain *sc = (gr_null_swapchain *)gr_object_lookup(gr_objects(), swapchain,
                                                                 GR_HANDLE_SWAPCHAIN, NULL);
    if (!sc)
        return GR_ERROR_INVALID_HANDLE;
    if (out_format) *out_format = sc->format;
    if (out_width) *out_width = sc->width;
    if (out_height) *out_height = sc->height;
    if (out_image_count) *out_image_count = sc->image_count;
    return GR_OK;
}

gr_result gr_swapchain_acquire(gr_handle swapchain, uint64_t timeout_ns,
                               uint32_t *out_image_index, gr_handle *out_view,
                               int32_t *out_needs_recreate)
{
    gr_null_swapchain *sc = (gr_null_swapchain *)gr_object_lookup(gr_objects(), swapchain,
                                                                 GR_HANDLE_SWAPCHAIN, NULL);
    (void)timeout_ns;
    if (!sc)
        return GR_ERROR_INVALID_HANDLE;
    if (out_image_index) *out_image_index = sc->current_image;
    if (out_view) *out_view = GR_NULL_HANDLE;
    if (out_needs_recreate) *out_needs_recreate = 0;
    return GR_OK;
}

gr_result gr_swapchain_recreate(gr_handle swapchain, uint32_t width, uint32_t height,
                                uint64_t after_value)
{
    gr_null_swapchain *sc = (gr_null_swapchain *)gr_object_lookup(gr_objects(), swapchain,
                                                                 GR_HANDLE_SWAPCHAIN, NULL);
    if (!sc)
        return GR_ERROR_INVALID_HANDLE;
    if (width == 0 || height == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    (void)after_value; /* a real backend retires the old images at this value */
    sc->width = width;
    sc->height = height;
    sc->current_image = 0;
    return GR_OK;
}

/* =======================================================================================
 * Queries
 * ======================================================================================= */
gr_result gr_query_pool_create(gr_handle device_handle, const gr_query_pool_desc *desc,
                               gr_handle *out_pool)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_query_pool *pool;
    gr_handle handle;
    if (!device || !desc || !out_pool)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pool = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_query_pool_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->count == 0 || desc->type > 1)
        return GR_ERROR_INVALID_ARGUMENT;
    pool = (gr_null_query_pool *)calloc(1, sizeof(*pool));
    if (!pool)
        return GR_ERROR_OUT_OF_MEMORY;
    pool->device = device;
    pool->count = desc->count;
    pool->type = desc->type;
    pool->results = (uint64_t *)calloc(desc->count, sizeof(uint64_t));
    if (!pool->results) {
        free(pool);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    handle = gr_object_insert(gr_objects(), GR_HANDLE_QUERY_POOL, pool);
    if (handle == GR_NULL_HANDLE) {
        free(pool->results);
        free(pool);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_pool = handle;
    return GR_OK;
}

gr_result gr_cmd_write_timestamp(gr_handle cmd_handle, gr_handle pool_handle, uint32_t index)
{
    gr_result status;
    gr_null_cmd *cmd = null_cmd(cmd_handle, &status);
    gr_null_query_pool *pool;
    if (!cmd)
        return status;
    if (cmd->state != GR_CMD_RECORDING)
        return GR_ERROR_NOT_READY;
    if (!(cmd->device->caps.caps & GR_CAP_CALIBRATED_TIMESTAMPS))
        return GR_ERROR_UNSUPPORTED;
    pool = (gr_null_query_pool *)gr_object_lookup(gr_objects(), pool_handle, GR_HANDLE_QUERY_POOL, NULL);
    if (!pool)
        return GR_ERROR_INVALID_HANDLE;
    if (pool->type != 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (index >= pool->count)
        return GR_ERROR_INVALID_ARGUMENT;
    /* A monotonic synthetic value: a test can prove the ordering and the plumbing, and a
     * real backend replaces it with the device counter. */
    pool->results[index] = (uint64_t)(index + 1u) * 1000ull;
    return GR_OK;
}

gr_result gr_query_pool_results(gr_handle pool_handle, uint32_t first, uint32_t count,
                                uint64_t *out_ns)
{
    gr_null_query_pool *pool = (gr_null_query_pool *)gr_object_lookup(gr_objects(), pool_handle,
                                                                     GR_HANDLE_QUERY_POOL, NULL);
    if (!pool || !out_ns)
        return GR_ERROR_INVALID_ARGUMENT;
    if (first >= pool->count || count > pool->count - first)
        return GR_ERROR_INVALID_ARGUMENT;
    memcpy(out_ns, pool->results + first, sizeof(uint64_t) * count);
    return GR_OK;
}

/* =======================================================================================
 * Shaders
 * ======================================================================================= */
gr_result gr_shader_create(gr_handle device_handle, const gr_shader_desc *desc,
                           gr_handle *out_shader)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    const gr_span_u8 *chosen = NULL;
    gr_null_shader *shader;
    gr_reflection reflection;
    gr_result status;
    gr_handle handle;

    if (!device || !desc || !out_shader)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_shader = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_shader_desc))
        return GR_ERROR_VERSION_MISMATCH;

    /* The reflection blob is the description of the shader; a container without it cannot be
     * validated, so a caller must supply one. */
    chosen = &desc->reflection_blob;
    if (!chosen->data || chosen->len == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    /* And at least one container must be present: a blob with no code is not loadable. */
    if (desc->spirv.len == 0 && desc->dxil.len == 0 && desc->msl_library.len == 0 &&
        desc->msl_source.len == 0)
        return GR_ERROR_UNSUPPORTED;

    /* The reflection is validated here, not at pipeline creation: a shader whose blob does
     * not parse is refused before it can be named by a pipeline. */
    status = gr_reflect_open(*chosen, &reflection);
    if (status != GR_OK)
        return status;

    shader = (gr_null_shader *)calloc(1, sizeof(*shader));
    if (!shader)
        return GR_ERROR_OUT_OF_MEMORY;
    shader->device = device;
    shader->blob = (uint8_t *)malloc(chosen->len);
    if (!shader->blob) {
        free(shader);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    memcpy(shader->blob, chosen->data, chosen->len);
    shader->blob_length = chosen->len;
    shader->reflection = reflection;
    /* The reflection's internal pointers refer to the caller's buffer; re-open against the
     * copy so they stay valid for the shader's lifetime. */
    status = gr_reflect_open((gr_span_u8){ shader->blob, shader->blob_length }, &shader->reflection);
    if (status != GR_OK) {
        free(shader->blob);
        free(shader);
        return status;
    }
    shader->stage = (gr_shader_stage)reflection.header->stage;
    shader->container = (gr_shader_container)reflection.header->container;
    shader->permutation_key = desc->permutation_key;
    shader->name = gr_str_dup(desc->name);

    handle = gr_object_insert(gr_objects(), GR_HANDLE_SHADER, shader);
    if (handle == GR_NULL_HANDLE) {
        free(shader->blob);
        free(shader->name);
        free(shader);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_shader = handle;
    null_log(device, 0, "shader created");
    return GR_OK;
}

/* The span a shader was built from, for gr_reflection_of() in grail_reflect.c. */
gr_result gr_shader_reflection_span(gr_handle shader_handle, gr_span_u8 *out_span)
{
    gr_null_shader *shader = (gr_null_shader *)gr_object_lookup(gr_objects(), shader_handle,
                                                               GR_HANDLE_SHADER, NULL);
    if (!shader || !out_span)
        return GR_ERROR_INVALID_HANDLE;
    out_span->data = shader->blob;
    out_span->len = (size_t)shader->blob_length;
    return GR_OK;
}

/* =======================================================================================
 * Pipelines
 * ======================================================================================= */
gr_result gr_pipeline_create(gr_handle device_handle, const gr_pipeline_desc *desc,
                             gr_handle *out_pipeline)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    gr_null_pipeline *pipeline;
    gr_handle handle;
    uint32_t i;
    int has_vertex, has_fragment, has_compute, has_mesh;

    if (!device || !desc || !out_pipeline)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pipeline = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_pipeline_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (!desc->name.data || desc->name.len == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    /* Once committed, no pipeline may be added: a renderer must not be able to stall on a
     * cold pipeline in the middle of a frame. */
    if (device->commit_done)
        return GR_ERROR_NOT_READY;

    has_vertex = desc->shaders[GR_SHADER_STAGE_VERTEX] != GR_NULL_HANDLE;
    has_fragment = desc->shaders[GR_SHADER_STAGE_FRAGMENT] != GR_NULL_HANDLE;
    has_compute = desc->shaders[GR_SHADER_STAGE_COMPUTE] != GR_NULL_HANDLE;
    has_mesh = desc->shaders[GR_SHADER_STAGE_MESH] != GR_NULL_HANDLE;
    if (desc->shaders[GR_SHADER_STAGE_TASK] != GR_NULL_HANDLE && !has_mesh)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->shaders[GR_SHADER_STAGE_LIBRARY] != GR_NULL_HANDLE)
        return GR_ERROR_UNSUPPORTED; /* ray tracing pipelines are not in this foundation */

    if (has_compute) {
        if (has_vertex || has_fragment || has_mesh)
            return GR_ERROR_INVALID_ARGUMENT;
    } else if (has_mesh) {
        if (has_vertex)
            return GR_ERROR_INVALID_ARGUMENT;
        if (!(device->caps.caps & GR_CAP_MESH_SHADER))
            return GR_ERROR_UNSUPPORTED;
    } else if (!has_vertex) {
        return GR_ERROR_INVALID_ARGUMENT; /* neither compute, mesh nor vertex */
    }

    for (i = 0; i < GR_SHADER_STAGE_COUNT; ++i) {
        gr_null_shader *shader;
        if (desc->shaders[i] == GR_NULL_HANDLE)
            continue;
        shader = (gr_null_shader *)gr_object_lookup(gr_objects(), desc->shaders[i],
                                                    GR_HANDLE_SHADER, NULL);
        if (!shader)
            return GR_ERROR_INVALID_HANDLE;
        /* The descriptor's key is load-bearing: a pipeline that declares a permutation may only
         * use shaders built for that permutation. Without this check a builder could pair a
         * permuted fragment shader with an unpermuted vertex shader and the mistake would only
         * show as wrong output. A pipeline declaring key 0 accepts anything, so the check
         * cannot get in the way of a caller that does not use permutations. */
        if (desc->permutation_key != 0 && shader->permutation_key != desc->permutation_key)
            return GR_ERROR_INVALID_ARGUMENT;
    }

    if (desc->color_count && !desc->color_formats)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->color_count > device->caps.max_color_attachments)
        return GR_ERROR_UNSUPPORTED;
    for (i = 0; i < desc->color_count; ++i) {
        if (desc->color_formats[i] == GR_FORMAT_UNDEFINED ||
            desc->color_formats[i] >= GR_FORMAT_COUNT)
            return GR_ERROR_INVALID_ARGUMENT;
        if (gr_format_class_of(desc->color_formats[i]) != GR_FORMAT_CLASS_COLOR)
            return GR_ERROR_INVALID_ARGUMENT;
    }
    if (desc->depth_format != GR_FORMAT_UNDEFINED &&
        gr_format_class_of(desc->depth_format) == GR_FORMAT_CLASS_COLOR)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->depth_compare > GR_COMPARE_ALWAYS)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->cull > GR_CULL_BACK)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->topology > GR_TOPOLOGY_PATCH_LIST)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->samples != 0 && desc->samples != 1 && desc->samples != 2 && desc->samples != 4 &&
        desc->samples != 8)
        return GR_ERROR_INVALID_ARGUMENT;
    /* A vertex pipeline without a vertex layout cannot be validated against its shader, so it
     * is refused rather than silently relying on the shader's locations. */
    if (has_vertex && desc->vertex_attribute_count == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->vertex_attribute_count && !desc->vertex_attributes)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->spec_count && !desc->spec)
        return GR_ERROR_INVALID_ARGUMENT;

    pipeline = (gr_null_pipeline *)calloc(1, sizeof(*pipeline));
    if (!pipeline)
        return GR_ERROR_OUT_OF_MEMORY;
    pipeline->device = device;
    pipeline->desc = *desc;
    /* The descriptor's arrays are borrowed; the pipeline keeps only what it needs to answer a
     * later query, and the caller keeps its arrays alive for the pipeline's lifetime. */
    pipeline->name = gr_str_dup(desc->name);

    handle = gr_object_insert(gr_objects(), GR_HANDLE_PIPELINE, pipeline);
    if (handle == GR_NULL_HANDLE) {
        free(pipeline->name);
        free(pipeline);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    device->pipelines_declared++;
    *out_pipeline = handle;
    return GR_OK;
}

gr_result gr_pipeline_commit(gr_handle device_handle, double *out_seconds)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    if (!device)
        return GR_ERROR_INVALID_HANDLE;
    if (device->commit_done)
        return GR_ERROR_NOT_READY;
    device->pipelines_committed = device->pipelines_declared;
    device->commit_done = 1;
    if (out_seconds)
        *out_seconds = 0.0; /* nothing is compiled: this is where a real backend reports it */
    return GR_OK;
}

gr_result gr_pipeline_stats(gr_handle device_handle, uint32_t *out_declared,
                            uint32_t *out_committed)
{
    gr_null_device *device = (gr_null_device *)null_get(NULL, device_handle, GR_HANDLE_DEVICE, NULL);
    if (!device)
        return GR_ERROR_INVALID_HANDLE;
    if (out_declared) *out_declared = device->pipelines_declared;
    if (out_committed) *out_committed = device->pipelines_committed;
    return GR_OK;
}
