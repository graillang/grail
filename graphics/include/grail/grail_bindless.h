/* grail_bindless.h - the one resource namespace every pipeline sees.
 *
 * The rule: binding never changes between passes. There is exactly one pipeline layout,
 * one descriptor set for resources (set 0) and one per-frame constant buffer (set 1), and
 * 128 bytes of push constants. A shader reaches a texture by an index it was given, not by
 * a binding an engine rewrote between draws.
 *
 * This is Abundance's design (abundance/engine/core/bindless.hpp:
 * "ONE descriptor set (set 0, update-after-bind, partially bound) holds every sampled
 * image, storage image, sampler, storage buffer and TLAS; set 1 holds the per-frame
 * constants... ONE pipeline layout ... serves every pipeline, so binding never changes
 * between passes").
 *
 * ---------------------------------------------------------------------------------------
 * One table, three spellings. Below, SET is 0 for resources and 1 for frame constants, and
 * B is the binding index. Each column is what that backend's compiler and API expect.
 *
 *   resource              SET B  Vulkan                     D3D12 (space, register)   Metal
 *   sampled images        0   0  VK_DESCRIPTOR_TYPE_       (0, t0) Tex2D[]           argument buffer
 *                                 SAMPLED_IMAGE            unbounded t[]             buffer(0)
 *   storage images        0   1  STORAGE_IMAGE            (0, u0) RWTexture[]       buffer(1)
 *   samplers              0   2  SAMPLER                  (0, s0) SamplerState[]    buffer(2)
 *   storage buffers       0   3  STORAGE_BUFFER           (0, t1) ByteAddressBuf[]  buffer(3)
 *   acceleration structs  0   4  ACCELERATION_STRUCTURE   (0, t2) RaytracingAccel[] buffer(4)
 *   frame constants       1   0  UNIFORM_BUFFER_DYNAMIC   (1, b0) ConstantBuffer     buffer(5)
 *   push constants        -   -  VK_SHADER_STAGE_*_BIT    root constants            setBytes()
 *                                128 bytes                b0..b31 (128 bytes)      <= 4096 bytes
 *
 * Why these numbers and not Abundance's 0/1/2/3-by-type order: Abundance writes
 * [[vk::binding(0,0)]] / (1,0) / (2,0) / (3,0) because it only ships Vulkan. Grail must
 * also produce D3D12. DXC maps `register(tN, spaceM)` to Vulkan set M / binding N by
 * default (verified against DXC 1.9.2609, graphics/docs/shader-flow.md "Bindings"), and
 * D3D12 register classes are separate namespaces, so t0/u0/s0 can share an index. Writing
 * register() therefore yields a correct Vulkan mapping *and* a correct D3D12 one from a
 * single declaration, with no -fvk-bind-register table. The consequence is that storage
 * buffers use t1, not u0, so that they cannot collide with storage images.
 *
 * Metal has no register spaces. SPIRV-Cross lays the same declarations out as one argument
 * buffer per set, so set 0 becomes buffer(0)..buffer(4) made of arrays, and set 1 becomes
 * buffer(5). The order above is the order the header declares them, which is what makes
 * that arg-buffer layout deterministic.
 * ---------------------------------------------------------------------------------------
 *
 * Capacity is a device property, not a compile-time promise: a caller must check
 * gr_device_caps.max_descriptor_array_length and the per-table capacities below. Exhaustion
 * is GR_ERROR_EXHAUSTED, a recoverable refusal, never a crash. A stale slot is refused the
 * same way. Slots are freed only once a completion value has passed (gr_device_retire).
 */
#ifndef GRAIL_BINDLESS_H
#define GRAIL_BINDLESS_H

#include "grail_abi.h"
#include "grail_rhi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* The descriptor set numbers. */
#define GR_BINDLESS_SET_RESOURCES 0u
#define GR_BINDLESS_SET_FRAME 1u

