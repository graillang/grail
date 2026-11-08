/* grail_shader_library.c - resolving a permutation key to that permutation's bytecode.
 *
 * The artifact naming produced by graphics/tools/shader.mjs is the index:
 *
 *     <name>.<stage>.refl.bin                 the no-flags build (permutation key 0)
 *     <name>.<stage>.<16 hex key>.refl.bin    one per permutation
 *
 * So the library needs no side index and no JSON parser: it walks the directory once, parses
 * every file name, and then maps a (name, stage, key) request onto a path. Loading is lazy and
 * cached, and every blob is validated by gr_reflect_open() before it is handed out, so a
 * truncated or stale artifact is a status at resolve time rather than a crash later.
 *
 * This file is backend-agnostic on purpose: it knows nothing about Vulkan, D3D12 or Metal.
 * gr_shader_create_resolved() is the only place it consults the device, and only to ask which
 * container that device wants.
 *
 * Portability: enumeration and reading use POSIX opendir/readdir/fopen. They are the only two
 * platform-dependent primitives in the file and are isolated in lib_enumerate()/lib_read_file();
 * the Windows host needs a FindFirstFile/ReadFile pair there and nothing else changes.
 */
#include "grail_internal.h"
#include "../include/grail/grail_bindless.h"

#include <stdio.h>
#include <sys/stat.h>

#if !defined(_WIN32)
#include <dirent.h>
#else
#include <windows.h>
#endif

#define GR_LIB_MAX_ENTRIES 256u
#define GR_LIB_PATH_MAX 512u
#define GR_LIB_NAME_MAX 128u
#define GR_LIB_CACHE_SLOTS 32u
#define GR_LIB_MAX_DEPTH 8u

typedef struct gr_lib_entry {
    char name[GR_LIB_NAME_MAX];
    uint32_t name_len;
    gr_shader_stage stage;
    uint64_t key;
    char path[GR_LIB_PATH_MAX];
} gr_lib_entry;

typedef struct gr_lib_cache_slot {
    uint32_t used;
    uint32_t entry;      /* index into the library's entries */
    uint8_t *blob;       /* owned; the reflection points into it */
    uint64_t blob_length;
    gr_reflection reflection;
    uint32_t frame_constants_size;
    /* The other containers are siblings of the blob, not inside it: the offline tool writes
     * <name>.<stage>[.<key>].dxil and .msl next to .refl.bin. They are optional, because a
     * Linux build has no DXIL and a build without SPIRV-Cross has no MSL. */
    uint8_t *dxil;
    uint64_t dxil_length;
    uint8_t *msl;
    uint64_t msl_length;
} gr_lib_cache_slot;

typedef struct gr_library {
    gr_lib_entry entries[GR_LIB_MAX_ENTRIES];
    uint32_t entry_count;
    uint32_t shader_count;
    gr_lib_cache_slot cache[GR_LIB_CACHE_SLOTS];
    uint32_t cache_used;
    uint64_t hits;
    uint64_t loads;
    uint64_t misses;
    char root[GR_LIB_PATH_MAX];
} gr_library;

/* ---------------------------------------------------------------------------------------
 * Name parsing
 * --------------------------------------------------------------------------------------- */
