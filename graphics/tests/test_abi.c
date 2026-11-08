/* test_abi.c - the ABI's own invariants: version, handle encoding, staleness, the object
 * table, format facts and the wire framing. No GPU, no window, no files. */
#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_bindless.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_shader.h"
#include "../include/grail/grail_window.h"
#include "../include/grail/grail_wire.h"
/* Included for the compiler, not for the tests: a header no translation unit includes is a
 * header whose declarations are never checked. Two were in that state until a collision between
 * a typedef and a function name in grail_backend_vulkan.h surfaced during the Vulkan probe. */
#include "../include/grail/grail_backend_vulkan.h"
#include "../include/grail/grail_backend_d3d12.h"
#include "../include/grail/grail_backend_metal.h"

#include <stdio.h>
#include <string.h>

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
            fprintf(stderr, "FAIL %s:%d: %s == %s (%llu != %llu)\n", __FILE__,        \
                    __LINE__, #a, #b, (unsigned long long)(a),                        \
                    (unsigned long long)(b));                                         \
        }                                                                             \
    } while (0)

static void test_version(void)
{
    gr_version v = gr_abi_version();
    CHECK_EQ(v.major, GR_ABI_VERSION_MAJOR);
    CHECK_EQ(v.minor, GR_ABI_VERSION_MINOR);
    CHECK_EQ(gr_abi_check(v), GR_OK);
    /* A caller from a different major is refused; a caller that needs a newer minor is
     * refused; a caller that needs an older minor is accepted. */
    v.major = (uint16_t)(GR_ABI_VERSION_MAJOR + 1u);
    v.minor = 0;
    CHECK_EQ(gr_abi_check(v), GR_ERROR_VERSION_MISMATCH);
    v.major = GR_ABI_VERSION_MAJOR;
    v.minor = (uint16_t)(GR_ABI_VERSION_MINOR + 1u);
    CHECK_EQ(gr_abi_check(v), GR_ERROR_VERSION_MISMATCH);
}

static void test_handles(void)
{
    gr_handle h = gr_handle_make(1234u, 7u, GR_HANDLE_BUFFER);
    CHECK_EQ(gr_handle_index(h), 1234u);
    CHECK_EQ(gr_handle_generation(h), 7u);
    CHECK_EQ(gr_handle_tag(h), (uint32_t)GR_HANDLE_BUFFER);
    CHECK(gr_handle_has_type(h, GR_HANDLE_BUFFER));
    CHECK(!gr_handle_has_type(h, GR_HANDLE_TEXTURE));
    CHECK(!gr_handle_is_null(h));
    /* Type and generation live in different bits and cannot alias the index. */
    CHECK_EQ(gr_handle_make(0u, 0u, GR_HANDLE_DEVICE) & 0xFFFFFFFFull, 0ull);
    CHECK(gr_handle_make(0u, 0u, GR_HANDLE_DEVICE) != GR_NULL_HANDLE);
    /* The tag field is 16 bits: a type above it cannot be encoded. */
    CHECK_EQ(gr_handle_tag(gr_handle_make(0u, 0u, 0xFFFFu)), 0xFFFFu);
}

static void test_struct_sizes(void)
{
    /* The sizes the wire protocol and the shader layout depend on. A change here is an ABI
     * change and must bump the version. */
    CHECK_EQ(sizeof(gr_frame_constants) % 16u, 0u);
    CHECK_EQ(sizeof(gr_frame_constants), 416u);
    CHECK_EQ(sizeof(gr_wire_packet), GR_WIRE_HEADER_SIZE);
    CHECK(sizeof(gr_event) >= 48u);
    CHECK_EQ(sizeof(gr_handle), 8u);
    CHECK_EQ(sizeof(gr_bindless_index), 4u);
    /* The frame constants' own field offsets, which the HLSL mirror must reproduce. */
    CHECK_EQ(offsetof(gr_frame_constants, view), 0u);
    CHECK_EQ(offsetof(gr_frame_constants, proj), 64u);
    CHECK_EQ(offsetof(gr_frame_constants, inv_view_proj), 192u);
    CHECK_EQ(offsetof(gr_frame_constants, origin), 256u);
    CHECK_EQ(offsetof(gr_frame_constants, jitter), 352u);
    CHECK_EQ(offsetof(gr_frame_constants, exposure), 368u);
    CHECK_EQ(offsetof(gr_frame_constants, frame_index), 384u);
    CHECK_EQ(offsetof(gr_frame_constants, version), 396u);
    CHECK_EQ(offsetof(gr_frame_constants, light_count), 400u);
}

