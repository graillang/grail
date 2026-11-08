/* grail_core.c - the ABI's shared helpers: version, status names, format table,
 * permutation hashing and the object table. Backend independent. */
#include "grail_internal.h"

#include <stddef.h>

/* ---------------------------------------------------------------------------------------
 * Version
 * --------------------------------------------------------------------------------------- */
gr_version gr_abi_version(void)
{
    gr_version v;
    v.major = (uint16_t)GR_ABI_VERSION_MAJOR;
    v.minor = (uint16_t)GR_ABI_VERSION_MINOR;
    return v;
}

gr_result gr_abi_check(gr_version required)
{
    /* Exact major, and an implementation at least as new as the caller requires. */
    if (required.major != GR_ABI_VERSION_MAJOR)
        return GR_ERROR_VERSION_MISMATCH;
    if (required.minor > GR_ABI_VERSION_MINOR)
        return GR_ERROR_VERSION_MISMATCH;
    return GR_OK;
}

/* ---------------------------------------------------------------------------------------
 * Names
 * --------------------------------------------------------------------------------------- */
const char *gr_result_name(gr_result result)
{
    switch (result) {
    case GR_OK: return "ok";
    case GR_TIMEOUT: return "timeout";
    case GR_NEED_MORE: return "need_more";
    case GR_ERROR_INVALID_ARGUMENT: return "invalid_argument";
    case GR_ERROR_INVALID_HANDLE: return "invalid_handle";
    case GR_ERROR_OUT_OF_MEMORY: return "out_of_memory";
    case GR_ERROR_UNSUPPORTED: return "unsupported";
    case GR_ERROR_DEVICE_LOST: return "device_lost";
    case GR_ERROR_VALIDATION_FAILED: return "validation_failed";
    case GR_ERROR_VERSION_MISMATCH: return "version_mismatch";
    case GR_ERROR_NOT_READY: return "not_ready";
    case GR_ERROR_EXHAUSTED: return "exhausted";
    case GR_ERROR_BACKEND: return "backend";
    case GR_ERROR_SHADER_INVALID: return "shader_invalid";
    case GR_ERROR_LAYOUT_MISMATCH: return "layout_mismatch";
    case GR_ERROR_PERMUTATION_MISSING: return "permutation_missing";
    default: return "unknown";
    }
}

const char *gr_backend_name(gr_backend backend)
{
    switch (backend) {
    case GR_BACKEND_NULL: return "null";
    case GR_BACKEND_VULKAN: return "vulkan";
    case GR_BACKEND_D3D12: return "d3d12";
    case GR_BACKEND_METAL: return "metal";
    default: return "unknown";
    }
}

const char *gr_shader_stage_suffix(gr_shader_stage stage)
{
    switch (stage) {
    case GR_SHADER_STAGE_VERTEX: return "vs";
    case GR_SHADER_STAGE_FRAGMENT: return "ps";
    case GR_SHADER_STAGE_COMPUTE: return "cs";
    case GR_SHADER_STAGE_MESH: return "ms";
    case GR_SHADER_STAGE_TASK: return "as";
    case GR_SHADER_STAGE_LIBRARY: return "lib";
    default: return "";
    }
}

gr_result gr_shader_stage_from_suffix(gr_str suffix, gr_shader_stage *out)
{
    gr_shader_stage stage;
    if (!out || !suffix.data)
        return GR_ERROR_INVALID_ARGUMENT;
    if (suffix.len == 2 && suffix.data[0] == 'v' && suffix.data[1] == 's') stage = GR_SHADER_STAGE_VERTEX;
    else if (suffix.len == 2 && suffix.data[0] == 'p' && suffix.data[1] == 's') stage = GR_SHADER_STAGE_FRAGMENT;
    else if (suffix.len == 2 && suffix.data[0] == 'c' && suffix.data[1] == 's') stage = GR_SHADER_STAGE_COMPUTE;
    else if (suffix.len == 2 && suffix.data[0] == 'm' && suffix.data[1] == 's') stage = GR_SHADER_STAGE_MESH;
    else if (suffix.len == 2 && suffix.data[0] == 'a' && suffix.data[1] == 's') stage = GR_SHADER_STAGE_TASK;
    else if (suffix.len == 3 && suffix.data[0] == 'l' && suffix.data[1] == 'i' && suffix.data[2] == 'b')
        stage = GR_SHADER_STAGE_LIBRARY;
    else
        return GR_ERROR_INVALID_ARGUMENT;
    *out = stage;
    return GR_OK;
}

/* ---------------------------------------------------------------------------------------
 * Formats. The table is indexed by gr_format, so a missing entry is a compile-time visible
 * omission rather than a silent 0.
 * --------------------------------------------------------------------------------------- */
