/* grail_rhi.h - the render hardware interface: device, queues, resources, command buffers.
 *
 * One contract, three backends. The shape is Abundance's own engine narrowed to what a
 * forward renderer needs: dynamic rendering (no render-pass objects), one bindless
 * descriptor set plus a per-frame constant buffer, queue timelines instead of binary
 * semaphores, explicit deferred destruction, and pipelines built before the first frame.
 * See graphics/docs/rhi-contract.md for why each of those is fixed rather than optional.
 *
 * Conventions this interface assumes and never re-negotiates per pipeline:
 *   - clip-space depth is reverse-Z with an infinite far plane on Vulkan and Metal, and
 *     D3D-style [0,1] depth on D3D12; the projection the caller supplies has already
 *     accounted for the backend (gr_device_caps.depth_range_zero_to_one says which)
 *   - triangle winding is counter-clockwise in NDC for front faces, and the backend
 *     flips it for D3D12 rather than the caller
 *   - matrices are row-major and act on column vectors, matching -Zpr and Abundance's
 *     core/math.hpp; constant buffers are scalar-layout so std140 never applies
 *   - a pipeline declares an empty pipeline layout: every pipeline uses the shared
 *     bindless layout, so binding never changes between passes
 *   - no resource is destroyed synchronously while a frame may reference it; destroy
 *     retires, and collect runs after a completion value
 */
#ifndef GRAIL_RHI_H
#define GRAIL_RHI_H

#include "grail_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* =======================================================================================
 * Device
 * ======================================================================================= */

typedef void *(*gr_alloc_fn)(void *user, size_t size, size_t align);
typedef void (*gr_free_fn)(void *user, void *ptr);
/* Reallocating host memory for descriptor structs and shader blobs. All three are optional;
 * a NULL allocator means the implementation uses its own. */
typedef struct gr_allocator {
    gr_alloc_fn alloc;
    gr_free_fn free;
    void *user;
} gr_allocator;

typedef enum gr_device_flags {
    GR_DEVICE_NONE = 0,
    GR_DEVICE_VALIDATION = 1u << 0,   /* VK_LAYER_KHRONOS_validation / D3D12 debug layer */
    GR_DEVICE_HEADLESS = 1u << 1,     /* no swapchain; render to offscreen textures */
    GR_DEVICE_GPU_TIMING = 1u << 2,   /* allocate timestamp queries and enable counters */
    GR_DEVICE_PIPELINE_STATS = 1u << 3, /* log per-pipeline statistics at build time */
    GR_DEVICE_LOW_POWER = 1u << 4,    /* prefer an integrated device */
    GR_DEVICE_CAPTURE = 1u << 5       /* enable RenderDoc/PIX/RGP-friendly markers */
} gr_device_flags;

typedef struct gr_device_desc {
    gr_desc_head head;
    gr_backend backend;         /* GR_BACKEND_NULL is always available */
    uint32_t flags;             /* gr_device_flags */
    gr_handle window;           /* GR_NULL_HANDLE: headless, no surface */
    gr_str app_name;
    gr_version app_version;
    uint32_t api_min_major;     /* 0: the backend's default (Vulkan 1.3, D3D12 FL 12_0, Metal 3.0) */
    uint32_t api_min_minor;
    gr_allocator allocator;     /* optional */
    /* Debug callback: called from any thread, must not call back into the device. */
    void (*log)(void *user, int32_t severity, gr_str message);
    void *log_user;
} gr_device_desc;

typedef struct gr_device_caps {
    gr_desc_head head;
    gr_backend backend;
    uint64_t caps;                  /* gr_caps bits */
    char device_name[128];
    char driver_name[128];
    uint32_t api_major, api_minor, api_patch;
    uint32_t vendor_id, device_id;
    uint64_t device_memory_bytes;   /* budget if known, else heap size hint */
    uint64_t buffer_address_min_align;
    uint64_t buffer_address_max_range;   /* 0 when GR_CAP_BUFFER_DEVICE_ADDRESS is absent */
    uint32_t max_push_constant_bytes;    /* >= 128 when GR_CAP_BINDLESS is set */
    uint32_t max_color_attachments;
    uint32_t max_descriptor_array_length;/* the bindless capacity the device accepts */
    uint32_t subgroup_size;
    uint32_t timestamp_valid_bits;
    float timestamp_period_ns;
    uint32_t depth_range_zero_to_one;    /* 1: D3D/Metal-style [0,1]; 0: reverse-Z [1,0] */
    uint64_t pipeline_cache_uuid[2];     /* 0 when the device has no persistent cache id */
    uint32_t max_frames_in_flight;       /* at least 2 */
    uint32_t _reserved;
} gr_device_caps;