static int hex_digit(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* "<name>.<stage>[.<key>]". `rel` is the path relative to the library root, without the
 * ".refl.bin" suffix, and `name_out` receives the part that is not the stage or the key. */
static gr_result parse_name(const char *rel, char *name_out, size_t name_cap,
                            gr_shader_stage *stage_out, uint64_t *key_out)
{
    size_t len = strlen(rel);
    size_t name_len = len;
    uint64_t key = 0;
    char suffix[4];

    /* Peel a 16-hex-digit key: ".<16 hex>" is 17 characters. */
    if (name_len >= 17u && rel[name_len - 17u] == '.') {
        unsigned i;
        int all_hex = 1;
        for (i = 0; i < 16u; ++i) {
            int digit = hex_digit(rel[name_len - 16u + i]);
            if (digit < 0) { all_hex = 0; break; }
            key = (key << 4) | (uint64_t)digit;
        }
        if (all_hex) {
            name_len -= 17u;
            *key_out = key;
        } else {
            /* Not a key: the file is a variant whose name happens to end in hex digits. Treat
             * it as the no-flags build rather than inventing a key. */
            *key_out = 0;
        }
    } else {
        *key_out = 0;
    }

    /* Peel the stage suffix, which is 2 characters or "lib". */
    if (name_len >= 4u && rel[name_len - 4u] == '.' &&
        rel[name_len - 3u] == 'l' && rel[name_len - 2u] == 'i' && rel[name_len - 1u] == 'b') {
        memcpy(suffix, "lib", 3);
        name_len -= 4u;
    } else if (name_len >= 3u && rel[name_len - 3u] == '.') {
        suffix[0] = rel[name_len - 2u];
        suffix[1] = rel[name_len - 1u];
        suffix[2] = '\0';
        name_len -= 3u;
    } else {
        return GR_ERROR_SHADER_INVALID;
    }

    {
        gr_str s;
        s.data = suffix;
        s.len = (uint32_t)strlen(suffix);
        s._pad = 0;
        if (gr_shader_stage_from_suffix(s, stage_out) != GR_OK)
            return GR_ERROR_SHADER_INVALID;
    }
    if (name_len == 0 || name_len >= name_cap)
        return GR_ERROR_SHADER_INVALID;
    memcpy(name_out, rel, name_len);
    name_out[name_len] = '\0';
    return GR_OK;
}

/* ---------------------------------------------------------------------------------------
 * Platform primitives. Everything else in this file is portable.
 * --------------------------------------------------------------------------------------- */
static gr_result lib_read_file(const char *path, uint8_t **out_data, size_t *out_len)
{
    FILE *file = fopen(path, "rb");
    long size;
    uint8_t *data;
    if (!file)
        return GR_ERROR_PERMUTATION_MISSING;
    if (fseek(file, 0, SEEK_END) != 0) { fclose(file); return GR_ERROR_BACKEND; }
    size = ftell(file);
    if (size <= 0) { fclose(file); return GR_ERROR_SHADER_INVALID; }
    if (fseek(file, 0, SEEK_SET) != 0) { fclose(file); return GR_ERROR_BACKEND; }
    data = (uint8_t *)malloc((size_t)size);
    if (!data) { fclose(file); return GR_ERROR_OUT_OF_MEMORY; }
    if (fread(data, 1, (size_t)size, file) != (size_t)size) {
        fclose(file); free(data); return GR_ERROR_BACKEND;
    }
    fclose(file);
    *out_data = data;
    *out_len = (size_t)size;
    return GR_OK;
}

/* Indexes one regular file if it is a *.refl.bin; `rel` is its path under the library root. */
static void lib_consider(gr_library *library, const char *path, char *rel, const char *name)
{
    size_t name_len = strlen(name);
    gr_lib_entry *entry;
    gr_shader_stage stage;
    uint64_t key;
    if (name_len <= 9u || strcmp(name + name_len - 9u, ".refl.bin") != 0)
        return;
    rel[strlen(rel) - 9u] = '\0'; /* strip ".refl.bin" */
    entry = &library->entries[library->entry_count];
    if (parse_name(rel, entry->name, sizeof(entry->name), &stage, &key) != GR_OK)
        return;
    entry->name_len = (uint32_t)strlen(entry->name);
    entry->stage = stage;
    entry->key = key;
    snprintf(entry->path, sizeof(entry->path), "%s", path);
    library->entry_count++;
}

static int lib_join(char *out, size_t cap, const char *a, const char *b)
{
    int n = a[0] ? snprintf(out, cap, "%s/%s", a, b) : snprintf(out, cap, "%s", b);
    return n >= 0 && (size_t)n < cap;
}

/* Walks `dir` under `rel_prefix`, appending every *.refl.bin. */
#if !defined(_WIN32)
static void lib_enumerate(gr_library *library, const char *dir, const char *rel_prefix,
                          unsigned depth)
{
    DIR *handle;
    struct dirent *item;

    if (depth > GR_LIB_MAX_DEPTH || library->entry_count >= GR_LIB_MAX_ENTRIES)
        return;
    handle = opendir(dir);
    if (!handle)
        return;
    while ((item = readdir(handle)) != NULL && library->entry_count < GR_LIB_MAX_ENTRIES) {
        char path[GR_LIB_PATH_MAX];
        char rel[GR_LIB_PATH_MAX];
        struct stat info;

        if (item->d_name[0] == '.')
            continue;
        if (!lib_join(path, sizeof(path), dir, item->d_name) ||
            !lib_join(rel, sizeof(rel), rel_prefix, item->d_name))
            continue;
        if (stat(path, &info) != 0)
            continue;
        if (S_ISDIR(info.st_mode))
            lib_enumerate(library, path, rel, depth + 1u);
        else
            lib_consider(library, path, rel, item->d_name);
    }
    closedir(handle);
}
#else
static void lib_enumerate(gr_library *library, const char *dir, const char *rel_prefix,
                          unsigned depth)
{
    char pattern[GR_LIB_PATH_MAX];
    WIN32_FIND_DATAA item;
    HANDLE handle;

    if (depth > GR_LIB_MAX_DEPTH || library->entry_count >= GR_LIB_MAX_ENTRIES)
        return;
    if (!lib_join(pattern, sizeof(pattern), dir, "*"))
        return;
    handle = FindFirstFileA(pattern, &item);
    if (handle == INVALID_HANDLE_VALUE)
        return;
    do {
        char path[GR_LIB_PATH_MAX];
        char rel[GR_LIB_PATH_MAX];
        if (item.cFileName[0] == '.')
            continue;
        if (!lib_join(path, sizeof(path), dir, item.cFileName) ||
            !lib_join(rel, sizeof(rel), rel_prefix, item.cFileName))
            continue;
        if (item.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
            lib_enumerate(library, path, rel, depth + 1u);
        else
            lib_consider(library, path, rel, item.cFileName);
    } while (library->entry_count < GR_LIB_MAX_ENTRIES && FindNextFileA(handle, &item));
    FindClose(handle);
}
#endif

/* ---------------------------------------------------------------------------------------
 * Index helpers
 * --------------------------------------------------------------------------------------- */
static int entry_compare(const void *lhs, const void *rhs)
{
    const gr_lib_entry *a = (const gr_lib_entry *)lhs;
    const gr_lib_entry *b = (const gr_lib_entry *)rhs;
    int by_name = strcmp(a->name, b->name);
    if (by_name != 0) return by_name;
    if (a->stage != b->stage) return a->stage < b->stage ? -1 : 1;
    if (a->key != b->key) return a->key < b->key ? -1 : 1;
    return 0;
}

static int name_matches(const gr_lib_entry *entry, gr_str name)
{
    if (!name.data)
        return 0;
    if ((size_t)name.len != strlen(entry->name))
        return 0;
    return memcmp(entry->name, name.data, name.len) == 0;
}

static int shader_exists(const gr_library *library, gr_str name, gr_shader_stage stage)
{
    uint32_t i;
    for (i = 0; i < library->entry_count; ++i)
        if (library->entries[i].stage == stage && name_matches(&library->entries[i], name))
            return 1;
    return 0;
}

static int find_entry(const gr_library *library, gr_str name, gr_shader_stage stage, uint64_t key)
{
    uint32_t i;
    for (i = 0; i < library->entry_count; ++i) {
        const gr_lib_entry *entry = &library->entries[i];
        if (entry->stage == stage && entry->key == key && name_matches(entry, name))
            return (int)i;
    }
    return -1;
}

static gr_lib_cache_slot *cache_find(gr_library *library, uint32_t entry)
{
    uint32_t i;
    for (i = 0; i < library->cache_used; ++i)
        if (library->cache[i].used && library->cache[i].entry == entry)
            return &library->cache[i];
    return NULL;
}

/* The sibling of an artifact: the same path with a different trailing suffix. */
static int sibling_path(const char *blob_path, const char *suffix, char *out, size_t cap)
{
    size_t len = strlen(blob_path);
    const char *tail = ".refl.bin";
    size_t tail_len = 9u;
    size_t keep;
    if (len <= tail_len || strcmp(blob_path + len - tail_len, tail) != 0)
        return 0;
    keep = len - tail_len;
    if (keep + strlen(suffix) + 1u > cap)
        return 0;
    memcpy(out, blob_path, keep);
    strcpy(out + keep, suffix);
    return 1;
}

/* ---------------------------------------------------------------------------------------
 * Public surface
 * --------------------------------------------------------------------------------------- */
gr_result gr_shader_library_open(const gr_shader_library_desc *desc, gr_handle *out_library)
{
    gr_library *library;
    gr_handle handle;
    uint32_t i;

    if (!desc || !out_library)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_library = GR_NULL_HANDLE;
    if (desc->head.size != sizeof(gr_shader_library_desc))
        return GR_ERROR_VERSION_MISMATCH;
    if (!desc->root.data || desc->root.len == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if (desc->root.len >= GR_LIB_PATH_MAX)
        return GR_ERROR_INVALID_ARGUMENT;

    library = (gr_library *)calloc(1, sizeof(*library));
    if (!library)
        return GR_ERROR_OUT_OF_MEMORY;
    memcpy(library->root, desc->root.data, desc->root.len);
    library->root[desc->root.len] = '\0';

    lib_enumerate(library, library->root, "", 0u);
    if (library->entry_count == 0) {
        /* An empty index is a build problem, not an empty-but-usable library: refusing here
         * means a mistaken root is reported once, at open, instead of as a hundred misses. */
        free(library);
        return GR_ERROR_PERMUTATION_MISSING;
    }
    qsort(library->entries, library->entry_count, sizeof(gr_lib_entry), entry_compare);
    /* Distinct (name, stage) pairs, which is how many shaders the library holds. */
    for (i = 0; i < library->entry_count; ++i) {
        if (i == 0 || library->entries[i].stage != library->entries[i - 1u].stage ||
            strcmp(library->entries[i].name, library->entries[i - 1u].name) != 0)
            library->shader_count++;
    }

    gr_objects_init_once();
    handle = gr_object_insert(gr_objects(), GR_HANDLE_SHADER_LIBRARY, library);
    if (handle == GR_NULL_HANDLE) {
        free(library);
        return GR_ERROR_OUT_OF_MEMORY;
    }
    *out_library = handle;
    return GR_OK;
}

void gr_shader_library_close(gr_handle library_handle)
{
    gr_library *library = (gr_library *)gr_object_remove(gr_objects(), library_handle,
                                                         GR_HANDLE_SHADER_LIBRARY);
    uint32_t i;
    if (!library)
        return;
    for (i = 0; i < library->cache_used; ++i) {
        free(library->cache[i].blob);
        free(library->cache[i].dxil);
        free(library->cache[i].msl);
    }
    free(library);
}

gr_result gr_shader_library_stats_query(gr_handle library_handle, gr_shader_library_stats *out)
{
    gr_library *library = (gr_library *)gr_object_lookup(gr_objects(), library_handle,
                                                         GR_HANDLE_SHADER_LIBRARY, NULL);
    if (!library || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (out->head.size != 0 && out->head.size < sizeof(gr_shader_library_stats))
        return GR_ERROR_VERSION_MISMATCH;
    memset(out, 0, sizeof(*out));
    out->head.size = (uint32_t)sizeof(*out);
    out->shader_count = library->shader_count;
    out->variant_count = library->entry_count;
    out->cache_capacity = GR_LIB_CACHE_SLOTS;
    out->cache_used = library->cache_used;
    out->cache_hits = library->hits;
    out->loads = library->loads;
    out->misses = library->misses;
    return GR_OK;
}

gr_result gr_shader_library_entries(gr_handle library_handle, uint32_t first, uint32_t count,
                                    gr_shader_entry *out, uint32_t *out_written)
{
    gr_library *library = (gr_library *)gr_object_lookup(gr_objects(), library_handle,
                                                         GR_HANDLE_SHADER_LIBRARY, NULL);
    uint32_t i;
    if (!library || !out || !out_written)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_written = 0;
    if (first > library->entry_count || count > library->entry_count - first)
        return GR_ERROR_INVALID_ARGUMENT;
    for (i = 0; i < count; ++i) {
        const gr_lib_entry *entry = &library->entries[first + i];
        out[i].name.data = entry->name;
        out[i].name.len = entry->name_len;
        out[i].name._pad = 0;
        out[i].stage = entry->stage;
        out[i].permutation_key = entry->key;
        (*out_written)++;
    }
    return GR_OK;
}

gr_result gr_shader_library_resolve(gr_handle library_handle, gr_str name, gr_shader_stage stage,
                                    uint64_t permutation_key, gr_resolved_shader *out)
{
    gr_library *library = (gr_library *)gr_object_lookup(gr_objects(), library_handle,
                                                         GR_HANDLE_SHADER_LIBRARY, NULL);
    gr_lib_cache_slot *slot;
    int entry_index;
    gr_result status;

    if (!library || !out)
        return GR_ERROR_INVALID_ARGUMENT;
    if (out->head.size != 0 && out->head.size < sizeof(gr_resolved_shader))
        return GR_ERROR_VERSION_MISMATCH;
    memset(out, 0, sizeof(*out));
    out->head.size = (uint32_t)sizeof(*out);
    out->stage = stage;
    out->permutation_key = permutation_key;
    if (!name.data || name.len == 0)
        return GR_ERROR_INVALID_ARGUMENT;
    if ((uint32_t)stage >= (uint32_t)GR_SHADER_STAGE_COUNT)
        return GR_ERROR_INVALID_ARGUMENT;

    /* An unknown shader and an unbuilt permutation are different failures and get different
     * statuses: the first is a typo in a builder, the second is a build that did not compile
     * the combination. Collapsing them into one code would make a missing permutation look like
     * a missing shader in every log. */
    if (!shader_exists(library, name, stage)) {
        library->misses++;
        return GR_ERROR_INVALID_ARGUMENT;
    }
    entry_index = find_entry(library, name, stage, permutation_key);
    if (entry_index < 0) {
        library->misses++;
        return GR_ERROR_PERMUTATION_MISSING;
    }

    slot = cache_find(library, (uint32_t)entry_index);
    if (slot) {
        library->hits++;
        out->blob.data = slot->blob;
        out->blob.len = (size_t)slot->blob_length;
        out->spirv.data = slot->blob + slot->reflection.header->bytecode_offset;
        out->spirv.len = (size_t)slot->reflection.header->bytecode_length;
        out->dxil.data = slot->dxil;
        out->dxil.len = (size_t)slot->dxil_length;
        out->msl_source.data = slot->msl;
        out->msl_source.len = (size_t)slot->msl_length;
        out->reflection = slot->reflection;
        out->frame_constants_size = slot->frame_constants_size;
        out->from_cache = 1;
        return GR_OK;
    }

    if (library->cache_used >= GR_LIB_CACHE_SLOTS) {
        /* Nothing is evicted: an eviction would invalidate spans a caller already holds. */
        library->misses++;
        return GR_ERROR_EXHAUSTED;
    }

    {
        uint8_t *blob = NULL;
        size_t blob_len = 0;
        gr_reflection reflection;
        uint32_t frame_size;

        status = lib_read_file(library->entries[entry_index].path, &blob, &blob_len);
        if (status != GR_OK) {
            library->misses++;
            return status;
        }
        status = gr_reflect_open((gr_span_u8){ blob, blob_len }, &reflection);
        if (status != GR_OK) {
            free(blob);
            library->misses++;
            return status;
        }
        /* The host's frame constants must be the shader's, or the renderer would read another
         * layout's memory as its own. Checked once, at load, not per draw. */
        frame_size = gr_reflect_frame_constants_size(&reflection);
        if (frame_size != 0 && frame_size != (uint32_t)sizeof(gr_frame_constants)) {
            free(blob);
            library->misses++;
            return GR_ERROR_LAYOUT_MISMATCH;
        }

        slot = &library->cache[library->cache_used++];
        slot->used = 1;
        slot->entry = (uint32_t)entry_index;
        slot->blob = blob;
        slot->blob_length = blob_len;
        slot->reflection = reflection;
        slot->frame_constants_size = frame_size;

        /* A missing sibling is normal, not an error: the same check is what a D3D12 host turns
         * into GR_ERROR_UNSUPPORTED when it asks for a container this build did not produce. */
        {
            char path[GR_LIB_PATH_MAX];
            uint8_t *data = NULL;
            size_t length = 0;
            if (sibling_path(library->entries[entry_index].path, ".dxil", path, sizeof(path)) &&
                lib_read_file(path, &data, &length) == GR_OK) {
                slot->dxil = data;
                slot->dxil_length = length;
            }
            data = NULL;
            if (sibling_path(library->entries[entry_index].path, ".msl", path, sizeof(path)) &&
                lib_read_file(path, &data, &length) == GR_OK) {
                slot->msl = data;
                slot->msl_length = length;
            }
        }
        library->loads++;

        out->blob.data = blob;
        out->blob.len = blob_len;
        out->spirv.data = blob + reflection.header->bytecode_offset;
        out->spirv.len = (size_t)reflection.header->bytecode_length;
        out->dxil.data = slot->dxil;
        out->dxil.len = (size_t)slot->dxil_length;
        out->msl_source.data = slot->msl;
        out->msl_source.len = (size_t)slot->msl_length;
        out->reflection = reflection;
        out->frame_constants_size = frame_size;
        out->from_cache = 0;
        return GR_OK;
    }
}

gr_result gr_shader_create_resolved(gr_handle device, gr_handle library, gr_str name,
                                    gr_shader_stage stage, uint64_t permutation_key,
                                    gr_handle *out_shader)
{
    gr_device_caps caps;
    gr_resolved_shader resolved;
    gr_shader_desc desc;
    gr_result status;

    if (!out_shader)
        return GR_ERROR_INVALID_ARGUMENT;
    *out_shader = GR_NULL_HANDLE;
    memset(&caps, 0, sizeof(caps));
    caps.head.size = (uint32_t)sizeof(caps);
    status = gr_device_get_caps(device, &caps);
    if (status != GR_OK)
        return status;

    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    status = gr_shader_library_resolve(library, name, stage, permutation_key, &resolved);
    if (status != GR_OK)
        return status;

    /* The container the device actually consumes. A device that wants DXIL and a library that
     * holds only SPIR-V is UNSUPPORTED here, not a surprise at pipeline creation. */
    memset(&desc, 0, sizeof(desc));
    desc.head.size = (uint32_t)sizeof(desc);
    desc.name = name;
    desc.permutation_key = permutation_key;
    desc.reflection_blob = resolved.blob;
    switch (caps.backend) {
    case GR_BACKEND_D3D12:
        if (resolved.dxil.len == 0)
            return GR_ERROR_UNSUPPORTED; /* this build produced no DXIL for that variant */
        desc.dxil = resolved.dxil;
        break;
    case GR_BACKEND_METAL:
        if (resolved.msl_source.len == 0)
            return GR_ERROR_UNSUPPORTED;
        desc.msl_source = resolved.msl_source;
        break;
    case GR_BACKEND_VULKAN:
    case GR_BACKEND_NULL:
    default:
        if (resolved.spirv.len == 0)
            return GR_ERROR_UNSUPPORTED;
        desc.spirv = resolved.spirv;
        break;
    }
    return gr_shader_create(device, &desc, out_shader);
}