typedef struct format_info {
    const char *name;
    uint32_t bytes_per_block;
    uint32_t block_w, block_h;
    uint8_t class_id;      /* gr_format_class */
    uint8_t srgb_pair;     /* the sRGB partner, or the self index */
    uint8_t hdr;
    uint8_t has_depth;
} format_info;

static const format_info kFormats[GR_FORMAT_COUNT] = {
    /* name                      bpb  w  h  class                          srgb  hdr depth */
    { "undefined",                0, 1, 1, GR_FORMAT_CLASS_COLOR,         0,  0, 0 },
    { "r8_unorm",                 1, 1, 1, GR_FORMAT_CLASS_COLOR,         1,  0, 0 },
    { "r8_uint",                  1, 1, 1, GR_FORMAT_CLASS_COLOR,         2,  0, 0 },
    { "r8g8_unorm",               2, 1, 1, GR_FORMAT_CLASS_COLOR,         3,  0, 0 },
    { "r8g8b8a8_unorm",           4, 1, 1, GR_FORMAT_CLASS_COLOR,         5,  0, 0 },
    { "r8g8b8a8_srgb",            4, 1, 1, GR_FORMAT_CLASS_COLOR,         4,  0, 0 },
    { "b8g8r8a8_unorm",           4, 1, 1, GR_FORMAT_CLASS_COLOR,         7,  0, 0 },
    { "b8g8r8a8_srgb",            4, 1, 1, GR_FORMAT_CLASS_COLOR,         6,  0, 0 },
    { "r16_float",                2, 1, 1, GR_FORMAT_CLASS_COLOR,         8,  1, 0 },
    { "r16_uint",                 2, 1, 1, GR_FORMAT_CLASS_COLOR,         9,  0, 0 },
    { "r16g16_float",             4, 1, 1, GR_FORMAT_CLASS_COLOR,        10,  1, 0 },
    { "r16g16b16a16_float",       8, 1, 1, GR_FORMAT_CLASS_COLOR,        11,  1, 0 },
    { "r16g16b16a16_unorm",       8, 1, 1, GR_FORMAT_CLASS_COLOR,        12,  0, 0 },
    { "r32_uint",                 4, 1, 1, GR_FORMAT_CLASS_COLOR,        13,  0, 0 },
    { "r32_float",                4, 1, 1, GR_FORMAT_CLASS_COLOR,        14,  1, 0 },
    { "r32g32_uint",              8, 1, 1, GR_FORMAT_CLASS_COLOR,        15,  0, 0 },
    { "r32g32_float",             8, 1, 1, GR_FORMAT_CLASS_COLOR,        16,  1, 0 },
    { "r32g32b32a32_float",      16, 1, 1, GR_FORMAT_CLASS_COLOR,        17,  1, 0 },
    { "r32g32b32a32_uint",       16, 1, 1, GR_FORMAT_CLASS_COLOR,        18,  0, 0 },
    { "r10g10b10a2_unorm",        4, 1, 1, GR_FORMAT_CLASS_COLOR,        19,  0, 0 },
    { "r11g11b10_float",          4, 1, 1, GR_FORMAT_CLASS_COLOR,        20,  1, 0 },
    { "bc7_unorm",               16, 4, 4, GR_FORMAT_CLASS_COLOR,        22,  0, 0 },
    { "bc7_srgb",                16, 4, 4, GR_FORMAT_CLASS_COLOR,        21,  0, 0 },
    { "bc5_unorm",               16, 4, 4, GR_FORMAT_CLASS_COLOR,        23,  0, 0 },
    { "d32_float",                4, 1, 1, GR_FORMAT_CLASS_DEPTH,        24,  0, 1 },
    { "d32_float_s8_uint",        8, 1, 1, GR_FORMAT_CLASS_DEPTH_STENCIL,25,  0, 1 },
    { "d24_unorm_s8_uint",        4, 1, 1, GR_FORMAT_CLASS_DEPTH_STENCIL,26,  0, 1 },
    { "d16_unorm",                2, 1, 1, GR_FORMAT_CLASS_DEPTH,        27,  0, 1 }
};

uint32_t gr_format_bytes_per_block(gr_format format)
{
    if ((unsigned)format >= GR_FORMAT_COUNT) return 0;
    return kFormats[format].bytes_per_block;
}

void gr_format_block_extent(gr_format format, uint32_t *out_w, uint32_t *out_h)
{
    if ((unsigned)format >= GR_FORMAT_COUNT) {
        if (out_w) *out_w = 0;
        if (out_h) *out_h = 0;
        return;
    }
    if (out_w) *out_w = kFormats[format].block_w;
    if (out_h) *out_h = kFormats[format].block_h;
}

