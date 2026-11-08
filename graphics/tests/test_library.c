/* test_library.c - the permutation-key -> bytecode path.
 *
 * Fixtures are written by this file rather than by the shader tool, so the test needs no DXC and
 * can construct exactly the cases that matter: a key that exists, a key that does not, a blob
 * whose frame constants disagree with the host, and a cache that fills. The blob writer here is
 * also a second, independent encoder of the format (the first is graphics/tools/shader.mjs).
 */
/* mkdtemp is POSIX 2008; -std=c11 alone hides it. */
#define _POSIX_C_SOURCE 200809L

#include "../include/grail/grail_bindless.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_shader.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int failures = 0;
static int checks = 0;

#define CHECK(cond)                                                                   \
    do {                                                                              \
        checks++;                                                                     \
        if (!(cond)) {                                                                \
            failures++;                                                               \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);           \
        }                                                                             \
    } while (0)

#define CHECK_EQ(a, b)                                                                \
    do {                                                                              \
        checks++;                                                                     \
        if ((a) != (b)) {                                                             \
            failures++;                                                               \
            fprintf(stderr, "FAIL %s:%d: %s == %s (%lld != %lld)\n", __FILE__,        \
                    __LINE__, #a, #b, (long long)(a), (long long)(b));                \
        }                                                                             \
    } while (0)

/* ---------------------------------------------------------------------------------------
 * A minimal, valid reflection blob. bytecode_len bytes of filler stand in for the SPIR-V;
 * `frame_constants` of 0 declares no set 1 block at all.
 * --------------------------------------------------------------------------------------- */
typedef struct writer {
    uint8_t *data;
    size_t capacity;
    size_t size;
    uint32_t strings;
    size_t string_start;
} writer;

static uint32_t w_str(writer *w, const char *text)
{
    uint32_t offset = (uint32_t)(w->size - w->string_start);
    size_t len = strlen(text);
    memcpy(w->data + w->size, text, len + 1u);
    w->size += len + 1u;
    return offset;
}

static void w_u32(writer *w, size_t at, uint32_t value) { memcpy(w->data + at, &value, 4); }
static void w_u16(writer *w, size_t at, uint16_t value) { memcpy(w->data + at, &value, 2); }
static void w_u64(writer *w, size_t at, uint64_t value) { memcpy(w->data + at, &value, 8); }

static size_t build_blob(uint8_t *out, size_t capacity, gr_shader_stage stage,
                         uint32_t bytecode_len, uint32_t frame_constants)
{
    writer w;
    size_t header = 136, bc_off, str_off, str_len, b_off, m_off, s_off;
    uint32_t entry, source, compiler, flags, bname, btype, mname, mtype;
    size_t at;

    memset(&w, 0, sizeof(w));
    w.data = out;
    w.capacity = capacity;
    w.size = 0;

    /* Header placeholder: fields are written below once the offsets are known. */
    memset(out, 0, header);
    w.size = header;

    /* Bytecode: filler, 4-aligned, non-zero length. */
    bc_off = w.size;
    memset(out + w.size, 0x5A, bytecode_len);
    w.size += bytecode_len;

    /* String section. */
    while (w.size % 4u) out[w.size++] = 0;
    w.string_start = w.size;
    w.size += 1; /* offset 0 is the empty string, never a wild pointer */
    out[w.string_start] = 0;
    entry = w_str(&w, "main");
    source = w_str(&w, "test/synthetic.hlsl");
    compiler = w_str(&w, "test-encoder");
    flags = w_str(&w, "-T test");
    bname = w_str(&w, "block");
    btype = w_str(&w, "struct");
    mname = w_str(&w, "block.m0");
    mtype = w_str(&w, "float4");
    str_off = w.string_start;
    str_len = w.size - w.string_start;

    /* Bindings: one set 1 / binding 0 uniform block when frame_constants != 0. */
    while (w.size % 4u) out[w.size++] = 0;
    b_off = w.size;
    if (frame_constants != 0) {
        at = w.size;
        w_u16(&w, at + 0, 1);        /* set */
        w_u16(&w, at + 2, 0);        /* binding */
        w_u16(&w, at + 4, 4);        /* kind: uniform buffer */
        w_u16(&w, at + 6, 1);        /* array size */
        w_u32(&w, at + 8, bname);
        w_u32(&w, at + 12, btype);
        w_u32(&w, at + 16, 1u << (uint32_t)stage);
        w_u32(&w, at + 20, 0);       /* member_first */
        w_u32(&w, at + 24, 1);       /* member_count */
        w.size += 32;
    }

    /* Members: one record whose size is the declared block size. */
    m_off = w.size;
    if (frame_constants != 0) {
        at = w.size;
        w_u32(&w, at + 0, mname);
        w_u32(&w, at + 4, mtype);
        w_u32(&w, at + 8, 0);              /* offset */
        w_u32(&w, at + 12, frame_constants); /* size */
        w_u16(&w, at + 16, 12);            /* kind: struct */
        w_u16(&w, at + 18, 1);             /* array size */
        w_u16(&w, at + 20, 0);             /* row-major */
        w.size += 24;
    }

    /* Stage record. */
    while (w.size % 4u) out[w.size++] = 0;
    s_off = w.size;
    at = w.size;
    w_u16(&w, at + 0, (uint16_t)stage);
    w_u32(&w, at + 4, 1);
    w_u32(&w, at + 8, 1);
    w_u32(&w, at + 12, 1);
    w_u32(&w, at + 28, 0);   /* push_constant_offset */
    w_u32(&w, at + 32, 0);   /* push_constant_size */
    w.size += 44;

    /* Header. */
    w_u32(&w, 0, 0x46455247u);
    w_u16(&w, 4, 1);
    w_u16(&w, 6, (uint16_t)header);
    w_u32(&w, 8, 0);                 /* container: SPIR-V */
    w_u32(&w, 12, (uint32_t)stage);
    w_u32(&w, 16, 0);
    w_u64(&w, 24, (uint64_t)w.size);
    w_u64(&w, 32, (uint64_t)bc_off);
    w_u64(&w, 40, (uint64_t)bytecode_len);
    w_u32(&w, 48, entry);
    w_u32(&w, 52, source);
    w_u32(&w, 56, compiler);
    w_u32(&w, 60, flags);
    w_u32(&w, 64, (uint32_t)str_off);
    w_u32(&w, 68, (uint32_t)str_len);
    w_u32(&w, 72, (uint32_t)b_off);
    w_u32(&w, 76, frame_constants ? 1u : 0u);
    w_u32(&w, 80, (uint32_t)m_off);
    w_u32(&w, 84, frame_constants ? 1u : 0u);
    w_u32(&w, 88, 0);   /* vertices */
    w_u32(&w, 92, 0);
    w_u32(&w, 96, (uint32_t)s_off);
    w_u32(&w, 100, 1);
    w_u32(&w, 104, (uint32_t)w.size); /* defines come after; none */
    w_u32(&w, 108, 0);
    return w.size;
}

static char scratch[256];

static int write_artifact(const char *name, const char *key_suffix, gr_shader_stage stage,
                          uint32_t bytecode_len, uint32_t frame_constants)
{
    uint8_t blob[8192];
    size_t size = build_blob(blob, sizeof(blob), stage, bytecode_len, frame_constants);
    char path[512];
    FILE *file;
    snprintf(path, sizeof(path), "%s/%s%s.refl.bin", scratch, name, key_suffix);
    file = fopen(path, "wb");
    if (!file)
        return 0;
    fwrite(blob, 1, size, file);
    fclose(file);
    return 1;
}

static gr_handle open_library(void)
{
    gr_shader_library_desc desc;
    gr_handle library = GR_NULL_HANDLE;
    memset(&desc, 0, sizeof(desc));
    desc.head.size = (uint32_t)sizeof(desc);
    desc.root.data = scratch;
    desc.root.len = (uint32_t)strlen(scratch);
    if (gr_shader_library_open(&desc, &library) != GR_OK)
        return GR_NULL_HANDLE;
    return library;
}

static void test_resolution(void)
{
    gr_handle library;
    gr_shader_library_stats stats;
    gr_resolved_shader resolved;
    gr_str name = { "tonemap", 7, 0 };
    gr_str missing_name = { "nosuchshader", 12, 0 };

    strcpy(scratch, "/tmp/grail-lib-XXXXXX");
    if (!mkdtemp(scratch)) { CHECK(0); return; }

    /* Two shaders, four variants: tonemap at keys 0, A, B and fullscreen at key 0. */
    CHECK(write_artifact("tonemap.ps", "", GR_SHADER_STAGE_FRAGMENT, 64, 0));
    CHECK(write_artifact("tonemap.ps", ".1111111111111111", GR_SHADER_STAGE_FRAGMENT, 128, 0));
    CHECK(write_artifact("tonemap.ps", ".2222222222222222", GR_SHADER_STAGE_FRAGMENT, 192, 0));
    CHECK(write_artifact("fullscreen.vs", "", GR_SHADER_STAGE_VERTEX, 32, 0));

    library = open_library();
    CHECK(library != GR_NULL_HANDLE);
    if (library == GR_NULL_HANDLE) return;

    memset(&stats, 0, sizeof(stats));
    stats.head.size = (uint32_t)sizeof(stats);
    CHECK_EQ(gr_shader_library_stats_query(library, &stats), GR_OK);
    CHECK_EQ(stats.shader_count, 2u);
    CHECK_EQ(stats.variant_count, 4u);
    CHECK_EQ(stats.cache_capacity, 32u);
    CHECK_EQ(stats.cache_used, 0u);

    /* The index is enumerable and sorted by name, then stage, then key. */
    {
        gr_shader_entry entries[8];
        uint32_t written = 0;
        CHECK_EQ(gr_shader_library_entries(library, 0, 4, entries, &written), GR_OK);
        CHECK_EQ(written, 4u);
        CHECK_EQ(entries[0].stage, GR_SHADER_STAGE_VERTEX); /* "fullscreen" < "tonemap" */
        CHECK_EQ(entries[0].permutation_key, 0u);
        CHECK_EQ(entries[1].permutation_key, 0u);
        CHECK_EQ(entries[2].permutation_key, 0x1111111111111111ull);
        CHECK_EQ(entries[3].permutation_key, 0x2222222222222222ull);
    }

    /* First resolve loads from disk; the second is a cache hit returning the same bytes. */
    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT, 0, &resolved), GR_OK);
    CHECK_EQ(resolved.from_cache, 0u);
    CHECK_EQ(resolved.spirv.len, 64u);
    CHECK_EQ(resolved.stage, GR_SHADER_STAGE_FRAGMENT);
    CHECK_EQ(resolved.permutation_key, 0u);
    {
        const uint8_t *first = resolved.spirv.data;
        gr_resolved_shader again;
        memset(&again, 0, sizeof(again));
        again.head.size = (uint32_t)sizeof(again);
        CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT, 0, &again), GR_OK);
        CHECK_EQ(again.from_cache, 1u);
        CHECK(again.spirv.data == first);          /* the same buffer, not a copy */
        CHECK_EQ(again.spirv.len, 64u);
    }

    /* A different key is a different bytecode, and is loaded separately. */
    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT,
                                       0x1111111111111111ull, &resolved), GR_OK);
    CHECK_EQ(resolved.from_cache, 0u);
    CHECK_EQ(resolved.spirv.len, 128u);

    /* A key that was never compiled is PERMUTATION_MISSING, not INVALID_ARGUMENT: the shader
     * exists, so the message must not blame the name. */
    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT,
                                       0x3333333333333333ull, &resolved),
             GR_ERROR_PERMUTATION_MISSING);
    CHECK_EQ(resolved.spirv.len, 0u);

    /* A miss must not evict or corrupt what is cached: the first key still hits. */
    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT, 0, &resolved), GR_OK);
    CHECK_EQ(resolved.from_cache, 1u);

    /* An unknown shader, and a known shader at the wrong stage, are both INVALID_ARGUMENT. */
    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, missing_name, GR_SHADER_STAGE_FRAGMENT, 0, &resolved),
             GR_ERROR_INVALID_ARGUMENT);
    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_VERTEX, 0, &resolved),
             GR_ERROR_INVALID_ARGUMENT);

    memset(&stats, 0, sizeof(stats));
    stats.head.size = (uint32_t)sizeof(stats);
    CHECK_EQ(gr_shader_library_stats_query(library, &stats), GR_OK);
    CHECK_EQ(stats.loads, 2u);   /* key 0 and key 1 */
    CHECK_EQ(stats.cache_hits, 2u);
    CHECK_EQ(stats.misses, 3u);  /* one missing key, one unknown shader, one wrong stage */

    gr_shader_library_close(library);
}