/* Binding indices inside set 0. */
enum {
    GR_BINDING_SAMPLED_IMAGES = 0,
    GR_BINDING_STORAGE_IMAGES = 1,
    GR_BINDING_SAMPLERS = 2,
    GR_BINDING_STORAGE_BUFFERS = 3,
    GR_BINDING_ACCELERATION_STRUCTURES = 4,
    GR_BINDING_COUNT
};

/* Binding index inside set 1. */
#define GR_BINDING_FRAME_CONSTANTS 0u

/* Push constant bytes. 128 is the Vulkan minimum that every conformant device guarantees,
 * and D3D12 root constants hold 128 bytes; exceeding it would drop a device. */
#define GR_PUSH_CONSTANT_BYTES 128u

/* Reference capacities, matching Abundance's bindless.hpp. A device may report fewer
 * through gr_device_caps.max_descriptor_array_length; it must report at least
 * GR_BINDLESS_MIN_* for a bindless device. */
enum {
    GR_BINDLESS_CAP_SAMPLED_IMAGES = 65536,
    GR_BINDLESS_CAP_STORAGE_IMAGES = 16384,
    GR_BINDLESS_CAP_SAMPLERS = 256,
    GR_BINDLESS_CAP_STORAGE_BUFFERS = 65536,
    GR_BINDLESS_CAP_ACCELERATION_STRUCTURES = 1024,

    GR_BINDLESS_MIN_SAMPLED_IMAGES = 4096,
    GR_BINDLESS_MIN_STORAGE_IMAGES = 1024,
    GR_BINDLESS_MIN_SAMPLERS = 16,
    GR_BINDLESS_MIN_STORAGE_BUFFERS = 4096
};

/* A slot index as the shader sees it. GR_BINDLESS_INDEX_NONE is never a valid slot. */
typedef uint32_t gr_bindless_index;
#define GR_BINDLESS_INDEX_NONE 0xFFFFFFFFu

typedef enum gr_bindless_table {
    GR_TABLE_SAMPLED_IMAGES = 0,
    GR_TABLE_STORAGE_IMAGES = 1,
    GR_TABLE_SAMPLERS = 2,
    GR_TABLE_STORAGE_BUFFERS = 3,
    GR_TABLE_ACCELERATION_STRUCTURES = 4
} gr_bindless_table;

typedef struct gr_bindless_info {
    gr_desc_head head;
    uint32_t capacity[GR_BINDING_COUNT];
    uint32_t high_water[GR_BINDING_COUNT];  /* the largest slot handed out so far, plus one */
    uint64_t releases_pending;              /* slots freed but not yet collectable */
} gr_bindless_info;

gr_result gr_bindless_get_info(gr_handle bindless, gr_bindless_info *out);

/* Slots are created by the resource calls (gr_texture_view_bindless_sampled,
 * gr_buffer_bindless_index) so that a resource and its slot can never disagree. Freeing a
 * slot releases the resource's claim on it; the resource itself is destroyed separately. */
gr_result gr_bindless_free(gr_handle bindless, gr_bindless_table table, gr_bindless_index index,
                           uint64_t after_value);

/* ---------------------------------------------------------------------------------------
 * Frame constants. Set 1, binding 0. One dynamic uniform buffer with a per-frame stride; a
 * frame's slot is selected by gr_cmd_push_frame_offset, not by rebinding.
 *
 * The GPU-side layout is the shader's, so this header states the contract and the shader
 * mirror (graphics/shaders/include/grail_frame.hlsli) states it again, and a static assert
 * on both sides plus the layout hash enforce agreement. Scalar layout, row-major matrices,
 * column vectors, 16-byte aligned members.
 *
 * Abundance's FrameConstants (engine/core/frame.hpp) is the model. Grail's first version is
 * deliberately smaller: a renderer port needs the camera and the timing first, and the
 * temporal and exposure blocks arrive with the passes that read them. The version field
 * exists so a shader can refuse a host it does not match instead of reading garbage.
 * --------------------------------------------------------------------------------------- */
