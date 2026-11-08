/* test_vk_cache.c - pipeline cache persistence, across processes.
 *
 * Three modes, each a separate process so "the next run accepts the blob" means what it says:
 *
 *   test_vk_cache run     <path>   create the indexed pipeline, commit, write the cache
 *   test_vk_cache verify  <path>   load that cache, create the same pipeline, draw, read back
 *   test_vk_cache corrupt <path>   a file that is not a usable cache is refused, not ignored
 *
 * Skips (exit 0) when there is no Vulkan device. Run by `make vk-cache` under the GPU lock.
 */
#include "../include/grail/grail_backend_vulkan.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_shader.h"

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
            fprintf(stderr, "FAIL %s:%d: %s == %s (%lld != %lld)\n", __FILE__,        \
                    __LINE__, #a, #b, (long long)(a), (long long)(b));                \
        }                                                                             \
    } while (0)

static gr_str as_str(const char *text)
{
    gr_str out;
    out.data = text;
    out.len = (uint32_t)strlen(text);
    out._pad = 0;
    return out;
}

static gr_handle make_device(const char *path, gr_result *out_status)
{
    gr_device_desc dd;
    gr_handle device = GR_NULL_HANDLE;
    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_VULKAN;
    dd.flags = GR_DEVICE_HEADLESS | GR_DEVICE_VALIDATION;
    dd.app_name = as_str("grail-vk-cache-test");
    dd.pipeline_cache_path = as_str(path);
    *out_status = gr_device_create(&dd, &device);
    return device;
}

/* The indexed pipeline both `run` and `verify` create, so the cache key is the same. */
static gr_result make_indexed_pipeline(gr_handle device, gr_handle *out_pipeline)
{
    gr_shader_library_desc ld;
    gr_handle library = GR_NULL_HANDLE;
    gr_handle vs = GR_NULL_HANDLE, fs = GR_NULL_HANDLE;
    gr_pipeline_desc pd;
    gr_vertex_binding vb;
    gr_vertex_attribute attributes[2];
    gr_format color = GR_FORMAT_R8G8B8A8_UNORM;
    gr_result status;

    memset(&ld, 0, sizeof(ld));
    ld.head.size = (uint32_t)sizeof(ld);
    ld.root = as_str("../.work/shaders");
    if (gr_shader_library_open(&ld, &library) != GR_OK)
        return GR_ERROR_UNSUPPORTED;
    status = gr_shader_create_resolved(device, library, as_str("core/triangle"),
                                       GR_SHADER_STAGE_VERTEX, 0, &vs);
    if (status != GR_OK)
        return status;
    status = gr_shader_create_resolved(device, library, as_str("core/triangle"),
                                       GR_SHADER_STAGE_FRAGMENT, 0, &fs);
    if (status != GR_OK)
        return status;

    memset(&vb, 0, sizeof(vb));
    vb.slot = 0;
    vb.stride = 24;
    memset(attributes, 0, sizeof(attributes));
    attributes[0].location = 0;
    attributes[0].binding = 0;
    attributes[0].format = GR_FORMAT_R32G32_FLOAT;
    attributes[0].offset = 0;
    attributes[1].location = 1;
    attributes[1].binding = 0;
    attributes[1].format = GR_FORMAT_R32G32B32A32_FLOAT;
    attributes[1].offset = 8;

    memset(&pd, 0, sizeof(pd));
    pd.head.size = (uint32_t)sizeof(pd);
    pd.name = as_str("vk/cache-indexed");
    pd.shaders[GR_SHADER_STAGE_VERTEX] = vs;
    pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fs;
    pd.vertex_bindings = &vb;
    pd.vertex_binding_count = 1;
    pd.vertex_attributes = attributes;
    pd.vertex_attribute_count = 2;
    pd.color_formats = &color;
    pd.color_count = 1;
    pd.depth_format = GR_FORMAT_UNDEFINED;
    pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
    pd.cull = GR_CULL_NONE;
    pd.front_face_ccw = 1;
    pd.samples = 1;
    status = gr_pipeline_create(device, &pd, out_pipeline);
    gr_shader_library_close(library);
    return status;
}

