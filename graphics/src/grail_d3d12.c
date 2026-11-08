/* grail_d3d12.c - the Direct3D 12 backend.
 *
 * Built only where the Windows SDK headers exist (_WIN32); every other build gets the same
 * entry points as GR_ERROR_UNSUPPORTED stubs, so the dispatcher in grail_null.c can route to
 * them unconditionally.
 *
 * Implemented slice: headless device (adapter chosen by the runtime), one direct queue whose
 * ID3D12Fence is the timeline every gr fence observes, 2D single-mip render-target textures
 * in the formats d3d_format() names, render-target views from one CPU descriptor heap, command
 * pools and lists (one allocator per list), texture barriers with tracked states, render passes
 * that set targets and clear, viewport/scissor, submit, a synchronous texture readback, DXIL
 * shaders, graphics pipelines on the contract root signature (push constants and frame
 * constants), push constants, frame-constant slots, depth attachments and depth state, vertex
 * input matched to reflection, upload/readback/device buffers, vertex and index buffers, draws
 * (plain and indexed), the bindless tables (sampled images, samplers including the thirteen fixed
 * ones, storage buffers), texture upload, compute pipelines and dispatch, deferred release,
 * and flip-model swapchains on an SDL3 window's HWND with acquire, present and resize.
 * Everything else - MSAA, storage images, indirect draws and dispatches, mesh pipelines,
 * semaphores and non-graphics queues - returns GR_ERROR_UNSUPPORTED rather than an
 * approximation.
 *
 * Ownership: the device owns every object it creates and releases them, newest first, in
 * gr_device_destroy. State: the ABI's explicit barriers are the only state changes; a barrier
 * or readback whose source state disagrees with the tracked state is refused with
 * GR_ERROR_NOT_READY instead of being silently corrected. */
#include "grail_internal.h"

#if defined(_WIN32)

#define COBJMACROS
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include "../include/grail/grail_bindless.h"
#include "../include/grail/grail_window.h"
#include <stdint.h>
#include <limits.h>

#define D3D_RTV_MAX 256u
#define D3D_FRAME_SLOTS 2u
#define D3D_DSV_MAX 64u
#define D3D_VERTEX_SLOTS 8u
#define D3D_VERTEX_ATTRIBUTES 16u
#define D3D_DECAY_MAX 64u
#define D3D_SWAP_MAX 16u

/* ---- the implemented slice --------------------------------------------------------------- */

typedef struct d3d_device d3d_device;

typedef struct d3d_node {        /* every object the device owns, freed by device_destroy */
    struct d3d_node *next;
    gr_handle handle;
    uint32_t type;
} d3d_node;

typedef struct d3d_queue {
    d3d_node node;
    d3d_device *device;
    ID3D12CommandQueue *queue;
    ID3D12Fence *timeline;       /* the queue timeline every fence observes */
    HANDLE event;
    uint64_t submitted;
} d3d_queue;

struct d3d_device {
    d3d_node node;
    ID3D12Device *device;
    IDXGIAdapter1 *adapter;
    d3d_queue *graphics;
    gr_handle queue_handle;
    ID3D12DescriptorHeap *rtv_heap;
    uint32_t rtv_stride;
    uint8_t rtv_used[D3D_RTV_MAX];
    ID3D12DescriptorHeap *dsv_heap;
    uint32_t dsv_stride;
    uint8_t dsv_used[D3D_DSV_MAX];
    d3d_node *objects;           /* owned objects, newest first */
    D3D_FEATURE_LEVEL max_level; /* the highest level the driver supports, reported in caps */
    ID3D12RootSignature *root;   /* the contract's signature, built with the first pipeline */
    /* The bindless namespace: one shader-visible CBV/SRV/UAV heap split into the sampled-image,
     * storage-image and storage-buffer tables, and one sampler heap. Slots are handed out by
     * the resource calls and recycled after gr_device_retire's value completes. */
    ID3D12DescriptorHeap *resource_heap, *sampler_heap;
    uint32_t resource_stride, sampler_stride;
    uint8_t *slot_used[GR_BINDING_COUNT];
    uint32_t high_water[GR_BINDING_COUNT];
    struct d3d_retired *retired; /* objects whose release waits for a queue value */
    uint64_t retired_pending;
    gr_handle bindless_handle;
    d3d_node bindless_node;
    ID3D12Resource *frame;       /* frame constants, one 256-byte-aligned slot per frame */
    uint8_t *frame_mapped;
    uint32_t frame_stride;
    uint32_t pipelines_declared, pipelines_committed;
    int commit_done;
    DXGI_ADAPTER_DESC1 adapter_desc;
};

typedef struct d3d_texture {
    d3d_node node;
    d3d_device *device;
    ID3D12Resource *resource;
    gr_format format;
    DXGI_FORMAT dxgi;
    uint32_t width, height, bytes_per_pixel;
    uint32_t samples;
    uint32_t usage;
    D3D12_RESOURCE_STATES state; /* the state the last recorded barrier leaves it in */
} d3d_texture;

typedef struct d3d_view {
    d3d_node node;
    d3d_texture *texture;
    uint32_t rtv_index;          /* D3D_RTV_MAX: not a render-target view */
    uint32_t dsv_index;          /* D3D_DSV_MAX: not a depth-stencil view */
    uint32_t sampled_slot;       /* GR_BINDLESS_INDEX_NONE unless the texture is SAMPLED */
} d3d_view;

typedef struct d3d_buffer {
    d3d_node node;
    d3d_device *device;
    ID3D12Resource *resource;
    uint64_t size;
    uint32_t usage;
    uint32_t memory;             /* gr_memory */
    uint8_t *mapped;             /* persistently mapped for UPLOAD and READBACK */
    uint32_t storage_slot;       /* GR_BINDLESS_INDEX_NONE unless STORAGE */
    D3D12_RESOURCE_STATES state; /* tracked for storage buffers; decays to COMMON at submit */
    int transitions;             /* 0: an UPLOAD/READBACK heap buffer, which never transitions */
} d3d_buffer;

typedef struct d3d_swapchain {
    d3d_node node;
    d3d_device *device;
    IDXGISwapChain3 *swapchain;
    gr_format format;
    uint32_t width, height, image_count;
    UINT sync_interval, present_flags;
    struct d3d_texture *images[D3D_SWAP_MAX];
    struct d3d_view *views[D3D_SWAP_MAX];
    gr_handle image_handles[D3D_SWAP_MAX], view_handles[D3D_SWAP_MAX];
    uint64_t image_done[D3D_SWAP_MAX]; /* queue value after which the image may be rendered again */
    uint32_t acquired;                 /* D3D_SWAP_MAX: nothing acquired */
} d3d_swapchain;

typedef struct d3d_sampler {
    d3d_node node;
    uint32_t slot;
} d3d_sampler;

typedef struct d3d_retired {
    struct d3d_retired *next;
    gr_handle object;
    uint64_t after_value;
} d3d_retired;

typedef struct d3d_pool {
    d3d_node node;
    d3d_device *device;
    gr_queue_kind queue;
} d3d_pool;

typedef struct d3d_cmd {
    d3d_node node;
    d3d_device *device;
    ID3D12CommandAllocator *allocator;
    ID3D12GraphicsCommandList *list;
    int recording;
    uint64_t last_submit;        /* queue value that must complete before the allocator resets */
    struct d3d_pipeline *pipeline; /* bound in this recording, or NULL */
    uint32_t frame_slot;
    d3d_buffer *decay[D3D_DECAY_MAX]; /* storage buffers transitioned in this recording */
    uint32_t decay_count;
    struct d3d_view *resolve_src[D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT]; /* resolved at end_render */
    struct d3d_view *resolve_dst[D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT];
    uint32_t resolve_count;
} d3d_cmd;

typedef struct d3d_shader {
    d3d_node node;
    d3d_device *device;
    gr_shader_stage stage;
    uint64_t permutation_key;
    uint8_t *dxil;               /* owned copy of the container */
    size_t dxil_len;
    uint8_t *refl;               /* owned copy of the reflection blob (vertex inputs) */
    size_t refl_len;
} d3d_shader;

typedef struct d3d_pipeline {
    d3d_node node;
    d3d_device *device;
    ID3D12PipelineState *pso;
    int compute;
    D3D_PRIMITIVE_TOPOLOGY topology;
    uint32_t strides[D3D_VERTEX_SLOTS]; /* per vertex-buffer slot, from the pipeline's bindings */
    uint32_t slot_mask;
} d3d_pipeline;

typedef struct d3d_fence {
    d3d_node node;
    d3d_device *device;
    uint64_t value;
} d3d_fence;

static void *d3d_get(gr_handle handle, uint32_t type)
{
    return gr_object_lookup(gr_objects(), handle, type, NULL);
}

static gr_result d3d_own(d3d_device *device, d3d_node *node, uint32_t type, void *object,
                         gr_handle *out)
{
    gr_handle handle = gr_object_insert(gr_objects(), type, object);
    if (handle == GR_NULL_HANDLE)
        return GR_ERROR_OUT_OF_MEMORY;
    node->handle = handle;
    node->type = type;
    node->next = device->objects;
    device->objects = node;
    *out = handle;
    return GR_OK;
}

static int d3d_is_depth(gr_format format)
{
    return format == GR_FORMAT_D32_FLOAT || format == GR_FORMAT_D16_UNORM ||
           format == GR_FORMAT_D24_UNORM_S8_UINT || format == GR_FORMAT_D32_FLOAT_S8_UINT;
}

static DXGI_FORMAT d3d_format(gr_format format, uint32_t *out_bpp)
{
    switch (format) {
    case GR_FORMAT_R8G8B8A8_UNORM: *out_bpp = 4; return DXGI_FORMAT_R8G8B8A8_UNORM;
    case GR_FORMAT_R8G8B8A8_SRGB: *out_bpp = 4; return DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
    case GR_FORMAT_B8G8R8A8_UNORM: *out_bpp = 4; return DXGI_FORMAT_B8G8R8A8_UNORM;
    case GR_FORMAT_B8G8R8A8_SRGB: *out_bpp = 4; return DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
    case GR_FORMAT_R16G16B16A16_FLOAT: *out_bpp = 8; return DXGI_FORMAT_R16G16B16A16_FLOAT;
    case GR_FORMAT_R32_FLOAT: *out_bpp = 4; return DXGI_FORMAT_R32_FLOAT;
    case GR_FORMAT_R32G32B32A32_FLOAT: *out_bpp = 16; return DXGI_FORMAT_R32G32B32A32_FLOAT;
    case GR_FORMAT_R32G32_FLOAT: *out_bpp = 8; return DXGI_FORMAT_R32G32_FLOAT;
    case GR_FORMAT_R32_UINT: *out_bpp = 4; return DXGI_FORMAT_R32_UINT;
    case GR_FORMAT_D32_FLOAT: *out_bpp = 4; return DXGI_FORMAT_D32_FLOAT;
    case GR_FORMAT_D16_UNORM: *out_bpp = 2; return DXGI_FORMAT_D16_UNORM;
    case GR_FORMAT_D24_UNORM_S8_UINT: *out_bpp = 4; return DXGI_FORMAT_D24_UNORM_S8_UINT;
    case GR_FORMAT_D32_FLOAT_S8_UINT: *out_bpp = 8; return DXGI_FORMAT_D32_FLOAT_S8X24_UINT;
    default: *out_bpp = 0; return DXGI_FORMAT_UNKNOWN;
    }
}

/* GR_STATE_UNDEFINED means "contents may be discarded"; D3D12 still needs the real prior state,
 * which the texture tracks. Any other source state must match what was last recorded. */
static int d3d_state(uint32_t state, D3D12_RESOURCE_STATES *out)
{
    switch (state) {
    case GR_STATE_GENERAL: *out = D3D12_RESOURCE_STATE_UNORDERED_ACCESS; return 1;
    case GR_STATE_SHADER_READ:
        *out = D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE | D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
        return 1;
    case GR_STATE_COLOR_ATTACHMENT: *out = D3D12_RESOURCE_STATE_RENDER_TARGET; return 1;
    case GR_STATE_DEPTH_ATTACHMENT_WRITE: *out = D3D12_RESOURCE_STATE_DEPTH_WRITE; return 1;
    case GR_STATE_DEPTH_ATTACHMENT_READ: *out = D3D12_RESOURCE_STATE_DEPTH_READ; return 1;
    case GR_STATE_TRANSFER_SRC: *out = D3D12_RESOURCE_STATE_COPY_SOURCE; return 1;
    case GR_STATE_TRANSFER_DST: *out = D3D12_RESOURCE_STATE_COPY_DEST; return 1;
    case GR_STATE_PRESENT: *out = D3D12_RESOURCE_STATE_PRESENT; return 1;
    default: return 0;
    }
}

static d3d_texture *d3d_texture_of(gr_handle handle)
{
    d3d_texture *texture = (d3d_texture *)d3d_get(handle, GR_HANDLE_TEXTURE);
    d3d_view *view;
    if (texture)
        return texture;
    view = (d3d_view *)d3d_get(handle, GR_HANDLE_TEXTURE_VIEW);
    return view ? view->texture : NULL;
}

static gr_result d3d_wait_value(d3d_queue *queue, uint64_t value, uint64_t timeout_ns)
{
    DWORD ms;
    if (ID3D12Fence_GetCompletedValue(queue->timeline) >= value)
        return GR_OK;
    if (FAILED(ID3D12Fence_SetEventOnCompletion(queue->timeline, value, queue->event)))
        return GR_ERROR_BACKEND;
    ms = timeout_ns >= (uint64_t)INFINITE * 1000000ull ? INFINITE : (DWORD)(timeout_ns / 1000000ull);
    if (WaitForSingleObject(queue->event, ms) != WAIT_OBJECT_0)
        return ID3D12Fence_GetCompletedValue(queue->timeline) >= value ? GR_OK : GR_TIMEOUT;
    return GR_OK;
}

static gr_result d3d_signal(d3d_queue *queue, uint64_t *out_value)
{
    uint64_t value = queue->submitted + 1;
    if (FAILED(ID3D12CommandQueue_Signal(queue->queue, queue->timeline, value)))
        return GR_ERROR_BACKEND;
    queue->submitted = value;
    if (out_value)
        *out_value = value;
    return GR_OK;
}

static const uint32_t d3d_table_capacity[GR_BINDING_COUNT] = {
    GR_BINDLESS_CAP_SAMPLED_IMAGES, GR_BINDLESS_CAP_STORAGE_IMAGES, GR_BINDLESS_CAP_SAMPLERS,
    GR_BINDLESS_CAP_STORAGE_BUFFERS, 0 /* acceleration structures: not on this backend yet */
};

/* Where each resource table starts in the shader-visible resource heap. */
static uint32_t d3d_table_base(uint32_t table)
{
    switch (table) {
    case GR_BINDING_SAMPLED_IMAGES: return 0;
    case GR_BINDING_STORAGE_IMAGES: return GR_BINDLESS_CAP_SAMPLED_IMAGES;
    case GR_BINDING_STORAGE_BUFFERS: return GR_BINDLESS_CAP_SAMPLED_IMAGES + GR_BINDLESS_CAP_STORAGE_IMAGES;
    default: return 0;
    }
}

static uint32_t d3d_slot_alloc(d3d_device *dev, uint32_t table, uint32_t first)
{
    uint32_t i;
    for (i = first; i < d3d_table_capacity[table]; ++i)
        if (!dev->slot_used[table][i]) {
            dev->slot_used[table][i] = 1;
            if (i + 1 > dev->high_water[table])
                dev->high_water[table] = i + 1;
            return i;
        }
    return GR_BINDLESS_INDEX_NONE;
}

static D3D12_CPU_DESCRIPTOR_HANDLE d3d_resource_cpu(d3d_device *dev, uint32_t table, uint32_t slot)
{
    D3D12_CPU_DESCRIPTOR_HANDLE cpu;
    dev->resource_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(dev->resource_heap, &cpu);
    cpu.ptr += (SIZE_T)(d3d_table_base(table) + slot) * dev->resource_stride;
    return cpu;
}

static D3D12_FILTER d3d_filter(const gr_sampler_desc *desc)
{
    D3D12_FILTER_TYPE min = desc->min_filter == GR_FILTER_NEAREST ? D3D12_FILTER_TYPE_POINT : D3D12_FILTER_TYPE_LINEAR;
    D3D12_FILTER_TYPE mag = desc->mag_filter == GR_FILTER_NEAREST ? D3D12_FILTER_TYPE_POINT : D3D12_FILTER_TYPE_LINEAR;
    D3D12_FILTER_TYPE mip = desc->mip_filter == GR_FILTER_NEAREST ? D3D12_FILTER_TYPE_POINT : D3D12_FILTER_TYPE_LINEAR;
    D3D12_FILTER_REDUCTION_TYPE reduction = desc->reduction == GR_REDUCTION_COMPARE ? D3D12_FILTER_REDUCTION_TYPE_COMPARISON
                                            : desc->reduction == GR_REDUCTION_MIN   ? D3D12_FILTER_REDUCTION_TYPE_MINIMUM
                                            : desc->reduction == GR_REDUCTION_MAX   ? D3D12_FILTER_REDUCTION_TYPE_MAXIMUM
                                                                                    : D3D12_FILTER_REDUCTION_TYPE_STANDARD;
    if (desc->max_anisotropy > 1.0f)
        return D3D12_ENCODE_ANISOTROPIC_FILTER(reduction);
    return D3D12_ENCODE_BASIC_FILTER(min, mag, mip, reduction);
}