static void test_cache_exhaustion(void)
{
    gr_handle library;
    gr_shader_library_stats stats;
    gr_str name = { "tonemap", 7, 0 };
    uint32_t i;
    int saw_exhausted = 0;

    strcpy(scratch, "/tmp/grail-lib-cap-XXXXXX");
    if (!mkdtemp(scratch)) { CHECK(0); return; }
    CHECK(write_artifact("tonemap.ps", "", GR_SHADER_STAGE_FRAGMENT, 64, 0));
    /* More variants than the cache holds, so the last resolves must refuse rather than evict. */
    for (i = 1; i <= 40u; ++i) {
        char suffix[32];
        snprintf(suffix, sizeof(suffix), ".%016x", i * 0x1111u);
        if (!write_artifact("tonemap.ps", suffix, GR_SHADER_STAGE_FRAGMENT, 64u + i * 4u, 0)) {
            CHECK(0);
            return;
        }
    }
    library = open_library();
    CHECK(library != GR_NULL_HANDLE);
    if (library == GR_NULL_HANDLE) return;

    for (i = 1; i <= 40u; ++i) {
        gr_resolved_shader resolved;
        gr_result status;
        memset(&resolved, 0, sizeof(resolved));
        resolved.head.size = (uint32_t)sizeof(resolved);
        status = gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT,
                                          (uint64_t)i * 0x1111u, &resolved);
        if (status == GR_ERROR_EXHAUSTED) { saw_exhausted = 1; break; }
        CHECK_EQ(status, GR_OK);
    }
    CHECK(saw_exhausted);

    memset(&stats, 0, sizeof(stats));
    stats.head.size = (uint32_t)sizeof(stats);
    CHECK_EQ(gr_shader_library_stats_query(library, &stats), GR_OK);
    CHECK_EQ(stats.cache_used, stats.cache_capacity);

    /* Nothing was evicted: an entry loaded before the cache filled still hits. */
    {
        gr_resolved_shader resolved;
        memset(&resolved, 0, sizeof(resolved));
        resolved.head.size = (uint32_t)sizeof(resolved);
        CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT, 0x1111ull,
                                           &resolved), GR_OK);
        CHECK_EQ(resolved.from_cache, 1u);
    }

    gr_shader_library_close(library);
}