gr_result gr_device_create(const gr_device_desc *desc, gr_handle *out_device);
void gr_device_destroy(gr_handle device);
gr_result gr_device_get_caps(gr_handle device, gr_device_caps *out);
gr_result gr_device_wait_idle(gr_handle device);

/* Address of one of the device's queues. GR_QUEUE_GRAPHICS is always present. */
typedef enum gr_queue_kind {
    GR_QUEUE_GRAPHICS = 0,
    GR_QUEUE_COMPUTE = 1,
    GR_QUEUE_TRANSFER = 2
} gr_queue_kind;

gr_result gr_device_queue(gr_handle device, gr_queue_kind kind, gr_handle *out_queue);

/* A monotonic counter a queue signals on every submission. Waiting on a value is the only
 * cross-queue and cross-frame dependency mechanism; there are no binary semaphores in the
 * public interface. A backend without timeline support emulates one with a fence. */
gr_result gr_queue_timeline(gr_handle queue, gr_handle *out_semaphore);
/* The last value submitted / the last value the GPU completed. */
uint64_t gr_queue_submitted(gr_handle queue);
uint64_t gr_queue_completed(gr_handle queue);
gr_result gr_queue_wait_idle(gr_handle queue);

/* =======================================================================================
 * Deferred destruction
 *
 * A handle is retired with the timeline value that must complete before its memory may be
 * released. destroy() on a resource is exactly retire(handle, 0). collect() frees every
 * retired object whose value the GPU has passed. This is Device::defer in Abundance.
 * ======================================================================================= */
gr_result gr_device_retire(gr_handle device, gr_handle object, uint64_t after_value);
/* Frees what has completed. Safe to call once per frame. */
gr_result gr_device_collect(gr_handle device);

/* =======================================================================================
 * Formats
 *
 * Deliberately a small closed set: everything a forward renderer, a compute pass and a
 * HDR present path needs. Adding a format is an additive ABI change. The values are stable
 * and independent of VkFormat/DXGI_FORMAT so the wire protocol carries them unchanged.
 * ======================================================================================= */
typedef enum gr_format {
    GR_FORMAT_UNDEFINED = 0,
    GR_FORMAT_R8_UNORM,
    GR_FORMAT_R8_UINT,
    GR_FORMAT_R8G8_UNORM,
    GR_FORMAT_R8G8B8A8_UNORM,
    GR_FORMAT_R8G8B8A8_SRGB,
    GR_FORMAT_B8G8R8A8_UNORM,
    GR_FORMAT_B8G8R8A8_SRGB,
    GR_FORMAT_R16_FLOAT,
    GR_FORMAT_R16_UINT,
    GR_FORMAT_R16G16_FLOAT,
    GR_FORMAT_R16G16B16A16_FLOAT,
    GR_FORMAT_R16G16B16A16_UNORM,
    GR_FORMAT_R32_UINT,
    GR_FORMAT_R32_FLOAT,
    GR_FORMAT_R32G32_UINT,
    GR_FORMAT_R32G32_FLOAT,
    GR_FORMAT_R32G32B32A32_FLOAT,
    GR_FORMAT_R32G32B32A32_UINT,
    GR_FORMAT_R10G10B10A2_UNORM,
    GR_FORMAT_R11G11B10_FLOAT,
    GR_FORMAT_BC7_UNORM,
    GR_FORMAT_BC7_SRGB,
    GR_FORMAT_BC5_UNORM,
    GR_FORMAT_D32_FLOAT,
    GR_FORMAT_D32_FLOAT_S8_UINT,
    GR_FORMAT_D24_UNORM_S8_UINT,
    GR_FORMAT_D16_UNORM,
    GR_FORMAT_COUNT
} gr_format;