static D3D12_TEXTURE_ADDRESS_MODE d3d_address(gr_address_mode mode)
{
    switch (mode) {
    case GR_ADDRESS_CLAMP: return D3D12_TEXTURE_ADDRESS_MODE_CLAMP;
    case GR_ADDRESS_MIRROR: return D3D12_TEXTURE_ADDRESS_MODE_MIRROR;
    case GR_ADDRESS_BORDER: return D3D12_TEXTURE_ADDRESS_MODE_BORDER;
    default: return D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    }
}

static void d3d_write_sampler(d3d_device *dev, uint32_t slot, const gr_sampler_desc *desc)
{
    D3D12_SAMPLER_DESC sd;
    D3D12_CPU_DESCRIPTOR_HANDLE cpu;
    memset(&sd, 0, sizeof(sd));
    sd.Filter = d3d_filter(desc);
    sd.AddressU = d3d_address(desc->address_u);
    sd.AddressV = d3d_address(desc->address_v);
    sd.AddressW = d3d_address(desc->address_w);
    sd.MipLODBias = desc->mip_lod_bias;
    sd.MaxAnisotropy = desc->max_anisotropy > 1.0f ? (UINT)desc->max_anisotropy : 1u;
    sd.ComparisonFunc = desc->reduction == GR_REDUCTION_COMPARE ? D3D12_COMPARISON_FUNC_GREATER_EQUAL
                                                                : D3D12_COMPARISON_FUNC_NEVER;
    sd.MinLOD = desc->min_lod;
    sd.MaxLOD = desc->max_lod > 0.0f ? desc->max_lod : D3D12_FLOAT32_MAX;
    dev->sampler_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(dev->sampler_heap, &cpu);
    cpu.ptr += (SIZE_T)slot * dev->sampler_stride;
    ID3D12Device_CreateSampler(dev->device, &sd, cpu);
}

static gr_result d3d_bindless_init(d3d_device *dev)
{
    D3D12_DESCRIPTOR_HEAP_DESC hd;
    uint32_t t, i;
    for (t = 0; t < GR_BINDING_COUNT; ++t) {
        dev->slot_used[t] = (uint8_t *)calloc(d3d_table_capacity[t] ? d3d_table_capacity[t] : 1, 1);
        if (!dev->slot_used[t])
            return GR_ERROR_OUT_OF_MEMORY;
    }
    memset(&hd, 0, sizeof(hd));
    hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    hd.NumDescriptors = GR_BINDLESS_CAP_SAMPLED_IMAGES + GR_BINDLESS_CAP_STORAGE_IMAGES + GR_BINDLESS_CAP_STORAGE_BUFFERS;
    hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    if (FAILED(ID3D12Device_CreateDescriptorHeap(dev->device, &hd, &IID_ID3D12DescriptorHeap,
                                                 (void **)&dev->resource_heap)))
        return GR_ERROR_UNSUPPORTED; /* the full-capacity table is the contract; it is not shrunk */
    hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER;
    hd.NumDescriptors = GR_BINDLESS_CAP_SAMPLERS;
    if (FAILED(ID3D12Device_CreateDescriptorHeap(dev->device, &hd, &IID_ID3D12DescriptorHeap,
                                                 (void **)&dev->sampler_heap)))
        return GR_ERROR_UNSUPPORTED;
    dev->resource_stride = ID3D12Device_GetDescriptorHandleIncrementSize(dev->device, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    dev->sampler_stride = ID3D12Device_GetDescriptorHandleIncrementSize(dev->device, D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER);
    for (i = 0; i < GR_SAMPLER_SLOT_COUNT; ++i) {
        gr_sampler_desc fixed;
        gr_fixed_sampler(i, &fixed);
        d3d_write_sampler(dev, i, &fixed);
        dev->slot_used[GR_BINDING_SAMPLERS][i] = 1;
    }
    dev->high_water[GR_BINDING_SAMPLERS] = GR_SAMPLER_SLOT_COUNT;
    return GR_OK;
}

gr_result gr_d3d12_abi_device_create(const gr_device_desc *desc, gr_handle *out_device)
{
    d3d_device *dev;
    IDXGIFactory4 *factory = NULL;
    D3D12_COMMAND_QUEUE_DESC qd;
    D3D12_DESCRIPTOR_HEAP_DESC hd;
    D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_12_0;
    LUID luid;
    gr_result status;
    if (!desc || !out_device)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_device = GR_NULL_HANDLE;
    if (desc->window != GR_NULL_HANDLE)
        return GR_ERROR_UNSUPPORTED; /* headless only: no swapchain in this slice */
    if (desc->api_min_major == 11)
        level = desc->api_min_minor >= 1 ? D3D_FEATURE_LEVEL_11_1 : D3D_FEATURE_LEVEL_11_0;
    else if (desc->api_min_major == 12 && desc->api_min_minor >= 1)
        level = D3D_FEATURE_LEVEL_12_1;
    else if (desc->api_min_major != 0 && desc->api_min_major != 12)
        return GR_ERROR_UNSUPPORTED;
    gr_objects_init_once();
    dev = (d3d_device *)calloc(1, sizeof(*dev));
    if (!dev)
        return GR_ERROR_OUT_OF_MEMORY;
    if (FAILED(D3D12CreateDevice(NULL, level, &IID_ID3D12Device, (void **)&dev->device))) {
        free(dev);
        return GR_ERROR_UNSUPPORTED;
    }
    dev->device->lpVtbl->GetAdapterLuid(dev->device, &luid);
    {
        static const D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_11_1,
                                                    D3D_FEATURE_LEVEL_12_0, D3D_FEATURE_LEVEL_12_1,
                                                    D3D_FEATURE_LEVEL_12_2 };
        D3D12_FEATURE_DATA_FEATURE_LEVELS query;
        query.NumFeatureLevels = (UINT)(sizeof(levels) / sizeof(levels[0]));
        query.pFeatureLevelsRequested = levels;
        query.MaxSupportedFeatureLevel = level;
        if (FAILED(ID3D12Device_CheckFeatureSupport(dev->device, D3D12_FEATURE_FEATURE_LEVELS, &query,
                                                    sizeof(query))))
            query.MaxSupportedFeatureLevel = level;
        dev->max_level = query.MaxSupportedFeatureLevel;
    }
    if (SUCCEEDED(CreateDXGIFactory1(&IID_IDXGIFactory4, (void **)&factory))) {
        if (SUCCEEDED(IDXGIFactory4_EnumAdapterByLuid(factory, luid, &IID_IDXGIAdapter1,
                                                      (void **)&dev->adapter)))
            IDXGIAdapter1_GetDesc1(dev->adapter, &dev->adapter_desc);
        IDXGIFactory4_Release(factory);
    }
    dev->graphics = (d3d_queue *)calloc(1, sizeof(*dev->graphics));
    memset(&qd, 0, sizeof(qd));
    qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    memset(&hd, 0, sizeof(hd));
    hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    hd.NumDescriptors = D3D_RTV_MAX;
    if (!dev->graphics ||
        FAILED(ID3D12Device_CreateCommandQueue(dev->device, &qd, &IID_ID3D12CommandQueue,
                                               (void **)&dev->graphics->queue)) ||
        FAILED(ID3D12Device_CreateFence(dev->device, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence,
                                        (void **)&dev->graphics->timeline)) ||
        !(dev->graphics->event = CreateEventA(NULL, FALSE, FALSE, NULL)) ||
        FAILED(ID3D12Device_CreateDescriptorHeap(dev->device, &hd, &IID_ID3D12DescriptorHeap,
                                                 (void **)&dev->rtv_heap)) ||
        (hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_DSV, hd.NumDescriptors = D3D_DSV_MAX,
         FAILED(ID3D12Device_CreateDescriptorHeap(dev->device, &hd, &IID_ID3D12DescriptorHeap,
                                                  (void **)&dev->dsv_heap)))) {
        status = GR_ERROR_BACKEND;
        goto fail;
    }
    dev->graphics->device = dev;
    {
        D3D12_HEAP_PROPERTIES upload;
        D3D12_RESOURCE_DESC bd;
        D3D12_RANGE none = { 0, 0 };
        dev->frame_stride = (uint32_t)((sizeof(gr_frame_constants) + 255u) & ~(size_t)255u);
        memset(&upload, 0, sizeof(upload));
        upload.Type = D3D12_HEAP_TYPE_UPLOAD;
        memset(&bd, 0, sizeof(bd));
        bd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        bd.Width = (UINT64)dev->frame_stride * D3D_FRAME_SLOTS;
        bd.Height = 1;
        bd.DepthOrArraySize = 1;
        bd.MipLevels = 1;
        bd.SampleDesc.Count = 1;
        bd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        if (FAILED(ID3D12Device_CreateCommittedResource(dev->device, &upload, D3D12_HEAP_FLAG_NONE, &bd,
                                                        D3D12_RESOURCE_STATE_GENERIC_READ, NULL,
                                                        &IID_ID3D12Resource, (void **)&dev->frame)) ||
            FAILED(ID3D12Resource_Map(dev->frame, 0, &none, (void **)&dev->frame_mapped))) {
            status = GR_ERROR_OUT_OF_MEMORY;
            goto fail;
        }
        memset(dev->frame_mapped, 0, (size_t)dev->frame_stride * D3D_FRAME_SLOTS);
    }
    dev->rtv_stride = ID3D12Device_GetDescriptorHandleIncrementSize(dev->device,
                                                                    D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    dev->dsv_stride = ID3D12Device_GetDescriptorHandleIncrementSize(dev->device,
                                                                    D3D12_DESCRIPTOR_HEAP_TYPE_DSV);
    status = d3d_bindless_init(dev);
    if (status != GR_OK)
        goto fail;
    *out_device = gr_object_insert(gr_objects(), GR_HANDLE_DEVICE, dev);
    if (*out_device == GR_NULL_HANDLE) {
        status = GR_ERROR_OUT_OF_MEMORY;
        goto fail;
    }
    dev->node.handle = *out_device;
    dev->bindless_handle = gr_object_insert(gr_objects(), GR_HANDLE_BINDLESS, dev);
    status = d3d_own(dev, &dev->graphics->node, GR_HANDLE_QUEUE, dev->graphics, &dev->queue_handle);
    if (status != GR_OK) {
        gr_object_remove(gr_objects(), *out_device, GR_HANDLE_DEVICE);
        *out_device = GR_NULL_HANDLE;
        goto fail;
    }
    return GR_OK;
fail:
    {
        uint32_t t;
        for (t = 0; t < GR_BINDING_COUNT; ++t)
            free(dev->slot_used[t]);
    }
    if (dev->resource_heap) ID3D12DescriptorHeap_Release(dev->resource_heap);
    if (dev->sampler_heap) ID3D12DescriptorHeap_Release(dev->sampler_heap);
    if (dev->frame) ID3D12Resource_Release(dev->frame);
    if (dev->dsv_heap) ID3D12DescriptorHeap_Release(dev->dsv_heap);
    if (dev->rtv_heap) ID3D12DescriptorHeap_Release(dev->rtv_heap);
    if (dev->graphics) {
        if (dev->graphics->event) CloseHandle(dev->graphics->event);
        if (dev->graphics->timeline) ID3D12Fence_Release(dev->graphics->timeline);
        if (dev->graphics->queue) ID3D12CommandQueue_Release(dev->graphics->queue);
        free(dev->graphics);
    }
    if (dev->adapter) IDXGIAdapter1_Release(dev->adapter);
    ID3D12Device_Release(dev->device);
    free(dev);
    return status;
}

static d3d_device *d3d_device_of(gr_handle handle)
{
    return (d3d_device *)d3d_get(handle, GR_HANDLE_DEVICE);
}

typedef struct d3d_swapchain d3d_swapchain_fwd;
static void d3d_swap_release_images(struct d3d_swapchain *sc);

static void d3d_release(d3d_node *node)
{
    switch (node->type) {
    case GR_HANDLE_TEXTURE: {
        d3d_texture *t = (d3d_texture *)node;
        ID3D12Resource_Release(t->resource);
        break;
    }
    case GR_HANDLE_TEXTURE_VIEW: {
        d3d_view *v = (d3d_view *)node;
        if (v->rtv_index < D3D_RTV_MAX)
            v->texture->device->rtv_used[v->rtv_index] = 0;
        if (v->dsv_index < D3D_DSV_MAX)
            v->texture->device->dsv_used[v->dsv_index] = 0;
        if (v->sampled_slot != GR_BINDLESS_INDEX_NONE)
            v->texture->device->slot_used[GR_BINDING_SAMPLED_IMAGES][v->sampled_slot] = 0;
        break;
    }
    case GR_HANDLE_SAMPLER:
        break; /* the slot is released by the caller, which knows the device */
    case GR_HANDLE_SWAPCHAIN: {
        d3d_swapchain *sc = (d3d_swapchain *)node;
        d3d_swap_release_images(sc);
        IDXGISwapChain3_Release(sc->swapchain);
        break;
    }
    case GR_HANDLE_BUFFER: {
        d3d_buffer *b = (d3d_buffer *)node;
        if (b->storage_slot != GR_BINDLESS_INDEX_NONE)
            b->device->slot_used[GR_BINDING_STORAGE_BUFFERS][b->storage_slot] = 0;
        if (b->mapped)
            ID3D12Resource_Unmap(b->resource, 0, NULL);
        ID3D12Resource_Release(b->resource);
        break;
    }
    case GR_HANDLE_CMD_BUFFER: {
        d3d_cmd *c = (d3d_cmd *)node;
        ID3D12GraphicsCommandList_Release(c->list);
        ID3D12CommandAllocator_Release(c->allocator);
        break;
    }
    case GR_HANDLE_SHADER: {
        d3d_shader *sh = (d3d_shader *)node;
        free(sh->refl);
        free(sh->dxil);
        break;
    }
    case GR_HANDLE_PIPELINE: {
        d3d_pipeline *pl = (d3d_pipeline *)node;
        ID3D12PipelineState_Release(pl->pso);
        break;
    }
    case GR_HANDLE_QUEUE: {
        d3d_queue *q = (d3d_queue *)node;
        CloseHandle(q->event);
        ID3D12Fence_Release(q->timeline);
        ID3D12CommandQueue_Release(q->queue);
        break;
    }
    default:
        break;
    }
    gr_object_remove(gr_objects(), node->handle, node->type);
    free(node);
}

gr_result gr_d3d12_abi_device_wait_idle(gr_handle device_handle)
{
    d3d_device *dev = d3d_device_of(device_handle);
    gr_result status;
    uint64_t value;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    status = d3d_signal(dev->graphics, &value);
    return status == GR_OK ? d3d_wait_value(dev->graphics, value, UINT64_MAX) : status;
}

gr_result gr_d3d12_abi_device_destroy(gr_handle device_handle)
{
    d3d_device *dev = d3d_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    (void)gr_d3d12_abi_device_wait_idle(device_handle);
    while (dev->objects) {       /* newest first: views before textures, the queue last */
        d3d_node *node = dev->objects;
        dev->objects = node->next;
        d3d_release(node);
    }
    ID3D12DescriptorHeap_Release(dev->rtv_heap);
    ID3D12DescriptorHeap_Release(dev->dsv_heap);
    ID3D12DescriptorHeap_Release(dev->resource_heap);
    ID3D12DescriptorHeap_Release(dev->sampler_heap);
    {
        uint32_t t;
        for (t = 0; t < GR_BINDING_COUNT; ++t)
            free(dev->slot_used[t]);
    }
    while (dev->retired) {
        d3d_retired *r = dev->retired;
        dev->retired = r->next;
        free(r);
    }
    if (dev->bindless_handle != GR_NULL_HANDLE)
        gr_object_remove(gr_objects(), dev->bindless_handle, GR_HANDLE_BINDLESS);
    if (dev->root) ID3D12RootSignature_Release(dev->root);
    if (dev->frame) ID3D12Resource_Release(dev->frame);
    if (dev->adapter) IDXGIAdapter1_Release(dev->adapter);
    ID3D12Device_Release(dev->device);
    gr_object_remove(gr_objects(), device_handle, GR_HANDLE_DEVICE);
    free(dev);
    return GR_OK;
}

gr_result gr_d3d12_abi_device_get_caps(gr_handle device_handle, gr_device_caps *out)
{
    d3d_device *dev = d3d_device_of(device_handle);
    uint64_t frequency = 0;
    size_t i;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!out || out->head.size < sizeof(*out))
        return GR_ERROR_INVALID_ARGUMENT;
    memset((char *)out + sizeof(out->head), 0, sizeof(*out) - sizeof(out->head));
    out->backend = GR_BACKEND_D3D12;
    for (i = 0; i + 1 < sizeof(out->device_name) && dev->adapter_desc.Description[i]; ++i)
        out->device_name[i] = dev->adapter_desc.Description[i] < 128
                                  ? (char)dev->adapter_desc.Description[i] : '?';
    memcpy(out->driver_name, "d3d12", 6);
    /* D3D12 has no API version beyond 12; the feature level is what a caller can rely on. */
    out->api_major = ((uint32_t)dev->max_level >> 12) & 0xFu;
    out->api_minor = ((uint32_t)dev->max_level >> 8) & 0xFu;
    out->vendor_id = dev->adapter_desc.VendorId;
    out->device_id = dev->adapter_desc.DeviceId;
    out->device_memory_bytes = dev->adapter_desc.DedicatedVideoMemory;
    out->max_push_constant_bytes = 128;
    out->max_color_attachments = D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT;
    out->timestamp_valid_bits = 64;
    if (SUCCEEDED(ID3D12CommandQueue_GetTimestampFrequency(dev->graphics->queue, &frequency)) &&
        frequency)
        out->timestamp_period_ns = (float)(1e9 / (double)frequency);
    out->depth_range_zero_to_one = 1;
    out->max_frames_in_flight = 2;
    return GR_OK;
}