static void test_layout_mismatch(void)
{
    gr_handle library;
    gr_str name = { "tonemap", 7, 0 };
    gr_resolved_shader resolved;

    strcpy(scratch, "/tmp/grail-lib-layout-XXXXXX");
    if (!mkdtemp(scratch)) { CHECK(0); return; }
    /* A block of the wrong size: the host's gr_frame_constants is 416 bytes. */
    CHECK(write_artifact("tonemap.ps", "", GR_SHADER_STAGE_FRAGMENT, 64, 400));
    library = open_library();
    CHECK(library != GR_NULL_HANDLE);
    if (library == GR_NULL_HANDLE) return;

    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT, 0, &resolved),
             GR_ERROR_LAYOUT_MISMATCH);
    gr_shader_library_close(library);

    /* And the correct size is accepted, so the check is not rejecting everything. */
    strcpy(scratch, "/tmp/grail-lib-layout2-XXXXXX");
    if (!mkdtemp(scratch)) { CHECK(0); return; }
    CHECK(write_artifact("tonemap.ps", "", GR_SHADER_STAGE_FRAGMENT, 64, 416));
    library = open_library();
    CHECK(library != GR_NULL_HANDLE);
    if (library == GR_NULL_HANDLE) return;
    memset(&resolved, 0, sizeof(resolved));
    resolved.head.size = (uint32_t)sizeof(resolved);
    CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT, 0, &resolved), GR_OK);
    CHECK_EQ(resolved.frame_constants_size, 416u);
    gr_shader_library_close(library);
}

