/* grail_abi.h - common ABI layer for Grail graphics.
 *
 * Every Grail graphics header is plain C99, has no dependency beyond <stdint.h>/<stddef.h>,
 * and is safe to include from C++ (extern "C") and from a foreign process.
 *
 * Three rules make this ABI usable by a Grail program that owns no libc:
 *   1. Objects are addressed by tagged 64-bit handles, never by pointers.
 *   2. No allocation crosses the boundary; a caller supplies memory or receives it from
 *      a handle-owned pool. Status is returned, never thrown or asserted.
 *   3. Every descriptor begins with {size, next} so a helper can grow without breaking
 *      an older implementation (the implementation rejects an unknown size, not an
 *      unknown field).
 *
 * See graphics/docs/rhi-contract.md for the contract as a whole, and
 * graphics/docs/first-renderer-port.md for what Grail cannot yet do with this interface.
 */
#ifndef GRAIL_ABI_H
#define GRAIL_ABI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------------------------------
 * Version. An implementation reports the version it implements; a caller states the
 * version it was compiled against. Grail requires an exact major match and a minor that
 * the implementation is at least equal to. Bump GR_ABI_VERSION_MINOR for a purely
 * additive change (new entry point, new enumerant, new field reached through `next`);
 * bump GR_ABI_VERSION_MAJOR for anything that changes an existing layout or meaning.
 * --------------------------------------------------------------------------------------- */
#define GR_ABI_VERSION_MAJOR 1
#define GR_ABI_VERSION_MINOR 0
#define GR_ABI_VERSION ((GR_ABI_VERSION_MAJOR << 16) | GR_ABI_VERSION_MINOR)

typedef struct gr_version {
    uint16_t major;
    uint16_t minor;
} gr_version;

/* ---------------------------------------------------------------------------------------
 * Status. GR_OK is 0; positive values are statuses that are not errors; negative values
 * are errors. A function that returns GR_OK has produced its outputs in full.
 * --------------------------------------------------------------------------------------- */
typedef int32_t gr_result;

enum {
    GR_OK = 0,
    GR_TIMEOUT = 1,            /* a fence or acquire did not complete; retry is legal */
    GR_NEED_MORE = 2,          /* a query filled the buffer it was given */

    GR_ERROR_INVALID_ARGUMENT   = -1,
    GR_ERROR_INVALID_HANDLE     = -2, /* null, stale generation, or wrong type tag */
    GR_ERROR_OUT_OF_MEMORY      = -3,
    GR_ERROR_UNSUPPORTED        = -4, /* capability absent on this device or backend */
    GR_ERROR_DEVICE_LOST        = -5,
    GR_ERROR_VALIDATION_FAILED  = -6,
    GR_ERROR_VERSION_MISMATCH   = -7,
    GR_ERROR_NOT_READY          = -8, /* object not in a state that permits the call */
    GR_ERROR_EXHAUSTED          = -9, /* bindless table or pool full; recoverable refusal */
    GR_ERROR_BACKEND            = -10, /* the backend API itself failed */
    GR_ERROR_SHADER_INVALID     = -11, /* the shader blob or its reflection is rejected */
    GR_ERROR_LAYOUT_MISMATCH    = -12  /* host and shader GPU layouts disagree */
};

/* A human-readable rendering of a status, for logs. Never NULL. */
const char *gr_result_name(gr_result result);

/* ---------------------------------------------------------------------------------------
 * Handles. 64 bits: index | generation | type tag. 0 is the null handle.
 *
 *   [63:48] type tag   (gr_handle_type)
 *   [47:32] generation (incremented when a slot is reused, so a stale handle is refused
 *                       instead of silently addressing a new object)
 *   [31:0]  index
 *
 * Handles are the only way a caller names a GPU object. They are stable integers, so they
 * can be written to a log, hashed into a pipeline cache key, or sent to another process
 * (graphics/include/grail_wire.h). A stale or foreign handle is detected, not dereferenced.
 * --------------------------------------------------------------------------------------- */
typedef uint64_t gr_handle;

typedef enum gr_handle_type {
    GR_HANDLE_NONE = 0,        /* the null handle's tag */
    GR_HANDLE_DEVICE = 1,
    GR_HANDLE_QUEUE = 2,
    GR_HANDLE_WINDOW = 3,
    GR_HANDLE_SWAPCHAIN = 4,
    GR_HANDLE_BUFFER = 5,
    GR_HANDLE_TEXTURE = 6,
    GR_HANDLE_TEXTURE_VIEW = 7,
    GR_HANDLE_SAMPLER = 8,
    GR_HANDLE_SHADER = 9,
    GR_HANDLE_PIPELINE = 10,
    GR_HANDLE_CMD_BUFFER = 11,
    GR_HANDLE_FENCE = 12,
    GR_HANDLE_SEMAPHORE = 13,
    GR_HANDLE_BINDLESS = 14,
    GR_HANDLE_QUERY_POOL = 15,
    GR_HANDLE_WIRE = 16,
    GR_HANDLE_CMD_POOL = 17,
    GR_HANDLE_TYPE_MAX = 0xFFFE
} gr_handle_type;

#define GR_NULL_HANDLE ((gr_handle)0)