gr_result gr_d3d12_abi_device_queue(gr_handle device_handle, gr_queue_kind kind, gr_handle *out_queue)
{
    d3d_device *dev = d3d_device_of(device_handle);
    if (!dev || !out_queue)
        return dev ? GR_ERROR_INVALID_ARGUMENT : GR_ERROR_INVALID_HANDLE;
    if (kind != GR_QUEUE_GRAPHICS)
        return GR_ERROR_UNSUPPORTED; /* one direct queue in this slice */
    *out_queue = dev->queue_handle;
    return GR_OK;
}

uint64_t gr_d3d12_abi_queue_submitted(gr_handle queue_handle)
{
    d3d_queue *queue = (d3d_queue *)d3d_get(queue_handle, GR_HANDLE_QUEUE);
    return queue ? queue->submitted : 0;
}

uint64_t gr_d3d12_abi_queue_completed(gr_handle queue_handle)
{
    d3d_queue *queue = (d3d_queue *)d3d_get(queue_handle, GR_HANDLE_QUEUE);
    return queue ? ID3D12Fence_GetCompletedValue(queue->timeline) : 0;
}

gr_result gr_d3d12_abi_queue_wait_idle(gr_handle queue_handle)
{
    d3d_queue *queue = (d3d_queue *)d3d_get(queue_handle, GR_HANDLE_QUEUE);
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    return d3d_wait_value(queue, queue->submitted, UINT64_MAX);
}

gr_result gr_d3d12_abi_texture_create(gr_handle device_handle, const gr_texture_desc *desc,
                                      gr_handle *out_texture)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_texture *texture;
    D3D12_HEAP_PROPERTIES heap;
    D3D12_RESOURCE_DESC rd;
    D3D12_CLEAR_VALUE clear;
    uint32_t bpp;
    DXGI_FORMAT dxgi;
    gr_result status;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!desc || !out_texture || desc->width == 0 || desc->height == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_texture = GR_NULL_HANDLE;
    dxgi = d3d_format(desc->format, &bpp);
    if (dxgi == DXGI_FORMAT_UNKNOWN || desc->type != GR_TEXTURE_2D || desc->mip_levels > 1 ||
        desc->array_layers > 1 ||
        (desc->usage & ~(uint32_t)(GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC |
                                   GR_TEXTURE_USAGE_TRANSFER_DST | GR_TEXTURE_USAGE_DEPTH_ATTACHMENT |
                                   GR_TEXTURE_USAGE_SAMPLED)))
        return GR_ERROR_UNSUPPORTED;
    if (desc->samples > 1) {
        D3D12_FEATURE_DATA_MULTISAMPLE_QUALITY_LEVELS q;
        if ((desc->samples & (desc->samples - 1)) || desc->samples > 16 ||
            !(desc->usage & (GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_DEPTH_ATTACHMENT)) ||
            (desc->usage & (GR_TEXTURE_USAGE_SAMPLED | GR_TEXTURE_USAGE_TRANSFER_SRC | GR_TEXTURE_USAGE_TRANSFER_DST)))
            return GR_ERROR_INVALID_ARGUMENT; /* a multisampled image is an attachment, resolved to read */
        memset(&q, 0, sizeof(q));
        q.Format = dxgi;
        q.SampleCount = desc->samples;
        if (FAILED(ID3D12Device_CheckFeatureSupport(dev->device, D3D12_FEATURE_MULTISAMPLE_QUALITY_LEVELS, &q,
                                                    sizeof(q))) || q.NumQualityLevels == 0)
            return GR_ERROR_UNSUPPORTED;
    }
    if (((desc->usage & GR_TEXTURE_USAGE_DEPTH_ATTACHMENT) != 0) != d3d_is_depth(desc->format) ||
        ((desc->usage & GR_TEXTURE_USAGE_COLOR_ATTACHMENT) && d3d_is_depth(desc->format)))
        return GR_ERROR_INVALID_ARGUMENT; /* a depth format is a depth attachment and nothing else */
    texture = (d3d_texture *)calloc(1, sizeof(*texture));
    if (!texture)
        return GR_ERROR_OUT_OF_MEMORY;
    memset(&heap, 0, sizeof(heap));
    heap.Type = D3D12_HEAP_TYPE_DEFAULT;
    memset(&rd, 0, sizeof(rd));
    rd.Dimension = D3D12_RESOURCE_DIMENSION_TEXTURE2D;
    rd.Width = desc->width;
    rd.Height = desc->height;
    rd.DepthOrArraySize = 1;
    rd.MipLevels = 1;
    rd.Format = dxgi;
    rd.SampleDesc.Count = desc->samples > 1 ? desc->samples : 1;
    if (desc->usage & GR_TEXTURE_USAGE_COLOR_ATTACHMENT)
        rd.Flags = D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;
    if (desc->usage & GR_TEXTURE_USAGE_DEPTH_ATTACHMENT)
        rd.Flags = D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL;
    memset(&clear, 0, sizeof(clear));
    clear.Format = dxgi; /* reverse-Z clears depth to 0.0, which is this value */
    if (FAILED(ID3D12Device_CreateCommittedResource(
            dev->device, &heap, D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_COMMON,
            (desc->usage & (GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_DEPTH_ATTACHMENT)) ? &clear : NULL,
            &IID_ID3D12Resource, (void **)&texture->resource))) {
        free(texture);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    texture->device = dev;
    texture->format = desc->format;
    texture->dxgi = dxgi;
    texture->width = desc->width;
    texture->height = desc->height;
    texture->bytes_per_pixel = bpp;
    texture->usage = desc->usage;
    texture->samples = desc->samples > 1 ? desc->samples : 1;
    texture->state = D3D12_RESOURCE_STATE_COMMON;
    status = d3d_own(dev, &texture->node, GR_HANDLE_TEXTURE, texture, out_texture);
    if (status != GR_OK) {
        ID3D12Resource_Release(texture->resource);
        free(texture);
    }
    return status;
}

gr_result gr_d3d12_abi_texture_view_create(gr_handle device_handle, const gr_texture_view_desc *desc,
                                           gr_handle *out_view)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_texture *texture;
    d3d_view *view;
    D3D12_RENDER_TARGET_VIEW_DESC rtv;
    D3D12_CPU_DESCRIPTOR_HANDLE cpu;
    uint32_t slot, bpp;
    gr_result status;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!desc || !out_view)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_view = GR_NULL_HANDLE;
    texture = (d3d_texture *)d3d_get(desc->texture, GR_HANDLE_TEXTURE);
    if (!texture || texture->device != dev)
        return GR_ERROR_INVALID_HANDLE;
    if (desc->type != GR_VIEW_2D || desc->base_mip != 0 || desc->mip_count > 1 ||
        desc->base_layer != 0 || desc->layer_count > 1)
        return GR_ERROR_UNSUPPORTED;
    view = (d3d_view *)calloc(1, sizeof(*view));
    if (!view)
        return GR_ERROR_OUT_OF_MEMORY;
    view->texture = texture;
    view->rtv_index = D3D_RTV_MAX;
    view->dsv_index = D3D_DSV_MAX;
    view->sampled_slot = GR_BINDLESS_INDEX_NONE;
    if ((texture->usage & GR_TEXTURE_USAGE_SAMPLED) && !d3d_is_depth(texture->format)) {
        D3D12_SHADER_RESOURCE_VIEW_DESC srv;
        view->sampled_slot = d3d_slot_alloc(dev, GR_BINDING_SAMPLED_IMAGES, 0);
        if (view->sampled_slot == GR_BINDLESS_INDEX_NONE) {
            free(view);
            return GR_ERROR_EXHAUSTED;
        }
        memset(&srv, 0, sizeof(srv));
        srv.Format = texture->dxgi;
        srv.ViewDimension = D3D12_SRV_DIMENSION_TEXTURE2D;
        srv.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        srv.Texture2D.MipLevels = 1;
        ID3D12Device_CreateShaderResourceView(dev->device, texture->resource, &srv,
                                              d3d_resource_cpu(dev, GR_BINDING_SAMPLED_IMAGES, view->sampled_slot));
    }
    if (d3d_is_depth(texture->format)) {
        D3D12_DEPTH_STENCIL_VIEW_DESC dsv;
        for (slot = 0; slot < D3D_DSV_MAX && dev->dsv_used[slot]; ++slot) {}
        if (slot == D3D_DSV_MAX) {
            free(view);
            return GR_ERROR_OUT_OF_MEMORY;
        }
        memset(&dsv, 0, sizeof(dsv));
        dsv.Format = texture->dxgi;
        dsv.ViewDimension = texture->samples > 1 ? D3D12_DSV_DIMENSION_TEXTURE2DMS : D3D12_DSV_DIMENSION_TEXTURE2D;
        dev->dsv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(dev->dsv_heap, &cpu);
        cpu.ptr += (SIZE_T)slot * dev->dsv_stride;
        ID3D12Device_CreateDepthStencilView(dev->device, texture->resource, &dsv, cpu);
        dev->dsv_used[slot] = 1;
        view->dsv_index = slot;
    } else {
        D3D12_RESOURCE_DESC rd;
        texture->resource->lpVtbl->GetDesc(texture->resource, &rd);
        if (rd.Flags & D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET) {
            for (slot = 0; slot < D3D_RTV_MAX && dev->rtv_used[slot]; ++slot) {}
            if (slot == D3D_RTV_MAX) {
                free(view);
                return GR_ERROR_OUT_OF_MEMORY;
            }
            memset(&rtv, 0, sizeof(rtv));
            rtv.Format = desc->format == GR_FORMAT_UNDEFINED ? texture->dxgi
                                                             : d3d_format(desc->format, &bpp);
            if (rtv.Format == DXGI_FORMAT_UNKNOWN) {
                free(view);
                return GR_ERROR_UNSUPPORTED;
            }
            rtv.ViewDimension = texture->samples > 1 ? D3D12_RTV_DIMENSION_TEXTURE2DMS : D3D12_RTV_DIMENSION_TEXTURE2D;
            dev->rtv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(dev->rtv_heap, &cpu);
            cpu.ptr += (SIZE_T)slot * dev->rtv_stride;
            ID3D12Device_CreateRenderTargetView(dev->device, texture->resource, &rtv, cpu);
            dev->rtv_used[slot] = 1;
            view->rtv_index = slot;
        }
    }
    status = d3d_own(dev, &view->node, GR_HANDLE_TEXTURE_VIEW, view, out_view);
    if (status != GR_OK) {
        if (view->rtv_index < D3D_RTV_MAX)
            dev->rtv_used[view->rtv_index] = 0;
        if (view->dsv_index < D3D_DSV_MAX)
            dev->dsv_used[view->dsv_index] = 0;
        if (view->sampled_slot != GR_BINDLESS_INDEX_NONE)
            dev->slot_used[GR_BINDING_SAMPLED_IMAGES][view->sampled_slot] = 0;
        free(view);
    }
    return status;
}

gr_result gr_d3d12_abi_cmd_pool_create(gr_handle device_handle, const gr_cmd_pool_desc *desc,
                                       gr_handle *out_pool)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_pool *pool;
    gr_result status;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!desc || !out_pool)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pool = GR_NULL_HANDLE;
    if (desc->queue != GR_QUEUE_GRAPHICS || desc->flags != 0)
        return GR_ERROR_UNSUPPORTED;
    pool = (d3d_pool *)calloc(1, sizeof(*pool));
    if (!pool)
        return GR_ERROR_OUT_OF_MEMORY;
    pool->device = dev;
    pool->queue = desc->queue;
    status = d3d_own(dev, &pool->node, GR_HANDLE_CMD_POOL, pool, out_pool);
    if (status != GR_OK)
        free(pool);
    return status;
}

/* One allocator per command list: an allocator may only be reset once everything recorded
 * through it has executed, and a per-list allocator makes that a per-list wait. */
gr_result gr_d3d12_abi_cmd_alloc(const gr_cmd_alloc_info *info, gr_handle *out_cmd)
{
    d3d_pool *pool;
    d3d_cmd *cmd;
    gr_result status;
    if (!info || !out_cmd)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_cmd = GR_NULL_HANDLE;
    pool = (d3d_pool *)d3d_get(info->pool, GR_HANDLE_CMD_POOL);
    if (!pool)
        return GR_ERROR_INVALID_HANDLE;
    cmd = (d3d_cmd *)calloc(1, sizeof(*cmd));
    if (!cmd)
        return GR_ERROR_OUT_OF_MEMORY;
    cmd->device = pool->device;
    if (FAILED(ID3D12Device_CreateCommandAllocator(pool->device->device, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                                   &IID_ID3D12CommandAllocator,
                                                   (void **)&cmd->allocator)) ||
        FAILED(ID3D12Device_CreateCommandList(pool->device->device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                              cmd->allocator, NULL, &IID_ID3D12GraphicsCommandList,
                                              (void **)&cmd->list)) ||
        FAILED(ID3D12GraphicsCommandList_Close(cmd->list))) {
        if (cmd->list) ID3D12GraphicsCommandList_Release(cmd->list);
        if (cmd->allocator) ID3D12CommandAllocator_Release(cmd->allocator);
        free(cmd);
        return GR_ERROR_BACKEND;
    }
    status = d3d_own(pool->device, &cmd->node, GR_HANDLE_CMD_BUFFER, cmd, out_cmd);
    if (status != GR_OK) {
        ID3D12GraphicsCommandList_Release(cmd->list);
        ID3D12CommandAllocator_Release(cmd->allocator);
        free(cmd);
    }
    return status;
}

static d3d_cmd *d3d_cmd_of(gr_handle handle)
{
    return (d3d_cmd *)d3d_get(handle, GR_HANDLE_CMD_BUFFER);
}

gr_result gr_d3d12_abi_cmd_reset(gr_handle cmd_handle)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    gr_result status;
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (cmd->recording)
        return GR_ERROR_NOT_READY;
    /* The GPU must be done with the allocator's memory before it is reused. */
    status = d3d_wait_value(cmd->device->graphics, cmd->last_submit, UINT64_MAX);
    if (status != GR_OK)
        return status;
    return FAILED(ID3D12CommandAllocator_Reset(cmd->allocator)) ? GR_ERROR_BACKEND : GR_OK;
}

gr_result gr_d3d12_abi_cmd_begin(gr_handle cmd_handle)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (cmd->recording)
        return GR_ERROR_NOT_READY;
    if (ID3D12Fence_GetCompletedValue(cmd->device->graphics->timeline) < cmd->last_submit)
        return GR_ERROR_NOT_READY; /* still executing: gr_cmd_reset first */
    if (FAILED(ID3D12GraphicsCommandList_Reset(cmd->list, cmd->allocator, NULL)))
        return GR_ERROR_BACKEND;
    cmd->recording = 1;
    cmd->pipeline = NULL;
    cmd->frame_slot = 0;
    cmd->decay_count = 0;
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_end(gr_handle cmd_handle)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    cmd->recording = 0;
    return FAILED(ID3D12GraphicsCommandList_Close(cmd->list)) ? GR_ERROR_BACKEND : GR_OK;
}