int main(int argc, char **argv)
{
    const char *mode = argc > 1 ? argv[1] : "";
    const char *path = argc > 2 ? argv[2] : "";
    gr_result status;
    gr_handle device;

    if (strcmp(mode, "corrupt") == 0) {
        /* A file that is not a cache: the header is wrong on purpose. It must be refused rather
         * than silently starting empty, because "cache ignored" looks exactly like "cache works". */
        FILE *file = fopen(path, "wb");
        const char garbage[64] = "this is not a pipeline cache, it is 64 bytes of text";
        CHECK(file != NULL);
        if (file) {
            fwrite(garbage, 1, sizeof(garbage), file);
            fclose(file);
        }
        device = make_device(path, &status);
        CHECK_EQ(status, GR_ERROR_CACHE_INVALID);
        CHECK(gr_handle_is_null(device));
        printf("vk-cache: corrupt header refused (%s)\n", gr_result_name(status));
        printf("vk-cache: %d checks passed\n", checks);
        return failures ? 1 : 0;
    }

    device = make_device(path, &status);
    if (status == GR_ERROR_UNSUPPORTED) {
        printf("vk-cache: skipped (no Vulkan device)\n");
        return 0;
    }
    CHECK_EQ(status, GR_OK);
    if (status != GR_OK) {
        fprintf(stderr, "vk-cache: device creation failed: %s\n", gr_result_name(status));
        return 1;
    }

    {
        gr_pipeline_cache_report report;
        gr_handle pipeline = GR_NULL_HANDLE;
        memset(&report, 0, sizeof(report));
        report.head.size = (uint32_t)sizeof(report);
        CHECK_EQ(gr_pipeline_cache_report_query(device, &report), GR_OK);
        CHECK_EQ(report.path_set, 1u);

        if (strcmp(mode, "verify") == 0) {
            /* The point of the whole increment: this process did not build the cache. */
            CHECK_EQ(report.loaded, 1u);
            printf("vk-cache: loaded an existing cache (%u bytes)\n", report.size_bytes);
        } else {
            CHECK_EQ(report.loaded, 0u);
        }

        CHECK_EQ(make_indexed_pipeline(device, &pipeline), GR_OK);
        CHECK(pipeline != GR_NULL_HANDLE);

        if (strcmp(mode, "run") == 0) {
            double seconds = 0.0;
            CHECK_EQ(gr_pipeline_commit(device, &seconds), GR_OK);
            memset(&report, 0, sizeof(report));
            report.head.size = (uint32_t)sizeof(report);
            CHECK_EQ(gr_pipeline_cache_report_query(device, &report), GR_OK);
            CHECK_EQ(report.saved, 1u);
            CHECK(report.size_bytes > 32u);
            printf("vk-cache: wrote %u bytes\n", report.size_bytes);
        } else {
            /* Loading a cache and creating a pipeline from it has to work, not merely parse: draw
             * with the pipeline the cache is supposed to accelerate. */
            const uint32_t kSize = 32;
            struct vertex { float pos[2]; float colour[4]; };
            const struct vertex vertices[3] = {
                { { -0.6f, -0.6f }, { 1.0f, 0.0f, 0.0f, 1.0f } },
                { {  0.6f, -0.6f }, { 0.0f, 1.0f, 0.0f, 1.0f } },
                { {  0.0f,  0.6f }, { 0.0f, 0.0f, 1.0f, 1.0f } }
            };
            const uint16_t indices[3] = { 0, 1, 2 };
            gr_buffer_desc bd;
            gr_texture_desc td;
            gr_texture_view_desc vd;
            gr_handle vb = GR_NULL_HANDLE, ib = GR_NULL_HANDLE;
            gr_handle target = GR_NULL_HANDLE, target_view = GR_NULL_HANDLE;
            gr_cmd_pool_desc cpd;
            gr_handle pool = GR_NULL_HANDLE, cmd = GR_NULL_HANDLE;
            gr_cmd_alloc_info cai;
            uint8_t pixels[32 * 32 * 4];
            uint64_t digest = 0xcbf29ce484222325ull;
            size_t i;

            memset(&bd, 0, sizeof(bd));
            bd.head.size = (uint32_t)sizeof(bd);
            bd.size = sizeof(vertices);
            bd.usage = GR_BUFFER_USAGE_VERTEX | GR_BUFFER_USAGE_TRANSFER_DST;
            bd.memory = GR_MEMORY_UPLOAD;
            CHECK_EQ(gr_buffer_create(device, &bd, &vb), GR_OK);
            CHECK_EQ(gr_buffer_write(vb, 0,
                                     (gr_span_u8){ (const uint8_t *)vertices, sizeof(vertices) }),
                     GR_OK);
            bd.size = sizeof(indices);
            bd.usage = GR_BUFFER_USAGE_INDEX | GR_BUFFER_USAGE_TRANSFER_DST;
            CHECK_EQ(gr_buffer_create(device, &bd, &ib), GR_OK);
            CHECK_EQ(gr_buffer_write(ib, 0,
                                     (gr_span_u8){ (const uint8_t *)indices, sizeof(indices) }),
                     GR_OK);

            memset(&td, 0, sizeof(td));
            td.head.size = (uint32_t)sizeof(td);
            td.type = GR_TEXTURE_2D;
            td.format = GR_FORMAT_R8G8B8A8_UNORM;
            td.width = kSize;
            td.height = kSize;
            td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
            CHECK_EQ(gr_texture_create(device, &td, &target), GR_OK);
            memset(&vd, 0, sizeof(vd));
            vd.head.size = (uint32_t)sizeof(vd);
            vd.texture = target;
            vd.type = GR_VIEW_2D;
            vd.format = GR_FORMAT_UNDEFINED;
            CHECK_EQ(gr_texture_view_create(device, &vd, &target_view), GR_OK);

            memset(&cpd, 0, sizeof(cpd));
            cpd.head.size = (uint32_t)sizeof(cpd);
            cpd.queue = GR_QUEUE_GRAPHICS;
            CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
            memset(&cai, 0, sizeof(cai));
            cai.head.size = (uint32_t)sizeof(cai);
            cai.pool = pool;
            CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);
            CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
            {
                gr_barrier barrier;
                gr_render_begin rb;
                gr_color_attachment color;
                gr_draw_indexed draw;
                gr_submit submit;
                gr_handle queue = GR_NULL_HANDLE, fence = GR_NULL_HANDLE;
                uint64_t value = 0;
                gr_result wait_status = GR_ERROR_BACKEND;
                float z = 0.5f;

                memset(&barrier, 0, sizeof(barrier));
                barrier.resource = target_view;
                barrier.src_state = GR_STATE_UNDEFINED;
                barrier.dst_state = GR_STATE_COLOR_ATTACHMENT;
                CHECK_EQ(gr_cmd_barrier(cmd, &barrier, 1), GR_OK);
                memset(&color, 0, sizeof(color));
                color.view = target_view;
                color.load_op = GR_LOAD_CLEAR;
                color.store_op = GR_STORE_STORE;
                color.clear[3] = 1.0f;
                memset(&rb, 0, sizeof(rb));
                rb.head.size = (uint32_t)sizeof(rb);
                rb.colors = &color;
                rb.color_count = 1;
                rb.render_w = kSize;
                rb.render_h = kSize;
                CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_OK);
                CHECK_EQ(gr_cmd_set_viewport(cmd, 0.0f, 0.0f, (float)kSize, (float)kSize, 0.0f, 1.0f),
                         GR_OK);
                CHECK_EQ(gr_cmd_set_scissor(cmd, 0, 0, kSize, kSize), GR_OK);
                CHECK_EQ(gr_cmd_bind_pipeline(cmd, pipeline), GR_OK);
                CHECK_EQ(gr_cmd_push_constants(cmd, 0,
                                               (gr_span_u8){ (const uint8_t *)&z, 4 }), GR_OK);
                CHECK_EQ(gr_cmd_bind_vertex_buffer(cmd, 0, vb, 0), GR_OK);
                CHECK_EQ(gr_cmd_bind_index_buffer(cmd, ib, 0, 0), GR_OK);
                memset(&draw, 0, sizeof(draw));
                draw.head.size = (uint32_t)sizeof(draw);
                draw.index_count = 3;
                draw.instance_count = 1;
                CHECK_EQ(gr_cmd_draw_indexed(cmd, &draw), GR_OK);
                CHECK_EQ(gr_cmd_end_render(cmd), GR_OK);
                barrier.src_state = GR_STATE_COLOR_ATTACHMENT;
                barrier.dst_state = GR_STATE_TRANSFER_SRC;
                CHECK_EQ(gr_cmd_barrier(cmd, &barrier, 1), GR_OK);
                CHECK_EQ(gr_cmd_end(cmd), GR_OK);

                CHECK_EQ(gr_device_queue(device, GR_QUEUE_GRAPHICS, &queue), GR_OK);
                memset(&submit, 0, sizeof(submit));
                submit.head.size = (uint32_t)sizeof(submit);
                submit.queue = queue;
                submit.cmds = &cmd;
                submit.cmd_count = 1;
                CHECK_EQ(gr_submit_commands(&submit, &value), GR_OK);
                CHECK_EQ(gr_fence_create(device, 0, &fence), GR_OK);
                CHECK_EQ(gr_fence_wait(fence, value, 5ull * 1000ull * 1000ull * 1000ull,
                                       &wait_status), GR_OK);
            }
            memset(pixels, 0, sizeof(pixels));
            CHECK_EQ(gr_texture_read(target, 0, 0, 0, 0, kSize, kSize, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
            for (i = 0; i < sizeof(pixels); ++i) {
                digest ^= pixels[i];
                digest *= 0x100000001b3ull;
            }
            printf("vk-cache: drew with the loaded pipeline, digest 0x%016llx\n",
                   (unsigned long long)digest);
            /* The triangle reached the target: the corner is the clear colour, the centre is not. */
            CHECK(pixels[0] == 0u && pixels[1] == 0u && pixels[2] == 0u);
            {
                size_t centre = (size_t)((kSize / 2) * kSize + kSize / 2) * 4u;
                CHECK(!(pixels[centre] == 0u && pixels[centre + 1] == 0u &&
                        pixels[centre + 2] == 0u));
            }
        }
    }

    gr_device_destroy(device);
    printf("vk-cache: %d checks passed\n", checks);
    return failures ? 1 : 0;
}