typedef enum gr_format_class {
    GR_FORMAT_CLASS_COLOR = 0,
    GR_FORMAT_CLASS_DEPTH = 1,
    GR_FORMAT_CLASS_DEPTH_STENCIL = 2
} gr_format_class;

/* Bytes per block and block extent; a BC format reports 4x4. 0 when unknown. */
uint32_t gr_format_bytes_per_block(gr_format format);
void gr_format_block_extent(gr_format format, uint32_t *out_w, uint32_t *out_h);
gr_format_class gr_format_class_of(gr_format format);
int gr_format_is_hdr(gr_format format);
/* The sRGB variant of a colour format, or the format itself. */
gr_format gr_format_to_srgb(gr_format format);
gr_format gr_format_to_linear(gr_format format);

/* =======================================================================================
 * Buffers
 * ======================================================================================= */
typedef enum gr_buffer_usage {
    GR_BUFFER_USAGE_NONE = 0,
    GR_BUFFER_USAGE_VERTEX = 1u << 0,
    GR_BUFFER_USAGE_INDEX = 1u << 1,
    GR_BUFFER_USAGE_UNIFORM = 1u << 2,       /* constant buffer */
    GR_BUFFER_USAGE_STORAGE = 1u << 3,
    GR_BUFFER_USAGE_INDIRECT = 1u << 4,
    GR_BUFFER_USAGE_TRANSFER_SRC = 1u << 5,
    GR_BUFFER_USAGE_TRANSFER_DST = 1u << 6,
    GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS = 1u << 7,
    GR_BUFFER_USAGE_ACCELERATION_STRUCTURE = 1u << 8
} gr_buffer_usage;

/* Host visibility is a separate decision from usage so an upload ring can be CPU-visible
 * and a uniform buffer can live in device-local memory with a staging copy. */
typedef enum gr_memory {
    GR_MEMORY_DEVICE = 0,     /* fastest for the GPU, not mapped */
    GR_MEMORY_UPLOAD = 1,     /* host-visible, host-coherent: write, read on the GPU */
    GR_MEMORY_READBACK = 2    /* host-visible, cached: write on the GPU, read on the host */
} gr_memory;

typedef struct gr_buffer_desc {
    gr_desc_head head;
    uint64_t size;
    uint32_t usage;      /* gr_buffer_usage */
    uint32_t memory;     /* gr_memory */
    gr_str name;         /* debug name; shows in validation, RenderDoc and PIX */
} gr_buffer_desc;

gr_result gr_buffer_create(gr_handle device, const gr_buffer_desc *desc, gr_handle *out_buffer);
/* Data to the GPU: a copy, legal only outside a recording command buffer. Blocking for
 * GR_MEMORY_DEVICE. Returns GR_ERROR_UNSUPPORTED when the buffer is not host-visible. */
gr_result gr_buffer_write(gr_handle buffer, uint64_t offset, gr_span_u8 data);
gr_result gr_buffer_read(gr_handle buffer, uint64_t offset, gr_mut_span_u8 out);
/* Persistent mapping for rings. A mapped buffer may not be bound while it is written. */
gr_result gr_buffer_map(gr_handle buffer, void **out_ptr);
void gr_buffer_unmap(gr_handle buffer);
/* 0 unless GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS was requested and supported. */
uint64_t gr_buffer_device_address(gr_handle buffer);
/* The bindless slot this buffer occupies (GR_BUFFER_USAGE_STORAGE). ~0u on failure. */
uint32_t gr_buffer_bindless_index(gr_handle buffer);

/* =======================================================================================
 * Textures and views
 * ======================================================================================= */
typedef enum gr_texture_usage {
    GR_TEXTURE_USAGE_NONE = 0,
    GR_TEXTURE_USAGE_SAMPLED = 1u << 0,
    GR_TEXTURE_USAGE_STORAGE = 1u << 1,
    GR_TEXTURE_USAGE_COLOR_ATTACHMENT = 1u << 2,
    GR_TEXTURE_USAGE_DEPTH_ATTACHMENT = 1u << 3,
    GR_TEXTURE_USAGE_TRANSFER_SRC = 1u << 4,
    GR_TEXTURE_USAGE_TRANSFER_DST = 1u << 5,
    GR_TEXTURE_USAGE_PRESENT = 1u << 6,
    GR_TEXTURE_USAGE_CUBE = 1u << 7
} gr_texture_usage;