gr_result gr_d3d12_abi_cmd_barrier(gr_handle cmd_handle, const gr_barrier *barriers, uint32_t count)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    D3D12_RESOURCE_BARRIER out[16];
    uint32_t i, n = 0;
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if ((count && !barriers) || count > 16)
        return GR_ERROR_INVALID_ARGUMENT;
    for (i = 0; i < count; ++i) {
        d3d_texture *texture = d3d_texture_of(barriers[i].resource);
        D3D12_RESOURCE_STATES before = 0, after = 0;
        if (!texture) {
            d3d_buffer *buffer = (d3d_buffer *)d3d_get(barriers[i].resource, GR_HANDLE_BUFFER);
            if (!buffer || buffer->device != cmd->device)
                return GR_ERROR_INVALID_HANDLE;
            if (!d3d_state(barriers[i].dst_state, &after))
                return GR_ERROR_INVALID_ARGUMENT;
            memset(&out[n], 0, sizeof(out[n]));
            if (!buffer->transitions) {
                continue; /* upload/readback heaps keep their one state */
            } else if (buffer->state == after) {
                /* Same state: a write-after-write or write-after-read on a storage buffer is a
                 * UAV barrier, not a transition. */
                if (after != D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
                    continue;
                out[n].Type = D3D12_RESOURCE_BARRIER_TYPE_UAV;
                out[n].UAV.pResource = buffer->resource;
            } else {
                out[n].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
                out[n].Transition.pResource = buffer->resource;
                out[n].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
                out[n].Transition.StateBefore = buffer->state;
                out[n].Transition.StateAfter = after;
                buffer->state = after;
                if (cmd->decay_count < D3D_DECAY_MAX)
                    cmd->decay[cmd->decay_count++] = buffer;
                else
                    return GR_ERROR_EXHAUSTED;
            }
            ++n;
            continue;
        }
        if (barriers[i].src_state != GR_STATE_UNDEFINED) {
            if (!d3d_state(barriers[i].src_state, &before))
                return GR_ERROR_INVALID_ARGUMENT;
            if (before != texture->state)
                return GR_ERROR_NOT_READY;
        }
        if (!d3d_state(barriers[i].dst_state, &after))
            return GR_ERROR_INVALID_ARGUMENT;
        if (texture->state == after)
            continue;
        memset(&out[n], 0, sizeof(out[n]));
        out[n].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        out[n].Transition.pResource = texture->resource;
        out[n].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        out[n].Transition.StateBefore = texture->state;
        out[n].Transition.StateAfter = after;
        texture->state = after;
        ++n;
    }
    if (n)
        ID3D12GraphicsCommandList_ResourceBarrier(cmd->list, n, out);
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_begin_render(gr_handle cmd_handle, const gr_render_begin *info)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    D3D12_CPU_DESCRIPTOR_HANDLE targets[D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT], base, depth;
    D3D12_VIEWPORT viewport;
    D3D12_RECT scissor;
    uint32_t i, width = 0, height = 0;
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if (!info || (info->color_count && !info->colors) ||
        info->color_count > D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT)
        return GR_ERROR_INVALID_ARGUMENT;
    cmd->device->rtv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(cmd->device->rtv_heap, &base);
    cmd->resolve_count = 0;
    for (i = 0; i < info->color_count; ++i) {
        d3d_view *view = (d3d_view *)d3d_get(info->colors[i].view, GR_HANDLE_TEXTURE_VIEW);
        if (!view)
            return GR_ERROR_INVALID_HANDLE;
        if (view->rtv_index == D3D_RTV_MAX)
            return GR_ERROR_INVALID_ARGUMENT;
        if (info->colors[i].resolve_view != GR_NULL_HANDLE) {
            d3d_view *dst = (d3d_view *)d3d_get(info->colors[i].resolve_view, GR_HANDLE_TEXTURE_VIEW);
            if (!dst)
                return GR_ERROR_INVALID_HANDLE;
            if (view->texture->samples < 2 || dst->texture->samples != 1 ||
                dst->texture->dxgi != view->texture->dxgi || dst->texture->width != view->texture->width ||
                dst->texture->height != view->texture->height)
                return GR_ERROR_INVALID_ARGUMENT; /* resolve an MSAA image into a same-size single-sample one */
            cmd->resolve_src[cmd->resolve_count] = view;
            cmd->resolve_dst[cmd->resolve_count] = dst;
            cmd->resolve_count++;
        }
        if (view->texture->state != D3D12_RESOURCE_STATE_RENDER_TARGET)
            return GR_ERROR_NOT_READY; /* the ABI requires an explicit barrier first */
        targets[i].ptr = base.ptr + (SIZE_T)view->rtv_index * cmd->device->rtv_stride;
        if (view->texture->width > width) width = view->texture->width;
        if (view->texture->height > height) height = view->texture->height;
    }
    if (info->depth) {
        d3d_view *view = (d3d_view *)d3d_get(info->depth->view, GR_HANDLE_TEXTURE_VIEW);
        if (!view)
            return GR_ERROR_INVALID_HANDLE;
        if (view->dsv_index == D3D_DSV_MAX)
            return GR_ERROR_INVALID_ARGUMENT;
        if (view->texture->state != D3D12_RESOURCE_STATE_DEPTH_WRITE)
            return GR_ERROR_NOT_READY;
        cmd->device->dsv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(cmd->device->dsv_heap, &depth);
        depth.ptr += (SIZE_T)view->dsv_index * cmd->device->dsv_stride;
        if (view->texture->width > width) width = view->texture->width;
        if (view->texture->height > height) height = view->texture->height;
    }
    ID3D12GraphicsCommandList_OMSetRenderTargets(cmd->list, info->color_count, targets, FALSE,
                                                 info->depth ? &depth : NULL);
    if (info->depth && info->depth->load_op == GR_LOAD_CLEAR)
        ID3D12GraphicsCommandList_ClearDepthStencilView(cmd->list, depth, D3D12_CLEAR_FLAG_DEPTH,
                                                        info->depth->clear_depth, 0, 0, NULL);
    for (i = 0; i < info->color_count; ++i)
        if (info->colors[i].load_op == GR_LOAD_CLEAR)
            ID3D12GraphicsCommandList_ClearRenderTargetView(cmd->list, targets[i],
                                                            info->colors[i].clear, 0, NULL);
    viewport.TopLeftX = (float)info->render_x;
    viewport.TopLeftY = (float)info->render_y;
    viewport.Width = (float)(info->render_w ? info->render_w : width);
    viewport.Height = (float)(info->render_h ? info->render_h : height);
    viewport.MinDepth = 0.0f;
    viewport.MaxDepth = 1.0f;
    scissor.left = info->render_x;
    scissor.top = info->render_y;
    scissor.right = info->render_x + (LONG)viewport.Width;
    scissor.bottom = info->render_y + (LONG)viewport.Height;
    ID3D12GraphicsCommandList_RSSetViewports(cmd->list, 1, &viewport);
    ID3D12GraphicsCommandList_RSSetScissorRects(cmd->list, 1, &scissor);
    return GR_OK;
}

/* A colour attachment with a resolve view is resolved as the pass ends: the MSAA image goes
 * RENDER_TARGET -> RESOLVE_SOURCE -> RENDER_TARGET and the target from its tracked state to
 * RESOLVE_DEST and back, so the pass leaves the caller's states unchanged. */
gr_result gr_d3d12_abi_cmd_end_render(gr_handle cmd_handle)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    uint32_t i;
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    for (i = 0; i < cmd->resolve_count; ++i) {
        d3d_texture *src = cmd->resolve_src[i]->texture, *dst = cmd->resolve_dst[i]->texture;
        D3D12_RESOURCE_BARRIER b[2];
        UINT n = dst->state == D3D12_RESOURCE_STATE_RESOLVE_DEST ? 1u : 2u;
        memset(b, 0, sizeof(b));
        b[0].Type = b[1].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b[0].Transition.Subresource = b[1].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b[0].Transition.pResource = src->resource;
        b[0].Transition.StateBefore = src->state;
        b[0].Transition.StateAfter = D3D12_RESOURCE_STATE_RESOLVE_SOURCE;
        b[1].Transition.pResource = dst->resource;
        b[1].Transition.StateBefore = dst->state;
        b[1].Transition.StateAfter = D3D12_RESOURCE_STATE_RESOLVE_DEST;
        ID3D12GraphicsCommandList_ResourceBarrier(cmd->list, n, b);
        ID3D12GraphicsCommandList_ResolveSubresource(cmd->list, dst->resource, 0, src->resource, 0, src->dxgi);
        b[0].Transition.StateBefore = D3D12_RESOURCE_STATE_RESOLVE_SOURCE;
        b[0].Transition.StateAfter = src->state;
        b[1].Transition.StateBefore = D3D12_RESOURCE_STATE_RESOLVE_DEST;
        b[1].Transition.StateAfter = dst->state;
        ID3D12GraphicsCommandList_ResourceBarrier(cmd->list, n, b);
    }
    cmd->resolve_count = 0;
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_set_viewport(gr_handle cmd_handle, float x, float y, float width,
                                        float height, float min_depth, float max_depth)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    D3D12_VIEWPORT viewport;
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    viewport.TopLeftX = x;
    viewport.TopLeftY = y;
    viewport.Width = width;
    viewport.Height = height;
    viewport.MinDepth = min_depth;
    viewport.MaxDepth = max_depth;
    ID3D12GraphicsCommandList_RSSetViewports(cmd->list, 1, &viewport);
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_set_scissor(gr_handle cmd_handle, int32_t x, int32_t y, uint32_t width,
                                       uint32_t height)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    D3D12_RECT rect;
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    rect.left = x;
    rect.top = y;
    rect.right = x + (LONG)width;
    rect.bottom = y + (LONG)height;
    ID3D12GraphicsCommandList_RSSetScissorRects(cmd->list, 1, &rect);
    return GR_OK;
}

gr_result gr_d3d12_abi_submit(const gr_submit *submit, uint64_t *out_value)
{
    d3d_queue *queue;
    ID3D12CommandList *lists[16];
    uint32_t i;
    uint64_t value;
    gr_result status;
    if (!submit || (submit->cmd_count && !submit->cmds) || submit->cmd_count > 16)
        return GR_ERROR_INVALID_ARGUMENT;
    queue = (d3d_queue *)d3d_get(submit->queue, GR_HANDLE_QUEUE);
    if (!queue)
        return GR_ERROR_INVALID_HANDLE;
    if (submit->wait_count || submit->signal_count)
        return GR_ERROR_UNSUPPORTED; /* cross-queue semaphores are not in this slice */
    for (i = 0; i < submit->cmd_count; ++i) {
        d3d_cmd *cmd = d3d_cmd_of(submit->cmds[i]);
        if (!cmd || cmd->device != queue->device)
            return GR_ERROR_INVALID_HANDLE;
        if (cmd->recording)
            return GR_ERROR_NOT_READY;
        lists[i] = (ID3D12CommandList *)cmd->list;
    }
    if (submit->cmd_count)
        ID3D12CommandQueue_ExecuteCommandLists(queue->queue, submit->cmd_count, lists);
    status = d3d_signal(queue, &value);
    if (status != GR_OK)
        return status;
    for (i = 0; i < submit->cmd_count; ++i) {
        d3d_cmd *cmd = d3d_cmd_of(submit->cmds[i]);
        uint32_t k;
        cmd->last_submit = value;
        /* Buffers decay to COMMON when ExecuteCommandLists finishes; the tracked state follows. */
        for (k = 0; k < cmd->decay_count; ++k)
            cmd->decay[k]->state = D3D12_RESOURCE_STATE_COMMON;
    }
    if (out_value)
        *out_value = value;
    return GR_OK;
}

gr_result gr_d3d12_abi_fence_create(gr_handle device_handle, uint64_t initial_value,
                                    gr_handle *out_fence)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_fence *fence;
    gr_result status;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!out_fence)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_fence = GR_NULL_HANDLE;
    fence = (d3d_fence *)calloc(1, sizeof(*fence));
    if (!fence)
        return GR_ERROR_OUT_OF_MEMORY;
    fence->device = dev;
    fence->value = initial_value;
    status = d3d_own(dev, &fence->node, GR_HANDLE_FENCE, fence, out_fence);
    if (status != GR_OK)
        free(fence);
    return status;
}

/* A fence observes the graphics queue's timeline, as on Vulkan. */
gr_result gr_d3d12_abi_fence_wait(gr_handle fence_handle, uint64_t value, uint64_t timeout_ns,
                                  gr_result *out_status)
{
    d3d_fence *fence = (d3d_fence *)d3d_get(fence_handle, GR_HANDLE_FENCE);
    gr_result status;
    if (!fence)
        return GR_ERROR_INVALID_HANDLE;
    status = d3d_wait_value(fence->device->graphics, value, timeout_ns);
    if (status == GR_OK)
        fence->value = value;
    if (out_status)
        *out_status = status;
    return status;
}

uint64_t gr_d3d12_abi_fence_value(gr_handle fence_handle)
{
    d3d_fence *fence = (d3d_fence *)d3d_get(fence_handle, GR_HANDLE_FENCE);
    return fence ? fence->value : 0;
}

/* A synchronous copy through a readback heap on its own allocator. `src_state` must be the state
 * the last recorded barrier left the texture in; it is restored afterwards. */
gr_result gr_d3d12_abi_texture_read(gr_handle texture_handle, uint32_t mip, uint32_t layer,
                                    uint32_t x, uint32_t y, uint32_t width, uint32_t height,
                                    uint32_t src_state, gr_mut_span_u8 out)
{
    d3d_texture *texture = d3d_texture_of(texture_handle); /* a texture or one of its views */
    d3d_device *dev;
    D3D12_RESOURCE_STATES state;
    D3D12_HEAP_PROPERTIES heap;
    D3D12_RESOURCE_DESC bd;
    D3D12_TEXTURE_COPY_LOCATION dst, src;
    D3D12_BOX box;
    D3D12_RESOURCE_BARRIER barrier;
    D3D12_RANGE range;
    ID3D12Resource *readback = NULL;
    ID3D12CommandAllocator *allocator = NULL;
    ID3D12GraphicsCommandList *list = NULL;
    uint32_t pitch, row_bytes, row;
    uint64_t value;
    uint8_t *mapped;
    gr_result status = GR_ERROR_BACKEND;
    if (!texture)
        return GR_ERROR_INVALID_HANDLE;
    dev = texture->device;
    row_bytes = width * texture->bytes_per_pixel;
    if (mip != 0 || layer != 0 || width == 0 || height == 0 || x + width > texture->width ||
        y + height > texture->height || !out.data || out.len < (size_t)row_bytes * height)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!d3d_state(src_state, &state))
        return GR_ERROR_INVALID_ARGUMENT;
    if (state != texture->state)
        return GR_ERROR_NOT_READY;
    pitch = (row_bytes + D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1) &
            ~(uint32_t)(D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1);
    memset(&heap, 0, sizeof(heap));
    heap.Type = D3D12_HEAP_TYPE_READBACK;
    memset(&bd, 0, sizeof(bd));
    bd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    bd.Width = (UINT64)pitch * height;
    bd.Height = 1;
    bd.DepthOrArraySize = 1;
    bd.MipLevels = 1;
    bd.SampleDesc.Count = 1;
    bd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    if (FAILED(ID3D12Device_CreateCommittedResource(dev->device, &heap, D3D12_HEAP_FLAG_NONE, &bd,
                                                    D3D12_RESOURCE_STATE_COPY_DEST, NULL,
                                                    &IID_ID3D12Resource, (void **)&readback)) ||
        FAILED(ID3D12Device_CreateCommandAllocator(dev->device, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                                   &IID_ID3D12CommandAllocator, (void **)&allocator)) ||
        FAILED(ID3D12Device_CreateCommandList(dev->device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                              allocator, NULL, &IID_ID3D12GraphicsCommandList,
                                              (void **)&list)))
        goto done;
    memset(&barrier, 0, sizeof(barrier));
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = texture->resource;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    if (state != D3D12_RESOURCE_STATE_COPY_SOURCE) {
        barrier.Transition.StateBefore = state;
        barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;
        ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &barrier);
    }
    memset(&dst, 0, sizeof(dst));
    dst.pResource = readback;
    dst.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
    dst.PlacedFootprint.Footprint.Format = texture->dxgi;
    dst.PlacedFootprint.Footprint.Width = width;
    dst.PlacedFootprint.Footprint.Height = height;
    dst.PlacedFootprint.Footprint.Depth = 1;
    dst.PlacedFootprint.Footprint.RowPitch = pitch;
    memset(&src, 0, sizeof(src));
    src.pResource = texture->resource;
    src.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    box.left = x;
    box.top = y;
    box.front = 0;
    box.right = x + width;
    box.bottom = y + height;
    box.back = 1;
    ID3D12GraphicsCommandList_CopyTextureRegion(list, &dst, 0, 0, 0, &src, &box);
    if (state != D3D12_RESOURCE_STATE_COPY_SOURCE) {
        barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_SOURCE;
        barrier.Transition.StateAfter = state;
        ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &barrier);
    }
    if (FAILED(ID3D12GraphicsCommandList_Close(list)))
        goto done;
    ID3D12CommandQueue_ExecuteCommandLists(dev->graphics->queue, 1, (ID3D12CommandList **)&list);
    status = d3d_signal(dev->graphics, &value);
    if (status == GR_OK)
        status = d3d_wait_value(dev->graphics, value, UINT64_MAX);
    if (status != GR_OK)
        goto done;
    range.Begin = 0;
    range.End = (SIZE_T)bd.Width;
    if (FAILED(ID3D12Resource_Map(readback, 0, &range, (void **)&mapped))) {
        status = GR_ERROR_BACKEND;
        goto done;
    }
    for (row = 0; row < height; ++row)
        memcpy(out.data + (size_t)row * row_bytes, mapped + (size_t)row * pitch, row_bytes);
    range.End = 0;
    ID3D12Resource_Unmap(readback, 0, &range);
    status = GR_OK;
done:
    if (list) ID3D12GraphicsCommandList_Release(list);
    if (allocator) ID3D12CommandAllocator_Release(allocator);
    if (readback) ID3D12Resource_Release(readback);
    return status;
}

/* ---- shaders, the root signature, pipelines and draws ------------------------------------ */

/* The contract's root signature (grail_backend_d3d12.h): 32 root constants at b0 for the push
 * constants, and the frame constants as a root CBV at b0 space1. The bindless descriptor tables
 * (t0/u0/s0/t1 in space 0) arrive with descriptor heaps; a shader that declares them fails
 * pipeline creation with GR_ERROR_UNSUPPORTED rather than binding something else. */