gr_format_class gr_format_class_of(gr_format format)
{
    if ((unsigned)format >= GR_FORMAT_COUNT) return GR_FORMAT_CLASS_COLOR;
    return (gr_format_class)kFormats[format].class_id;
}

int gr_format_is_hdr(gr_format format)
{
    if ((unsigned)format >= GR_FORMAT_COUNT) return 0;
    return kFormats[format].hdr;
}

gr_format gr_format_to_srgb(gr_format format)
{
    if ((unsigned)format >= GR_FORMAT_COUNT) return GR_FORMAT_UNDEFINED;
    /* Only the colour formats with an sRGB partner map; a depth format maps to itself. */
    switch (format) {
    case GR_FORMAT_R8G8B8A8_UNORM: return GR_FORMAT_R8G8B8A8_SRGB;
    case GR_FORMAT_B8G8R8A8_UNORM: return GR_FORMAT_B8G8R8A8_SRGB;
    case GR_FORMAT_BC7_UNORM: return GR_FORMAT_BC7_SRGB;
    default: return format;
    }
}

gr_format gr_format_to_linear(gr_format format)
{
    if ((unsigned)format >= GR_FORMAT_COUNT) return GR_FORMAT_UNDEFINED;
    switch (format) {
    case GR_FORMAT_R8G8B8A8_SRGB: return GR_FORMAT_R8G8B8A8_UNORM;
    case GR_FORMAT_B8G8R8A8_SRGB: return GR_FORMAT_B8G8R8A8_UNORM;
    case GR_FORMAT_BC7_SRGB: return GR_FORMAT_BC7_UNORM;
    default: return format;
    }
}

/* ---------------------------------------------------------------------------------------
 * Strings and hashing
 * --------------------------------------------------------------------------------------- */
char *gr_str_dup(gr_str s)
{
    char *copy;
    if (!s.data || s.len == 0)
        return NULL;
    copy = (char *)malloc((size_t)s.len + 1u);
    if (!copy)
        return NULL;
    memcpy(copy, s.data, s.len);
    copy[s.len] = '\0';
    return copy;
}

uint64_t gr_hash_bytes(const void *data, size_t len)
{
    const uint8_t *p = (const uint8_t *)data;
    uint64_t hash = 0xcbf29ce484222325ull; /* FNV-1a 64 offset basis */
    size_t i;
    for (i = 0; i < len; ++i) {
        hash ^= (uint64_t)p[i];
        hash *= 0x100000001b3ull;
    }
    return hash;
}

uint64_t gr_hash_bytes_into(uint64_t hash, const void *data, size_t len)
{
    const uint8_t *p = (const uint8_t *)data;
    size_t i;
    for (i = 0; i < len; ++i) {
        hash ^= (uint64_t)p[i];
        hash *= 0x100000001b3ull;
    }
    return hash;
}

uint64_t gr_hash_u64(uint64_t hash, uint64_t value)
{
    /* FNV-1a over the eight bytes of a value, so field order matters and padding never does. */
    unsigned i;
    for (i = 0; i < 8; ++i) {
        hash ^= (value >> (i * 8u)) & 0xFFu;
        hash *= 0x100000001b3ull;
    }
    return hash;
}

/* ---------------------------------------------------------------------------------------
 * Permutation keys
 * --------------------------------------------------------------------------------------- */
static int permutation_compare(const void *lhs, const void *rhs)
{
    const gr_permutation_entry *a = (const gr_permutation_entry *)lhs;
    const gr_permutation_entry *b = (const gr_permutation_entry *)rhs;
    if (a->name < b->name) return -1;
    if (a->name > b->name) return 1;
    return 0;
}

uint32_t gr_permutation_name_id(gr_str name)
{
    if (!name.data || name.len == 0)
        return 0;
    return (uint32_t)(gr_hash_bytes(name.data, name.len) & 0xFFFFFFFFull);
}

uint64_t gr_permutation_key(const gr_permutation *perm)
{
    gr_permutation_entry sorted[GR_PERMUTATION_MAX_ENTRIES];
    uint32_t count, i;
    uint64_t hash = 0xcbf29ce484222325ull;

    if (!perm || perm->count == 0)
        return hash;
    count = perm->count;
    if (count > GR_PERMUTATION_MAX_ENTRIES)
        count = GR_PERMUTATION_MAX_ENTRIES;
    memcpy(sorted, perm->entries, sizeof(gr_permutation_entry) * count);
    /* qsort is used rather than an insertion sort so the ordering is the same on every
     * platform; the comparator is total over the key, which makes the result stable. */
    qsort(sorted, count, sizeof(gr_permutation_entry), permutation_compare);
    for (i = 0; i < count; ++i) {
        hash = gr_hash_u64(hash, (uint64_t)sorted[i].name);
        hash = gr_hash_u64(hash, (uint64_t)sorted[i].value);
    }
    return hash;
}

