/* test_d3d12_backend.c - the D3D12 backend on a real device.
 *
 * Built for x86_64-windows with the MinGW-w64 headers and run under Wine, whose d3d12.dll is
 * vkd3d over the host's Vulkan driver; on Windows it runs as is. Two clears of one target must
 * read back the exact UNORM bytes of their clear colours, and every refusal the slice promises
 * is exercised: wrong source state, a render pass without the barrier, a recording list in a
 * submit, unsupported descriptors, and stale handles after gr_device_destroy. */
#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_shader.h"
#include "../include/grail/grail_bindless.h"
#include <stdio.h>
#include <string.h>

static int g_checks, g_failures;
#define CHECK(c) do { ++g_checks; if (!(c)) { ++g_failures; printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); } } while (0)
#define CHECK_EQ(a, b) do { long long a_ = (long long)(a), b_ = (long long)(b); ++g_checks; \
    if (a_ != b_) { ++g_failures; printf("FAIL %s:%d: %s == %lld, expected %lld\n", __FILE__, __LINE__, #a, a_, b_); } } while (0)

static gr_result record_clear(gr_handle cmd, gr_handle texture, gr_handle view, uint32_t from,
                              const float clear[4], uint32_t size)
{
    gr_barrier barrier;
    gr_color_attachment color;
    gr_render_begin rb;
    gr_result st;
    if ((st = gr_cmd_reset(cmd)) != GR_OK || (st = gr_cmd_begin(cmd)) != GR_OK)
        return st;
    memset(&barrier, 0, sizeof(barrier));
    barrier.resource = texture;
    barrier.src_state = from;
    barrier.dst_state = GR_STATE_COLOR_ATTACHMENT;
    if ((st = gr_cmd_barrier(cmd, &barrier, 1)) != GR_OK)
        return st;
    memset(&color, 0, sizeof(color));
    color.view = view;
    color.load_op = GR_LOAD_CLEAR;
    color.store_op = GR_STORE_STORE;
    memcpy(color.clear, clear, sizeof(color.clear));
    memset(&rb, 0, sizeof(rb));
    rb.head.size = (uint32_t)sizeof(rb);
    rb.colors = &color;
    rb.color_count = 1;
    rb.render_w = size;
    rb.render_h = size;
    if ((st = gr_cmd_begin_render(cmd, &rb)) != GR_OK || (st = gr_cmd_end_render(cmd)) != GR_OK)
        return st;
    barrier.src_state = GR_STATE_COLOR_ATTACHMENT;
    barrier.dst_state = GR_STATE_TRANSFER_SRC;
    if ((st = gr_cmd_barrier(cmd, &barrier, 1)) != GR_OK)
        return st;
    return gr_cmd_end(cmd);
}

int main(int argc, char **argv)
{
    const char *artifacts = argc > 1 ? argv[1] : "../../shaders";
    enum { kSize = 16 };
    static const float clears[2][4] = { { 0.25f, 0.5f, 0.75f, 1.0f }, { 1.0f, 0.0f, 0.5f, 0.0f } };
    static const uint8_t expect[2][4] = { { 64, 128, 191, 255 }, { 255, 0, 128, 0 } };
    gr_device_desc dd;
    gr_device_caps caps;
    gr_texture_desc td;
    gr_texture_view_desc vd;
    gr_cmd_pool_desc cpd;
    gr_cmd_alloc_info cai;
    gr_handle device = GR_NULL_HANDLE, other = GR_NULL_HANDLE, queue = GR_NULL_HANDLE;
    gr_handle texture = GR_NULL_HANDLE, view = GR_NULL_HANDLE, pool = GR_NULL_HANDLE;
    gr_handle cmd = GR_NULL_HANDLE, fence = GR_NULL_HANDLE, bad = GR_NULL_HANDLE;
    static uint8_t pixels[kSize * kSize * 4];
    uint32_t pass, i;

    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_D3D12;
    /* Wine's vkd3d stops at feature level 11_1; this slice needs nothing above 11_0. */
    dd.api_min_major = 11;
    CHECK_EQ(gr_device_create(&dd, &device), GR_OK);
    if (device == GR_NULL_HANDLE) {
        printf("d3d12-backend: no device\n");
        return 1;
    }
    memset(&caps, 0, sizeof(caps));
    caps.head.size = (uint32_t)sizeof(caps);
    CHECK_EQ(gr_device_get_caps(device, &caps), GR_OK);
    CHECK_EQ(caps.backend, GR_BACKEND_D3D12);
    CHECK(caps.api_major >= 11);
    CHECK_EQ(caps.depth_range_zero_to_one, 1);
    CHECK(caps.max_color_attachments == 8);
    printf("d3d12-backend: device \"%s\" vendor 0x%04x, feature level %u_%u\n", caps.device_name,
           caps.vendor_id, caps.api_major, caps.api_minor);

    /* One backend per process: a Vulkan device next to a D3D12 one is refused. */
    dd.backend = GR_BACKEND_VULKAN;
    CHECK_EQ(gr_device_create(&dd, &other), GR_ERROR_UNSUPPORTED);
    CHECK_EQ(gr_device_queue(device, GR_QUEUE_COMPUTE, &queue), GR_ERROR_UNSUPPORTED);
    CHECK_EQ(gr_device_queue(device, GR_QUEUE_GRAPHICS, &queue), GR_OK);

    memset(&td, 0, sizeof(td));
    td.head.size = (uint32_t)sizeof(td);
    td.type = GR_TEXTURE_2D;
    td.format = GR_FORMAT_R8G8B8A8_UNORM;
    td.width = kSize;
    td.height = kSize;
    td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_SAMPLED;
    CHECK_EQ(gr_texture_create(device, &td, &bad), GR_ERROR_UNSUPPORTED); /* no SRVs yet */
    td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
    CHECK_EQ(gr_texture_create(device, &td, &texture), GR_OK);
    memset(&vd, 0, sizeof(vd));
    vd.head.size = (uint32_t)sizeof(vd);
    vd.texture = texture;
    vd.type = GR_VIEW_2D;
    CHECK_EQ(gr_texture_view_create(device, &vd, &view), GR_OK);

    memset(&cpd, 0, sizeof(cpd));
    cpd.head.size = (uint32_t)sizeof(cpd);
    cpd.queue = GR_QUEUE_GRAPHICS;
    CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
    memset(&cai, 0, sizeof(cai));
    cai.head.size = (uint32_t)sizeof(cai);
    cai.pool = pool;
    CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);
    CHECK_EQ(gr_fence_create(device, 0, &fence), GR_OK);

    /* Refusals while recording: a source state that disagrees with the tracked one, and a
     * render pass on a target that was never transitioned. */
    {
        gr_barrier barrier;
        gr_color_attachment color;
        gr_render_begin rb;
        gr_submit submit;
        CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
        memset(&barrier, 0, sizeof(barrier));
        barrier.resource = texture;
        barrier.src_state = GR_STATE_TRANSFER_SRC;
        barrier.dst_state = GR_STATE_COLOR_ATTACHMENT;
        CHECK_EQ(gr_cmd_barrier(cmd, &barrier, 1), GR_ERROR_NOT_READY);
        memset(&color, 0, sizeof(color));
        color.view = view;
        color.load_op = GR_LOAD_CLEAR;
        memset(&rb, 0, sizeof(rb));
        rb.head.size = (uint32_t)sizeof(rb);
        rb.colors = &color;
        rb.color_count = 1;
        CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_ERROR_NOT_READY);
        memset(&submit, 0, sizeof(submit));
        submit.head.size = (uint32_t)sizeof(submit);
        submit.queue = queue;
        submit.cmds = &cmd;
        submit.cmd_count = 1;
        CHECK_EQ(gr_submit_commands(&submit, NULL), GR_ERROR_NOT_READY);
        CHECK_EQ(gr_cmd_end(cmd), GR_OK);
    }

    for (pass = 0; pass < 2; ++pass) {
        gr_submit submit;
        uint64_t value = 0;
        gr_result wait_status = GR_ERROR_BACKEND;
        uint32_t wrong = 0;
        CHECK_EQ(record_clear(cmd, texture, view, pass == 0 ? GR_STATE_UNDEFINED : GR_STATE_TRANSFER_SRC,
                              clears[pass], kSize), GR_OK);
        memset(&submit, 0, sizeof(submit));
        submit.head.size = (uint32_t)sizeof(submit);
        submit.queue = queue;
        submit.cmds = &cmd;
        submit.cmd_count = 1;
        CHECK_EQ(gr_submit_commands(&submit, &value), GR_OK);
        CHECK(value > 0);
        CHECK_EQ(gr_queue_submitted(queue), value);
        CHECK_EQ(gr_fence_wait(fence, value, 5000000000ull, &wait_status), GR_OK);
        CHECK_EQ(wait_status, GR_OK);
        CHECK(gr_queue_completed(queue) >= value);
        CHECK_EQ(gr_texture_read(texture, 0, 0, 0, 0, kSize, kSize, GR_STATE_COLOR_ATTACHMENT,
                                 (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_ERROR_NOT_READY);
        memset(pixels, 0xAB, sizeof(pixels));
        CHECK_EQ(gr_texture_read(texture, 0, 0, 0, 0, kSize, kSize, GR_STATE_TRANSFER_SRC,
                                 (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
        for (i = 0; i < kSize * kSize; ++i)
            if (memcmp(pixels + i * 4, expect[pass], 4) != 0)
                ++wrong;
        CHECK_EQ(wrong, 0);
        printf("d3d12-backend: clear (%.3f %.3f %.3f %.3f) reads back %u %u %u %u on all %u pixels\n",
               clears[pass][0], clears[pass][1], clears[pass][2], clears[pass][3], pixels[0], pixels[1],
               pixels[2], pixels[3], (unsigned)(kSize * kSize - wrong));
    }

    /* A sub-rectangle read honours the box and the tight row stride. */
    CHECK_EQ(gr_texture_read(texture, 0, 0, 3, 5, 2, 2, GR_STATE_TRANSFER_SRC,
                             (gr_mut_span_u8){ pixels, 16 }), GR_OK);
    CHECK(memcmp(pixels + 12, expect[1], 4) == 0);
    CHECK_EQ(gr_texture_read(texture, 0, 0, 15, 0, 2, 1, GR_STATE_TRANSFER_SRC,
                             (gr_mut_span_u8){ pixels, 8 }), GR_ERROR_INVALID_ARGUMENT);


    /* A real draw: the offline tool's DXIL for the full-screen triangle and the solid shader,
     * on the contract root signature, with the tint as push constants. Every pixel must be what
     * the shader computes: r = u, g = v, b = tint.b = 0.5, a = 1 at the pixel centre. */
    {
        enum { kDraw = 64 };
        static uint8_t frame[kDraw * kDraw * 4];
        gr_shader_library_desc ld;
        gr_handle library = GR_NULL_HANDLE, vs = GR_NULL_HANDLE, fs = GR_NULL_HANDLE;
        gr_handle pipeline = GR_NULL_HANDLE, refused = GR_NULL_HANDLE, target = GR_NULL_HANDLE;
        gr_handle target_view = GR_NULL_HANDLE, draw_cmd = GR_NULL_HANDLE;
        gr_pipeline_desc pd;
        gr_format color = GR_FORMAT_R8G8B8A8_UNORM;
        gr_str vs_name = { "core/fullscreen", 15, 0 };
        gr_str fs_name = { "core/solid", 10, 0 };
        float tint[4] = { 1.0f, 1.0f, 0.5f, 1.0f };
        gr_draw draw;
        gr_barrier barrier;
        gr_color_attachment attachment;
        gr_render_begin rb;
        gr_submit submit;
        gr_frame_constants constants;
        uint64_t value = 0;
        uint32_t count = 0, declared = 0, committed = 0, x, y, wrong = 0;
        gr_result wait_status = GR_ERROR_BACKEND;

        memset(&ld, 0, sizeof(ld));
        ld.head.size = (uint32_t)sizeof(ld);
        ld.root.data = artifacts;
        ld.root.len = (uint32_t)strlen(artifacts);
        CHECK_EQ(gr_shader_library_open(&ld, &library), GR_OK);
        CHECK(library != GR_NULL_HANDLE);
        CHECK_EQ(gr_shader_create_resolved(device, library, vs_name, GR_SHADER_STAGE_VERTEX, 0, &vs), GR_OK);
        CHECK_EQ(gr_shader_create_resolved(device, library, fs_name, GR_SHADER_STAGE_FRAGMENT, 0, &fs), GR_OK);

        memset(&pd, 0, sizeof(pd));
        pd.head.size = (uint32_t)sizeof(pd);
        pd.shaders[GR_SHADER_STAGE_VERTEX] = vs;
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fs;
        pd.color_formats = &color;
        pd.color_count = 1;
        pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
        pd.cull = GR_CULL_NONE;
        pd.front_face_ccw = 1;
        pd.samples = 4;
        CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_UNSUPPORTED); /* no MSAA yet */
        pd.samples = 1;
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = vs; /* a vertex shader in the fragment slot */
        CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_INVALID_ARGUMENT);
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fs;
        CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
        CHECK_EQ(gr_pipeline_stats(device, &declared, &committed), GR_OK);
        CHECK_EQ(declared, 1);
        CHECK_EQ(committed, 0);

        CHECK_EQ(gr_frame_slot_count(device, &count), GR_OK);
        CHECK_EQ(count, 2);
        memset(&constants, 0, sizeof(constants));
        CHECK_EQ(gr_frame_constants_write(device, 1, &constants), GR_OK);
        CHECK_EQ(gr_frame_constants_write(device, 2, &constants), GR_ERROR_INVALID_ARGUMENT);

        memset(&td, 0, sizeof(td));
        td.head.size = (uint32_t)sizeof(td);
        td.type = GR_TEXTURE_2D;
        td.format = GR_FORMAT_R8G8B8A8_UNORM;
        td.width = kDraw;
        td.height = kDraw;
        td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
        CHECK_EQ(gr_texture_create(device, &td, &target), GR_OK);
        memset(&vd, 0, sizeof(vd));
        vd.head.size = (uint32_t)sizeof(vd);
        vd.texture = target;
        vd.type = GR_VIEW_2D;
        CHECK_EQ(gr_texture_view_create(device, &vd, &target_view), GR_OK);
        CHECK_EQ(gr_cmd_alloc(&cai, &draw_cmd), GR_OK);

        CHECK_EQ(gr_cmd_begin(draw_cmd), GR_OK);
        CHECK_EQ(gr_cmd_push_constants(draw_cmd, 0, (gr_span_u8){ (const uint8_t *)tint, sizeof(tint) }),
                 GR_ERROR_NOT_READY); /* no pipeline bound yet */
        memset(&draw, 0, sizeof(draw));
        draw.head.size = (uint32_t)sizeof(draw);
        draw.vertex_count = 3;
        draw.instance_count = 1;
        CHECK_EQ(gr_cmd_draw(draw_cmd, &draw), GR_ERROR_NOT_READY);
        memset(&barrier, 0, sizeof(barrier));
        barrier.resource = target;
        barrier.src_state = GR_STATE_UNDEFINED;
        barrier.dst_state = GR_STATE_COLOR_ATTACHMENT;
        CHECK_EQ(gr_cmd_barrier(draw_cmd, &barrier, 1), GR_OK);
        memset(&attachment, 0, sizeof(attachment));
        attachment.view = target_view;
        attachment.load_op = GR_LOAD_CLEAR;
        attachment.store_op = GR_STORE_STORE;
        attachment.clear[3] = 1.0f;
        memset(&rb, 0, sizeof(rb));
        rb.head.size = (uint32_t)sizeof(rb);
        rb.colors = &attachment;
        rb.color_count = 1;
        CHECK_EQ(gr_cmd_begin_render(draw_cmd, &rb), GR_OK);
        CHECK_EQ(gr_cmd_bind_pipeline(draw_cmd, pipeline), GR_OK);
        CHECK_EQ(gr_cmd_push_frame_offset(draw_cmd, 1), GR_OK);
        CHECK_EQ(gr_cmd_push_constants(draw_cmd, 2, (gr_span_u8){ (const uint8_t *)tint, sizeof(tint) }),
                 GR_ERROR_INVALID_ARGUMENT); /* root constants are 32-bit aligned */
        CHECK_EQ(gr_cmd_push_constants(draw_cmd, 0, (gr_span_u8){ (const uint8_t *)tint, sizeof(tint) }), GR_OK);
        CHECK_EQ(gr_cmd_draw(draw_cmd, &draw), GR_OK);
        CHECK_EQ(gr_cmd_end_render(draw_cmd), GR_OK);
        barrier.src_state = GR_STATE_COLOR_ATTACHMENT;
        barrier.dst_state = GR_STATE_TRANSFER_SRC;
        CHECK_EQ(gr_cmd_barrier(draw_cmd, &barrier, 1), GR_OK);
        CHECK_EQ(gr_cmd_end(draw_cmd), GR_OK);
        memset(&submit, 0, sizeof(submit));
        submit.head.size = (uint32_t)sizeof(submit);
        submit.queue = queue;
        submit.cmds = &draw_cmd;
        submit.cmd_count = 1;
        CHECK_EQ(gr_submit_commands(&submit, &value), GR_OK);
        CHECK_EQ(gr_fence_wait(fence, value, 5000000000ull, &wait_status), GR_OK);
        CHECK_EQ(gr_texture_read(target, 0, 0, 0, 0, kDraw, kDraw, GR_STATE_TRANSFER_SRC,
                                 (gr_mut_span_u8){ frame, sizeof(frame) }), GR_OK);
        for (y = 0; y < kDraw; ++y)
            for (x = 0; x < kDraw; ++x) {
                const uint8_t *px = frame + ((size_t)y * kDraw + x) * 4;
                unsigned er = (unsigned)(((x + 0.5) / kDraw) * 255.0 + 0.5);
                unsigned eg = (unsigned)(((y + 0.5) / kDraw) * 255.0 + 0.5);
                if (px[0] != er || px[1] != eg || px[2] != 128 || px[3] != 255) {
                    if (wrong < 3)
                        printf("d3d12-backend: pixel %u,%u = %u %u %u %u, expected %u %u 128 255\n", x, y,
                               px[0], px[1], px[2], px[3], er, eg);
                    ++wrong;
                }
            }
        CHECK_EQ(wrong, 0);
        printf("d3d12-backend: draw %ux%u matches the shader on %u pixels (corners %u,%u,%u,%u / %u,%u,%u,%u)\n",
               kDraw, kDraw, (unsigned)(kDraw * kDraw - wrong), frame[0], frame[1], frame[2], frame[3],
               frame[sizeof(frame) - 4], frame[sizeof(frame) - 3], frame[sizeof(frame) - 2], frame[sizeof(frame) - 1]);
        gr_shader_library_close(library);
    }


    /* Vertex and index buffers through a reflected input layout, and reverse-Z depth: the same
     * indexed triangle is drawn near (z 0.75, green) and then far (z 0.25, red). With the depth
     * pipeline the far draw must be rejected inside the triangle; with the colour-only pipeline
     * it must win. The depth buffer must read back exactly 0.75 inside and 0.0 outside. */
    {
        enum { kTri = 64 };
        struct vertex { float pos[2]; float colour[4]; };
        static const struct vertex near_v[3] = { { { -0.6f, -0.6f }, { 0, 1, 0, 1 } },
                                                 { { 0.6f, -0.6f }, { 0, 1, 0, 1 } },
                                                 { { 0.0f, 0.6f }, { 0, 1, 0, 1 } } };
        static const struct vertex far_v[3] = { { { -0.6f, -0.6f }, { 1, 0, 0, 1 } },
                                                { { 0.6f, -0.6f }, { 1, 0, 0, 1 } },
                                                { { 0.0f, 0.6f }, { 1, 0, 0, 1 } } };
        static const uint16_t indices[3] = { 0, 1, 2 };
        static uint8_t rgba[kTri * kTri * 4];
        static float depth_values[kTri * kTri];
        gr_shader_library_desc ld;
        gr_handle library = GR_NULL_HANDLE, vs = GR_NULL_HANDLE, fs = GR_NULL_HANDLE;
        gr_handle with_depth = GR_NULL_HANDLE, colour_only = GR_NULL_HANDLE, refused = GR_NULL_HANDLE;
        gr_handle vb_near = GR_NULL_HANDLE, vb_far = GR_NULL_HANDLE, ib = GR_NULL_HANDLE, dev_buf = GR_NULL_HANDLE;
        gr_handle colour_tex = GR_NULL_HANDLE, colour_view = GR_NULL_HANDLE;
        gr_handle depth_tex = GR_NULL_HANDLE, depth_view = GR_NULL_HANDLE, cmd2 = GR_NULL_HANDLE;
        gr_vertex_binding binding = { 0, (uint32_t)sizeof(struct vertex), 0 };
        gr_vertex_attribute attrs[2];
        gr_pipeline_desc pd;
        gr_buffer_desc bd;
        gr_format color = GR_FORMAT_R8G8B8A8_UNORM;
        gr_str name = { "core/triangle", 13, 0 };
        uint32_t variant;
        uint8_t probe[4];

        memset(&ld, 0, sizeof(ld));
        ld.head.size = (uint32_t)sizeof(ld);
        ld.root.data = artifacts;
        ld.root.len = (uint32_t)strlen(artifacts);
        CHECK_EQ(gr_shader_library_open(&ld, &library), GR_OK);
        CHECK_EQ(gr_shader_create_resolved(device, library, name, GR_SHADER_STAGE_VERTEX, 0, &vs), GR_OK);
        CHECK_EQ(gr_shader_create_resolved(device, library, name, GR_SHADER_STAGE_FRAGMENT, 0, &fs), GR_OK);

        memset(&bd, 0, sizeof(bd));
        bd.head.size = (uint32_t)sizeof(bd);
        bd.size = sizeof(near_v);
        bd.usage = GR_BUFFER_USAGE_VERTEX;
        bd.memory = GR_MEMORY_UPLOAD;
        CHECK_EQ(gr_buffer_create(device, &bd, &vb_near), GR_OK);
        CHECK_EQ(gr_buffer_create(device, &bd, &vb_far), GR_OK);
        CHECK_EQ(gr_buffer_write(vb_near, 0, (gr_span_u8){ (const uint8_t *)near_v, sizeof(near_v) }), GR_OK);
        CHECK_EQ(gr_buffer_write(vb_far, 0, (gr_span_u8){ (const uint8_t *)far_v, sizeof(far_v) }), GR_OK);
        CHECK_EQ(gr_buffer_write(vb_far, 8, (gr_span_u8){ (const uint8_t *)far_v, sizeof(far_v) }),
                 GR_ERROR_INVALID_ARGUMENT); /* past the end */
        bd.size = sizeof(indices);
        bd.usage = GR_BUFFER_USAGE_INDEX;
        CHECK_EQ(gr_buffer_create(device, &bd, &ib), GR_OK);
        CHECK_EQ(gr_buffer_write(ib, 0, (gr_span_u8){ (const uint8_t *)indices, sizeof(indices) }), GR_OK);
        bd.memory = GR_MEMORY_DEVICE;
        CHECK_EQ(gr_buffer_create(device, &bd, &dev_buf), GR_OK);
        CHECK_EQ(gr_buffer_write(dev_buf, 0, (gr_span_u8){ (const uint8_t *)indices, sizeof(indices) }),
                 GR_ERROR_UNSUPPORTED); /* device memory needs a staging copy */
        bd.usage = GR_BUFFER_USAGE_STORAGE;
        CHECK_EQ(gr_buffer_create(device, &bd, &refused), GR_ERROR_UNSUPPORTED);

        memset(attrs, 0, sizeof(attrs));
        attrs[0].location = 0;
        attrs[0].binding = 0;
        attrs[0].format = GR_FORMAT_R32G32_FLOAT;
        attrs[0].offset = 0;
        attrs[1].location = 1;
        attrs[1].binding = 0;
        attrs[1].format = GR_FORMAT_R32G32B32A32_FLOAT;
        attrs[1].offset = 8;
        memset(&pd, 0, sizeof(pd));
        pd.head.size = (uint32_t)sizeof(pd);
        pd.shaders[GR_SHADER_STAGE_VERTEX] = vs;
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fs;
        pd.vertex_bindings = &binding;
        pd.vertex_binding_count = 1;
        pd.vertex_attributes = attrs;
        pd.vertex_attribute_count = 1; /* COLOR0 left unfed */
        pd.color_formats = &color;
        pd.color_count = 1;
        pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
        pd.cull = GR_CULL_NONE;
        pd.front_face_ccw = 1;
        pd.samples = 1;
        CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_INVALID_ARGUMENT);
        pd.vertex_attribute_count = 2;
        attrs[1].location = 7; /* a register the shader does not read */
        CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_INVALID_ARGUMENT);
        attrs[1].location = 1;
        CHECK_EQ(gr_pipeline_create(device, &pd, &colour_only), GR_OK);
        pd.depth_format = GR_FORMAT_D32_FLOAT;
        pd.depth_test = 1;
        pd.depth_write = 1;
        pd.depth_compare = GR_COMPARE_GREATER_EQUAL;
        CHECK_EQ(gr_pipeline_create(device, &pd, &with_depth), GR_OK);
        {
            /* Every pipeline is declared; the commit seals the set. */
            uint32_t declared = 0, committed = 0;
            CHECK_EQ(gr_pipeline_commit(device, NULL), GR_OK);
            CHECK_EQ(gr_pipeline_stats(device, &declared, &committed), GR_OK);
            CHECK_EQ(declared, 3);
            CHECK_EQ(committed, 3);
            CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_NOT_READY);
            CHECK_EQ(gr_pipeline_commit(device, NULL), GR_ERROR_NOT_READY);
        }

        memset(&td, 0, sizeof(td));
        td.head.size = (uint32_t)sizeof(td);
        td.type = GR_TEXTURE_2D;
        td.width = kTri;
        td.height = kTri;
        td.format = GR_FORMAT_R8G8B8A8_UNORM;
        td.usage = GR_TEXTURE_USAGE_COLOR_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
        CHECK_EQ(gr_texture_create(device, &td, &colour_tex), GR_OK);
        td.format = GR_FORMAT_D32_FLOAT;
        CHECK_EQ(gr_texture_create(device, &td, &refused), GR_ERROR_INVALID_ARGUMENT); /* depth as colour */
        td.usage = GR_TEXTURE_USAGE_DEPTH_ATTACHMENT | GR_TEXTURE_USAGE_TRANSFER_SRC;
        CHECK_EQ(gr_texture_create(device, &td, &depth_tex), GR_OK);
        memset(&vd, 0, sizeof(vd));
        vd.head.size = (uint32_t)sizeof(vd);
        vd.type = GR_VIEW_2D;
        vd.texture = colour_tex;
        CHECK_EQ(gr_texture_view_create(device, &vd, &colour_view), GR_OK);
        vd.texture = depth_tex;
        CHECK_EQ(gr_texture_view_create(device, &vd, &depth_view), GR_OK);
        CHECK_EQ(gr_cmd_alloc(&cai, &cmd2), GR_OK);

        for (variant = 0; variant < 2; ++variant) {
            gr_barrier barriers[2];
            gr_color_attachment ca;
            gr_depth_attachment da;
            gr_render_begin rb2;
            gr_draw_indexed di;
            gr_submit sub;
            uint64_t v = 0;
            gr_result ws = GR_ERROR_BACKEND;
            float z;
            uint32_t pass2;
            CHECK_EQ(gr_cmd_reset(cmd2), GR_OK);
            CHECK_EQ(gr_cmd_begin(cmd2), GR_OK);
            memset(barriers, 0, sizeof(barriers));
            barriers[0].resource = colour_tex;
            barriers[0].src_state = variant ? GR_STATE_TRANSFER_SRC : GR_STATE_UNDEFINED;
            barriers[0].dst_state = GR_STATE_COLOR_ATTACHMENT;
            barriers[1].resource = depth_tex;
            barriers[1].src_state = variant ? GR_STATE_TRANSFER_SRC : GR_STATE_UNDEFINED;
            barriers[1].dst_state = GR_STATE_DEPTH_ATTACHMENT_WRITE;
            CHECK_EQ(gr_cmd_barrier(cmd2, barriers, 2), GR_OK);
            memset(&ca, 0, sizeof(ca));
            ca.view = colour_view;
            ca.load_op = GR_LOAD_CLEAR;
            ca.store_op = GR_STORE_STORE;
            ca.clear[2] = 1.0f; /* blue background */
            ca.clear[3] = 1.0f;
            memset(&da, 0, sizeof(da));
            da.view = depth_view;
            da.load_op = GR_LOAD_CLEAR;
            da.store_op = GR_STORE_STORE;
            da.clear_depth = 0.0f; /* reverse-Z: the far plane */
            memset(&rb2, 0, sizeof(rb2));
            rb2.head.size = (uint32_t)sizeof(rb2);
            rb2.colors = &ca;
            rb2.color_count = 1;
            rb2.depth = &da;
            CHECK_EQ(gr_cmd_begin_render(cmd2, &rb2), GR_OK);
            CHECK_EQ(gr_cmd_bind_index_buffer(cmd2, ib, 1, 0), GR_ERROR_INVALID_ARGUMENT); /* misaligned */
            CHECK_EQ(gr_cmd_bind_vertex_buffer(cmd2, 0, vb_near, 0), GR_ERROR_NOT_READY); /* no pipeline */
            CHECK_EQ(gr_cmd_bind_pipeline(cmd2, variant ? colour_only : with_depth), GR_OK);
            CHECK_EQ(gr_cmd_bind_vertex_buffer(cmd2, 1, vb_near, 0), GR_ERROR_INVALID_ARGUMENT); /* no slot 1 */
            CHECK_EQ(gr_cmd_bind_index_buffer(cmd2, ib, 0, 0), GR_OK);
            memset(&di, 0, sizeof(di));
            di.head.size = (uint32_t)sizeof(di);
            di.index_count = 3;
            di.instance_count = 1;
            for (pass2 = 0; pass2 < 2; ++pass2) {
                z = pass2 == 0 ? 0.75f : 0.25f;
                CHECK_EQ(gr_cmd_bind_vertex_buffer(cmd2, 0, pass2 == 0 ? vb_near : vb_far, 0), GR_OK);
                CHECK_EQ(gr_cmd_push_constants(cmd2, 0, (gr_span_u8){ (const uint8_t *)&z, 4 }), GR_OK);
                CHECK_EQ(gr_cmd_draw_indexed(cmd2, &di), GR_OK);
            }
            CHECK_EQ(gr_cmd_end_render(cmd2), GR_OK);
            barriers[0].src_state = GR_STATE_COLOR_ATTACHMENT;
            barriers[0].dst_state = GR_STATE_TRANSFER_SRC;
            barriers[1].src_state = GR_STATE_DEPTH_ATTACHMENT_WRITE;
            barriers[1].dst_state = GR_STATE_TRANSFER_SRC;
            CHECK_EQ(gr_cmd_barrier(cmd2, barriers, 2), GR_OK);
            CHECK_EQ(gr_cmd_end(cmd2), GR_OK);
            memset(&sub, 0, sizeof(sub));
            sub.head.size = (uint32_t)sizeof(sub);
            sub.queue = queue;
            sub.cmds = &cmd2;
            sub.cmd_count = 1;
            CHECK_EQ(gr_submit_commands(&sub, &v), GR_OK);
            CHECK_EQ(gr_fence_wait(fence, v, 5000000000ull, &ws), GR_OK);
            CHECK_EQ(gr_texture_read(colour_tex, 0, 0, 0, 0, kTri, kTri, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ rgba, sizeof(rgba) }), GR_OK);
            CHECK_EQ(gr_texture_read(depth_tex, 0, 0, 0, 0, kTri, kTri, GR_STATE_TRANSFER_SRC,
                                     (gr_mut_span_u8){ (uint8_t *)depth_values, sizeof(depth_values) }), GR_OK);
            memcpy(probe, rgba + ((size_t)(kTri / 2) * kTri + kTri / 2) * 4, 4);
            if (variant == 0) {
                /* Depth test on: the near green triangle survives the far red one. */
                CHECK(probe[0] == 0 && probe[1] == 255 && probe[2] == 0 && probe[3] == 255);
                CHECK(depth_values[(kTri / 2) * kTri + kTri / 2] == 0.75f);
            } else {
                /* Colour-only: the later red draw wins; depth keeps what was cleared. */
                CHECK(probe[0] == 255 && probe[1] == 0 && probe[2] == 0 && probe[3] == 255);
                CHECK(depth_values[(kTri / 2) * kTri + kTri / 2] == 0.0f);
            }
            /* Outside the triangle: the blue clear, the far plane. */
            CHECK(rgba[0] == 0 && rgba[1] == 0 && rgba[2] == 255 && rgba[3] == 255);
            CHECK(depth_values[0] == 0.0f);
            printf("d3d12-backend: indexed %s: centre %u %u %u %u depth %.2f, corner %u %u %u depth %.2f\n",
                   variant ? "colour-only" : "depth-tested", probe[0], probe[1], probe[2], probe[3],
                   depth_values[(kTri / 2) * kTri + kTri / 2], rgba[0], rgba[1], rgba[2], depth_values[0]);
        }
        gr_shader_library_close(library);
    }

    CHECK_EQ(gr_device_wait_idle(device), GR_OK);
    gr_device_destroy(device);
    /* The device released everything it owned: every handle is now stale. */
    CHECK_EQ(gr_cmd_begin(cmd), GR_ERROR_INVALID_HANDLE);
    CHECK_EQ(gr_texture_read(texture, 0, 0, 0, 0, 1, 1, GR_STATE_TRANSFER_SRC,
                             (gr_mut_span_u8){ pixels, 4 }), GR_ERROR_INVALID_HANDLE);
    CHECK_EQ(gr_queue_submitted(queue), 0);

    printf("d3d12-backend: %d checks, %d failures\n", g_checks, g_failures);
    return g_failures != 0;
}