static gr_result d3d_root_signature(d3d_device *dev)
{
    D3D12_ROOT_PARAMETER params[6];
    D3D12_DESCRIPTOR_RANGE ranges[4];
    D3D12_ROOT_SIGNATURE_DESC desc;
    ID3DBlob *blob = NULL, *error = NULL;
    HRESULT hr;
    if (dev->root)
        return GR_OK;
    memset(params, 0, sizeof(params));
    params[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    params[0].Constants.ShaderRegister = 0;
    params[0].Constants.RegisterSpace = 0;
    params[0].Constants.Num32BitValues = GR_PUSH_CONSTANT_BYTES / 4u;
    params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
    params[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_CBV;
    params[1].Descriptor.ShaderRegister = 0;
    params[1].Descriptor.RegisterSpace = 1;
    params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
    /* The bindless tables at the registers grail_bindless.hlsli declares, each unbounded and
     * alone in its register class and space: t0 space0 sampled images, u0 space2 storage
     * images, s2 space0 samplers, u0 space3 storage buffers. */
    {
        static const D3D12_DESCRIPTOR_RANGE_TYPE types[4] = {
            D3D12_DESCRIPTOR_RANGE_TYPE_SRV, D3D12_DESCRIPTOR_RANGE_TYPE_UAV,
            D3D12_DESCRIPTOR_RANGE_TYPE_SAMPLER, D3D12_DESCRIPTOR_RANGE_TYPE_UAV
        };
        uint32_t r;
        memset(ranges, 0, sizeof(ranges));
        for (r = 0; r < 4; ++r) {
            ranges[r].RangeType = types[r];
            ranges[r].NumDescriptors = UINT_MAX;
            ranges[r].BaseShaderRegister = r == 2 ? 2u : 0u;
            ranges[r].RegisterSpace = r == 1 ? 2u : r == 3 ? 3u : 0u;
            ranges[r].OffsetInDescriptorsFromTableStart = 0;
            params[2 + r].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
            params[2 + r].DescriptorTable.NumDescriptorRanges = 1;
            params[2 + r].DescriptorTable.pDescriptorRanges = &ranges[r];
            params[2 + r].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
        }
    }
    memset(&desc, 0, sizeof(desc));
    desc.NumParameters = 6;
    desc.pParameters = params;
    /* One signature serves every pipeline, so it admits an input layout; a pipeline without
     * vertex input pays nothing for the flag. */
    desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
    hr = D3D12SerializeRootSignature(&desc, D3D_ROOT_SIGNATURE_VERSION_1, &blob, &error);
    if (error) ID3D10Blob_Release(error);
    if (FAILED(hr))
        return GR_ERROR_BACKEND;
    hr = ID3D12Device_CreateRootSignature(dev->device, 0, ID3D10Blob_GetBufferPointer(blob),
                                          ID3D10Blob_GetBufferSize(blob), &IID_ID3D12RootSignature,
                                          (void **)&dev->root);
    ID3D10Blob_Release(blob);
    return FAILED(hr) ? GR_ERROR_BACKEND : GR_OK;
}

gr_result gr_d3d12_abi_shader_create(gr_handle device_handle, const gr_shader_desc *desc,
                                     gr_handle *out_shader)
{
    d3d_device *dev = d3d_device_of(device_handle);
    gr_reflection reflection;
    d3d_shader *shader;
    gr_result status;
    if (!dev || !desc || !out_shader)
        return dev ? GR_ERROR_INVALID_ARGUMENT : GR_ERROR_INVALID_HANDLE;
    *out_shader = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_shader_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (!desc->reflection_blob.data || desc->reflection_blob.len == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!desc->dxil.data || desc->dxil.len == 0)
        return GR_ERROR_UNSUPPORTED; /* no container this backend consumes */
    status = gr_reflect_open(desc->reflection_blob, &reflection);
    if (status != GR_OK)
        return status;
    if (reflection.header->stage >= GR_SHADER_STAGE_COUNT)
        return GR_ERROR_SHADER_INVALID;
    /* The blob describes one container. When that container is DXIL it must be these bytes; when
     * it is SPIR-V, the DXIL beside it was compiled from the same source and key by the same tool. */
    if (reflection.header->container == GR_CONTAINER_DXIL &&
        reflection.header->bytecode_length != desc->dxil.len)
        return GR_ERROR_SHADER_INVALID;
    shader = (d3d_shader *)calloc(1, sizeof(*shader));
    if (!shader)
        return GR_ERROR_OUT_OF_MEMORY;
    shader->dxil = (uint8_t *)malloc(desc->dxil.len);
    if (!shader->dxil) {
        free(shader);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    memcpy(shader->dxil, desc->dxil.data, desc->dxil.len);
    shader->dxil_len = desc->dxil.len;
    shader->refl = (uint8_t *)malloc(desc->reflection_blob.len);
    if (!shader->refl) {
        free(shader->dxil);
        free(shader);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    memcpy(shader->refl, desc->reflection_blob.data, desc->reflection_blob.len);
    shader->refl_len = desc->reflection_blob.len;
    shader->device = dev;
    shader->stage = (gr_shader_stage)reflection.header->stage;
    shader->permutation_key = desc->permutation_key;
    status = d3d_own(dev, &shader->node, GR_HANDLE_SHADER, shader, out_shader);
    if (status != GR_OK) {
        free(shader->refl);
        free(shader->dxil);
        free(shader);
    }
    return status;
}

static int d3d_blend(uint32_t mode, D3D12_RENDER_TARGET_BLEND_DESC *out)
{
    memset(out, 0, sizeof(*out));
    out->RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;
    out->BlendOp = D3D12_BLEND_OP_ADD;
    out->BlendOpAlpha = D3D12_BLEND_OP_ADD;
    out->SrcBlend = D3D12_BLEND_ONE;
    out->DestBlend = D3D12_BLEND_ZERO;
    out->SrcBlendAlpha = D3D12_BLEND_ONE;
    out->DestBlendAlpha = D3D12_BLEND_ZERO;
    out->LogicOp = D3D12_LOGIC_OP_NOOP;
    switch (mode) {
    case GR_BLEND_OPAQUE:
        return 1;
    case GR_BLEND_ALPHA:
        out->BlendEnable = TRUE;
        out->SrcBlend = D3D12_BLEND_SRC_ALPHA;
        out->DestBlend = D3D12_BLEND_INV_SRC_ALPHA;
        out->DestBlendAlpha = D3D12_BLEND_INV_SRC_ALPHA;
        return 1;
    case GR_BLEND_PREMULTIPLIED:
        out->BlendEnable = TRUE;
        out->DestBlend = D3D12_BLEND_INV_SRC_ALPHA;
        out->DestBlendAlpha = D3D12_BLEND_INV_SRC_ALPHA;
        return 1;
    case GR_BLEND_ADDITIVE:
        out->BlendEnable = TRUE;
        out->DestBlend = D3D12_BLEND_ONE;
        out->DestBlendAlpha = D3D12_BLEND_ONE;
        return 1;
    default:
        return 0;
    }
}

gr_result gr_d3d12_abi_pipeline_create(gr_handle device_handle, const gr_pipeline_desc *desc,
                                       gr_handle *out_pipeline)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_shader *vertex, *fragment = NULL;
    d3d_pipeline *pipeline;
    D3D12_GRAPHICS_PIPELINE_STATE_DESC pd;
    D3D12_INPUT_ELEMENT_DESC elements[D3D_VERTEX_ATTRIBUTES];
    D3D_PRIMITIVE_TOPOLOGY topology;
    uint32_t i, bpp;
    gr_result status;
    HRESULT hr;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!desc || !out_pipeline)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_pipeline = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_pipeline_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (dev->commit_done)
        return GR_ERROR_NOT_READY; /* every pipeline is declared before the commit */
    if (desc->shaders[GR_SHADER_STAGE_MESH] != GR_NULL_HANDLE ||
        desc->shaders[GR_SHADER_STAGE_TASK] != GR_NULL_HANDLE)
        return GR_ERROR_UNSUPPORTED; /* mesh pipelines are not in this slice */
    if (desc->shaders[GR_SHADER_STAGE_COMPUTE] != GR_NULL_HANDLE) {
        d3d_shader *compute = (d3d_shader *)d3d_get(desc->shaders[GR_SHADER_STAGE_COMPUTE], GR_HANDLE_SHADER);
        D3D12_COMPUTE_PIPELINE_STATE_DESC cd;
        uint32_t stage;
        for (stage = 0; stage < GR_SHADER_STAGE_COUNT; ++stage)
            if (stage != GR_SHADER_STAGE_COMPUTE && desc->shaders[stage] != GR_NULL_HANDLE)
                return GR_ERROR_INVALID_ARGUMENT; /* a compute pipeline has exactly one stage */
        if (!compute || compute->device != dev || compute->stage != GR_SHADER_STAGE_COMPUTE ||
            (desc->permutation_key != 0 && compute->permutation_key != desc->permutation_key))
            return GR_ERROR_INVALID_ARGUMENT;
        status = d3d_root_signature(dev);
        if (status != GR_OK)
            return status;
        memset(&cd, 0, sizeof(cd));
        cd.pRootSignature = dev->root;
        cd.CS.pShaderBytecode = compute->dxil;
        cd.CS.BytecodeLength = compute->dxil_len;
        pipeline = (d3d_pipeline *)calloc(1, sizeof(*pipeline));
        if (!pipeline)
            return GR_ERROR_OUT_OF_MEMORY;
        hr = ID3D12Device_CreateComputePipelineState(dev->device, &cd, &IID_ID3D12PipelineState,
                                                     (void **)&pipeline->pso);
        if (FAILED(hr)) {
            free(pipeline);
            return hr == E_INVALIDARG ? GR_ERROR_INVALID_ARGUMENT : GR_ERROR_SHADER_INVALID;
        }
        pipeline->device = dev;
        pipeline->compute = 1;
        status = d3d_own(dev, &pipeline->node, GR_HANDLE_PIPELINE, pipeline, out_pipeline);
        if (status != GR_OK) {
            ID3D12PipelineState_Release(pipeline->pso);
            free(pipeline);
            return status;
        }
        dev->pipelines_declared++;
        return GR_OK;
    }
    vertex = (d3d_shader *)d3d_get(desc->shaders[GR_SHADER_STAGE_VERTEX], GR_HANDLE_SHADER);
    if (!vertex || vertex->device != dev || vertex->stage != GR_SHADER_STAGE_VERTEX)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->shaders[GR_SHADER_STAGE_FRAGMENT] != GR_NULL_HANDLE) {
        fragment = (d3d_shader *)d3d_get(desc->shaders[GR_SHADER_STAGE_FRAGMENT], GR_HANDLE_SHADER);
        if (!fragment || fragment->device != dev || fragment->stage != GR_SHADER_STAGE_FRAGMENT)
            return GR_ERROR_INVALID_ARGUMENT;
    }
    if (desc->permutation_key != 0 &&
        (vertex->permutation_key != desc->permutation_key ||
         (fragment && fragment->permutation_key != desc->permutation_key)))
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->conservative || desc->depth_bias || desc->query_pool != GR_NULL_HANDLE)
        return GR_ERROR_UNSUPPORTED; /* conservative raster, depth bias, queries */
    if (desc->samples > 16 || (desc->samples & (desc->samples - 1)))
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->depth_compare > GR_COMPARE_ALWAYS ||
        (desc->vertex_attribute_count && !desc->vertex_attributes) ||
        (desc->vertex_binding_count && !desc->vertex_bindings) ||
        desc->vertex_attribute_count > D3D_VERTEX_ATTRIBUTES || desc->vertex_binding_count > D3D_VERTEX_SLOTS)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->color_count == 0 || desc->color_count > D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT ||
        !desc->color_formats)
        return GR_ERROR_INVALID_ARGUMENT;
    memset(&pd, 0, sizeof(pd));
    switch (desc->topology) {
    case GR_TOPOLOGY_TRIANGLE_LIST:
        pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
        topology = D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
        break;
    case GR_TOPOLOGY_TRIANGLE_STRIP:
        pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
        topology = D3D_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP;
        break;
    case GR_TOPOLOGY_LINE_LIST:
        pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
        topology = D3D_PRIMITIVE_TOPOLOGY_LINELIST;
        break;
    case GR_TOPOLOGY_POINT_LIST:
        pd.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_POINT;
        topology = D3D_PRIMITIVE_TOPOLOGY_POINTLIST;
        break;
    default:
        return GR_ERROR_UNSUPPORTED; /* patches need hull/domain stages */
    }
    for (i = 0; i < desc->color_count; ++i) {
        pd.RTVFormats[i] = d3d_format(desc->color_formats[i], &bpp);
        if (pd.RTVFormats[i] == DXGI_FORMAT_UNKNOWN)
            return GR_ERROR_UNSUPPORTED;
        if (!d3d_blend(desc->blend ? (uint32_t)desc->blend[i] : GR_BLEND_OPAQUE,
                       &pd.BlendState.RenderTarget[i]))
            return GR_ERROR_INVALID_ARGUMENT;
    }
    pd.BlendState.IndependentBlendEnable = desc->color_count > 1;
    pd.BlendState.AlphaToCoverageEnable = desc->alpha_to_coverage ? TRUE : FALSE;
    pd.NumRenderTargets = desc->color_count;
    pd.SampleMask = UINT32_MAX;
    pd.SampleDesc.Count = desc->samples > 1 ? desc->samples : 1;
    pd.RasterizerState.MultisampleEnable = desc->samples > 1 ? TRUE : FALSE;
    pd.RasterizerState.FillMode = desc->wireframe ? D3D12_FILL_MODE_WIREFRAME : D3D12_FILL_MODE_SOLID;
    pd.RasterizerState.CullMode = desc->cull == GR_CULL_FRONT  ? D3D12_CULL_MODE_FRONT
                                  : desc->cull == GR_CULL_BACK ? D3D12_CULL_MODE_BACK
                                                               : D3D12_CULL_MODE_NONE;
    pd.RasterizerState.FrontCounterClockwise = desc->front_face_ccw ? TRUE : FALSE;
    pd.RasterizerState.DepthClipEnable = desc->depth_clamp ? FALSE : TRUE;
    if (desc->depth_format != GR_FORMAT_UNDEFINED) {
        static const D3D12_COMPARISON_FUNC compare[] = {
            D3D12_COMPARISON_FUNC_NEVER, D3D12_COMPARISON_FUNC_LESS, D3D12_COMPARISON_FUNC_EQUAL,
            D3D12_COMPARISON_FUNC_LESS_EQUAL, D3D12_COMPARISON_FUNC_GREATER,
            D3D12_COMPARISON_FUNC_NOT_EQUAL, D3D12_COMPARISON_FUNC_GREATER_EQUAL,
            D3D12_COMPARISON_FUNC_ALWAYS
        };
        if (!d3d_is_depth(desc->depth_format))
            return GR_ERROR_INVALID_ARGUMENT;
        pd.DSVFormat = d3d_format(desc->depth_format, &bpp);
        pd.DepthStencilState.DepthEnable = desc->depth_test ? TRUE : FALSE;
        pd.DepthStencilState.DepthWriteMask = desc->depth_write ? D3D12_DEPTH_WRITE_MASK_ALL
                                                                : D3D12_DEPTH_WRITE_MASK_ZERO;
        /* GR_COMPARE_NEVER is the zero of a cleared descriptor, which the contract reads as its
         * default, GREATER_EQUAL (reverse-Z); a never-passing depth test is not expressible. */
        pd.DepthStencilState.DepthFunc = desc->depth_compare == GR_COMPARE_NEVER
                                             ? D3D12_COMPARISON_FUNC_GREATER_EQUAL
                                             : compare[desc->depth_compare];
    }
    /* Vertex input: each attribute's location is matched to the vertex shader's reflected input
     * of the same register, whose semantic names the D3D12 input element. */
    {
        gr_reflection vrefl;
        uint32_t a, v;
        if (gr_reflect_open((gr_span_u8){ vertex->refl, vertex->refl_len }, &vrefl) != GR_OK)
            return GR_ERROR_SHADER_INVALID;
        if (desc->vertex_attribute_count != vrefl.header->vertex_count)
            return GR_ERROR_INVALID_ARGUMENT; /* every input the shader reads must be fed, once */
        for (a = 0; a < desc->vertex_attribute_count; ++a) {
            const gr_vertex_attribute *in = &desc->vertex_attributes[a];
            const gr_reflect_vertex *match = NULL;
            uint32_t b, step = 0, found = 0;
            for (v = 0; v < vrefl.header->vertex_count; ++v)
                if (vrefl.vertices[v].location == in->location)
                    match = &vrefl.vertices[v];
            for (b = 0; b < desc->vertex_binding_count; ++b)
                if (desc->vertex_bindings[b].slot == in->binding) {
                    step = desc->vertex_bindings[b].step_rate;
                    found = 1;
                }
            if (!match || !found || in->binding >= D3D_VERTEX_SLOTS)
                return GR_ERROR_INVALID_ARGUMENT;
            elements[a].SemanticName = gr_reflect_string(&vrefl, match->semantic);
            elements[a].SemanticIndex = match->semantic_index;
            elements[a].Format = d3d_format(in->format, &bpp);
            if (elements[a].Format == DXGI_FORMAT_UNKNOWN)
                return GR_ERROR_UNSUPPORTED;
            elements[a].InputSlot = in->binding;
            elements[a].AlignedByteOffset = in->offset;
            elements[a].InputSlotClass = step ? D3D12_INPUT_CLASSIFICATION_PER_INSTANCE_DATA
                                              : D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA;
            elements[a].InstanceDataStepRate = step ? 1 : 0;
        }
        pd.InputLayout.pInputElementDescs = elements;
        pd.InputLayout.NumElements = desc->vertex_attribute_count;
    }
    /* Specialisation constants do not exist in DXIL: the offline flow has already built this
     * bytecode for the permutation, so `spec` is part of the key only. */
    status = d3d_root_signature(dev);
    if (status != GR_OK)
        return status;
    pd.pRootSignature = dev->root;
    pd.VS.pShaderBytecode = vertex->dxil;
    pd.VS.BytecodeLength = vertex->dxil_len;
    if (fragment) {
        pd.PS.pShaderBytecode = fragment->dxil;
        pd.PS.BytecodeLength = fragment->dxil_len;
    }
    pipeline = (d3d_pipeline *)calloc(1, sizeof(*pipeline));
    if (!pipeline)
        return GR_ERROR_OUT_OF_MEMORY;
    hr = ID3D12Device_CreateGraphicsPipelineState(dev->device, &pd, &IID_ID3D12PipelineState,
                                                  (void **)&pipeline->pso);
    if (FAILED(hr)) {
        free(pipeline);
        /* E_INVALIDARG is a mismatch the runtime can name (signature vs root signature, outputs
         * vs formats); anything else is the driver refusing the bytecode. */
        return hr == E_INVALIDARG ? GR_ERROR_INVALID_ARGUMENT : GR_ERROR_SHADER_INVALID;
    }
    pipeline->device = dev;
    pipeline->topology = topology;
    for (i = 0; i < desc->vertex_binding_count; ++i) {
        uint32_t slot = desc->vertex_bindings[i].slot;
        if (slot >= D3D_VERTEX_SLOTS) {
            ID3D12PipelineState_Release(pipeline->pso);
            free(pipeline);
            return GR_ERROR_INVALID_ARGUMENT;
        }
        pipeline->strides[slot] = desc->vertex_bindings[i].stride;
        pipeline->slot_mask |= 1u << slot;
    }
    status = d3d_own(dev, &pipeline->node, GR_HANDLE_PIPELINE, pipeline, out_pipeline);
    if (status != GR_OK) {
        ID3D12PipelineState_Release(pipeline->pso);
        free(pipeline);
        return status;
    }
    dev->pipelines_declared++;
    return GR_OK;
}