typedef enum gr_texture_type {
    GR_TEXTURE_2D = 0,
    GR_TEXTURE_2D_ARRAY = 1,
    GR_TEXTURE_3D = 2,
    GR_TEXTURE_CUBE = 3,
    GR_TEXTURE_CUBE_ARRAY = 4
} gr_texture_type;

typedef enum gr_sample_count {
    GR_SAMPLES_1 = 1,
    GR_SAMPLES_2 = 2,
    GR_SAMPLES_4 = 4,
    GR_SAMPLES_8 = 8
} gr_sample_count;

typedef struct gr_texture_desc {
    gr_desc_head head;
    uint32_t type;           /* gr_texture_type */
    gr_format format;
    uint32_t width, height, depth;   /* depth is layers for arrays/cubes, 1 for 2D */
    uint32_t mip_levels;     /* 0: a full chain */
    uint32_t array_layers;   /* 1 for 2D/3D */
    uint32_t samples;        /* gr_sample_count */
    uint32_t usage;          /* gr_texture_usage */
    gr_str name;
} gr_texture_desc;

gr_result gr_texture_create(gr_handle device, const gr_texture_desc *desc, gr_handle *out_texture);
gr_result gr_texture_write(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y,
                           uint32_t width, uint32_t height, gr_span_u8 row_major);
/* Reads pixels back to host memory.
 *
 * `src_state` is the state the caller knows the texture is in — the graph tracks it, so the backend
 * does not try to. It is required rather than optional because a readback has to transition the
 * image to TRANSFER_SRC before the copy, and guessing the starting layout is how a second readback
 * of the same image failed validation. The transition and the copy are recorded into one command
 * buffer, so recording order equals submission order. */
gr_result gr_texture_read(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y,
                          uint32_t width, uint32_t height, uint32_t src_state, gr_mut_span_u8 out);
/* A view reinterprets an existing texture (slice, mip range, format family). Creating a
 * second view of the same texture is how a render target is also sampled. */
typedef enum gr_texture_view_type {
    GR_VIEW_2D = 0,
    GR_VIEW_2D_ARRAY = 1,
    GR_VIEW_CUBE = 2,
    GR_VIEW_CUBE_ARRAY = 3,
    GR_VIEW_3D = 4
} gr_texture_view_type;

typedef struct gr_texture_view_desc {
    gr_desc_head head;
    gr_handle texture;
    gr_texture_view_type type;
    gr_format format;        /* GR_FORMAT_UNDEFINED: the texture's format */
    uint32_t base_mip, mip_count;      /* mip_count 0 means all remaining */
    uint32_t base_layer, layer_count;  /* layer_count 0 means all remaining */
    gr_str name;
} gr_texture_view_desc;

gr_result gr_texture_view_create(gr_handle device, const gr_texture_view_desc *desc,
                                 gr_handle *out_view);
/* The bindless slots a sampled or storage view occupies. ~0u on failure. */
uint32_t gr_texture_view_bindless_sampled(gr_handle view);
uint32_t gr_texture_view_bindless_storage(gr_handle view);

/* =======================================================================================
 * Samplers
 *
 * The thirteen fixed slots of Abundance's abe::Sampler are created by the device and are
 * reached by constant index from a shader, so a material never binds a sampler object.
 * ======================================================================================= */
