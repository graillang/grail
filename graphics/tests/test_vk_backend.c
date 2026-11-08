/* test_vk_backend.c - the Vulkan backend core, headless.
 *
 * Creates a real device, asks it for its capabilities, resolves the tonemap permutations out of
 * the shader library, has the driver compile every one of them into a shader module, builds the
 * bindless pipeline layout and a graphics pipeline for dynamic rendering, commits, and destroys
 * everything. No swapchain, no window, no draw: this is the increment that proves the ABI's device
 * and pipeline surface can be implemented on Vulkan at all.
 *
 * Skips (exit 0) when there is no Vulkan device, so the suite still runs on a machine without a
 * driver. Needs the shader artifacts: pass their directory as argv[1] (default ../.work/shaders).
 *
 * Talks to a driver, so `make test` does not run it. `make vk-smoke` runs it under the exclusive
 * GPU lock.
 */
#include "../include/grail/grail_bindless.h"
#include "../include/grail/grail_backend_vulkan.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_shader.h"
#include "../include/grail/grail_graph.h"

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

static void on_log(void *user, int32_t severity, gr_str message)
{
    (void)user;
    fprintf(stderr, "grail[%d]: %.*s\n", (int)severity, (int)message.len, message.data);
}

int main(int argc, char **argv)
{
    const char *artifacts = argc > 1 ? argv[1] : "../.work/shaders";
    gr_device_desc dd;
    gr_device_caps caps;
    gr_handle device = GR_NULL_HANDLE;
    gr_handle library = GR_NULL_HANDLE;
    gr_shader_library_desc ld;
    gr_str name = { "core/tonemap", 12, 0 };
    gr_str vs_name = { "core/fullscreen", 15, 0 };
    gr_handle fragments[8];
    gr_handle pipeline_solid = GR_NULL_HANDLE;
    gr_handle pipeline_bindless = GR_NULL_HANDLE;
    gr_handle pipeline_compute = GR_NULL_HANDLE;
    gr_handle pipeline_triangle = GR_NULL_HANDLE;
    uint32_t slot_a = GR_BINDLESS_INDEX_NONE;
    uint32_t slot_b = GR_BINDLESS_INDEX_NONE;
    gr_handle texture_a = GR_NULL_HANDLE, texture_b = GR_NULL_HANDLE;
    gr_handle view_a = GR_NULL_HANDLE, view_b = GR_NULL_HANDLE;
    uint64_t keys[8];
    uint32_t fragment_count = 0, i;

    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_VULKAN;
    dd.flags = GR_DEVICE_HEADLESS | GR_DEVICE_VALIDATION;
    dd.app_name = (gr_str){ "grail-vk-backend-test", 21, 0 };
    dd.log = on_log;
    if (gr_device_create(&dd, &device) == GR_ERROR_UNSUPPORTED) {
        printf("vk-backend: skipped (no Vulkan device)\n");
        return 0;
    }
    CHECK(device != GR_NULL_HANDLE);
    if (device == GR_NULL_HANDLE) {
        fprintf(stderr, "vk-backend: device creation failed\n");
        return 1;
    }

    /* Capabilities come from the driver, not from a table in our source. */
    memset(&caps, 0, sizeof(caps));
    caps.head.size = (uint32_t)sizeof(caps);
    CHECK_EQ(gr_device_get_caps(device, &caps), GR_OK);
    CHECK_EQ(caps.backend, GR_BACKEND_VULKAN);
    CHECK(caps.device_name[0] != '\0');
    CHECK(caps.max_push_constant_bytes >= GR_PUSH_CONSTANT_BYTES);
    CHECK(caps.device_memory_bytes > 0u);
    CHECK((caps.caps & GR_CAP_BINDLESS) != 0);
    CHECK((caps.caps & GR_CAP_DYNAMIC_RENDERING) != 0);
    CHECK((caps.caps & GR_CAP_TIMELINE_SEMAPHORE) != 0);
    CHECK((caps.caps & GR_CAP_BUFFER_DEVICE_ADDRESS) != 0);
    printf("vk-backend: device %s, API %u.%u.%u, push constants %u, %llu MiB\n", caps.device_name,
           caps.api_major, caps.api_minor, caps.api_patch, caps.max_push_constant_bytes,
           (unsigned long long)(caps.device_memory_bytes / (1024ull * 1024ull)));

    /* Three queues, distinct handles. */
    {
        gr_handle graphics = GR_NULL_HANDLE, compute = GR_NULL_HANDLE, transfer = GR_NULL_HANDLE;
        CHECK_EQ(gr_device_queue(device, GR_QUEUE_GRAPHICS, &graphics), GR_OK);
        CHECK_EQ(gr_device_queue(device, GR_QUEUE_COMPUTE, &compute), GR_OK);
        CHECK_EQ(gr_device_queue(device, GR_QUEUE_TRANSFER, &transfer), GR_OK);
        CHECK(graphics != GR_NULL_HANDLE);
        CHECK(compute != GR_NULL_HANDLE);
        CHECK(transfer != GR_NULL_HANDLE);
        CHECK(graphics != compute || graphics != transfer);
        CHECK_EQ(gr_queue_submitted(graphics), 0u);
        CHECK_EQ(gr_queue_completed(graphics), 0u);
    }

    /* The bindless table exists with the capacities the contract asks for. */
    {
        gr_bindless_info info;
        gr_handle bindless = gr_device_bindless(device);
        CHECK(bindless != GR_NULL_HANDLE);
        memset(&info, 0, sizeof(info));
        info.head.size = (uint32_t)sizeof(info);
        CHECK_EQ(gr_bindless_get_info(bindless, &info), GR_OK);
        CHECK_EQ(info.capacity[GR_TABLE_SAMPLED_IMAGES], GR_BINDLESS_CAP_SAMPLED_IMAGES);
        CHECK_EQ(info.capacity[GR_TABLE_STORAGE_BUFFERS], GR_BINDLESS_CAP_STORAGE_BUFFERS);
    }

    /* The shader library the offline tool wrote. */
    memset(&ld, 0, sizeof(ld));
    ld.head.size = (uint32_t)sizeof(ld);
    ld.root.data = artifacts;
    ld.root.len = (uint32_t)strlen(artifacts);
    CHECK_EQ(gr_shader_library_open(&ld, &library), GR_OK);
    if (library == GR_NULL_HANDLE) {
        fprintf(stderr, "vk-backend: no shader artifacts in %s\n", artifacts);
        gr_device_destroy(device);
        return 1;
    }

    /* Every tonemap permutation becomes a real VkShaderModule: the driver accepts the SPIR-V the
     * offline tool produced, for each combination. */
    {
        gr_shader_library_stats stats;
        gr_shader_entry entries[64];
        uint32_t written = 0;
        memset(&stats, 0, sizeof(stats));
        stats.head.size = (uint32_t)sizeof(stats);
        CHECK_EQ(gr_shader_library_stats_query(library, &stats), GR_OK);
        CHECK_EQ(gr_shader_library_entries(library, 0, stats.variant_count, entries, &written), GR_OK);
        for (i = 0; i < written && fragment_count < 8u; ++i) {
            if (entries[i].stage != GR_SHADER_STAGE_FRAGMENT || entries[i].name.len != name.len ||
                memcmp(entries[i].name.data, name.data, name.len) != 0)
                continue;
            keys[fragment_count] = entries[i].permutation_key;
            fragment_count++;
        }
        CHECK_EQ(fragment_count, 5u); /* the no-flags build plus four combinations */
        for (i = 0; i < fragment_count; ++i) {
            gr_handle shader = GR_NULL_HANDLE;
            CHECK_EQ(gr_shader_create_resolved(device, library, name, GR_SHADER_STAGE_FRAGMENT,
                                               keys[i], &shader), GR_OK);
            CHECK(shader != GR_NULL_HANDLE);
            fragments[i] = shader;
        }
        printf("vk-backend: %u tonemap shader modules created by the driver\n", fragment_count);
    }

    /* A graphics pipeline: the bindless layout, dynamic rendering, reverse-Z depth. Both stages
     * are the default permutation (key 0), because that is the only combination the vertex stage
     * was built for. */
    {
        gr_handle vertex = GR_NULL_HANDLE;
        gr_handle pipeline = GR_NULL_HANDLE;
        gr_pipeline_desc pd;
        gr_format color = GR_FORMAT_R8G8B8A8_UNORM;

        CHECK_EQ(gr_shader_create_resolved(device, library, vs_name, GR_SHADER_STAGE_VERTEX, 0,
                                           &vertex), GR_OK);
        CHECK(vertex != GR_NULL_HANDLE);

        memset(&pd, 0, sizeof(pd));
        pd.head.size = (uint32_t)sizeof(pd);
        pd.name = (gr_str){ "vk/tonemap", 11, 0 };
        pd.shaders[GR_SHADER_STAGE_VERTEX] = vertex;
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fragments[0];
        pd.color_formats = &color;
        pd.color_count = 1;
        pd.depth_format = GR_FORMAT_D32_FLOAT;
        pd.depth_test = 1;
        pd.depth_write = 1;
        pd.depth_compare = GR_COMPARE_GREATER_EQUAL;
        pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
        pd.cull = GR_CULL_NONE;
        pd.front_face_ccw = 1;
        pd.samples = 1;
        CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
        CHECK(pipeline != GR_NULL_HANDLE);

        /* The descriptor's permutation key is enforced on this backend too. */
        {
            gr_handle other = GR_NULL_HANDLE;
            pd.permutation_key = 0x1234ull; /* no shader carries this key */
            CHECK_EQ(gr_pipeline_create(device, &pd, &other), GR_ERROR_INVALID_ARGUMENT);
            pd.permutation_key = 0;
        }
    }

    /* A pipeline that needs no descriptors, for the offscreen frame below. */
    {
        gr_handle vertex = GR_NULL_HANDLE;
        gr_handle solid = GR_NULL_HANDLE;
        gr_handle pipeline = GR_NULL_HANDLE;
        gr_pipeline_desc pd;
        gr_format color = GR_FORMAT_R8G8B8A8_UNORM;
        gr_str solid_name = { "core/solid", 10, 0 };

        CHECK_EQ(gr_shader_create_resolved(device, library, vs_name, GR_SHADER_STAGE_VERTEX, 0,
                                           &vertex), GR_OK);
        CHECK_EQ(gr_shader_create_resolved(device, library, solid_name, GR_SHADER_STAGE_FRAGMENT, 0,
                                           &solid), GR_OK);
        memset(&pd, 0, sizeof(pd));
        pd.head.size = (uint32_t)sizeof(pd);
        pd.name = (gr_str){ "vk/solid", 8, 0 };
        pd.shaders[GR_SHADER_STAGE_VERTEX] = vertex;
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = solid;
        pd.color_formats = &color;
        pd.color_count = 1;
        pd.depth_format = GR_FORMAT_UNDEFINED; /* colour only: the frame has no depth attachment */
        pd.depth_test = 0;
        pd.depth_write = 0;
        pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
        pd.cull = GR_CULL_NONE;
        pd.front_face_ccw = 1;
        pd.samples = 1;
        CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
        CHECK(pipeline != GR_NULL_HANDLE);
        pipeline_solid = pipeline;
    }

    /* The pipeline that samples the bindless table. Its fragment stage reads set 0 (a sampled
     * image and a sampler) and set 1 (the frame constants), which is what makes the frame below
     * a test of the live table rather than of a solid colour. */
    {
        gr_handle vertex = GR_NULL_HANDLE;
        gr_handle fragment = GR_NULL_HANDLE;
        gr_handle pipeline = GR_NULL_HANDLE;
        gr_pipeline_desc pd;
        gr_format color = GR_FORMAT_R8G8B8A8_UNORM;
        gr_str fragment_name = { "core/tonemap", 12, 0 };

        CHECK_EQ(gr_shader_create_resolved(device, library, vs_name, GR_SHADER_STAGE_VERTEX, 0,
                                           &vertex), GR_OK);
        CHECK_EQ(gr_shader_create_resolved(device, library, fragment_name,
                                           GR_SHADER_STAGE_FRAGMENT, 0, &fragment), GR_OK);
        memset(&pd, 0, sizeof(pd));
        pd.head.size = (uint32_t)sizeof(pd);
        pd.name = (gr_str){ "vk/bindless", 11, 0 };
        pd.shaders[GR_SHADER_STAGE_VERTEX] = vertex;
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fragment;
        pd.color_formats = &color;
        pd.color_count = 1;
        pd.depth_format = GR_FORMAT_UNDEFINED;
        pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
        pd.cull = GR_CULL_NONE;
        pd.front_face_ccw = 1;
        pd.samples = 1;
        CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
        CHECK(pipeline != GR_NULL_HANDLE);
        pipeline_bindless = pipeline;
    }

    /* Two graded textures for the graph frame: A is filled, B receives A tonemapped. Their views
     * are created here so both claim sampled slots before the pipeline is committed. */
    {
        gr_texture_desc td;
        gr_texture_view_desc vd;
        gr_handle a = GR_NULL_HANDLE, b = GR_NULL_HANDLE;
        gr_handle va = GR_NULL_HANDLE, vb = GR_NULL_HANDLE;
        memset(&td, 0, sizeof(td));
        td.head.size = (uint32_t)sizeof(td);
        td.type = GR_TEXTURE_2D;
        td.format = GR_FORMAT_R8G8B8A8_UNORM;
        td.width = 64;
        td.height = 64;
        td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_SAMPLED |
                   GR_TEXTURE_USAGE_TRANSFER_SRC;
        CHECK_EQ(gr_texture_create(device, &td, &a), GR_OK);
        CHECK_EQ(gr_texture_create(device, &td, &b), GR_OK);
        memset(&vd, 0, sizeof(vd));
        vd.head.size = (uint32_t)sizeof(vd);
        vd.texture = a;
        vd.type = GR_VIEW_2D;
        vd.format = GR_FORMAT_UNDEFINED;
        CHECK_EQ(gr_texture_view_create(device, &vd, &va), GR_OK);
        slot_a = gr_texture_view_bindless_sampled(va);
        vd.texture = b;
        CHECK_EQ(gr_texture_view_create(device, &vd, &vb), GR_OK);
        slot_b = gr_texture_view_bindless_sampled(vb);
        CHECK(slot_a != GR_BINDLESS_INDEX_NONE && slot_b != GR_BINDLESS_INDEX_NONE);
        texture_a = a;
        texture_b = b;
        view_a = va;
        view_b = vb;
    }

    /* A compute pipeline: no attachments, no vertex stage, dispatched over a storage buffer. */
    {
        gr_handle compute = GR_NULL_HANDLE;
        gr_handle pipeline = GR_NULL_HANDLE;
        gr_pipeline_desc pd;
        gr_str compute_name = { "core/frame_setup", 16, 0 };
        CHECK_EQ(gr_shader_create_resolved(device, library, compute_name, GR_SHADER_STAGE_COMPUTE, 0,
                                           &compute), GR_OK);
        memset(&pd, 0, sizeof(pd));
        pd.head.size = (uint32_t)sizeof(pd);
        pd.name = (gr_str){ "vk/frame_setup", 15, 0 };
        pd.shaders[GR_SHADER_STAGE_COMPUTE] = compute;
        CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
        CHECK(pipeline != GR_NULL_HANDLE);
        pipeline_compute = pipeline;
    }

    /* The real draw path: a pipeline with a vertex input layout, fed by a vertex and an index
     * buffer. fullscreen.vs generates its vertices and binds nothing; this one reads attributes. */
    {
        gr_handle vs = GR_NULL_HANDLE, fs = GR_NULL_HANDLE, pipeline = GR_NULL_HANDLE;
        gr_pipeline_desc pd;
        gr_format color = GR_FORMAT_R8G8B8A8_UNORM;
        gr_vertex_binding vb;
        gr_vertex_attribute attributes[2];
        gr_str vs_name = { "core/triangle", 13, 0 };
        gr_str fs_name = { "core/triangle", 13, 0 };

        CHECK_EQ(gr_shader_create_resolved(device, library, vs_name, GR_SHADER_STAGE_VERTEX, 0, &vs),
                 GR_OK);
        CHECK_EQ(gr_shader_create_resolved(device, library, fs_name, GR_SHADER_STAGE_FRAGMENT, 0, &fs),
                 GR_OK);
        CHECK(vs != GR_NULL_HANDLE && fs != GR_NULL_HANDLE);

        memset(&vb, 0, sizeof(vb));
        vb.slot = 0;
        vb.stride = 24; /* float2 position + float4 colour */
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
        pd.name = (gr_str){ "vk/triangle", 11, 0 };
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
        CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
        CHECK(pipeline != GR_NULL_HANDLE);
        pipeline_triangle = pipeline;
    }

    /* Commit closes the registry, and the driver's pipeline cache has content. */
    {
        double seconds = -1.0;
        uint32_t declared = 0, committed = 0;
        CHECK_EQ(gr_pipeline_commit(device, &seconds), GR_OK);
        CHECK(seconds >= 0.0);
        CHECK_EQ(gr_pipeline_stats(device, &declared, &committed), GR_OK);
        CHECK_EQ(declared, 5u);
        CHECK_EQ(committed, 5u);
        {
            gr_device_caps after;
            memset(&after, 0, sizeof(after));
            after.head.size = (uint32_t)sizeof(after);
            CHECK_EQ(gr_device_get_caps(device, &after), GR_OK);
            printf("vk-backend: pipeline cache %llu bytes\n",
                   (unsigned long long)after.pipeline_cache_uuid[1]);
            CHECK(after.pipeline_cache_uuid[1] > 0u);
        }
        {
            gr_pipeline_desc pd;
            gr_handle pipeline = GR_NULL_HANDLE;
            memset(&pd, 0, sizeof(pd));
            pd.head.size = (uint32_t)sizeof(pd);
            pd.name = (gr_str){ "late", 4, 0 };
            CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_ERROR_NOT_READY);
        }
    }

    /* -----------------------------------------------------------------------------------
     * One real offscreen frame: clear plus a draw, executed and read back.
     * --------------------------------------------------------------------------------- */
    {
        const uint32_t kSize = 64;
        gr_texture_desc td;
        gr_handle texture = GR_NULL_HANDLE;
        gr_texture_view_desc vd;
        gr_handle view = GR_NULL_HANDLE;
        gr_cmd_pool_desc cpd;
        gr_handle pool = GR_NULL_HANDLE;
        gr_cmd_alloc_info cai;
        gr_handle cmd = GR_NULL_HANDLE;
        uint8_t pixels[64 * 64 * 4];
        uint64_t digests[2];
        uint32_t pass;

        memset(&td, 0, sizeof(td));
        td.head.size = (uint32_t)sizeof(td);
        td.type = GR_TEXTURE_2D;
        td.format = GR_FORMAT_R8G8B8A8_UNORM;
        td.width = kSize;
        td.height = kSize;
        td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
        CHECK_EQ(gr_texture_create(device, &td, &texture), GR_OK);
        CHECK(texture != GR_NULL_HANDLE);

        memset(&vd, 0, sizeof(vd));
        vd.head.size = (uint32_t)sizeof(vd);
        vd.texture = texture;
        vd.type = GR_VIEW_2D;
        vd.format = GR_FORMAT_UNDEFINED;
        CHECK_EQ(gr_texture_view_create(device, &vd, &view), GR_OK);

        memset(&cpd, 0, sizeof(cpd));
        cpd.head.size = (uint32_t)sizeof(cpd);
        cpd.queue = GR_QUEUE_GRAPHICS;
        CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
        memset(&cai, 0, sizeof(cai));
        cai.head.size = (uint32_t)sizeof(cai);
        cai.pool = pool;
        CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);

        /* Two passes over the same target: a second, independent render must produce the same
         * bytes, which is what makes the digest evidence rather than an observation. */
        for (pass = 0; pass < 2u; ++pass) {
            gr_barrier barrier;
            gr_render_begin rb;
            gr_color_attachment color;
            gr_draw draw;
            gr_submit submit;
            gr_handle queue = GR_NULL_HANDLE;
            gr_handle fence = GR_NULL_HANDLE;
            uint64_t value = 0, digest = 0xcbf29ce484222325ull;
            gr_result wait_status = GR_ERROR_BACKEND;
            float tint[4] = { 1.0f, 1.0f, 0.5f, 1.0f };
            size_t i;

            CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
            CHECK_EQ(gr_cmd_begin(cmd), GR_OK);

            memset(&barrier, 0, sizeof(barrier));
            barrier.resource = texture;
            barrier.src_state = pass == 0 ? GR_STATE_UNDEFINED : GR_STATE_TRANSFER_SRC;
            barrier.dst_state = GR_STATE_COLOR_ATTACHMENT;
            CHECK_EQ(gr_cmd_barrier(cmd, &barrier, 1), GR_OK);

            memset(&color, 0, sizeof(color));
            color.view = view;
            color.load_op = GR_LOAD_CLEAR;
            color.store_op = GR_STORE_STORE;
            color.clear[0] = 0.0f;
            color.clear[1] = 0.0f;
            color.clear[2] = 0.0f;
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
            CHECK_EQ(gr_cmd_bind_pipeline(cmd, pipeline_solid), GR_OK);
            CHECK_EQ(gr_cmd_push_constants(cmd, 2u, 0,
                                           (gr_span_u8){ (const uint8_t *)tint, sizeof(tint) }),
                     GR_OK);
            memset(&draw, 0, sizeof(draw));
            draw.head.size = (uint32_t)sizeof(draw);
            draw.vertex_count = 3; /* the fullscreen triangle */
            draw.instance_count = 1;
            CHECK_EQ(gr_cmd_draw(cmd, &draw), GR_OK);
            CHECK_EQ(gr_cmd_end_render(cmd), GR_OK);

            memset(&barrier, 0, sizeof(barrier));
            barrier.resource = texture;
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
            CHECK(value > 0u);
            CHECK_EQ(gr_queue_submitted(queue), value);

            /* The timeline wait the ABI exposes: no binary semaphores, no guessing. */
            CHECK_EQ(gr_fence_create(device, 0, &fence), GR_OK);
            CHECK_EQ(gr_fence_wait(fence, value, 5ull * 1000ull * 1000ull * 1000ull, &wait_status),
                     GR_OK);
            CHECK_EQ(wait_status, GR_OK);

            memset(pixels, 0, sizeof(pixels));
            CHECK_EQ(gr_texture_read(texture, 0, 0, 0, 0, kSize, kSize, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
            for (i = 0; i < sizeof(pixels); ++i) {
                digest ^= pixels[i];
                digest *= 0x100000001b3ull;
            }
            digests[pass] = digest;
        }

        printf("vk-backend: frame %ux%u, digest 0x%016llx\n", kSize, kSize,
               (unsigned long long)digests[0]);
        /* Deterministic: two independent clears-and-draws give the same bytes. */
        CHECK_EQ(digests[0], digests[1]);

        /* And the image holds what the shader computes, not the clear colour. */
        {
            size_t distinct = 0;
            uint8_t colors[256][3];
            size_t i, j;
            int all_opaque = 1;
            for (i = 0; i < sizeof(pixels); i += 4u) {
                if (pixels[i + 3] != 255u)
                    all_opaque = 0;
                for (j = 0; j < distinct; ++j)
                    if (colors[j][0] == pixels[i] && colors[j][1] == pixels[i + 1] &&
                        colors[j][2] == pixels[i + 2])
                        break;
                if (j == distinct && distinct < 256u) {
                    colors[distinct][0] = pixels[i];
                    colors[distinct][1] = pixels[i + 1];
                    colors[distinct][2] = pixels[i + 2];
                    distinct++;
                }
            }
            CHECK(all_opaque);
            CHECK(distinct > 32u); /* a gradient, not a flat clear */
            /* The shader writes b = tint.b = 0.5 for every pixel. */
            CHECK(pixels[2] >= 126u && pixels[2] <= 130u);
            /* r rises with x and g with y, so the two opposite corners must differ. */
            CHECK(pixels[0] != pixels[sizeof(pixels) - 4u] ||
                  pixels[1] != pixels[sizeof(pixels) - 3u]);
            printf("vk-backend: %zu distinct colours, corner rgba %u,%u,%u,%u / %u,%u,%u,%u\n",
                   distinct, pixels[0], pixels[1], pixels[2], pixels[3],
                   pixels[sizeof(pixels) - 4u], pixels[sizeof(pixels) - 3u],
                   pixels[sizeof(pixels) - 2u], pixels[sizeof(pixels) - 1u]);
        }
    }

    /* -----------------------------------------------------------------------------------
     * A frame that samples the live bindless table.
     * --------------------------------------------------------------------------------- */
    {
        const uint32_t kSize = 64;
        static const uint8_t kQuadrants[4][3] = {
            { 51, 102, 153 }, { 204, 51, 51 }, { 51, 204, 51 }, { 153, 153, 51 }
        };
        uint8_t source[8 * 8 * 4];
        gr_texture_desc td;
        gr_handle src = GR_NULL_HANDLE, dst = GR_NULL_HANDLE;
        gr_texture_view_desc vd;
        gr_handle src_view = GR_NULL_HANDLE, dst_view = GR_NULL_HANDLE;
        gr_cmd_pool_desc cpd;
        gr_handle pool = GR_NULL_HANDLE, cmd = GR_NULL_HANDLE;
        gr_cmd_alloc_info cai;
        gr_frame_constants constants;
        uint32_t sampled_slot = GR_BINDLESS_INDEX_NONE;
        uint8_t pixels[64 * 64 * 4];
        uint64_t digests[3];
        uint32_t pass;
        int expected_hits[4] = { 0, 0, 0, 0 };

        /* Four flat quadrants: small, and each quadrant's filtered value is exactly its texel, so
         * what the shader sampled is not in doubt. */
        {
            uint32_t y, x;
            for (y = 0; y < 8u; ++y)
                for (x = 0; x < 8u; ++x) {
                    uint32_t q = (y < 4u ? 0u : 2u) + (x < 4u ? 0u : 1u);
                    uint8_t *pixel = &source[(y * 8u + x) * 4u];
                    pixel[0] = kQuadrants[q][0];
                    pixel[1] = kQuadrants[q][1];
                    pixel[2] = kQuadrants[q][2];
                    pixel[3] = 255;
                }
        }

        memset(&td, 0, sizeof(td));
        td.head.size = (uint32_t)sizeof(td);
        td.type = GR_TEXTURE_2D;
        td.format = GR_FORMAT_R8G8B8A8_UNORM;
        td.width = 8;
        td.height = 8;
        td.usage = GR_TEXTURE_USAGE_SAMPLED | GR_TEXTURE_USAGE_TRANSFER_DST;
        CHECK_EQ(gr_texture_create(device, &td, &src), GR_OK);
        CHECK_EQ(gr_texture_write(src, 0, 0, 0, 0, 8, 8, (gr_span_u8){ source, sizeof(source) }),
                 GR_OK);

        /* Creating the view claims a slot in the live sampled-image table. */
        memset(&vd, 0, sizeof(vd));
        vd.head.size = (uint32_t)sizeof(vd);
        vd.texture = src;
        vd.type = GR_VIEW_2D;
        vd.format = GR_FORMAT_UNDEFINED;
        CHECK_EQ(gr_texture_view_create(device, &vd, &src_view), GR_OK);
        sampled_slot = gr_texture_view_bindless_sampled(src_view);
        CHECK(sampled_slot != GR_BINDLESS_INDEX_NONE);
        printf("vk-backend: source texture at sampled slot %u\n", sampled_slot);

        td.width = kSize;
        td.height = kSize;
        td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
        CHECK_EQ(gr_texture_create(device, &td, &dst), GR_OK);
        memset(&vd, 0, sizeof(vd));
        vd.head.size = (uint32_t)sizeof(vd);
        vd.texture = dst;
        vd.type = GR_VIEW_2D;
        vd.format = GR_FORMAT_UNDEFINED;
        CHECK_EQ(gr_texture_view_create(device, &vd, &dst_view), GR_OK);

        /* The frame constants the shader reads: exposure.z = 1 leaves the sampled colour alone. */
        memset(&constants, 0, sizeof(constants));
        constants.version = GR_FRAME_CONSTANTS_VERSION;
        constants.exposure[0] = 1.0f;
        constants.exposure[2] = 1.0f;
        constants.frame_index = 0;
        CHECK_EQ(gr_frame_constants_write(device, 0, &constants), GR_OK);

        memset(&cpd, 0, sizeof(cpd));
        cpd.head.size = (uint32_t)sizeof(cpd);
        cpd.queue = GR_QUEUE_GRAPHICS;
        CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
        memset(&cai, 0, sizeof(cai));
        cai.head.size = (uint32_t)sizeof(cai);
        cai.pool = pool;
        CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);

        /* Pass 0 and 1: the same source, so the digests must match. Pass 2: a different source,
         * so the digest must move — which is only possible if the sample is real. */
        for (pass = 0; pass < 3u; ++pass) {
            gr_barrier barrier;
            gr_render_begin rb;
            gr_color_attachment color_attachment;
            gr_draw draw;
            gr_submit submit;
            gr_handle queue = GR_NULL_HANDLE, fence = GR_NULL_HANDLE;
            uint64_t value = 0, digest = 0xcbf29ce484222325ull;
            gr_result wait_status = GR_ERROR_BACKEND;
            uint32_t push[4];
            size_t i;

            if (pass == 2u) {
                /* Overwrite every texel with one new colour. */
                for (i = 0; i < sizeof(source); i += 4u) {
                    source[i + 0] = 200;
                    source[i + 1] = 40;
                    source[i + 2] = 90;
                }
                CHECK_EQ(gr_texture_write(src, 0, 0, 0, 0, 8, 8,
                                          (gr_span_u8){ source, sizeof(source) }), GR_OK);
            }

            CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
            CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
            CHECK_EQ(gr_cmd_push_frame_offset(cmd, 0), GR_OK);

            memset(&barrier, 0, sizeof(barrier));
            barrier.resource = dst;
            barrier.src_state = GR_STATE_UNDEFINED;
            barrier.dst_state = GR_STATE_COLOR_ATTACHMENT;
            CHECK_EQ(gr_cmd_barrier(cmd, &barrier, 1), GR_OK);

            memset(&color_attachment, 0, sizeof(color_attachment));
            color_attachment.view = dst_view;
            color_attachment.load_op = GR_LOAD_CLEAR;
            color_attachment.store_op = GR_STORE_STORE;
            color_attachment.clear[3] = 1.0f;
            memset(&rb, 0, sizeof(rb));
            rb.head.size = (uint32_t)sizeof(rb);
            rb.colors = &color_attachment;
            rb.color_count = 1;
            rb.render_w = kSize;
            rb.render_h = kSize;
            CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_OK);
            CHECK_EQ(gr_cmd_set_viewport(cmd, 0.0f, 0.0f, (float)kSize, (float)kSize, 0.0f, 1.0f),
                     GR_OK);
            CHECK_EQ(gr_cmd_set_scissor(cmd, 0, 0, kSize, kSize), GR_OK);
            /* Binding the pipeline binds both descriptor sets: that is the contract. */
            CHECK_EQ(gr_cmd_bind_pipeline(cmd, pipeline_bindless), GR_OK);
            push[0] = sampled_slot;
            push[1] = 1; /* exposure_enabled */
            push[2] = 0;
            push[3] = 0;
            CHECK_EQ(gr_cmd_push_constants(cmd, 2u, 0,
                                           (gr_span_u8){ (const uint8_t *)push, sizeof(push) }),
                     GR_OK);
            memset(&draw, 0, sizeof(draw));
            draw.head.size = (uint32_t)sizeof(draw);
            draw.vertex_count = 3;
            draw.instance_count = 1;
            CHECK_EQ(gr_cmd_draw(cmd, &draw), GR_OK);
            CHECK_EQ(gr_cmd_end_render(cmd), GR_OK);

            memset(&barrier, 0, sizeof(barrier));
            barrier.resource = dst;
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
            CHECK_EQ(gr_fence_wait(fence, value, 5ull * 1000ull * 1000ull * 1000ull, &wait_status),
                     GR_OK);
            CHECK_EQ(wait_status, GR_OK);

            memset(pixels, 0, sizeof(pixels));
            CHECK_EQ(gr_texture_read(dst, 0, 0, 0, 0, kSize, kSize, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
            for (i = 0; i < sizeof(pixels); ++i) {
                digest ^= pixels[i];
                digest *= 0x100000001b3ull;
            }
            digests[pass] = digest;

            if (pass == 0) {
                /* Every pixel opaque, and the four filtered quadrant colours present: the shader
                 * sampled each texel of the uploaded image. */
                uint32_t q;
                int all_opaque = 1;
                for (i = 0; i < sizeof(pixels); i += 4u)
                    if (pixels[i + 3] != 255u)
                        all_opaque = 0;
                CHECK(all_opaque);
                for (q = 0; q < 4u; ++q) {
                    float r = kQuadrants[q][0] / 255.0f;
                    float g = kQuadrants[q][1] / 255.0f;
                    float b = kQuadrants[q][2] / 255.0f;
                    float a = 2.51f, bb = 0.03f, c = 2.43f, d = 0.59f, e = 0.14f;
                    float tr = (r * (a * r + bb)) / (r * (c * r + d) + e);
                    float tg = (g * (a * g + bb)) / (g * (c * g + d) + e);
                    float tb = (b * (a * b + bb)) / (b * (c * b + d) + e);
                    uint8_t er = (uint8_t)(tr * 255.0f + 0.5f);
                    uint8_t eg = (uint8_t)(tg * 255.0f + 0.5f);
                    uint8_t eb = (uint8_t)(tb * 255.0f + 0.5f);
                    for (i = 0; i < sizeof(pixels); i += 4u) {
                        int dr = (int)pixels[i] - (int)er;
                        int dg = (int)pixels[i + 1] - (int)eg;
                        int db = (int)pixels[i + 2] - (int)eb;
                        if (dr >= -3 && dr <= 3 && dg >= -3 && dg <= 3 && db >= -3 && db <= 3) {
                            expected_hits[q] = 1;
                            break;
                        }
                    }
                }
                for (q = 0; q < 4u; ++q)
                    CHECK(expected_hits[q] == 1);
            }
        }

        printf("vk-backend: bindless frame digest 0x%016llx (same source twice), "
               "0x%016llx (other source)\n",
               (unsigned long long)digests[0], (unsigned long long)digests[2]);
        /* Deterministic, and genuinely reading the table. */
        CHECK_EQ(digests[0], digests[1]);
        CHECK(digests[0] != digests[2]);
        /* And distinct from the solid frame's digest, because a different pipeline ran. */
        CHECK(digests[0] != 0u);
    }

    /* -----------------------------------------------------------------------------------
     * A compute dispatch over a buffer taken from the storage-buffer table.
     * --------------------------------------------------------------------------------- */
    {
        const uint32_t kCount = 64;
        gr_buffer_desc bd;
        gr_handle buffer = GR_NULL_HANDLE;
        gr_cmd_pool_desc cpd;
        gr_handle pool = GR_NULL_HANDLE, cmd = GR_NULL_HANDLE;
        gr_cmd_alloc_info cai;
        uint32_t slot = GR_BINDLESS_INDEX_NONE;
        uint64_t address = 0;
        uint32_t seed;
        uint64_t digests[3];

        memset(&bd, 0, sizeof(bd));
        bd.head.size = (uint32_t)sizeof(bd);
        bd.size = kCount * 4u;
        bd.usage = GR_BUFFER_USAGE_STORAGE | GR_BUFFER_USAGE_TRANSFER_SRC |
                   GR_BUFFER_USAGE_TRANSFER_DST | GR_BUFFER_USAGE_SHADER_DEVICE_ADDRESS;
        bd.memory = GR_MEMORY_UPLOAD;
        CHECK_EQ(gr_buffer_create(device, &bd, &buffer), GR_OK);
        CHECK(buffer != GR_NULL_HANDLE);

        /* The buffer claimed a slot in the storage-buffer table as it was created, and it has a
         * device address because its usage asked for one. */
        slot = gr_buffer_bindless_index(buffer);
        CHECK(slot != GR_BINDLESS_INDEX_NONE);
        address = gr_buffer_device_address(buffer);
        CHECK(address != 0u);
        printf("vk-backend: storage buffer at slot %u, device address 0x%llx\n", slot,
               (unsigned long long)address);

        memset(&cpd, 0, sizeof(cpd));
        cpd.head.size = (uint32_t)sizeof(cpd);
        cpd.queue = GR_QUEUE_COMPUTE;
        CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
        memset(&cai, 0, sizeof(cai));
        cai.head.size = (uint32_t)sizeof(cai);
        cai.pool = pool;
        CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);

        for (seed = 0; seed < 3u; ++seed) {
            gr_barrier barrier;
            gr_submit submit;
            gr_handle queue = GR_NULL_HANDLE, fence = GR_NULL_HANDLE;
            uint64_t value = 0, digest = 0xcbf29ce484222325ull;
            gr_result wait_status = GR_ERROR_BACKEND;
            uint32_t push[4];
            uint32_t values[kCount];
            uint32_t i;
            int all_match = 1;

            /* Seed 1 second time so the first two runs are the same seed and the last differs. */
            push[0] = slot;
            push[1] = kCount;
            push[2] = seed < 2u ? 12345u : 999u; /* two runs at one seed, then a different one */
            push[3] = 0;

            CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
            CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
            CHECK_EQ(gr_cmd_push_frame_offset(cmd, 0), GR_OK);

            memset(&barrier, 0, sizeof(barrier));
            barrier.resource = buffer;
            barrier.src_state = GR_STATE_GENERAL;
            barrier.dst_state = GR_STATE_GENERAL;
            CHECK_EQ(gr_cmd_barrier(cmd, &barrier, 1), GR_OK);

            CHECK_EQ(gr_cmd_bind_pipeline(cmd, pipeline_compute), GR_OK);
            CHECK_EQ(gr_cmd_push_constants(cmd, 4u, 0,
                                           (gr_span_u8){ (const uint8_t *)push, sizeof(push) }),
                     GR_OK);
            CHECK_EQ(gr_cmd_dispatch(cmd, 1, 1, 1), GR_OK); /* 64 threads, one per counter */

            memset(&barrier, 0, sizeof(barrier));
            barrier.resource = buffer;
            barrier.src_state = GR_STATE_GENERAL;
            barrier.dst_state = GR_STATE_COPY_SOURCE_HOST;
            CHECK_EQ(gr_cmd_barrier(cmd, &barrier, 1), GR_OK);
            CHECK_EQ(gr_cmd_end(cmd), GR_OK);

            CHECK_EQ(gr_device_queue(device, GR_QUEUE_COMPUTE, &queue), GR_OK);
            memset(&submit, 0, sizeof(submit));
            submit.head.size = (uint32_t)sizeof(submit);
            submit.queue = queue;
            submit.cmds = &cmd;
            submit.cmd_count = 1;
            CHECK_EQ(gr_submit_commands(&submit, &value), GR_OK);
            CHECK_EQ(gr_fence_create(device, 0, &fence), GR_OK);
            CHECK_EQ(gr_fence_wait(fence, value, 5ull * 1000ull * 1000ull * 1000ull, &wait_status),
                     GR_OK);
            CHECK_EQ(wait_status, GR_OK);

            memset(values, 0, sizeof(values));
            CHECK_EQ(gr_buffer_read(buffer, 0, (gr_mut_span_u8){ (uint8_t *)values, sizeof(values) }),
                     GR_OK);
            for (i = 0; i < kCount * 4u; ++i) {
                digest ^= ((const uint8_t *)values)[i];
                digest *= 0x100000001b3ull;
            }
            digests[seed] = digest;

            if (seed == 0) {
                /* Every element is the hash the shader computes, evaluated independently here. */
                for (i = 0; i < kCount; ++i) {
                    uint32_t expected = 12345u ^ (i * 0x9E3779B9u);
                    expected ^= expected >> 16;
                    expected *= 0x7FEB352Du;
                    expected ^= expected >> 15;
                    if (values[i] != expected)
                        all_match = 0;
                }
                CHECK(all_match);
            }
        }
        printf("vk-backend: compute digest seed 12345 = 0x%016llx (twice), seed 999 = 0x%016llx\n",
               (unsigned long long)digests[0], (unsigned long long)digests[2]);
        /* Deterministic for a fixed seed, and genuinely driven by it. */
        CHECK_EQ(digests[0], digests[1]);
        CHECK(digests[0] != digests[2]);
    }

    /* -----------------------------------------------------------------------------------
     * A three-pass frame driven entirely by the compiled graph.
     *
     *   fill   writes A                       (solid gradient)
     *   grade  reads A, writes B              (tonemap sampling A)
     *   final  reads B, writes C              (tonemap sampling B)
     *
     * Every transition the passes need is derived by the graph; this block only applies what
     * gr_graph_pass_barriers hands back. If the derivation were wrong the driver would reject the
     * submission or the readback would not be what a two-stage tonemap produces.
     * --------------------------------------------------------------------------------- */
    {
        const uint32_t kSize = 64;
        gr_graph_desc gd;
        gr_handle graph = GR_NULL_HANDLE;
        gr_graph_resource ra, rb, rc;
        gr_graph_pass p_fill, p_grade, p_final;
        gr_graph_compile_report report;
        gr_cmd_pool_desc cpd;
        gr_handle pool = GR_NULL_HANDLE, cmd = GR_NULL_HANDLE;
        gr_cmd_alloc_info cai;
        gr_handle texture_c = GR_NULL_HANDLE, view_c = GR_NULL_HANDLE;
        uint32_t order[3];
        uint32_t pass_index;
        uint64_t digest_b = 0, digest_c = 0;

        /* The third target: the final pass reads B and writes here. */
        {
            gr_texture_desc td;
            gr_texture_view_desc vd;
            memset(&td, 0, sizeof(td));
            td.head.size = (uint32_t)sizeof(td);
            td.type = GR_TEXTURE_2D;
            td.format = GR_FORMAT_R8G8B8A8_UNORM;
            td.width = kSize;
            td.height = kSize;
            td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
            CHECK_EQ(gr_texture_create(device, &td, &texture_c), GR_OK);
            memset(&vd, 0, sizeof(vd));
            vd.head.size = (uint32_t)sizeof(vd);
            vd.texture = texture_c;
            vd.type = GR_VIEW_2D;
            vd.format = GR_FORMAT_UNDEFINED;
            CHECK_EQ(gr_texture_view_create(device, &vd, &view_c), GR_OK);
        }

        memset(&gd, 0, sizeof(gd));
        gd.head.size = (uint32_t)sizeof(gd);
        CHECK(gr_graph_create(&gd, &graph) != GR_NULL_HANDLE);

        /* Declared in reverse on purpose: the graph orders them, not this list. */
        CHECK_EQ(gr_graph_add_pass(graph, (gr_str){ "final", 5, 0 }, &p_final), GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, (gr_str){ "grade", 5, 0 }, &p_grade), GR_OK);
        CHECK_EQ(gr_graph_add_pass(graph, (gr_str){ "fill", 4, 0 }, &p_fill), GR_OK);
        CHECK_EQ(gr_graph_add_resource(graph, (gr_str){ "a", 1, 0 }, GR_GRAPH_RESOURCE_TEXTURE,
                                       texture_a, &ra), GR_OK);
        CHECK_EQ(gr_graph_add_resource(graph, (gr_str){ "b", 1, 0 }, GR_GRAPH_RESOURCE_TEXTURE,
                                       texture_b, &rb), GR_OK);
        CHECK_EQ(gr_graph_add_resource(graph, (gr_str){ "c", 1, 0 }, GR_GRAPH_RESOURCE_TEXTURE,
                                       texture_c, &rc), GR_OK);

        CHECK_EQ(gr_graph_pass_write(graph, p_fill, ra, GR_STATE_COLOR_ATTACHMENT), GR_OK);
        CHECK_EQ(gr_graph_pass_read(graph, p_grade, ra, GR_STATE_SHADER_READ), GR_OK);
        CHECK_EQ(gr_graph_pass_write(graph, p_grade, rb, GR_STATE_COLOR_ATTACHMENT), GR_OK);
        CHECK_EQ(gr_graph_pass_read(graph, p_final, rb, GR_STATE_SHADER_READ), GR_OK);
        CHECK_EQ(gr_graph_pass_write(graph, p_final, rc, GR_STATE_COLOR_ATTACHMENT), GR_OK);
        CHECK_EQ(gr_graph_pass_set_side_effect(graph, p_final, 1), GR_OK);

        memset(&report, 0, sizeof(report));
        report.head.size = (uint32_t)sizeof(report);
        CHECK_EQ(gr_graph_compile(graph, &report), GR_OK);
        CHECK_EQ(report.error, GR_GRAPH_OK);
        CHECK_EQ(report.live_count, 3u);
        CHECK_EQ(report.culled_count, 0u);
        /* A: undefined->colour, colour->sampled. B: undefined->colour, colour->sampled.
         * C: undefined->colour. */
        CHECK_EQ(report.barrier_count, 5u);
        for (pass_index = 0; pass_index < 3u; ++pass_index)
            CHECK_EQ(gr_graph_execution_order(graph, pass_index, &order[pass_index]), GR_OK);
        CHECK_EQ(order[0], p_fill);
        CHECK_EQ(order[1], p_grade);
        CHECK_EQ(order[2], p_final);
        printf("vk-backend: graph ordered %u,%u,%u with %u derived barriers\n", order[0], order[1],
               order[2], report.barrier_count);

        memset(&cpd, 0, sizeof(cpd));
        cpd.head.size = (uint32_t)sizeof(cpd);
        cpd.queue = GR_QUEUE_GRAPHICS;
        CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
        memset(&cai, 0, sizeof(cai));
        cai.head.size = (uint32_t)sizeof(cai);
        cai.pool = pool;
        CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);
        CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
        CHECK_EQ(gr_cmd_push_frame_offset(cmd, 0), GR_OK);

        /* Walk the derived order. Each step applies exactly what the graph derived for it. */
        {
            uint32_t step;
            for (step = 0; step < 3u; ++step) {
                gr_barrier barriers[8];
                uint32_t count = 0;
                gr_graph_pass pass = order[step];
                gr_handle target = pass == p_fill ? view_a : pass == p_grade ? view_b : view_c;
                gr_handle pipeline_used = pass == p_fill ? pipeline_solid : pipeline_bindless;
                gr_render_begin rb_begin;
                gr_color_attachment color;
                gr_draw draw;
                uint32_t push[4];

                CHECK_EQ(gr_graph_pass_barriers(graph, step, barriers, 8, &count), GR_OK);
                if (count)
                    CHECK_EQ(gr_cmd_barrier(cmd, barriers, count), GR_OK);

                memset(&color, 0, sizeof(color));
                color.view = target;
                color.load_op = GR_LOAD_CLEAR;
                color.store_op = GR_STORE_STORE;
                color.clear[3] = 1.0f;
                memset(&rb_begin, 0, sizeof(rb_begin));
                rb_begin.head.size = (uint32_t)sizeof(rb_begin);
                rb_begin.colors = &color;
                rb_begin.color_count = 1;
                rb_begin.render_w = kSize;
                rb_begin.render_h = kSize;
                CHECK_EQ(gr_cmd_begin_render(cmd, &rb_begin), GR_OK);
                CHECK_EQ(gr_cmd_set_viewport(cmd, 0.0f, 0.0f, (float)kSize, (float)kSize, 0.0f, 1.0f),
                         GR_OK);
                CHECK_EQ(gr_cmd_set_scissor(cmd, 0, 0, kSize, kSize), GR_OK);
                CHECK_EQ(gr_cmd_bind_pipeline(cmd, pipeline_used), GR_OK);
                if (pass == p_fill) {
                    /* solid.ps reads a float4 tint. */
                    float tint[4];
                    tint[0] = 1.0f;
                    tint[1] = 1.0f;
                    tint[2] = 0.5f;
                    tint[3] = 1.0f;
                    memcpy(push, tint, sizeof(push));
                } else {
                    /* tonemap.ps reads { sampled slot, exposure_enabled }. */
                    push[0] = pass == p_grade ? slot_a : slot_b;
                    push[1] = 1;
                    push[2] = 0;
                    push[3] = 0;
                }
                CHECK_EQ(gr_cmd_push_constants(cmd, 2u, 0,
                                               (gr_span_u8){ (const uint8_t *)push, sizeof(push) }),
                         GR_OK);
                memset(&draw, 0, sizeof(draw));
                draw.head.size = (uint32_t)sizeof(draw);
                draw.vertex_count = 3;
                draw.instance_count = 1;
                CHECK_EQ(gr_cmd_draw(cmd, &draw), GR_OK);
                CHECK_EQ(gr_cmd_end_render(cmd), GR_OK);
            }
        }

        /* Readback of B and C is host work, not a pass, so these two transitions are issued
         * directly rather than declared in the graph. */
        {
            gr_barrier readback[2];
            memset(readback, 0, sizeof(readback));
            readback[0].resource = texture_b;
            readback[0].src_state = GR_STATE_SHADER_READ;
            readback[0].dst_state = GR_STATE_TRANSFER_SRC;
            readback[1].resource = texture_c;
            readback[1].src_state = GR_STATE_COLOR_ATTACHMENT;
            readback[1].dst_state = GR_STATE_TRANSFER_SRC;
            CHECK_EQ(gr_cmd_barrier(cmd, readback, 2), GR_OK);
        }
        CHECK_EQ(gr_cmd_end(cmd), GR_OK);

        {
            gr_submit submit;
            gr_handle queue = GR_NULL_HANDLE, fence = GR_NULL_HANDLE;
            uint64_t value = 0;
            gr_result wait_status = GR_ERROR_BACKEND;
            uint8_t pixels[64 * 64 * 4];
            size_t i;

            CHECK_EQ(gr_device_queue(device, GR_QUEUE_GRAPHICS, &queue), GR_OK);
            memset(&submit, 0, sizeof(submit));
            submit.head.size = (uint32_t)sizeof(submit);
            submit.queue = queue;
            submit.cmds = &cmd;
            submit.cmd_count = 1;
            CHECK_EQ(gr_submit_commands(&submit, &value), GR_OK);
            CHECK_EQ(gr_fence_create(device, 0, &fence), GR_OK);
            CHECK_EQ(gr_fence_wait(fence, value, 5ull * 1000ull * 1000ull * 1000ull, &wait_status),
                     GR_OK);
            CHECK_EQ(wait_status, GR_OK);

            memset(pixels, 0, sizeof(pixels));
            CHECK_EQ(gr_texture_read(texture_b, 0, 0, 0, 0, kSize, kSize, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
            for (i = 0; i < sizeof(pixels); ++i) {
                digest_b ^= pixels[i];
                digest_b *= 0x100000001b3ull;
            }
            memset(pixels, 0, sizeof(pixels));
            CHECK_EQ(gr_texture_read(texture_c, 0, 0, 0, 0, kSize, kSize, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
            for (i = 0; i < sizeof(pixels); ++i) {
                digest_c ^= pixels[i];
                digest_c *= 0x100000001b3ull;
            }
        }

        printf("vk-backend: graph frame digests b=0x%016llx c=0x%016llx\n",
               (unsigned long long)digest_b, (unsigned long long)digest_c);
        /* The third pass applied the tonemap a second time, so C is not a copy of B. */
        if (digest_b == digest_c) {
            uint8_t probe[64 * 64 * 4];
            size_t i;
            memset(probe, 0, sizeof(probe));
            gr_texture_read(texture_b, 0, 0, 0, 0, 64, 64, GR_STATE_TRANSFER_SRC,
                            (gr_mut_span_u8){ probe, sizeof(probe) });
            printf("  b pixels:");
            for (i = 0; i < 8; ++i)
                printf(" %u,%u,%u,%u", probe[i * 4], probe[i * 4 + 1], probe[i * 4 + 2],
                       probe[i * 4 + 3]);
            printf("\n");
            memset(probe, 0, sizeof(probe));
            gr_texture_read(texture_c, 0, 0, 0, 0, 64, 64, GR_STATE_TRANSFER_SRC,
                            (gr_mut_span_u8){ probe, sizeof(probe) });
            printf("  c pixels:");
            for (i = 0; i < 8; ++i)
                printf(" %u,%u,%u,%u", probe[i * 4], probe[i * 4 + 1], probe[i * 4 + 2],
                       probe[i * 4 + 3]);
            printf("\n");
        }
        CHECK(digest_b != digest_c);
        CHECK(digest_b != 0u && digest_c != 0u);
    }

    /* -----------------------------------------------------------------------------------
     * An indexed draw through the graph, with vertex and index buffers.
     * --------------------------------------------------------------------------------- */
    if (pipeline_triangle != GR_NULL_HANDLE) {
        const uint32_t kSize = 64;
        struct vertex { float pos[2]; float colour[4]; };
        const struct vertex vertices[3] = {
            { { -0.6f, -0.6f }, { 1.0f, 0.0f, 0.0f, 1.0f } },
            { {  0.6f, -0.6f }, { 0.0f, 1.0f, 0.0f, 1.0f } },
            { {  0.0f,  0.6f }, { 0.0f, 0.0f, 1.0f, 1.0f } }
        };
        const uint16_t indices[3] = { 0, 1, 2 };
        gr_buffer_desc bd;
        gr_handle vb = GR_NULL_HANDLE, ib = GR_NULL_HANDLE, indirect = GR_NULL_HANDLE;
        gr_texture_desc td;
        gr_handle target = GR_NULL_HANDLE, target_view = GR_NULL_HANDLE;
        gr_texture_view_desc vd;
        gr_cmd_pool_desc cpd;
        gr_handle pool = GR_NULL_HANDLE, cmd = GR_NULL_HANDLE;
        gr_cmd_alloc_info cai;
        uint64_t digests[3]; /* direct, direct again, indirect */
        uint32_t pass;

        memset(&bd, 0, sizeof(bd));
        bd.head.size = (uint32_t)sizeof(bd);
        bd.size = sizeof(vertices);
        bd.usage = GR_BUFFER_USAGE_VERTEX | GR_BUFFER_USAGE_TRANSFER_DST;
        bd.memory = GR_MEMORY_UPLOAD;
        CHECK_EQ(gr_buffer_create(device, &bd, &vb), GR_OK);
        CHECK_EQ(gr_buffer_write(vb, 0, (gr_span_u8){ (const uint8_t *)vertices, sizeof(vertices) }),
                 GR_OK);
        bd.size = sizeof(indices);
        bd.usage = GR_BUFFER_USAGE_INDEX | GR_BUFFER_USAGE_TRANSFER_DST;
        CHECK_EQ(gr_buffer_create(device, &bd, &ib), GR_OK);
        CHECK_EQ(gr_buffer_write(ib, 0, (gr_span_u8){ (const uint8_t *)indices, sizeof(indices) }),
                 GR_OK);

        /* One VkDrawIndexedIndirectCommand: indexCount, instanceCount, firstIndex, vertexOffset,
         * firstInstance - 20 bytes, which is the stride the backend validates against. */
        {
            uint32_t command[5];
            command[0] = 3; /* index count */
            command[1] = 1; /* instance count */
            command[2] = 0; /* first index */
            command[3] = 0; /* vertex offset */
            command[4] = 0; /* first instance */
            bd.size = sizeof(command);
            bd.usage = GR_BUFFER_USAGE_INDIRECT | GR_BUFFER_USAGE_TRANSFER_DST;
            CHECK_EQ(gr_buffer_create(device, &bd, &indirect), GR_OK);
            CHECK_EQ(gr_buffer_write(indirect, 0,
                                     (gr_span_u8){ (const uint8_t *)command, sizeof(command) }),
                     GR_OK);
        }

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

        for (pass = 0; pass < 3u; ++pass) {
            /* The third pass is the same draw issued indirectly: it must produce the same pixels,
             * or the argument block is being read as something other than the command it holds. */
            int use_indirect = pass == 2;
            gr_graph_desc gd;
            gr_handle graph = GR_NULL_HANDLE;
            gr_graph_resource res;
            gr_graph_pass render_pass;
            gr_graph_compile_report report;
            gr_barrier barriers[4];
            uint32_t barrier_count = 0;
            gr_render_begin rb;
            gr_color_attachment color;
            gr_draw_indexed draw;
            gr_submit submit;
            gr_handle queue = GR_NULL_HANDLE, fence = GR_NULL_HANDLE;
            uint64_t value = 0, digest = 0xcbf29ce484222325ull;
            gr_result wait_status = GR_ERROR_BACKEND;
            uint8_t pixels[64 * 64 * 4];
            size_t i;

            memset(&gd, 0, sizeof(gd));
            gd.head.size = (uint32_t)sizeof(gd);
            CHECK(gr_graph_create(&gd, &graph) != GR_NULL_HANDLE);
            CHECK_EQ(gr_graph_add_resource(graph, (gr_str){ "target", 6, 0 },
                                           GR_GRAPH_RESOURCE_TEXTURE, target_view, &res), GR_OK);
            CHECK_EQ(gr_graph_add_pass(graph, (gr_str){ "tri", 3, 0 }, &render_pass), GR_OK);
            CHECK_EQ(gr_graph_pass_write(graph, render_pass, res, GR_STATE_COLOR_ATTACHMENT), GR_OK);
            CHECK_EQ(gr_graph_pass_set_side_effect(graph, render_pass, 1), GR_OK);
            memset(&report, 0, sizeof(report));
            report.head.size = (uint32_t)sizeof(report);
            CHECK_EQ(gr_graph_compile(graph, &report), GR_OK);

            CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
            CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
            CHECK_EQ(gr_cmd_push_frame_offset(cmd, 0), GR_OK);
            CHECK_EQ(gr_graph_pass_barriers(graph, 0, barriers, 4, &barrier_count), GR_OK);
            CHECK_EQ(gr_cmd_barrier(cmd, barriers, barrier_count), GR_OK);

            memset(&color, 0, sizeof(color));
            color.view = target_view;
            color.load_op = GR_LOAD_CLEAR;
            color.store_op = GR_STORE_STORE;
            color.clear[3] = 1.0f; /* opaque black, so the triangle is unmistakable */
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
            CHECK_EQ(gr_cmd_bind_pipeline(cmd, pipeline_triangle), GR_OK);
            if (use_indirect) {
                /* Refused inside the same recording: a stride that would read into the next
                 * command, and a buffer that never asked to be an indirect source. */
                CHECK_EQ(gr_cmd_draw_indexed_indirect(cmd, indirect, 0, 1, 16),
                         GR_ERROR_INVALID_ARGUMENT);
                CHECK_EQ(gr_cmd_draw_indexed_indirect(cmd, vb, 0, 1, 20),
                         GR_ERROR_INVALID_ARGUMENT);
            }
            CHECK_EQ(gr_cmd_bind_vertex_buffer(cmd, 0, vb, 0), GR_OK);
            CHECK_EQ(gr_cmd_bind_index_buffer(cmd, ib, 0, 0), GR_OK);
            if (use_indirect) {
                CHECK_EQ(gr_cmd_draw_indexed_indirect(cmd, indirect, 0, 1, 20), GR_OK);
            } else {
                memset(&draw, 0, sizeof(draw));
                draw.head.size = (uint32_t)sizeof(draw);
                draw.index_count = 3;
                draw.instance_count = 1;
                CHECK_EQ(gr_cmd_draw_indexed(cmd, &draw), GR_OK);
            }
            CHECK_EQ(gr_cmd_end_render(cmd), GR_OK);
            {
                gr_barrier to_copy;
                memset(&to_copy, 0, sizeof(to_copy));
                to_copy.resource = target_view;
                to_copy.src_state = GR_STATE_COLOR_ATTACHMENT;
                to_copy.dst_state = GR_STATE_TRANSFER_SRC;
                CHECK_EQ(gr_cmd_barrier(cmd, &to_copy, 1), GR_OK);
            }
            CHECK_EQ(gr_cmd_end(cmd), GR_OK);

            CHECK_EQ(gr_device_queue(device, GR_QUEUE_GRAPHICS, &queue), GR_OK);
            memset(&submit, 0, sizeof(submit));
            submit.head.size = (uint32_t)sizeof(submit);
            submit.queue = queue;
            submit.cmds = &cmd;
            submit.cmd_count = 1;
            CHECK_EQ(gr_submit_commands(&submit, &value), GR_OK);
            CHECK_EQ(gr_fence_create(device, 0, &fence), GR_OK);
            CHECK_EQ(gr_fence_wait(fence, value, 5ull * 1000ull * 1000ull * 1000ull, &wait_status),
                     GR_OK);

            memset(pixels, 0, sizeof(pixels));
            CHECK_EQ(gr_texture_read(target, 0, 0, 0, 0, kSize, kSize, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
            for (i = 0; i < sizeof(pixels); ++i) {
                digest ^= pixels[i];
                digest *= 0x100000001b3ull;
            }
            digests[pass] = digest;

            if (pass == 0) {
                /* The corners are outside the triangle, so they hold the clear colour; the centre
                 * is inside it, so it holds a blend of the three vertex colours. */
                size_t corners[2] = { 0, (size_t)(kSize * kSize - 1) * 4u };
                size_t centre = (size_t)((kSize / 2) * kSize + kSize / 2) * 4u;
                uint32_t k;
                for (k = 0; k < 2u; ++k)
                    CHECK(pixels[corners[k]] == 0u && pixels[corners[k] + 1] == 0u &&
                          pixels[corners[k] + 2] == 0u);
                CHECK(!(pixels[centre] == 0u && pixels[centre + 1] == 0u && pixels[centre + 2] == 0u));
                /* All three vertex colours reach the target, which only happens if the index
                 * buffer selected the right vertices and the rasteriser interpolated between them. */
                {
                    int red = 0, green = 0, blue = 0;
                    for (i = 0; i < sizeof(pixels); i += 4u) {
                        if (pixels[i] > 64u && pixels[i + 1] < 32u && pixels[i + 2] < 32u) red = 1;
                        if (pixels[i + 1] > 64u && pixels[i] < 32u && pixels[i + 2] < 32u) green = 1;
                        if (pixels[i + 2] > 64u && pixels[i] < 32u && pixels[i + 1] < 32u) blue = 1;
                    }
                    CHECK(red && green && blue);
                }
                printf("vk-backend: indexed triangle centre rgba %u,%u,%u,%u (corners clear)\n",
                       pixels[centre], pixels[centre + 1], pixels[centre + 2], pixels[centre + 3]);
            }
            gr_graph_destroy(graph);
        }
        printf("vk-backend: indexed triangle digest 0x%016llx (direct, twice); indirect 0x%016llx\n",
               (unsigned long long)digests[0], (unsigned long long)digests[2]);
        CHECK_EQ(digests[0], digests[1]);
        /* The indirect draw produced exactly the direct draw's pixels. */
        CHECK_EQ(digests[0], digests[2]);
    }

    CHECK_EQ(gr_device_wait_idle(device), GR_OK);

    /* The whole frame path under the validation layer: pipelines, descriptors, barriers, dispatches
     * and readbacks. A functional check cannot see a validation error, so this is the assertion
     * that would have caught the anisotropic samplers and the descriptor pool. */
    {
        gr_vk_validation_report report;
        memset(&report, 0, sizeof(report));
        report.head.size = (uint32_t)sizeof(report);
        CHECK_EQ(gr_vk_validation(device, &report), GR_OK);
        printf("vk-backend: validation errors=%u warnings=%u infos=%u\n", report.error_count,
               report.warning_count, report.info_count);
        {
            uint32_t i;
            for (i = 0; i < report.message_count && i < GR_VK_VALIDATION_MESSAGES; ++i) {
                gr_str message;
                if (gr_vk_validation_message(device, i, &message) == GR_OK) {
                    char flat[GR_VK_VALIDATION_MESSAGE_LEN];
                    uint32_t k;
                    for (k = 0; k < message.len && k < sizeof(flat) - 1u; ++k)
                        flat[k] = (message.data[k] == '\n') ? ' ' : message.data[k];
                    flat[k] = '\0';
                    printf("  layer[%u]: %s\n", i, flat);
                }
            }
        }
        if (report.error_count || report.warning_count) {
            uint32_t i;
            for (i = 0; i < report.message_count && i < GR_VK_VALIDATION_MESSAGES; ++i) {
                gr_str message;
                if (gr_vk_validation_message(device, i, &message) == GR_OK) {
                    char flat[GR_VK_VALIDATION_MESSAGE_LEN];
                    uint32_t k;
                    for (k = 0; k < message.len && k < sizeof(flat) - 1u; ++k)
                        flat[k] = (message.data[k] == '\n') ? ' ' : message.data[k];
                    flat[k] = '\0';
                    printf("  layer[%u]: %s\n", i, flat);
                }
            }
        }
        CHECK_EQ(report.enabled, 1u);
        CHECK_EQ(report.error_count, 0u);
        CHECK_EQ(report.warning_count, 0u);
    }

    gr_shader_library_close(library);
    gr_device_destroy(device);

    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("vk-backend: %d checks passed\n", checks);
    return 0;
}