/* Pipelines are compiled at creation; the commit seals the set, as on Vulkan. */
gr_result gr_d3d12_abi_pipeline_commit(gr_handle device_handle, double *out_seconds)
{
    d3d_device *dev = d3d_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (dev->commit_done)
        return GR_ERROR_NOT_READY;
    dev->pipelines_committed = dev->pipelines_declared;
    dev->commit_done = 1;
    if (out_seconds)
        *out_seconds = 0.0;
    return GR_OK;
}

gr_result gr_d3d12_abi_pipeline_stats(gr_handle device_handle, uint32_t *out_declared,
                                      uint32_t *out_committed)
{
    d3d_device *dev = d3d_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (out_declared) *out_declared = dev->pipelines_declared;
    if (out_committed) *out_committed = dev->pipelines_committed;
    return GR_OK;
}

static void d3d_bind_frame(d3d_cmd *cmd)
{
    D3D12_GPU_VIRTUAL_ADDRESS address = ID3D12Resource_GetGPUVirtualAddress(cmd->device->frame) +
                                        (UINT64)cmd->frame_slot * cmd->device->frame_stride;
    if (cmd->pipeline && cmd->pipeline->compute)
        ID3D12GraphicsCommandList_SetComputeRootConstantBufferView(cmd->list, 1, address);
    else
        ID3D12GraphicsCommandList_SetGraphicsRootConstantBufferView(cmd->list, 1, address);
}

gr_result gr_d3d12_abi_cmd_bind_pipeline(gr_handle cmd_handle, gr_handle pipeline_handle)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    d3d_pipeline *pipeline = (d3d_pipeline *)d3d_get(pipeline_handle, GR_HANDLE_PIPELINE);
    if (!cmd || !pipeline || pipeline->device != cmd->device)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    {
        d3d_device *dev = cmd->device;
        ID3D12DescriptorHeap *heaps[2] = { dev->resource_heap, dev->sampler_heap };
        D3D12_GPU_DESCRIPTOR_HANDLE resource, sampler, table;
        uint32_t t;
        static const uint32_t tables[4] = { GR_BINDING_SAMPLED_IMAGES, GR_BINDING_STORAGE_IMAGES,
                                            GR_BINDING_SAMPLERS, GR_BINDING_STORAGE_BUFFERS };
        ID3D12GraphicsCommandList_SetDescriptorHeaps(cmd->list, 2, heaps);
        ID3D12GraphicsCommandList_SetPipelineState(cmd->list, pipeline->pso);
        dev->resource_heap->lpVtbl->GetGPUDescriptorHandleForHeapStart(dev->resource_heap, &resource);
        dev->sampler_heap->lpVtbl->GetGPUDescriptorHandleForHeapStart(dev->sampler_heap, &sampler);
        if (pipeline->compute)
            ID3D12GraphicsCommandList_SetComputeRootSignature(cmd->list, dev->root);
        else {
            ID3D12GraphicsCommandList_SetGraphicsRootSignature(cmd->list, dev->root);
            ID3D12GraphicsCommandList_IASetPrimitiveTopology(cmd->list, pipeline->topology);
        }
        /* The tables never change: binding is fixed at pipeline bind, as on Vulkan. */
        for (t = 0; t < 4; ++t) {
            table = tables[t] == GR_BINDING_SAMPLERS ? sampler : resource;
            if (tables[t] != GR_BINDING_SAMPLERS)
                table.ptr += (UINT64)d3d_table_base(tables[t]) * dev->resource_stride;
            if (pipeline->compute)
                ID3D12GraphicsCommandList_SetComputeRootDescriptorTable(cmd->list, 2 + t, table);
            else
                ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(cmd->list, 2 + t, table);
        }
    }
    cmd->pipeline = pipeline;
    d3d_bind_frame(cmd);
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_push_constants(gr_handle cmd_handle, uint32_t offset, gr_span_u8 data)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!data.data || (offset % 4u) != 0 || (data.len % 4u) != 0 || data.len == 0 ||
        offset + data.len > GR_PUSH_CONSTANT_BYTES)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording || !cmd->pipeline)
        return GR_ERROR_NOT_READY; /* root constants need the bound root signature */
    if (cmd->pipeline->compute)
        ID3D12GraphicsCommandList_SetComputeRoot32BitConstants(cmd->list, 0, (UINT)(data.len / 4u),
                                                              data.data, offset / 4u);
    else
        ID3D12GraphicsCommandList_SetGraphicsRoot32BitConstants(cmd->list, 0, (UINT)(data.len / 4u),
                                                               data.data, offset / 4u);
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_draw(gr_handle cmd_handle, const gr_draw *draw)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!draw)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording || !cmd->pipeline || cmd->pipeline->compute)
        return GR_ERROR_NOT_READY;
    ID3D12GraphicsCommandList_DrawInstanced(cmd->list, draw->vertex_count, draw->instance_count,
                                            draw->first_vertex, draw->first_instance);
    return GR_OK;
}

gr_result gr_d3d12_abi_frame_slot_count(gr_handle device_handle, uint32_t *out_count)
{
    d3d_device *dev = d3d_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!out_count)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_count = D3D_FRAME_SLOTS;
    return GR_OK;
}

gr_result gr_d3d12_abi_frame_constants_write(gr_handle device_handle, uint32_t slot,
                                             const gr_frame_constants *constants)
{
    d3d_device *dev = d3d_device_of(device_handle);
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!constants || slot >= D3D_FRAME_SLOTS)
        return GR_ERROR_INVALID_ARGUMENT;
    memcpy(dev->frame_mapped + (size_t)slot * dev->frame_stride, constants, sizeof(*constants));
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_push_frame_offset(gr_handle cmd_handle, uint32_t frame_slot)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (frame_slot >= D3D_FRAME_SLOTS)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    cmd->frame_slot = frame_slot;
    if (cmd->pipeline)
        d3d_bind_frame(cmd);
    return GR_OK;
}

/* ---- buffers, vertex/index binding and indexed draws ------------------------------------ */

gr_result gr_d3d12_abi_buffer_create(gr_handle device_handle, const gr_buffer_desc *desc,
                                     gr_handle *out_buffer)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_buffer *buffer;
    D3D12_HEAP_PROPERTIES heap;
    D3D12_RESOURCE_DESC bd;
    D3D12_RESOURCE_STATES initial;
    D3D12_RANGE none = { 0, 0 };
    gr_result status;
    int storage;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!desc || !out_buffer)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_buffer = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_buffer_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (desc->size == 0 || desc->memory > GR_MEMORY_READBACK)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->usage & (GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS | GR_BUFFER_USAGE_ACCELERATION_STRUCTURE |
                       GR_BUFFER_USAGE_INDIRECT))
        return GR_ERROR_UNSUPPORTED; /* device addresses, ray tracing, indirect */
    memset(&heap, 0, sizeof(heap));
    storage = (desc->usage & GR_BUFFER_USAGE_STORAGE) != 0;
    if (storage && desc->memory != GR_MEMORY_DEVICE) {
        /* UPLOAD and READBACK heaps cannot hold a UAV. A host-visible storage buffer lives in a
         * custom heap: write-back CPU pages in system memory (L0), which the GPU can write. */
        heap.Type = D3D12_HEAP_TYPE_CUSTOM;
        heap.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_WRITE_BACK;
        heap.MemoryPoolPreference = D3D12_MEMORY_POOL_L0;
        initial = D3D12_RESOURCE_STATE_COMMON;
    } else {
        heap.Type = desc->memory == GR_MEMORY_UPLOAD     ? D3D12_HEAP_TYPE_UPLOAD
                    : desc->memory == GR_MEMORY_READBACK ? D3D12_HEAP_TYPE_READBACK
                                                         : D3D12_HEAP_TYPE_DEFAULT;
        initial = desc->memory == GR_MEMORY_UPLOAD     ? D3D12_RESOURCE_STATE_GENERIC_READ
                  : desc->memory == GR_MEMORY_READBACK ? D3D12_RESOURCE_STATE_COPY_DEST
                                                       : D3D12_RESOURCE_STATE_COMMON;
    }
    memset(&bd, 0, sizeof(bd));
    bd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    bd.Width = (desc->usage & GR_BUFFER_USAGE_UNIFORM) ? (desc->size + 255u) & ~(uint64_t)255u : desc->size;
    bd.Height = 1;
    bd.DepthOrArraySize = 1;
    bd.MipLevels = 1;
    bd.SampleDesc.Count = 1;
    bd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    if (storage) {
        if (desc->size % 4u)
            return GR_ERROR_INVALID_ARGUMENT; /* a byte-address buffer is addressed in words */
        bd.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
    }
    buffer = (d3d_buffer *)calloc(1, sizeof(*buffer));
    if (!buffer)
        return GR_ERROR_OUT_OF_MEMORY;
    if (FAILED(ID3D12Device_CreateCommittedResource(dev->device, &heap, D3D12_HEAP_FLAG_NONE, &bd, initial,
                                                    NULL, &IID_ID3D12Resource, (void **)&buffer->resource))) {
        free(buffer);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    if (desc->memory != GR_MEMORY_DEVICE &&
        FAILED(ID3D12Resource_Map(buffer->resource, 0, desc->memory == GR_MEMORY_UPLOAD ? &none : NULL,
                                  (void **)&buffer->mapped))) {
        ID3D12Resource_Release(buffer->resource);
        free(buffer);
        return GR_ERROR_BACKEND;
    }
    buffer->device = dev;
    buffer->size = desc->size;
    buffer->usage = desc->usage;
    buffer->memory = desc->memory;
    buffer->state = initial;
    buffer->transitions = heap.Type == D3D12_HEAP_TYPE_DEFAULT || heap.Type == D3D12_HEAP_TYPE_CUSTOM;
    buffer->storage_slot = GR_BINDLESS_INDEX_NONE;
    if (storage) {
        D3D12_UNORDERED_ACCESS_VIEW_DESC uav;
        buffer->storage_slot = d3d_slot_alloc(dev, GR_BINDING_STORAGE_BUFFERS, 0);
        if (buffer->storage_slot == GR_BINDLESS_INDEX_NONE) {
            if (buffer->mapped) ID3D12Resource_Unmap(buffer->resource, 0, NULL);
            ID3D12Resource_Release(buffer->resource);
            free(buffer);
            return GR_ERROR_EXHAUSTED;
        }
        memset(&uav, 0, sizeof(uav));
        uav.Format = DXGI_FORMAT_R32_TYPELESS;
        uav.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
        uav.Buffer.NumElements = (UINT)(desc->size / 4u);
        uav.Buffer.Flags = D3D12_BUFFER_UAV_FLAG_RAW;
        ID3D12Device_CreateUnorderedAccessView(dev->device, buffer->resource, NULL, &uav,
                                               d3d_resource_cpu(dev, GR_BINDING_STORAGE_BUFFERS, buffer->storage_slot));
    }
    status = d3d_own(dev, &buffer->node, GR_HANDLE_BUFFER, buffer, out_buffer);
    if (status != GR_OK) {
        if (buffer->mapped) ID3D12Resource_Unmap(buffer->resource, 0, NULL);
        ID3D12Resource_Release(buffer->resource);
        free(buffer);
    }
    return status;
}

static d3d_buffer *d3d_buffer_of(gr_handle handle)
{
    return (d3d_buffer *)d3d_get(handle, GR_HANDLE_BUFFER);
}

/* As on Vulkan: host access is to UPLOAD and READBACK memory; device memory needs a staging copy
 * the caller records, and is refused here rather than silently stalling the queue. */
gr_result gr_d3d12_abi_buffer_write(gr_handle buffer_handle, uint64_t offset, gr_span_u8 data)
{
    d3d_buffer *buffer = d3d_buffer_of(buffer_handle);
    if (!buffer)
        return GR_ERROR_INVALID_HANDLE;
    if (!data.data || offset > buffer->size || (uint64_t)data.len > buffer->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->mapped)
        return GR_ERROR_UNSUPPORTED;
    memcpy(buffer->mapped + offset, data.data, data.len);
    return GR_OK;
}

gr_result gr_d3d12_abi_buffer_read(gr_handle buffer_handle, uint64_t offset, gr_mut_span_u8 out)
{
    d3d_buffer *buffer = d3d_buffer_of(buffer_handle);
    if (!buffer)
        return GR_ERROR_INVALID_HANDLE;
    if (!out.data || offset > buffer->size || (uint64_t)out.len > buffer->size - offset)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!buffer->mapped)
        return GR_ERROR_UNSUPPORTED;
    memcpy(out.data, buffer->mapped + offset, out.len);
    return GR_OK;
}

gr_result gr_d3d12_abi_buffer_map(gr_handle buffer_handle, void **out_ptr)
{
    d3d_buffer *buffer = d3d_buffer_of(buffer_handle);
    if (!buffer)
        return GR_ERROR_INVALID_HANDLE;
    if (!out_ptr)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_ptr = buffer->mapped;
    return buffer->mapped ? GR_OK : GR_ERROR_UNSUPPORTED;
}

/* Buffers stay mapped for their lifetime (both heap types allow it); unmap is a no-op. */
void gr_d3d12_abi_buffer_unmap(gr_handle buffer_handle)
{
    (void)buffer_handle;
}

uint64_t gr_d3d12_abi_buffer_device_address(gr_handle buffer_handle)
{
    (void)buffer_handle;
    return 0; /* GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS is refused at creation */
}

uint32_t gr_d3d12_abi_buffer_bindless_index(gr_handle buffer_handle)
{
    d3d_buffer *buffer = d3d_buffer_of(buffer_handle);
    return buffer ? buffer->storage_slot : GR_BINDLESS_INDEX_NONE;
}

