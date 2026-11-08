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
        pd.depth_format = GR_FORMAT_D32_FLOAT;
        pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
        pd.cull = GR_CULL_NONE;
        pd.front_face_ccw = 1;
        pd.samples = 1;
        CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_UNSUPPORTED); /* no depth yet */
        pd.depth_format = GR_FORMAT_UNDEFINED;
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = vs; /* a vertex shader in the fragment slot */
        CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_INVALID_ARGUMENT);
        pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fs;
        CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
        CHECK_EQ(gr_pipeline_commit(device, NULL), GR_OK);
        CHECK_EQ(gr_pipeline_stats(device, &declared, &committed), GR_OK);
        CHECK_EQ(declared, 1);
        CHECK_EQ(committed, 1);
        CHECK_EQ(gr_pipeline_create(device, &pd, &refused), GR_ERROR_NOT_READY); /* sealed */

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