typedef enum gr_sampler_slot {
    GR_SAMPLER_LINEAR_CLAMP = 0,
    GR_SAMPLER_LINEAR_WRAP = 1,
    GR_SAMPLER_POINT_CLAMP = 2,
    GR_SAMPLER_POINT_WRAP = 3,
    GR_SAMPLER_ANISO_WRAP = 4,
    GR_SAMPLER_ANISO_CLAMP = 5,
    GR_SAMPLER_SHADOW_COMPARE = 6,   /* comparison, GREATER_OR_EQUAL for reverse-Z */
    GR_SAMPLER_MIN_REDUCE = 7,
    GR_SAMPLER_MAX_REDUCE = 8,
    GR_SAMPLER_LINEAR_CLAMP_U_WRAP_V = 9,
    GR_SAMPLER_LINEAR_WRAP_U_CLAMP_V = 10,
    GR_SAMPLER_ANISO_CLAMP_U_WRAP_V = 11,
    GR_SAMPLER_ANISO_WRAP_U_CLAMP_V = 12,
    GR_SAMPLER_SLOT_COUNT
} gr_sampler_slot;

typedef enum gr_filter {
    GR_FILTER_NEAREST = 0,
    GR_FILTER_LINEAR = 1
} gr_filter;

typedef enum gr_address_mode {
    GR_ADDRESS_WRAP = 0,
    GR_ADDRESS_CLAMP = 1,
    GR_ADDRESS_MIRROR = 2,
    GR_ADDRESS_BORDER = 3
} gr_address_mode;

typedef enum gr_reduction {
    GR_REDUCTION_WEIGHTED = 0,  /* sampling */
    GR_REDUCTION_MIN = 1,
    GR_REDUCTION_MAX = 2,
    GR_REDUCTION_COMPARE = 3
} gr_reduction;

typedef struct gr_sampler_desc {
    gr_desc_head head;
    gr_filter min_filter, mag_filter, mip_filter;
    gr_address_mode address_u, address_v, address_w;
    float mip_lod_bias;
    float max_anisotropy;    /* 1.0 disables anisotropic filtering; <=16 typical */
    float min_lod, max_lod;
    gr_reduction reduction;
    gr_str name;
} gr_sampler_desc;

/* Creates a sampler object. Its slot in the bindless sampler table is returned; the fixed
 * thirteen are created by the device and always occupy slots 0..12. */
gr_result gr_sampler_create(gr_handle device, const gr_sampler_desc *desc, gr_handle *out_sampler,
                            uint32_t *out_slot);

/* =======================================================================================
 * Bindless table and frame constants
 *
 * Set 0 is the whole resource namespace. Set 1 is the per-frame constant buffer, one
 * dynamic uniform buffer with a per-frame stride. Both live in grail_bindless.h.
 * ======================================================================================= */
gr_handle gr_device_bindless(gr_handle device);

/* =======================================================================================
 * Command buffers
 *
 * Exactly two levels: primary only, and a command buffer is either recording or reset.
 * There is no secondary-buffer or render-pass object to keep in sync. A frame's work is
 * recorded into one or more primaries and submitted with explicit timeline waits.
 * ======================================================================================= */
typedef struct gr_cmd_pool_desc {
    gr_desc_head head;
    gr_queue_kind queue;     /* where the pool's buffers will be submitted */
    uint32_t flags;          /* reserved; 0 */
} gr_cmd_pool_desc;

typedef struct gr_cmd_alloc_info {
    gr_desc_head head;
    gr_handle pool;          /* required: this call has no device to fall back to */
    gr_str name;
} gr_cmd_alloc_info;

gr_result gr_cmd_pool_create(gr_handle device, const gr_cmd_pool_desc *desc, gr_handle *out_pool);
/* Begins recording. A command buffer may only be submitted between end() and reset(). */
gr_result gr_cmd_alloc(const gr_cmd_alloc_info *info, gr_handle *out_cmd);
gr_result gr_cmd_begin(gr_handle cmd);
gr_result gr_cmd_end(gr_handle cmd);
gr_result gr_cmd_reset(gr_handle cmd);

/* Resource state. Every transition is explicit; the implementation does not infer one.
 * A texture read before its first write must transition from GR_STATE_UNDEFINED. */