gr_result gr_d3d12_abi_cmd_bind_vertex_buffer(gr_handle cmd_handle, uint32_t slot, gr_handle buffer_handle,
                                              uint64_t offset)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    d3d_buffer *buffer = d3d_buffer_of(buffer_handle);
    D3D12_VERTEX_BUFFER_VIEW view;
    if (!cmd || !buffer || buffer->device != cmd->device)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording || !cmd->pipeline)
        return GR_ERROR_NOT_READY; /* the stride comes from the bound pipeline */
    if (slot >= D3D_VERTEX_SLOTS || !(cmd->pipeline->slot_mask & (1u << slot)) ||
        !(buffer->usage & GR_BUFFER_USAGE_VERTEX) || offset >= buffer->size)
        return GR_ERROR_INVALID_ARGUMENT;
    view.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(buffer->resource) + offset;
    view.SizeInBytes = (UINT)(buffer->size - offset);
    view.StrideInBytes = cmd->pipeline->strides[slot];
    ID3D12GraphicsCommandList_IASetVertexBuffers(cmd->list, slot, 1, &view);
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_bind_index_buffer(gr_handle cmd_handle, gr_handle buffer_handle, uint64_t offset,
                                             uint32_t index_type)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    d3d_buffer *buffer = d3d_buffer_of(buffer_handle);
    D3D12_INDEX_BUFFER_VIEW view;
    if (!cmd || !buffer || buffer->device != cmd->device)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording)
        return GR_ERROR_NOT_READY;
    if (index_type > 1 || !(buffer->usage & GR_BUFFER_USAGE_INDEX) || offset >= buffer->size ||
        (offset % (index_type ? 4u : 2u)) != 0)
        return GR_ERROR_INVALID_ARGUMENT;
    view.BufferLocation = ID3D12Resource_GetGPUVirtualAddress(buffer->resource) + offset;
    view.SizeInBytes = (UINT)(buffer->size - offset);
    view.Format = index_type ? DXGI_FORMAT_R32_UINT : DXGI_FORMAT_R16_UINT;
    ID3D12GraphicsCommandList_IASetIndexBuffer(cmd->list, &view);
    return GR_OK;
}

gr_result gr_d3d12_abi_cmd_draw_indexed(gr_handle cmd_handle, const gr_draw_indexed *draw)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!draw)
        return GR_ERROR_INVALID_ARGUMENT;
    if (!cmd->recording || !cmd->pipeline || cmd->pipeline->compute)
        return GR_ERROR_NOT_READY;
    ID3D12GraphicsCommandList_DrawIndexedInstanced(cmd->list, draw->index_count, draw->instance_count,
                                                   draw->first_index, draw->vertex_offset, draw->first_instance);
    return GR_OK;
}

/* ---- the bindless table, samplers, texture upload, dispatch, deferred release ----------- */

gr_handle gr_d3d12_abi_device_bindless(gr_handle device_handle)
{
    d3d_device *dev = d3d_device_of(device_handle);
    return dev ? dev->bindless_handle : GR_NULL_HANDLE;
}

gr_result gr_d3d12_abi_bindless_get_info(gr_handle bindless_handle, gr_bindless_info *out)
{
    d3d_device *dev = (d3d_device *)d3d_get(bindless_handle, GR_HANDLE_BINDLESS);
    uint32_t t;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!out || out->head.size < sizeof(*out))
        return GR_ERROR_INVALID_ARGUMENT;
    memset((char *)out + sizeof(out->head), 0, sizeof(*out) - sizeof(out->head));
    for (t = 0; t < GR_BINDING_COUNT; ++t) {
        out->capacity[t] = d3d_table_capacity[t];
        out->high_water[t] = dev->high_water[t];
    }
    out->releases_pending = dev->retired_pending;
    return GR_OK;
}

gr_result gr_d3d12_abi_sampler_create(gr_handle device_handle, const gr_sampler_desc *desc,
                                      gr_handle *out_sampler, uint32_t *out_slot)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_sampler *sampler;
    gr_result status;
    uint32_t slot;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!desc || !out_sampler)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_sampler = GR_NULL_HANDLE;
    if (out_slot)
        *out_slot = GR_BINDLESS_INDEX_NONE;
    slot = d3d_slot_alloc(dev, GR_BINDING_SAMPLERS, GR_SAMPLER_SLOT_COUNT);
    if (slot == GR_BINDLESS_INDEX_NONE)
        return GR_ERROR_EXHAUSTED;
    sampler = (d3d_sampler *)calloc(1, sizeof(*sampler));
    if (!sampler) {
        dev->slot_used[GR_BINDING_SAMPLERS][slot] = 0;
        return GR_ERROR_OUT_OF_MEMORY;
    }
    sampler->slot = slot;
    d3d_write_sampler(dev, slot, desc);
    status = d3d_own(dev, &sampler->node, GR_HANDLE_SAMPLER, sampler, out_sampler);
    if (status != GR_OK) {
        dev->slot_used[GR_BINDING_SAMPLERS][slot] = 0;
        free(sampler);
        return status;
    }
    if (out_slot)
        *out_slot = slot;
    return GR_OK;
}

uint32_t gr_d3d12_abi_texture_view_bindless_sampled(gr_handle view_handle)
{
    d3d_view *view = (d3d_view *)d3d_get(view_handle, GR_HANDLE_TEXTURE_VIEW);
    return view ? view->sampled_slot : GR_BINDLESS_INDEX_NONE;
}

/* A synchronous upload through an upload heap on its own allocator, mirroring the readback: the
 * texture goes from its tracked state to COPY_DEST and back. `rows` is tightly packed. */
gr_result gr_d3d12_abi_texture_write(gr_handle texture_handle, uint32_t mip, uint32_t layer, uint32_t x,
                                     uint32_t y, uint32_t width, uint32_t height, gr_span_u8 rows)
{
    d3d_texture *texture = (d3d_texture *)d3d_get(texture_handle, GR_HANDLE_TEXTURE);
    d3d_device *dev;
    D3D12_HEAP_PROPERTIES heap;
    D3D12_RESOURCE_DESC bd;
    D3D12_TEXTURE_COPY_LOCATION dst, src;
    D3D12_RESOURCE_BARRIER barrier;
    D3D12_RANGE none = { 0, 0 };
    ID3D12Resource *upload = NULL;
    ID3D12CommandAllocator *allocator = NULL;
    ID3D12GraphicsCommandList *list = NULL;
    uint32_t pitch, row_bytes, row;
    uint64_t value;
    uint8_t *mapped;
    gr_result status = GR_ERROR_BACKEND;
    if (!texture)
        return GR_ERROR_INVALID_HANDLE;
    dev = texture->device;
    row_bytes = width * texture->bytes_per_pixel;
    if (mip != 0 || layer != 0 || width == 0 || height == 0 || x + width > texture->width ||
        y + height > texture->height || !rows.data || rows.len < (size_t)row_bytes * height ||
        d3d_is_depth(texture->format))
        return GR_ERROR_INVALID_ARGUMENT;
    pitch = (row_bytes + D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1) &
            ~(uint32_t)(D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1);
    memset(&heap, 0, sizeof(heap));
    heap.Type = D3D12_HEAP_TYPE_UPLOAD;
    memset(&bd, 0, sizeof(bd));
    bd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
    bd.Width = (UINT64)pitch * height;
    bd.Height = 1;
    bd.DepthOrArraySize = 1;
    bd.MipLevels = 1;
    bd.SampleDesc.Count = 1;
    bd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    if (FAILED(ID3D12Device_CreateCommittedResource(dev->device, &heap, D3D12_HEAP_FLAG_NONE, &bd,
                                                    D3D12_RESOURCE_STATE_GENERIC_READ, NULL, &IID_ID3D12Resource,
                                                    (void **)&upload)) ||
        FAILED(ID3D12Resource_Map(upload, 0, &none, (void **)&mapped)))
        goto done;
    for (row = 0; row < height; ++row)
        memcpy(mapped + (size_t)row * pitch, rows.data + (size_t)row * row_bytes, row_bytes);
    ID3D12Resource_Unmap(upload, 0, NULL);
    if (FAILED(ID3D12Device_CreateCommandAllocator(dev->device, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                                   &IID_ID3D12CommandAllocator, (void **)&allocator)) ||
        FAILED(ID3D12Device_CreateCommandList(dev->device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator, NULL,
                                              &IID_ID3D12GraphicsCommandList, (void **)&list)))
        goto done;
    memset(&barrier, 0, sizeof(barrier));
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = texture->resource;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    if (texture->state != D3D12_RESOURCE_STATE_COPY_DEST) {
        barrier.Transition.StateBefore = texture->state;
        barrier.Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_DEST;
        ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &barrier);
    }
    memset(&src, 0, sizeof(src));
    src.pResource = upload;
    src.Type = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
    src.PlacedFootprint.Footprint.Format = texture->dxgi;
    src.PlacedFootprint.Footprint.Width = width;
    src.PlacedFootprint.Footprint.Height = height;
    src.PlacedFootprint.Footprint.Depth = 1;
    src.PlacedFootprint.Footprint.RowPitch = pitch;
    memset(&dst, 0, sizeof(dst));
    dst.pResource = texture->resource;
    dst.Type = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
    ID3D12GraphicsCommandList_CopyTextureRegion(list, &dst, x, y, 0, &src, NULL);
    if (texture->state != D3D12_RESOURCE_STATE_COPY_DEST) {
        barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_COPY_DEST;
        barrier.Transition.StateAfter = texture->state;
        ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &barrier);
    }
    if (FAILED(ID3D12GraphicsCommandList_Close(list)))
        goto done;
    ID3D12CommandQueue_ExecuteCommandLists(dev->graphics->queue, 1, (ID3D12CommandList **)&list);
    status = d3d_signal(dev->graphics, &value);
    if (status == GR_OK)
        status = d3d_wait_value(dev->graphics, value, UINT64_MAX);
done:
    if (list) ID3D12GraphicsCommandList_Release(list);
    if (allocator) ID3D12CommandAllocator_Release(allocator);
    if (upload) ID3D12Resource_Release(upload);
    return status;
}

gr_result gr_d3d12_abi_cmd_dispatch(gr_handle cmd_handle, uint32_t x, uint32_t y, uint32_t z)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    if (!cmd->recording || !cmd->pipeline || !cmd->pipeline->compute)
        return GR_ERROR_NOT_READY;
    if (x == 0 || y == 0 || z == 0 || x > D3D12_CS_DISPATCH_MAX_THREAD_GROUPS_PER_DIMENSION ||
        y > D3D12_CS_DISPATCH_MAX_THREAD_GROUPS_PER_DIMENSION ||
        z > D3D12_CS_DISPATCH_MAX_THREAD_GROUPS_PER_DIMENSION)
        return GR_ERROR_INVALID_ARGUMENT;
    ID3D12GraphicsCommandList_Dispatch(cmd->list, x, y, z);
    return GR_OK;
}

/* Releases an object once the graphics timeline reaches `after_value`; gr_device_collect frees
 * whatever has become safe. The handle stays valid until then. */
gr_result gr_d3d12_abi_device_retire(gr_handle device_handle, gr_handle object, uint64_t after_value)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_node *node;
    d3d_retired *entry;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    for (node = dev->objects; node && node->handle != object; node = node->next) {}
    if (!node || node->type == GR_HANDLE_QUEUE)
        return GR_ERROR_INVALID_HANDLE; /* not one of this device's objects, or not retirable */
    entry = (d3d_retired *)calloc(1, sizeof(*entry));
    if (!entry)
        return GR_ERROR_OUT_OF_MEMORY;
    entry->object = object;
    entry->after_value = after_value;
    entry->next = dev->retired;
    dev->retired = entry;
    dev->retired_pending++;
    return GR_OK;
}

gr_result gr_d3d12_abi_device_collect(gr_handle device_handle)
{
    d3d_device *dev = d3d_device_of(device_handle);
    d3d_retired **link;
    uint64_t done;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    done = ID3D12Fence_GetCompletedValue(dev->graphics->timeline);
    link = &dev->retired;
    while (*link) {
        d3d_retired *entry = *link;
        if (entry->after_value <= done) {
            d3d_node **owner = &dev->objects;
            while (*owner && (*owner)->handle != entry->object)
                owner = &(*owner)->next;
            if (*owner) {
                d3d_node *node = *owner;
                *owner = node->next;
                if (node->type == GR_HANDLE_SAMPLER)
                    dev->slot_used[GR_BINDING_SAMPLERS][((d3d_sampler *)node)->slot] = 0;
                d3d_release(node);
            }
            *link = entry->next;
            free(entry);
            dev->retired_pending--;
        } else {
            link = &entry->next;
        }
    }
    return GR_OK;
}

/* ---- swapchains and presentation -------------------------------------------------------- */

/* A swapchain's images are textures and views in the object table, owned by the swapchain (not
 * the device list) so that a recreate replaces them without the device freeing them twice. */
static void d3d_swap_release_images(d3d_swapchain *sc)
{
    uint32_t i;
    for (i = 0; i < sc->image_count; ++i) {
        if (sc->views[i]) {
            if (sc->views[i]->rtv_index < D3D_RTV_MAX)
                sc->device->rtv_used[sc->views[i]->rtv_index] = 0;
            gr_object_remove(gr_objects(), sc->view_handles[i], GR_HANDLE_TEXTURE_VIEW);
            free(sc->views[i]);
            sc->views[i] = NULL;
        }
        if (sc->images[i]) {
            ID3D12Resource_Release(sc->images[i]->resource);
            gr_object_remove(gr_objects(), sc->image_handles[i], GR_HANDLE_TEXTURE);
            free(sc->images[i]);
            sc->images[i] = NULL;
        }
    }
}

static gr_result d3d_swap_wrap_images(d3d_swapchain *sc)
{
    d3d_device *dev = sc->device;
    D3D12_CPU_DESCRIPTOR_HANDLE cpu;
    uint32_t i, slot, bpp;
    for (i = 0; i < sc->image_count; ++i) {
        d3d_texture *tex = (d3d_texture *)calloc(1, sizeof(*tex));
        d3d_view *view = (d3d_view *)calloc(1, sizeof(*view));
        if (!tex || !view) {
            free(tex);
            free(view);
            return GR_ERROR_OUT_OF_MEMORY;
        }
        if (FAILED(IDXGISwapChain3_GetBuffer(sc->swapchain, i, &IID_ID3D12Resource, (void **)&tex->resource))) {
            free(tex);
            free(view);
            return GR_ERROR_BACKEND;
        }
        tex->device = dev;
        tex->format = sc->format;
        tex->dxgi = d3d_format(sc->format, &bpp);
        tex->bytes_per_pixel = bpp;
        tex->width = sc->width;
        tex->height = sc->height;
        tex->usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC | GR_TEXTURE_USAGE_PRESENT;
        tex->state = D3D12_RESOURCE_STATE_PRESENT; /* == COMMON: what a flip-model buffer starts in */
        sc->images[i] = tex;
        sc->image_handles[i] = gr_object_insert(gr_objects(), GR_HANDLE_TEXTURE, tex);
        for (slot = 0; slot < D3D_RTV_MAX && dev->rtv_used[slot]; ++slot) {}
        if (slot == D3D_RTV_MAX || sc->image_handles[i] == GR_NULL_HANDLE) {
            free(view);
            return GR_ERROR_OUT_OF_MEMORY;
        }
        dev->rtv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(dev->rtv_heap, &cpu);
        cpu.ptr += (SIZE_T)slot * dev->rtv_stride;
        ID3D12Device_CreateRenderTargetView(dev->device, tex->resource, NULL, cpu);
        dev->rtv_used[slot] = 1;
        view->texture = tex;
        view->rtv_index = slot;
        view->dsv_index = D3D_DSV_MAX;
        view->sampled_slot = GR_BINDLESS_INDEX_NONE;
        sc->views[i] = view;
        sc->view_handles[i] = gr_object_insert(gr_objects(), GR_HANDLE_TEXTURE_VIEW, view);
        if (sc->view_handles[i] == GR_NULL_HANDLE)
            return GR_ERROR_OUT_OF_MEMORY;
        sc->image_done[i] = 0;
    }
    return GR_OK;
}