static inline gr_handle gr_handle_make(uint32_t index, uint32_t generation, uint32_t type)
{
    return ((gr_handle)(type & 0xFFFFu) << 48) | ((gr_handle)(generation & 0xFFFFu) << 32) |
           (gr_handle)index;
}
static inline uint32_t gr_handle_index(gr_handle h) { return (uint32_t)(h & 0xFFFFFFFFu); }
static inline uint32_t gr_handle_generation(gr_handle h) { return (uint32_t)((h >> 32) & 0xFFFFu); }
static inline uint32_t gr_handle_tag(gr_handle h) { return (uint32_t)((h >> 48) & 0xFFFFu); }
static inline int gr_handle_is_null(gr_handle h) { return h == GR_NULL_HANDLE; }
/* Non-zero when `h` is non-null and carries the expected type tag. Does not prove liveness. */
static inline int gr_handle_has_type(gr_handle h, gr_handle_type type)
{
    return h != GR_NULL_HANDLE && gr_handle_tag(h) == (uint32_t)type;
}

/* ---------------------------------------------------------------------------------------
 * Strings and spans. A gr_str is a pointer plus a length and is NOT required to be
 * NUL-terminated. Pointers never cross a process boundary; grail_wire.h carries text as
 * (offset, length) into the packet for that case.
 * --------------------------------------------------------------------------------------- */
typedef struct gr_str {
    const char *data;
    uint32_t len;   /* bytes, excluding any terminator */
    uint32_t _pad;  /* zero; keeps later 8-byte members aligned */
} gr_str;

#define GR_STR(literal) { (literal), (uint32_t)(sizeof(literal) - 1u), 0u }

typedef struct gr_span_u8 {
    const uint8_t *data;
    size_t len;
} gr_span_u8;

typedef struct gr_mut_span_u8 {
    uint8_t *data;
    size_t len;
} gr_mut_span_u8;

/* Length of a NUL-terminated string from a header file, at compile time. */
#define GR_COUNTOF(a) (sizeof(a) / sizeof((a)[0]))

/* ---------------------------------------------------------------------------------------
 * Descriptor head. Every structure a caller passes in begins with these two fields and is
 * initialised with GR_DESC_INIT, which records its own size. An implementation validates
 * `size` and rejects a structure it does not understand with GR_ERROR_VERSION_MISMATCH; it
 * never reads past what the caller declared. `next` chains an extension structure.
 * --------------------------------------------------------------------------------------- */
typedef struct gr_desc_head {
    uint32_t size;            /* sizeof the caller's structure */
    uint32_t _reserved;
    const void *next;         /* extension chain, or NULL */
} gr_desc_head;

#define GR_DESC_INIT(type) { (uint32_t)sizeof(type), 0u, NULL }

/* ---------------------------------------------------------------------------------------
 * Capability bits. A backend fills these in a gr_device_caps; a caller asks once after
 * device creation rather than probing per call. These are the engine-relevant ones derived
 * from Abundance's DeviceCaps (abundance/engine/core/device.hpp).
 * --------------------------------------------------------------------------------------- */
typedef enum gr_caps {
    GR_CAP_NONE                   = 0,
    GR_CAP_BINDLESS               = 1u << 0,  /* set 0 descriptor-indexed table */
    GR_CAP_DESCRIPTOR_UPDATE_AFTER_BIND = 1u << 1,
    GR_CAP_DYNAMIC_RENDERING      = 1u << 2,  /* no VkRenderPass / no D3D12 render pass object */
    GR_CAP_TIMELINE_SEMAPHORE     = 1u << 3,  /* queue timelines; Metal uses MTLEvent instead */
    GR_CAP_BUFFER_DEVICE_ADDRESS  = 1u << 4,
    GR_CAP_MESH_SHADER            = 1u << 5,
    GR_CAP_RAY_TRACING            = 1u << 6,
    GR_CAP_16BIT_TYPES            = 1u << 7,
    GR_CAP_64BIT_INTEGER          = 1u << 8,
    GR_CAP_FLOAT_ATOMICS          = 1u << 9,
    GR_CAP_INT64_IMAGE_ATOMICS    = 1u << 10, /* depth|id visibility packing */
    GR_CAP_CONSERVATIVE_RASTER    = 1u << 11,
    GR_CAP_CALIBRATED_TIMESTAMPS  = 1u << 12,
    GR_CAP_MEMORY_BUDGET          = 1u << 13, /* VK_EXT_memory_budget / D3D12 QueryVideoMemoryInfo */
    GR_CAP_SUBGROUP_OPERATIONS    = 1u << 14,
    GR_CAP_STORAGE_IMAGE_FORMAT_UNKNOWN = 1u << 15, /* bindless RW textures of any format */
    GR_CAP_WIRE_BRIDGE            = 1u << 16  /* backend may be driven over grail_wire.h */
} gr_caps;

/* ---------------------------------------------------------------------------------------
 * Backend identity. A device is created by exactly one backend. GR_BACKEND_NULL is a real
 * implementation (graphics/src/grail_null.c): it validates every call and allocates
 * handles without touching a GPU, so the ABI is exercised on any machine, in CI, and on a
 * host with no display.
 * --------------------------------------------------------------------------------------- */
typedef enum gr_backend {
    GR_BACKEND_NULL = 0,
    GR_BACKEND_VULKAN = 1,  /* Linux, Windows */
    GR_BACKEND_D3D12 = 2,   /* Windows 10 2004+ / Windows 11 */
    GR_BACKEND_METAL = 3    /* macOS 13+ */
} gr_backend;

const char *gr_backend_name(gr_backend backend);

/* The ABI version this implementation was built against. */
gr_version gr_abi_version(void);
/* GR_OK when a caller compiled against `required` can talk to this implementation. */
gr_result gr_abi_check(gr_version required);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_ABI_H */