uint64_t gr_pipeline_cache_key(uint64_t permutation_key, uint64_t shader_identity)
{
    uint64_t hash = 0xcbf29ce484222325ull;
    hash = gr_hash_u64(hash, permutation_key);
    hash = gr_hash_u64(hash, shader_identity);
    return hash;
}

/* ---------------------------------------------------------------------------------------
 * Object table
 * --------------------------------------------------------------------------------------- */
static gr_object_table g_objects;

gr_object_table *gr_objects(void) { return &g_objects; }

void gr_objects_init_once(void)
{
    static int initialised = 0;
    if (!initialised) {
        gr_object_table_init(&g_objects);
        initialised = 1;
    }
}

void gr_object_table_init(gr_object_table *table)
{
    uint32_t i;
    memset(table, 0, sizeof(*table));
    table->free_head = GR_OBJECT_MAX;
    /* Build the free list from the end so index 0 is handed out first; index 0 with
     * generation 0 and type 0 would collide with GR_NULL_HANDLE, so the first insert must
     * not be index 0 with type 0. GR_HANDLE_NONE is 0, so no real object uses type 0. */
    for (i = GR_OBJECT_MAX; i-- > 0;) {
        table->slots[i].object = NULL;
        table->slots[i].live = 0;
        table->slots[i].generation = 1; /* never 0: a handle always carries a non-zero gen */
        table->slots[i].type = GR_HANDLE_NONE;
        table->slots[i].next_free = table->free_head;
        table->free_head = i;
    }
}

gr_handle gr_object_insert(gr_object_table *table, uint32_t type, void *object)
{
    uint32_t index;
    if (!table || !object || type == GR_HANDLE_NONE || (uint32_t)type > GR_HANDLE_TYPE_MAX)
        return GR_NULL_HANDLE;
    index = table->free_head;
    if (index >= GR_OBJECT_MAX)
        return GR_NULL_HANDLE;
    table->free_head = table->slots[index].next_free;
    table->slots[index].object = object;
    table->slots[index].type = (uint32_t)type;
    table->slots[index].live = 1;
    table->slots[index].next_free = GR_OBJECT_MAX;
    table->live_count++;
    return gr_handle_make(index, table->slots[index].generation, (uint32_t)type);
}

void *gr_object_lookup(gr_object_table *table, gr_handle handle, uint32_t type,
                       gr_result *out_status)
{
    gr_object_slot *slot;
    uint32_t index;
    gr_result status = GR_OK;

    if (!table) {
        status = GR_ERROR_INVALID_HANDLE;
        goto done;
    }
    if (handle == GR_NULL_HANDLE) {
        status = GR_ERROR_INVALID_HANDLE;
        goto done;
    }
    if (gr_handle_tag(handle) != (uint32_t)type) {
        status = GR_ERROR_INVALID_ARGUMENT; /* the handle is real, of another type */
        goto done;
    }
    index = gr_handle_index(handle);
    if (index >= GR_OBJECT_MAX) {
        status = GR_ERROR_INVALID_HANDLE;
        goto done;
    }
    slot = &table->slots[index];
    if (!slot->live || slot->type != (uint32_t)type ||
        slot->generation != gr_handle_generation(handle)) {
        status = GR_ERROR_INVALID_HANDLE;
        goto done;
    }
    if (out_status) *out_status = GR_OK;
    return slot->object;

done:
    if (out_status) *out_status = status;
    return NULL;
}

void *gr_object_remove(gr_object_table *table, gr_handle handle, uint32_t type)
{
    gr_object_slot *slot;
    uint32_t index;
    void *object;

    if (!table || handle == GR_NULL_HANDLE || gr_handle_tag(handle) != (uint32_t)type)
        return NULL;
    index = gr_handle_index(handle);
    if (index >= GR_OBJECT_MAX)
        return NULL;
    slot = &table->slots[index];
    if (!slot->live || slot->type != (uint32_t)type ||
        slot->generation != gr_handle_generation(handle))
        return NULL;

    object = slot->object;
    slot->object = NULL;
    slot->live = 0;
    slot->type = GR_HANDLE_NONE;
    /* Bump the generation so every handle that named this slot is dead. The 16-bit field
     * wraps: after 65535 reuses of one index a decades-old handle could be accepted again.
     * In practice a slot is reused only after a frame completed, so the wrap needs a
     * process that has created 65535 objects in one slot. */
    slot->generation = (slot->generation + 1u) & 0xFFFFu;
    if (slot->generation == 0)
        slot->generation = 1;
    slot->next_free = table->free_head;
    table->free_head = index;
    table->live_count--;
    return object;
}