#define GR_FRAME_CONSTANTS_VERSION 1u
#define GR_FRAME_CONSTANTS_MAX_LIGHTS 256u

typedef struct gr_frame_constants {
    float view[16];                /* camera-relative world -> view (rotation only) */
    float proj[16];                /* view -> clip, reverse-Z, infinite far plane */
    float view_proj[16];
    float inv_view_proj[16];
    float origin[4];               /* xyz: camera world position; w: unused, 0 */
    float viewport[4];             /* x,y: render size in pixels; z,w: 1/size */
    float time[4];                 /* x: seconds since start; y: delta seconds; z: frame index; w: unused */
    float sun_direction[4];        /* xyz: unit vector towards the sun; w: angular radius (rad) */
    float sun_illuminance[4];      /* rgb: illuminance at the ground; w: unused */
    float camera_forward[4];       /* xyz: unit forward; w: near plane in metres */
    float jitter[4];               /* xy: this frame's sub-pixel jitter in pixels; zw: previous */
    /* exposure is declared before the scalars, and both sides use this order, so that the
     * float4 lands on a 16-byte boundary under scalar layout and under C's natural
     * alignment. Declared in the C order that HLSL's scalar layout would also produce,
     * rather than trusting a compiler to insert the same padding: HLSL aligns a float4 to
     * 16, C aligns a float[4] to 4, and a silent disagreement here is precisely the drift
     * the layout hash exists to catch. Total size: 416 bytes on both sides. */
    float exposure[4];             /* x: display scale; y: EV100; z: pre-exposure; w: last pre-exposure */
    uint32_t frame_index;          /* 384 */
    uint32_t frame_seed;           /* hash of frame_index for stochastic passes */
    uint32_t flags;                /* gr_frame_flags */
    uint32_t version;              /* GR_FRAME_CONSTANTS_VERSION; a shader refuses a mismatch */
    uint32_t light_count;
    uint32_t _reserved0[3];
} gr_frame_constants;

typedef enum gr_frame_flags {
    GR_FRAME_NONE = 0,
    GR_FRAME_HISTORY_RESET = 1u << 0,   /* upscaler/temporal history is invalid this frame */
    GR_FRAME_CAPTURE = 1u << 1,         /* a capture is in progress */
    GR_FRAME_HEADLESS = 1u << 2
} gr_frame_flags;

/* Selected by gr_cmd_push_frame_offset at the start of a frame's recording. */
gr_result gr_cmd_push_frame_offset(gr_handle cmd, uint32_t frame_slot);
/* Fills one frame's slot with the constants a shader reads. Paired with the push above: this
 * writes the data, that selects which slot the recording reads. */
gr_result gr_frame_constants_write(gr_handle device, uint32_t frame_slot,
                                   const gr_frame_constants *constants);
/* The number of slots the device keeps in flight. */
gr_result gr_frame_slot_count(gr_handle device, uint32_t *out_count);
/* The host-side slot for this frame; the caller writes constants into it. */
uint32_t gr_frame_current_slot(gr_handle device);

#ifdef __cplusplus
} /* extern "C" */
#endif

/* The sizes both sides must agree on. A host that disagrees with its shaders must refuse to
 * run, which is what the layout hash enforces; these asserts make the disagreement a
 * compile error first. */
#if defined(__cplusplus) && (__cplusplus >= 201703L)
static_assert(sizeof(gr_frame_constants) % 16 == 0,
              "gr_frame_constants must be a multiple of 16 bytes for scalar and std140 layout");
static_assert(sizeof(gr_frame_constants) <= (1u << 16),
              "gr_frame_constants must fit a single dynamic uniform buffer slot");
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 201112L)
_Static_assert(sizeof(gr_frame_constants) % 16 == 0,
               "gr_frame_constants must be a multiple of 16 bytes for scalar and std140 layout");
_Static_assert(sizeof(gr_frame_constants) <= (1u << 16),
               "gr_frame_constants must fit a single dynamic uniform buffer slot");
#endif

#endif /* GRAIL_BINDLESS_H */
