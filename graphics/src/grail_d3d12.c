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
 * that set targets and clear, viewport/scissor, submit, and a synchronous texture readback.
 * Everything else - buffers, shaders, pipelines, draws, bindless, swapchains, semaphores and
 * non-graphics queues - returns GR_ERROR_UNSUPPORTED rather than an approximation.
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
#include <stdint.h>

#define D3D_RTV_MAX 256u

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
    d3d_node *objects;           /* owned objects, newest first */
    D3D_FEATURE_LEVEL max_level; /* the highest level the driver supports, reported in caps */
    DXGI_ADAPTER_DESC1 adapter_desc;
};

typedef struct d3d_texture {
    d3d_node node;
    d3d_device *device;
    ID3D12Resource *resource;
    gr_format format;
    DXGI_FORMAT dxgi;
    uint32_t width, height, bytes_per_pixel;
    D3D12_RESOURCE_STATES state; /* the state the last recorded barrier leaves it in */
} d3d_texture;

typedef struct d3d_view {
    d3d_node node;
    d3d_texture *texture;
    uint32_t rtv_index;          /* D3D_RTV_MAX: not a render-target view */
} d3d_view;

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
} d3d_cmd;

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
                                                 (void **)&dev->rtv_heap))) {
        status = GR_ERROR_BACKEND;
        goto fail;
    }
    dev->graphics->device = dev;
    dev->rtv_stride = ID3D12Device_GetDescriptorHandleIncrementSize(dev->device,
                                                                    D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    *out_device = gr_object_insert(gr_objects(), GR_HANDLE_DEVICE, dev);
    if (*out_device == GR_NULL_HANDLE) {
        status = GR_ERROR_OUT_OF_MEMORY;
        goto fail;
    }
    dev->node.handle = *out_device;
    status = d3d_own(dev, &dev->graphics->node, GR_HANDLE_QUEUE, dev->graphics, &dev->queue_handle);
    if (status != GR_OK) {
        gr_object_remove(gr_objects(), *out_device, GR_HANDLE_DEVICE);
        *out_device = GR_NULL_HANDLE;
        goto fail;
    }
    return GR_OK;
fail:
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
        break;
    }
    case GR_HANDLE_CMD_BUFFER: {
        d3d_cmd *c = (d3d_cmd *)node;
        ID3D12GraphicsCommandList_Release(c->list);
        ID3D12CommandAllocator_Release(c->allocator);
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
        desc->array_layers > 1 || desc->samples > 1 ||
        (desc->usage & ~(uint32_t)(GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC |
                                   GR_TEXTURE_USAGE_TRANSFER_DST)))
        return GR_ERROR_UNSUPPORTED;
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
    rd.SampleDesc.Count = 1;
    if (desc->usage & GR_TEXTURE_USAGE_COLOR_ATTACHMENT)
        rd.Flags = D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;
    memset(&clear, 0, sizeof(clear));
    clear.Format = dxgi;
    if (FAILED(ID3D12Device_CreateCommittedResource(
            dev->device, &heap, D3D12_HEAP_FLAG_NONE, &rd, D3D12_RESOURCE_STATE_COMMON,
            (desc->usage & GR_TEXTURE_USAGE_COLOR_ATTACHMENT) ? &clear : NULL, &IID_ID3D12Resource,
            (void **)&texture->resource))) {
        free(texture);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    texture->device = dev;
    texture->format = desc->format;
    texture->dxgi = dxgi;
    texture->width = desc->width;
    texture->height = desc->height;
    texture->bytes_per_pixel = bpp;
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
    {
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
            rtv.ViewDimension = D3D12_RTV_DIMENSION_TEXTURE2D;
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
        if (!texture)
            return GR_ERROR_UNSUPPORTED; /* buffer barriers are not in this slice */
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
    D3D12_CPU_DESCRIPTOR_HANDLE targets[D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT], base;
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
    if (info->depth)
        return GR_ERROR_UNSUPPORTED;
    cmd->device->rtv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(cmd->device->rtv_heap, &base);
    for (i = 0; i < info->color_count; ++i) {
        d3d_view *view = (d3d_view *)d3d_get(info->colors[i].view, GR_HANDLE_TEXTURE_VIEW);
        if (!view)
            return GR_ERROR_INVALID_HANDLE;
        if (view->rtv_index == D3D_RTV_MAX || info->colors[i].resolve_view != GR_NULL_HANDLE)
            return GR_ERROR_UNSUPPORTED;
        if (view->texture->state != D3D12_RESOURCE_STATE_RENDER_TARGET)
            return GR_ERROR_NOT_READY; /* the ABI requires an explicit barrier first */
        targets[i].ptr = base.ptr + (SIZE_T)view->rtv_index * cmd->device->rtv_stride;
        if (view->texture->width > width) width = view->texture->width;
        if (view->texture->height > height) height = view->texture->height;
    }
    ID3D12GraphicsCommandList_OMSetRenderTargets(cmd->list, info->color_count, targets, FALSE, NULL);
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

gr_result gr_d3d12_abi_cmd_end_render(gr_handle cmd_handle)
{
    d3d_cmd *cmd = d3d_cmd_of(cmd_handle);
    if (!cmd)
        return GR_ERROR_INVALID_HANDLE;
    return cmd->recording ? GR_OK : GR_ERROR_NOT_READY;
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
    for (i = 0; i < submit->cmd_count; ++i)
        d3d_cmd_of(submit->cmds[i])->last_submit = value;
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
    d3d_texture *texture = (d3d_texture *)d3d_get(texture_handle, GR_HANDLE_TEXTURE);
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

/* ---- not in this slice ------------------------------------------------------------------ */

gr_result gr_d3d12_abi_queue_timeline(gr_handle queue, gr_handle *out_semaphore)
{
    (void)queue;
    (void)out_semaphore;
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
    return 0;
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
    return 0;
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
    return 0;
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
    return 0;
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