typedef enum gr_resource_state {
    GR_STATE_UNDEFINED = 0,
    GR_STATE_GENERAL,           /* storage read/write, any layout */
    GR_STATE_SHADER_READ,       /* sampled */
    GR_STATE_COLOR_ATTACHMENT,
    GR_STATE_DEPTH_ATTACHMENT_WRITE,
    GR_STATE_DEPTH_ATTACHMENT_READ,
    GR_STATE_TRANSFER_SRC,
    GR_STATE_TRANSFER_DST,
    GR_STATE_PRESENT,
    GR_STATE_INDIRECT_ARGUMENT,
    GR_STATE_VERTEX_BUFFER,
    GR_STATE_INDEX_BUFFER,
    GR_STATE_COPY_SOURCE_HOST    /* readback path */
} gr_resource_state;

typedef struct gr_barrier {
    gr_handle resource;          /* buffer, texture or texture view */
    uint32_t src_state;          /* gr_resource_state */
    uint32_t dst_state;
    uint32_t base_mip, mip_count;      /* textures; 0 mip_count means one */
    uint32_t base_layer, layer_count;
    uint32_t queue_from, queue_to;     /* queue ownership transfer; index-based */
} gr_barrier;

gr_result gr_cmd_barrier(gr_handle cmd, const gr_barrier *barriers, uint32_t count);

/* Dynamic rendering: the only render scope. Attachments are views, resolved explicitly.
 * `depth` may be GR_NULL_HANDLE for a colour-only pass; then depth_test is ignored. */
typedef enum gr_load_op {
    GR_LOAD_DONT_CARE = 0,   /* discard; the pass fully overwrites the attachment */
    GR_LOAD_CLEAR = 1,
    GR_LOAD_LOAD = 2
} gr_load_op;

typedef enum gr_store_op {
    GR_STORE_DISCARD = 0,    /* valid only for a pass's attachments that are not read later */
    GR_STORE_STORE = 1
} gr_store_op;

typedef struct gr_color_attachment {
    gr_handle view;
    uint32_t load_op;        /* gr_load_op */
    uint32_t store_op;       /* gr_store_op */
    float clear[4];
    uint32_t resolve_view;   /* unused, 0; MSAA resolve is a separate explicit pass */
    uint32_t _reserved;
} gr_color_attachment;

typedef struct gr_depth_attachment {
    gr_handle view;
    uint32_t load_op;
    uint32_t store_op;
    float clear_depth;
    uint32_t clear_stencil;  /* only written when clear_depth is unused */
    uint32_t _reserved;
} gr_depth_attachment;

typedef struct gr_render_begin {
    gr_desc_head head;
    const gr_color_attachment *colors;
    uint32_t color_count;
    const gr_depth_attachment *depth;   /* NULL: no depth attachment */
    int32_t render_x, render_y;
    uint32_t render_w, render_h;        /* 0: the union of the attachments' extents */
    gr_str name;                        /* debug scope; shows in RenderDoc and PIX */
} gr_render_begin;

gr_result gr_cmd_begin_render(gr_handle cmd, const gr_render_begin *info);
gr_result gr_cmd_end_render(gr_handle cmd);

/* Viewport and scissor are dynamic state, expected on nearly every pass. */
gr_result gr_cmd_set_viewport(gr_handle cmd, float x, float y, float width, float height,
                              float min_depth, float max_depth);
gr_result gr_cmd_set_scissor(gr_handle cmd, int32_t x, int32_t y, uint32_t width, uint32_t height);

/* Pipelines are fully baked: binding one changes no state beyond the pipeline itself, and
 * the bindless table is already bound. */
gr_result gr_cmd_bind_pipeline(gr_handle cmd, gr_handle pipeline);
/* Writes push constants.
 *
 * There is deliberately no stage mask. The pipeline layout declares which stages may read which
 * byte range, and Vulkan requires the call to name exactly those stages for the bytes it writes —
 * a narrower mask is a validation error, and a wider one is meaningless. So the backend derives the
 * stages by intersecting the layout's declared ranges with [offset, offset + data.len). A caller
 * that wants per-stage constants changes the layout, which is the only place the decision can live
 * without a second source of truth. */
gr_result gr_cmd_push_constants(gr_handle cmd, uint32_t offset, gr_span_u8 data);
gr_result gr_cmd_bind_vertex_buffer(gr_handle cmd, uint32_t slot, gr_handle buffer, uint64_t offset);
gr_result gr_cmd_bind_index_buffer(gr_handle cmd, gr_handle buffer, uint64_t offset,
                                   uint32_t index_type /* 0: u16, 1: u32 */);