static void test_empty_and_resolved_shader(void)
{
    gr_shader_library_desc desc;
    gr_handle library = GR_NULL_HANDLE;
    gr_handle device = GR_NULL_HANDLE;
    gr_device_desc dd;
    gr_str name = { "tonemap", 7, 0 };

    strcpy(scratch, "/tmp/grail-lib-empty-XXXXXX");
    if (!mkdtemp(scratch)) { CHECK(0); return; }
    /* An empty root is a build mistake, reported at open rather than as a hundred misses. */
    memset(&desc, 0, sizeof(desc));
    desc.head.size = (uint32_t)sizeof(desc);
    desc.root.data = scratch;
    desc.root.len = (uint32_t)strlen(scratch);
    CHECK_EQ(gr_shader_library_open(&desc, &library), GR_ERROR_PERMUTATION_MISSING);
    CHECK(gr_handle_is_null(library));

    CHECK(write_artifact("tonemap.ps", "", GR_SHADER_STAGE_FRAGMENT, 64, 416));
    CHECK(write_artifact("tonemap.ps", ".00000000000000ab", GR_SHADER_STAGE_FRAGMENT, 96, 416));
    /* A vertex stage at the same key, so a coherent graphics pipeline can be built. */
    CHECK(write_artifact("fullscreen.vs", ".00000000000000ab", GR_SHADER_STAGE_VERTEX, 32, 0));
    library = open_library();
    CHECK(library != GR_NULL_HANDLE);
    if (library == GR_NULL_HANDLE) return;

    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_NULL;
    dd.flags = GR_DEVICE_HEADLESS;
    CHECK_EQ(gr_device_create(&dd, &device), GR_OK);

    /* The whole pipeline-side path: a name, a stage and a key become a shader handle. */
    {
        gr_handle fragment = GR_NULL_HANDLE;
        gr_handle vertex = GR_NULL_HANDLE;
        gr_str vertex_name = { "fullscreen", 10, 0 };
        gr_vertex_binding binding;
        gr_vertex_attribute attribute;
        gr_format color_format = GR_FORMAT_R8G8B8A8_UNORM;

        CHECK_EQ(gr_shader_create_resolved(device, library, name, GR_SHADER_STAGE_FRAGMENT,
                                           0xabull, &fragment), GR_OK);
        CHECK(fragment != GR_NULL_HANDLE);
        CHECK_EQ(gr_shader_create_resolved(device, library, vertex_name, GR_SHADER_STAGE_VERTEX,
                                           0xabull, &vertex), GR_OK);
        CHECK(vertex != GR_NULL_HANDLE);

        memset(&binding, 0, sizeof(binding));
        binding.slot = 0;
        binding.stride = 16;
        memset(&attribute, 0, sizeof(attribute));
        attribute.location = 0;
        attribute.binding = 0;
        attribute.format = GR_FORMAT_R32G32B32A32_FLOAT;
        attribute.offset = 0;

        /* A pipeline may not mix permutations: the descriptor's key is enforced against every
         * shader it names. */
        {
            gr_pipeline_desc pipeline;
            gr_handle out = GR_NULL_HANDLE;
            memset(&pipeline, 0, sizeof(pipeline));
            pipeline.head.size = (uint32_t)sizeof(pipeline);
            pipeline.name = (gr_str){ "bad mix", 7, 0 };
            pipeline.shaders[GR_SHADER_STAGE_VERTEX] = vertex;     /* built at key 0xab */
            pipeline.shaders[GR_SHADER_STAGE_FRAGMENT] = fragment; /* built at key 0xab */
            pipeline.vertex_bindings = &binding;
            pipeline.vertex_binding_count = 1;
            pipeline.vertex_attributes = &attribute;
            pipeline.vertex_attribute_count = 1;
            pipeline.color_formats = &color_format;
            pipeline.color_count = 1;
            pipeline.depth_format = GR_FORMAT_D32_FLOAT;
            pipeline.topology = GR_TOPOLOGY_TRIANGLE_LIST;
            pipeline.cull = GR_CULL_BACK;
            pipeline.depth_compare = GR_COMPARE_GREATER_EQUAL;
            pipeline.samples = 1;

            pipeline.permutation_key = 0xcdull; /* declared differently from every shader */
            CHECK_EQ(gr_pipeline_create(device, &pipeline, &out), GR_ERROR_INVALID_ARGUMENT);
            pipeline.permutation_key = 0xabull; /* matching: accepted */
            CHECK_EQ(gr_pipeline_create(device, &pipeline, &out), GR_OK);
        }
    }
    /* A key that was not compiled is refused at the shader boundary too. */
    {
        gr_handle shader = GR_NULL_HANDLE;
        CHECK_EQ(gr_shader_create_resolved(device, library, name, GR_SHADER_STAGE_FRAGMENT,
                                           0xffffull, &shader), GR_ERROR_PERMUTATION_MISSING);
        CHECK(gr_handle_is_null(shader));
    }

    gr_device_destroy(device);
    gr_shader_library_close(library);
}