gr_result gr_d3d12_abi_swapchain_create(gr_handle device_handle, const gr_swapchain_desc *desc,
                                        gr_handle *out_swapchain)
{
    d3d_device *dev = d3d_device_of(device_handle);
    gr_window_native native;
    gr_window_size size;
    DXGI_SWAP_CHAIN_DESC1 sd;
    IDXGIFactory4 *factory = NULL;
    IDXGISwapChain1 *one = NULL;
    d3d_swapchain *sc;
    uint32_t bpp;
    gr_result status;
    HRESULT hr;
    if (!dev)
        return GR_ERROR_INVALID_HANDLE;
    if (!desc || !out_swapchain)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_swapchain = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_swapchain_desc))
        return GR_ERROR_VERSION_MISMATCH;
    status = gr_window_get_native(desc->window, &native);
    if (status != GR_OK)
        return status;
    if (native.backend != GR_BACKEND_D3D12 || !native.handle_a)
        return GR_ERROR_UNSUPPORTED; /* the window cannot give this backend an HWND */
    memset(&size, 0, sizeof(size));
    if (gr_window_get_size(desc->window, &size) != GR_OK)
        return GR_ERROR_BACKEND;
    sc = (d3d_swapchain *)calloc(1, sizeof(*sc));
    if (!sc)
        return GR_ERROR_OUT_OF_MEMORY;
    sc->device = dev;
    sc->format = desc->format == GR_FORMAT_UNDEFINED ? GR_FORMAT_B8G8R8A8_UNORM : desc->format;
    sc->width = desc->width ? desc->width : size.pixel_width;
    sc->height = desc->height ? desc->height : size.pixel_height;
    sc->image_count = desc->image_count ? desc->image_count : 3;
    sc->acquired = D3D_SWAP_MAX;
    if (sc->image_count < 2 || sc->image_count > D3D_SWAP_MAX || sc->width == 0 || sc->height == 0 ||
        (sc->format != GR_FORMAT_B8G8R8A8_UNORM && sc->format != GR_FORMAT_R8G8B8A8_UNORM) ||
        desc->present_mode > GR_PRESENT_FIFO_RELAXED) {
        free(sc);
        return GR_ERROR_INVALID_ARGUMENT; /* flip-model swapchains take 2..16 UNORM buffers */
    }
    /* FIFO and FIFO_RELAXED: sync interval 1; MAILBOX and IMMEDIATE: interval 0 (IMMEDIATE may
     * tear only where the factory allows tearing; without it, interval 0 does not tear). */
    sc->sync_interval = (desc->present_mode == GR_PRESENT_FIFO || desc->present_mode == GR_PRESENT_FIFO_RELAXED) ? 1u : 0u;
    memset(&sd, 0, sizeof(sd));
    sd.Width = sc->width;
    sd.Height = sc->height;
    sd.Format = d3d_format(sc->format, &bpp);
    sd.SampleDesc.Count = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.BufferCount = sc->image_count;
    sd.Scaling = DXGI_SCALING_STRETCH;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    sd.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
    if (FAILED(CreateDXGIFactory1(&IID_IDXGIFactory4, (void **)&factory))) {
        free(sc);
        return GR_ERROR_BACKEND;
    }
    hr = IDXGIFactory4_CreateSwapChainForHwnd(factory, (IUnknown *)dev->graphics->queue, (HWND)native.handle_a,
                                              &sd, NULL, NULL, &one);
    if (SUCCEEDED(hr))
        IDXGIFactory4_MakeWindowAssociation(factory, (HWND)native.handle_a, DXGI_MWA_NO_ALT_ENTER);
    IDXGIFactory4_Release(factory);
    if (FAILED(hr)) {
        free(sc);
        return GR_ERROR_BACKEND;
    }
    hr = IDXGISwapChain1_QueryInterface(one, &IID_IDXGISwapChain3, (void **)&sc->swapchain);
    IDXGISwapChain1_Release(one);
    if (FAILED(hr)) {
        free(sc);
        return GR_ERROR_UNSUPPORTED;
    }
    status = d3d_swap_wrap_images(sc);
    if (status == GR_OK)
        status = d3d_own(dev, &sc->node, GR_HANDLE_SWAPCHAIN, sc, out_swapchain);
    if (status != GR_OK) {
        d3d_swap_release_images(sc);
        IDXGISwapChain3_Release(sc->swapchain);
        free(sc);
    }
    return status;
}

static d3d_swapchain *d3d_swap_of(gr_handle handle)
{
    return (d3d_swapchain *)d3d_get(handle, GR_HANDLE_SWAPCHAIN);
}

gr_result gr_d3d12_abi_swapchain_info(gr_handle swapchain, gr_format *out_format, uint32_t *out_width,
                                      uint32_t *out_height, uint32_t *out_image_count)
{
    d3d_swapchain *sc = d3d_swap_of(swapchain);
    if (!sc)
        return GR_ERROR_INVALID_HANDLE;
    if (out_format) *out_format = sc->format;
    if (out_width) *out_width = sc->width;
    if (out_height) *out_height = sc->height;
    if (out_image_count) *out_image_count = sc->image_count;
    return GR_OK;
}

/* DXGI hands out back buffers in order; acquiring waits only for the submission that last
 * presented this image (frame pacing), never for the queue to drain. */
gr_result gr_d3d12_abi_swapchain_acquire(gr_handle swapchain, uint64_t timeout_ns, uint32_t *out_image_index,
                                         gr_handle *out_view, int32_t *out_needs_recreate)
{
    d3d_swapchain *sc = d3d_swap_of(swapchain);
    uint32_t index;
    gr_result status;
    if (!sc)
        return GR_ERROR_INVALID_HANDLE;
    if (out_needs_recreate) *out_needs_recreate = 0;
    if (out_view) *out_view = GR_NULL_HANDLE;
    if (sc->acquired != D3D_SWAP_MAX)
        return GR_ERROR_NOT_READY; /* the previous image has not been presented */
    index = IDXGISwapChain3_GetCurrentBackBufferIndex(sc->swapchain);
    if (index >= sc->image_count)
        return GR_ERROR_BACKEND;
    status = d3d_wait_value(sc->device->graphics, sc->image_done[index], timeout_ns);
    if (status != GR_OK)
        return status;
    sc->acquired = index;
    if (out_image_index) *out_image_index = index;
    if (out_view) *out_view = sc->view_handles[index];
    return GR_OK;
}

gr_result gr_d3d12_abi_present(gr_handle queue_handle, gr_handle swapchain, uint32_t image_index,
                               uint64_t wait_value, uint64_t *out_value)
{
    d3d_queue *queue = (d3d_queue *)d3d_get(queue_handle, GR_HANDLE_QUEUE);
    d3d_swapchain *sc = d3d_swap_of(swapchain);
    uint64_t value;
    gr_result status;
    HRESULT hr;
    if (!queue || !sc || sc->device != queue->device)
        return GR_ERROR_INVALID_HANDLE;
    if (image_index != sc->acquired || wait_value > queue->submitted)
        return GR_ERROR_INVALID_ARGUMENT; /* not the acquired image, or a value never submitted */
    if (sc->images[image_index]->state != D3D12_RESOURCE_STATE_PRESENT)
        return GR_ERROR_NOT_READY; /* the ABI requires the barrier to PRESENT first */
    /* Present is ordered after every earlier submission on the same queue, so `wait_value` is
     * satisfied by queue order; it is validated, not waited on the CPU. */
    hr = IDXGISwapChain3_Present(sc->swapchain, sc->sync_interval, 0);
    if (hr == DXGI_ERROR_DEVICE_REMOVED || hr == DXGI_ERROR_DEVICE_RESET)
        return GR_ERROR_DEVICE_LOST;
    if (FAILED(hr))
        return GR_ERROR_BACKEND;
    status = d3d_signal(queue, &value);
    if (status != GR_OK)
        return status;
    sc->image_done[image_index] = value;
    sc->acquired = D3D_SWAP_MAX;
    if (out_value)
        *out_value = value;
    return GR_OK;
}

gr_result gr_d3d12_abi_swapchain_recreate(gr_handle swapchain, uint32_t width, uint32_t height,
                                          uint64_t after_value)
{
    d3d_swapchain *sc = d3d_swap_of(swapchain);
    uint32_t bpp;
    gr_result status;
    if (!sc)
        return GR_ERROR_INVALID_HANDLE;
    if (width == 0 || height == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (sc->acquired != D3D_SWAP_MAX)
        return GR_ERROR_NOT_READY;
    /* ResizeBuffers needs every reference to the old buffers gone and the GPU done with them. */
    status = d3d_wait_value(sc->device->graphics, after_value > sc->device->graphics->submitted
                                                      ? sc->device->graphics->submitted : after_value,
                            UINT64_MAX);
    if (status == GR_OK)
        status = d3d_wait_value(sc->device->graphics, sc->device->graphics->submitted, UINT64_MAX);
    if (status != GR_OK)
        return status;
    d3d_swap_release_images(sc);
    if (FAILED(IDXGISwapChain3_ResizeBuffers(sc->swapchain, sc->image_count, width, height,
                                             d3d_format(sc->format, &bpp), 0)))
        return GR_ERROR_BACKEND;
    sc->width = width;
    sc->height = height;
    return d3d_swap_wrap_images(sc);
}

/* ---- not in this slice ------------------------------------------------------------------ */

gr_result gr_d3d12_abi_queue_timeline(gr_handle queue, gr_handle *out_semaphore)
{
    (void)queue;
    (void)out_semaphore;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_draw_indexed_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset, uint32_t draw_count, uint32_t stride)
{
    (void)cmd;
    (void)buffer;
    (void)offset;
    (void)draw_count;
    (void)stride;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_dispatch_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset)
{
    (void)cmd;
    (void)buffer;
    (void)offset;
    return GR_ERROR_UNSUPPORTED;
}

#else /* !_WIN32 */

gr_result gr_d3d12_abi_device_create(const gr_device_desc *desc, gr_handle *out_device)
{
    (void)desc;
    (void)out_device;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_device_destroy(gr_handle device)
{
    (void)device;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_device_get_caps(gr_handle device, gr_device_caps *out)
{
    (void)device;
    (void)out;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_device_wait_idle(gr_handle device)
{
    (void)device;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_device_queue(gr_handle device, gr_queue_kind kind, gr_handle *out_queue)
{
    (void)device;
    (void)kind;
    (void)out_queue;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_queue_timeline(gr_handle queue, gr_handle *out_semaphore)
{
    (void)queue;
    (void)out_semaphore;
    return GR_ERROR_UNSUPPORTED;
}

uint64_t gr_d3d12_abi_queue_submitted(gr_handle queue)
{
    (void)queue;
    return 0;
}

uint64_t gr_d3d12_abi_queue_completed(gr_handle queue)
{
    (void)queue;
    return 0;
}

gr_result gr_d3d12_abi_queue_wait_idle(gr_handle queue)
{
    (void)queue;
    return GR_ERROR_UNSUPPORTED;
}

gr_handle gr_d3d12_abi_device_bindless(gr_handle device)
{
    (void)device;
    return GR_NULL_HANDLE;
}

gr_result gr_d3d12_abi_bindless_get_info(gr_handle bindless, gr_bindless_info *out)
{
    (void)bindless;
    (void)out;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_device_retire(gr_handle device, gr_handle object, uint64_t after_value)
{
    (void)device;
    (void)object;
    (void)after_value;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_device_collect(gr_handle device)
{
    (void)device;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_shader_create(gr_handle device, const gr_shader_desc *desc, gr_handle *out_shader)
{
    (void)device;
    (void)desc;
    (void)out_shader;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_pipeline_create(gr_handle device, const gr_pipeline_desc *desc, gr_handle *out_pipeline)
{
    (void)device;
    (void)desc;
    (void)out_pipeline;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_pipeline_commit(gr_handle device, double *out_seconds)
{
    (void)device;
    (void)out_seconds;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_pipeline_stats(gr_handle device, uint32_t *out_declared, uint32_t *out_committed)
{
    (void)device;
    (void)out_declared;
    (void)out_committed;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_texture_create(gr_handle device, const gr_texture_desc *desc, gr_handle *out_texture)
{
    (void)device;
    (void)desc;
    (void)out_texture;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_texture_view_create(gr_handle device, const gr_texture_view_desc *desc, gr_handle *out_view)
{
    (void)device;
    (void)desc;
    (void)out_view;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_texture_read(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t width, uint32_t height, uint32_t src_state, gr_mut_span_u8 out)
{
    (void)texture;
    (void)mip;
    (void)layer;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    (void)src_state;
    (void)out;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_pool_create(gr_handle device, const gr_cmd_pool_desc *desc, gr_handle *out_pool)
{
    (void)device;
    (void)desc;
    (void)out_pool;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_alloc(const gr_cmd_alloc_info *info, gr_handle *out_cmd)
{
    (void)info;
    (void)out_cmd;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_begin(gr_handle cmd)
{
    (void)cmd;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_end(gr_handle cmd)
{
    (void)cmd;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_reset(gr_handle cmd)
{
    (void)cmd;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_barrier(gr_handle cmd, const gr_barrier *barriers, uint32_t count)
{
    (void)cmd;
    (void)barriers;
    (void)count;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_begin_render(gr_handle cmd, const gr_render_begin *info)
{
    (void)cmd;
    (void)info;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_end_render(gr_handle cmd)
{
    (void)cmd;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_set_viewport(gr_handle cmd, float x, float y, float width, float height, float min_depth, float max_depth)
{
    (void)cmd;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    (void)min_depth;
    (void)max_depth;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_set_scissor(gr_handle cmd, int32_t x, int32_t y, uint32_t width, uint32_t height)
{
    (void)cmd;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_bind_pipeline(gr_handle cmd, gr_handle pipeline)
{
    (void)cmd;
    (void)pipeline;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_push_constants(gr_handle cmd, uint32_t offset, gr_span_u8 data)
{
    (void)cmd;
    (void)offset;
    (void)data;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_draw(gr_handle cmd, const gr_draw *draw)
{
    (void)cmd;
    (void)draw;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_draw_indexed(gr_handle cmd, const gr_draw_indexed *draw)
{
    (void)cmd;
    (void)draw;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_draw_indexed_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset, uint32_t draw_count, uint32_t stride)
{
    (void)cmd;
    (void)buffer;
    (void)offset;
    (void)draw_count;
    (void)stride;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_bind_vertex_buffer(gr_handle cmd, uint32_t slot, gr_handle buffer, uint64_t offset)
{
    (void)cmd;
    (void)slot;
    (void)buffer;
    (void)offset;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_bind_index_buffer(gr_handle cmd, gr_handle buffer, uint64_t offset, uint32_t index_type)
{
    (void)cmd;
    (void)buffer;
    (void)offset;
    (void)index_type;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_dispatch(gr_handle cmd, uint32_t x, uint32_t y, uint32_t z)
{
    (void)cmd;
    (void)x;
    (void)y;
    (void)z;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_dispatch_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset)
{
    (void)cmd;
    (void)buffer;
    (void)offset;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_submit(const gr_submit *submit, uint64_t *out_value)
{
    (void)submit;
    (void)out_value;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_swapchain_create(gr_handle device, const gr_swapchain_desc *desc, gr_handle *out_swapchain)
{
    (void)device;
    (void)desc;
    (void)out_swapchain;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_swapchain_info(gr_handle swapchain, gr_format *out_format, uint32_t *out_width, uint32_t *out_height, uint32_t *out_image_count)
{
    (void)swapchain;
    (void)out_format;
    (void)out_width;
    (void)out_height;
    (void)out_image_count;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_swapchain_acquire(gr_handle swapchain, uint64_t timeout_ns, uint32_t *out_image_index, gr_handle *out_view, int32_t *out_needs_recreate)
{
    (void)swapchain;
    (void)timeout_ns;
    (void)out_image_index;
    (void)out_view;
    (void)out_needs_recreate;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_swapchain_recreate(gr_handle swapchain, uint32_t width, uint32_t height, uint64_t after_value)
{
    (void)swapchain;
    (void)width;
    (void)height;
    (void)after_value;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_present(gr_handle queue, gr_handle swapchain, uint32_t image_index, uint64_t wait_value, uint64_t *out_value)
{
    (void)queue;
    (void)swapchain;
    (void)image_index;
    (void)wait_value;
    (void)out_value;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_fence_create(gr_handle device, uint64_t initial_value, gr_handle *out_fence)
{
    (void)device;
    (void)initial_value;
    (void)out_fence;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_fence_wait(gr_handle fence, uint64_t value, uint64_t timeout_ns, gr_result *out_status)
{
    (void)fence;
    (void)value;
    (void)timeout_ns;
    (void)out_status;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_buffer_create(gr_handle device, const gr_buffer_desc *desc, gr_handle *out_buffer)
{
    (void)device;
    (void)desc;
    (void)out_buffer;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_buffer_write(gr_handle buffer, uint64_t offset, gr_span_u8 data)
{
    (void)buffer;
    (void)offset;
    (void)data;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_buffer_read(gr_handle buffer, uint64_t offset, gr_mut_span_u8 out)
{
    (void)buffer;
    (void)offset;
    (void)out;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_buffer_map(gr_handle buffer, void **out_ptr)
{
    (void)buffer;
    (void)out_ptr;
    return GR_ERROR_UNSUPPORTED;
}

uint64_t gr_d3d12_abi_buffer_device_address(gr_handle buffer)
{
    (void)buffer;
    return 0;
}

uint32_t gr_d3d12_abi_buffer_bindless_index(gr_handle buffer)
{
    (void)buffer;
    return ~0u;
}

gr_result gr_d3d12_abi_sampler_create(gr_handle device, const gr_sampler_desc *desc, gr_handle *out_sampler, uint32_t *out_slot)
{
    (void)device;
    (void)desc;
    (void)out_sampler;
    (void)out_slot;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_texture_write(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t w, uint32_t h, gr_span_u8 rows)
{
    (void)texture;
    (void)mip;
    (void)layer;
    (void)x;
    (void)y;
    (void)w;
    (void)h;
    (void)rows;
    return GR_ERROR_UNSUPPORTED;
}

uint32_t gr_d3d12_abi_texture_view_bindless_sampled(gr_handle view)
{
    (void)view;
    return ~0u;
}

gr_result gr_d3d12_abi_frame_constants_write(gr_handle device, uint32_t slot, const gr_frame_constants *constants)
{
    (void)device;
    (void)slot;
    (void)constants;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_frame_slot_count(gr_handle device, uint32_t *out_count)
{
    (void)device;
    (void)out_count;
    return GR_ERROR_UNSUPPORTED;
}

gr_result gr_d3d12_abi_cmd_push_frame_offset(gr_handle cmd, uint32_t frame_slot)
{
    (void)cmd;
    (void)frame_slot;
    return GR_ERROR_UNSUPPORTED;
}

void gr_d3d12_abi_buffer_unmap(gr_handle buffer)
{
    (void)buffer;
}

uint64_t gr_d3d12_abi_fence_value(gr_handle fence)
{
    (void)fence;
    return 0;
}

#endif /* _WIN32 */