typedef struct gr_draw {
    gr_desc_head head;
    uint32_t vertex_count, instance_count;
    uint32_t first_vertex, first_instance;
} gr_draw;

typedef struct gr_draw_indexed {
    gr_desc_head head;
    uint32_t index_count, instance_count;
    uint32_t first_index;
    int32_t vertex_offset;
    uint32_t first_instance;
} gr_draw_indexed;

gr_result gr_cmd_draw(gr_handle cmd, const gr_draw *draw);
gr_result gr_cmd_draw_indexed(gr_handle cmd, const gr_draw_indexed *draw);
/* Indirect argument buffer; offset must satisfy gr_device_caps.buffer_address_min_align. */
gr_result gr_cmd_draw_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset,
                               uint32_t draw_count, uint32_t stride);
/* The same, for index buffers. `stride` must be at least the size of an indexed draw command
 * (20 bytes) and a multiple of 4, because the argument block is read as an array of those. A
 * smaller or unaligned stride is refused rather than read off the end of the block. */
gr_result gr_cmd_draw_indexed_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset,
                                       uint32_t draw_count, uint32_t stride);
gr_result gr_cmd_dispatch(gr_handle cmd, uint32_t x, uint32_t y, uint32_t z);
gr_result gr_cmd_dispatch_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset);

/* Mesh pipelines, present only with GR_CAP_MESH_SHADER. */
gr_result gr_cmd_draw_mesh(gr_handle cmd, uint32_t x, uint32_t y, uint32_t z);
gr_result gr_cmd_draw_mesh_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset,
                                    uint32_t count, uint32_t stride);

/* Explicit copy. A copy requires the resources in TRANSFER_SRC/TRANSFER_DST. */
typedef struct gr_buffer_copy {
    gr_handle src, dst;
    uint64_t src_offset, dst_offset, size;
} gr_buffer_copy;
gr_result gr_cmd_copy_buffer(gr_handle cmd, const gr_buffer_copy *copies, uint32_t count);

typedef struct gr_buffer_image_copy {
    gr_handle buffer, texture;
    uint64_t buffer_offset;
    uint32_t buffer_row_length;   /* texels; 0 means tightly packed */
    uint32_t buffer_image_height; /* 0 means tightly packed */
    uint32_t mip, layer, x, y, z;
    uint32_t width, height, depth;
} gr_buffer_image_copy;
gr_result gr_cmd_copy_buffer_to_texture(gr_handle cmd, const gr_buffer_image_copy *copy);
gr_result gr_cmd_copy_texture_to_buffer(gr_handle cmd, const gr_buffer_image_copy *copy);

/* Temporal and temporal-free markers, shown in the debugger and written to the log. */
gr_result gr_cmd_begin_scope(gr_handle cmd, gr_str name);
gr_result gr_cmd_end_scope(gr_handle cmd);

/* =======================================================================================
 * Synchronization and submission
 * ======================================================================================= */
gr_result gr_fence_create(gr_handle device, uint64_t initial_value, gr_handle *out_fence);
uint64_t gr_fence_value(gr_handle fence);
gr_result gr_fence_wait(gr_handle fence, uint64_t value, uint64_t timeout_ns,
                        gr_result *out_status);
gr_result gr_fence_reset(gr_handle fence, uint64_t value);

typedef struct gr_semaphore_wait {
    gr_handle semaphore;     /* timeline semaphore from gr_queue_timeline */
    uint64_t value;
    uint32_t stage_mask;     /* gr_pipeline_stage bits; 0 means "at submission" */
} gr_semaphore_wait;

typedef struct gr_semaphore_signal {
    gr_handle semaphore;
    uint64_t value;
} gr_semaphore_signal;

typedef enum gr_pipeline_stages {
    GR_STAGE_NONE = 0,
    GR_STAGE_TOP = 1u << 0,
    GR_STAGE_VERTEX = 1u << 1,
    GR_STAGE_FRAGMENT = 1u << 2,
    GR_STAGE_COMPUTE = 1u << 3,
    GR_STAGE_TRANSFER = 1u << 4,
    GR_STAGE_DEPTH = 1u << 5,
    GR_STAGE_MESH = 1u << 6,
    GR_STAGE_ALL = 0x7FFFFFFFu
} gr_pipeline_stages;