/* Resolves artifacts the shader tool actually produced, when a path is given. This is the
 * integration half: the fixtures above prove the library's logic, this proves the naming the
 * tool writes and the naming the library parses are the same convention. */
static void test_real_artifacts(const char *root)
{
    gr_shader_library_desc desc;
    gr_handle library = GR_NULL_HANDLE;
    gr_shader_library_stats stats;
    gr_shader_entry entries[64];
    uint32_t written = 0, i, tonemap_variants = 0;
    uint64_t keys[64];
    gr_str name = { "core/tonemap", 12, 0 };

    memset(&desc, 0, sizeof(desc));
    desc.head.size = (uint32_t)sizeof(desc);
    desc.root.data = root;
    desc.root.len = (uint32_t)strlen(root);
    CHECK_EQ(gr_shader_library_open(&desc, &library), GR_OK);
    if (library == GR_NULL_HANDLE)
        return;

    memset(&stats, 0, sizeof(stats));
    stats.head.size = (uint32_t)sizeof(stats);
    CHECK_EQ(gr_shader_library_stats_query(library, &stats), GR_OK);
    printf("library: %u shaders, %u variants in %s\n", stats.shader_count, stats.variant_count, root);

    CHECK_EQ(gr_shader_library_entries(library, 0, stats.variant_count, entries, &written), GR_OK);
    for (i = 0; i < written; ++i) {
        if (entries[i].stage == GR_SHADER_STAGE_FRAGMENT && entries[i].name.len == name.len &&
            memcmp(entries[i].name.data, name.data, name.len) == 0) {
            if (tonemap_variants < 64)
                keys[tonemap_variants] = entries[i].permutation_key;
            tonemap_variants++;
        }
    }
    /* The base build plus the four declared combinations of the two tonemap domains. */
    CHECK_EQ(tonemap_variants, 5u);

    /* Every variant resolves, the real shader's frame-constant block is the host's 416 bytes, and
     * the programs are the four distinct permutations. */
    {
        uint64_t digests[64];
        uint32_t distinct = 0;
        for (i = 0; i < tonemap_variants && i < 64u; ++i) {
            gr_resolved_shader resolved;
            uint64_t digest = 0xcbf29ce484222325ull;
            size_t b;
            uint32_t j;
            int duplicate = 0;

            memset(&resolved, 0, sizeof(resolved));
            resolved.head.size = (uint32_t)sizeof(resolved);
            CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT, keys[i],
                                               &resolved), GR_OK);
            CHECK_EQ(resolved.frame_constants_size, 416u);
            CHECK(resolved.spirv.len > 0u);
            for (b = 0; b < resolved.spirv.len; ++b) {
                digest ^= resolved.spirv.data[b];
                digest *= 0x100000001b3ull;
            }
            for (j = 0; j < distinct; ++j)
                if (digests[j] == digest) duplicate = 1;
            if (!duplicate)
                digests[distinct++] = digest;
        }
        /* Five artifacts hold four programs: the no-flags build IS the declared default
         * combination, so its bytecode matches that variant's exactly. Asserting 4 rather than 5
         * is what records that the directive defaults and the #ifndef defaults agree, on real
         * compiler output rather than on a fixture. */
        CHECK_EQ(tonemap_variants, 5u);
        CHECK_EQ(distinct, 4u);
    }

    /* A key the tool never built is a miss, on real artifacts as well. */
    {
        gr_resolved_shader resolved;
        memset(&resolved, 0, sizeof(resolved));
        resolved.head.size = (uint32_t)sizeof(resolved);
        CHECK_EQ(gr_shader_library_resolve(library, name, GR_SHADER_STAGE_FRAGMENT,
                                           0xdeadbeefdeadbeefull, &resolved),
                 GR_ERROR_PERMUTATION_MISSING);
    }
    gr_shader_library_close(library);
}

int main(int argc, char **argv)
{
    test_resolution();
    test_cache_exhaustion();
    test_layout_mismatch();
    test_empty_and_resolved_shader();
    if (argc > 1)
        test_real_artifacts(argv[1]);
    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("library: %d checks passed\n", checks);
    return 0;
}