static void test_formats(void)
{
    CHECK_EQ(gr_format_bytes_per_block(GR_FORMAT_R8G8B8A8_UNORM), 4u);
    CHECK_EQ(gr_format_bytes_per_block(GR_FORMAT_R16G16B16A16_FLOAT), 8u);
    CHECK_EQ(gr_format_bytes_per_block(GR_FORMAT_BC7_UNORM), 16u);
    CHECK_EQ(gr_format_bytes_per_block(GR_FORMAT_D32_FLOAT), 4u);
    CHECK_EQ(gr_format_bytes_per_block(GR_FORMAT_UNDEFINED), 0u);
    {
        uint32_t w = 0, h = 0;
        gr_format_block_extent(GR_FORMAT_BC7_UNORM, &w, &h);
        CHECK_EQ(w, 4u);
        CHECK_EQ(h, 4u);
        gr_format_block_extent(GR_FORMAT_R32G32B32A32_FLOAT, &w, &h);
        CHECK_EQ(w, 1u);
        CHECK_EQ(h, 1u);
    }
    CHECK_EQ(gr_format_class_of(GR_FORMAT_D32_FLOAT), GR_FORMAT_CLASS_DEPTH);
    CHECK_EQ(gr_format_class_of(GR_FORMAT_D32_FLOAT_S8_UINT), GR_FORMAT_CLASS_DEPTH_STENCIL);
    CHECK_EQ(gr_format_class_of(GR_FORMAT_R8G8B8A8_SRGB), GR_FORMAT_CLASS_COLOR);
    CHECK(gr_format_is_hdr(GR_FORMAT_R16G16B16A16_FLOAT));
    CHECK(!gr_format_is_hdr(GR_FORMAT_R8G8B8A8_UNORM));
    CHECK_EQ(gr_format_to_srgb(GR_FORMAT_R8G8B8A8_UNORM), GR_FORMAT_R8G8B8A8_SRGB);
    CHECK_EQ(gr_format_to_linear(GR_FORMAT_R8G8B8A8_SRGB), GR_FORMAT_R8G8B8A8_UNORM);
    CHECK_EQ(gr_format_to_srgb(GR_FORMAT_D32_FLOAT), GR_FORMAT_D32_FLOAT);
}

static void test_stage_suffix(void)
{
    gr_shader_stage stage;
    CHECK_EQ(gr_shader_stage_from_suffix((gr_str)GR_STR("vs"), &stage), GR_OK);
    CHECK_EQ(stage, GR_SHADER_STAGE_VERTEX);
    CHECK_EQ(gr_shader_stage_from_suffix((gr_str)GR_STR("cs"), &stage), GR_OK);
    CHECK_EQ(stage, GR_SHADER_STAGE_COMPUTE);
    CHECK_EQ(gr_shader_stage_from_suffix((gr_str)GR_STR("lib"), &stage), GR_OK);
    CHECK_EQ(stage, GR_SHADER_STAGE_LIBRARY);
    CHECK_EQ(gr_shader_stage_from_suffix((gr_str)GR_STR("xx"), &stage), GR_ERROR_INVALID_ARGUMENT);
    /* The suffix of a stage round-trips, which is what makes a file name authoritative. */
    CHECK(strcmp(gr_shader_stage_suffix(GR_SHADER_STAGE_MESH), "ms") == 0);
    CHECK(strcmp(gr_shader_stage_suffix(GR_SHADER_STAGE_TASK), "as") == 0);
}

static void test_permutation_key(void)
{
    gr_permutation a, b;
    uint32_t i;
    memset(&a, 0, sizeof(a));
    memset(&b, 0, sizeof(b));
    a.count = 3;
    a.entries[0].name = 10; a.entries[0].value = 1;
    a.entries[1].name = 20; a.entries[1].value = 2;
    a.entries[2].name = 30; a.entries[2].value = 3;
    /* The same pairs in a different order must hash identically: a cache keyed by this
     * cannot miss because a caller enumerated its defines in another order. */
    b.count = 3;
    b.entries[0].name = 30; b.entries[0].value = 3;
    b.entries[1].name = 10; b.entries[1].value = 1;
    b.entries[2].name = 20; b.entries[2].value = 2;
    CHECK(gr_permutation_key(&a) == gr_permutation_key(&b));
    /* A changed value must differ. */
    b.entries[2].value = 4;
    CHECK(gr_permutation_key(&a) != gr_permutation_key(&b));
    CHECK(gr_pipeline_cache_key(gr_permutation_key(&a), 0x1234u) != gr_permutation_key(&a));
    for (i = 0; i < 8; ++i)
        CHECK(gr_permutation_key(&a) == gr_permutation_key(&a));
}

static void test_bytes_span(void)
{
    {
        /* GR_STR is a brace initialiser, not an expression, so it is bound to a variable
         * before inspection. */
        gr_str abc = GR_STR("abc");
        CHECK_EQ(abc.len, 3u);
        CHECK_EQ(abc.data[0], 'a');
    }
    CHECK(strcmp(gr_result_name(GR_OK), "ok") == 0);
    CHECK(strcmp(gr_result_name(GR_ERROR_LAYOUT_MISMATCH), "layout_mismatch") == 0);
    CHECK(strcmp(gr_backend_name(GR_BACKEND_METAL), "metal") == 0);
    CHECK(strcmp(gr_result_name((gr_result)12345), "unknown") == 0);
}

int main(void)
{
    test_version();
    test_handles();
    test_struct_sizes();
    test_formats();
    test_stage_suffix();
    test_permutation_key();
    test_bytes_span();
    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("abi: %d checks passed\n", checks);
    return 0;
}