typedef struct gr_submit {
    gr_desc_head head;
    gr_handle queue;
    const gr_handle *cmds;
    uint32_t cmd_count;
    const gr_semaphore_wait *waits;     /* what must complete before this submission */
    uint32_t wait_count;
    const gr_semaphore_signal *signals; /* what this submission makes available */
    uint32_t signal_count;
} gr_submit;

/* Submits. The queue's timeline is signalled with the next value automatically and that
 * value is written to out_value, so every submission is observable without extra work. */
gr_result gr_submit_commands(const gr_submit *submit, uint64_t *out_value);

/* Maps a submission's timeline value to a monotonically comparable number usable as the
 * `after_value` of gr_device_retire. */
gr_result gr_queue_present(gr_handle queue, gr_handle swapchain, uint32_t image_index,
                           uint64_t wait_value, uint64_t *out_value);

/* =======================================================================================
 * Presentation modes
 *
 * Declared here rather than in grail_window.h because the swapchain is what must satisfy
 * it; the window layer only clamps a request to what the display allows.
 * ======================================================================================= */
typedef enum gr_present_mode {
    GR_PRESENT_FIFO = 0,        /* vsync, always available, lowest power */
    GR_PRESENT_MAILBOX = 1,     /* vsync with a one-frame queue; never tear */
    GR_PRESENT_IMMEDIATE = 2,   /* no vsync; may tear */
    GR_PRESENT_FIFO_RELAXED = 3
} gr_present_mode;

/* =======================================================================================
 * Swapchain
 * ======================================================================================= */
typedef struct gr_swapchain_desc {
    gr_desc_head head;
    gr_handle window;
    uint32_t width, height;      /* 0: the window's current pixel size */
    uint32_t image_count;        /* 0: a backend default (3) */
    gr_format format;            /* GR_FORMAT_UNDEFINED: the backend's preferred */
    uint32_t present_mode;       /* gr_present_mode */
    uint32_t usage;              /* gr_texture_usage for the images; SAMPLED and COLOR_ATTACHMENT */
    gr_str name;
} gr_swapchain_desc;

gr_result gr_swapchain_create(gr_handle device, const gr_swapchain_desc *desc,
                              gr_handle *out_swapchain);
/* The swapchain's actual format and extent, after any backend correction. */
gr_result gr_swapchain_info(gr_handle swapchain, gr_format *out_format, uint32_t *out_width,
                            uint32_t *out_height, uint32_t *out_image_count);
/* Acquires the next image. GR_TIMEOUT means nothing was ready. out_needs_recreate is 1 when
 * the swapchain is out of date (resize, format change) and must be rebuilt. */
gr_result gr_swapchain_acquire(gr_handle swapchain, uint64_t timeout_ns,
                               uint32_t *out_image_index, gr_handle *out_view,
                               int32_t *out_needs_recreate);
/* Rebuilds the swapchain in place, retiring the old one at `after_value`. */
gr_result gr_swapchain_recreate(gr_handle swapchain, uint32_t width, uint32_t height,
                               uint64_t after_value);

/* =======================================================================================
 * Queries
 * ======================================================================================= */
typedef struct gr_query_pool_desc {
    gr_desc_head head;
    uint32_t count;
    uint32_t type;   /* 0: timestamp, 1: occlusion */
    gr_str name;
} gr_query_pool_desc;

gr_result gr_query_pool_create(gr_handle device, const gr_query_pool_desc *desc,
                               gr_handle *out_pool);
gr_result gr_cmd_write_timestamp(gr_handle cmd, gr_handle pool, uint32_t index);
/* Reads `count` results in nanoseconds. Valid only after the submission that wrote them
 * completed; returns GR_ERROR_NOT_READY otherwise. */
gr_result gr_query_pool_results(gr_handle pool, uint32_t first, uint32_t count, uint64_t *out_ns);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_RHI_H */
