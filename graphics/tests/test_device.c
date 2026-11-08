/* test_device.c - the null backend end to end: window, device, resources, recording,
 * submission, retirement. This is the test that proves the ABI is implementable and that a
 * caller's plumbing (create, record, submit, release) is exercised on a machine with no
 * GPU and no display. */
#include "../include/grail/grail_bindless.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_window.h"
#include "../include/grail/grail_shader.h"

/* From grail_internal.h; the push-constant stage derivation is pure, so it is tested without a
 * device. */
uint32_t gr_push_constant_stage_mask(const uint32_t *range_offsets, const uint32_t *range_sizes,
                                    const uint32_t *range_stages, uint32_t range_count,
                                    uint32_t offset, uint32_t size);

#include <stdio.h>
#include <string.h>

/* The null backend's test hook (grail_null_window.c), deliberately not in a public header. */
gr_result gr_null_window_inject(gr_handle window, const gr_event *event);

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

static uint32_t log_count;
static void on_log(void *user, int32_t severity, gr_str message)
{
    (void)user; (void)severity; (void)message;
    log_count++;
}

static void test_window(void)
{
    gr_window_desc wd;
    gr_handle window = GR_NULL_HANDLE;
    gr_window_size size;
    gr_input_state input;
    gr_event events[4];
    uint32_t count = 7;
    size_t text_used = 99;
    gr_present_mode mode;
    gr_display_info display;

    memset(&wd, 0, sizeof(wd));
    wd.head.size = (uint32_t)sizeof(wd);
    wd.title = (gr_str)GR_STR("grail test");
    wd.width = 640;
    wd.height = 360;
    wd.flags = GR_WINDOW_RESIZABLE | GR_WINDOW_HIGH_DPI;
    CHECK_EQ(gr_window_create(&wd, &window), GR_OK);
    CHECK(gr_handle_has_type(window, GR_HANDLE_WINDOW));

    CHECK_EQ(gr_window_get_size(window, &size), GR_OK);
    CHECK_EQ(size.logical_width, 640u);
    CHECK_EQ(size.pixel_width, 640u);
    CHECK(size.scale == 1.0f);

    /* An empty drain reports zero and succeeds. */
    CHECK_EQ(gr_window_pump(window, events, 4, &count, (gr_mut_span_u8){ NULL, 0 }, &text_used),
             GR_OK);
    CHECK_EQ(count, 0u);

    /* An injected resize is drained in order and moves the pixel size. */
    {
        gr_event resize;
        memset(&resize, 0, sizeof(resize));
        resize.type = GR_EVENT_RESIZED;
        resize.a = 1280;
        resize.b = 720;
        CHECK_EQ(gr_null_window_inject(window, &resize), GR_OK);
        CHECK_EQ(gr_window_pump(window, events, 4, &count, (gr_mut_span_u8){ NULL, 0 }, &text_used),
                 GR_OK);
        CHECK_EQ(count, 1u);
        CHECK_EQ(events[0].type, GR_EVENT_RESIZED);
        CHECK_EQ(events[0].a, 1280);
        CHECK_EQ(gr_window_get_size(window, &size), GR_OK);
        CHECK_EQ(size.pixel_width, 1280u);
        CHECK_EQ(size.logical_width, 640u); /* the two are genuinely distinct */
    }

    /* Minimising reports zero pixels, which is the signal to skip presenting. */
    {
        gr_event min;
        memset(&min, 0, sizeof(min));
        min.type = GR_EVENT_MINIMISED;
        min.a = 1;
        CHECK_EQ(gr_null_window_inject(window, &min), GR_OK);
        CHECK_EQ(gr_window_pump(window, events, 4, &count, (gr_mut_span_u8){ NULL, 0 }, &text_used), GR_OK);
        CHECK_EQ(gr_window_get_size(window, &size), GR_OK);
        CHECK_EQ(size.pixel_width, 0u);
    }

    memset(&input, 0, sizeof(input));
    input.head.size = (uint32_t)sizeof(input);
    CHECK_EQ(gr_window_input_state(window, &input), GR_OK);
    CHECK_EQ(input.frame, 0u);          /* first snapshot */
    CHECK_EQ(gr_window_set_relative_mouse(window, 1), GR_OK);
    CHECK_EQ(gr_window_input_state(window, &input), GR_OK);
    CHECK_EQ(input.relative_mouse, 1u);
    CHECK_EQ(input.frame, 1u);

    CHECK_EQ(gr_window_resolve_present_mode(window, GR_PRESENT_MAILBOX, &mode), GR_OK);
    CHECK_EQ(mode, GR_PRESENT_MAILBOX);
    CHECK_EQ(gr_window_display_query(0, &display), GR_OK);
    CHECK(display.refresh_hz > 0.0f);
    CHECK_EQ(gr_window_display_query(5, &display), GR_ERROR_INVALID_ARGUMENT);
    CHECK(gr_window_display_count() >= 1u);
    CHECK_EQ(gr_window_key_down(window, GR_KEY_ESCAPE), 0);
    gr_window_destroy(window);
}

static void test_device_and_resources(void)
{
    gr_device_desc dd;
    gr_handle device = GR_NULL_HANDLE;
    gr_device_caps caps;
    gr_buffer_desc bd;
    gr_handle buffer = GR_NULL_HANDLE;
    gr_texture_desc td;
    gr_handle texture = GR_NULL_HANDLE;
    uint8_t out[16];

    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_NULL;
    dd.flags = GR_DEVICE_HEADLESS;
    dd.app_name = (gr_str)GR_STR("grail test");
    dd.log = on_log;
    CHECK_EQ(gr_device_create(&dd, &device), GR_OK);
    CHECK(gr_handle_has_type(device, GR_HANDLE_DEVICE));
    CHECK(log_count > 0u);

    /* A backend this build does not implement is refused, not substituted. */
    dd.backend = GR_BACKEND_D3D12;
    {
        gr_handle other = GR_NULL_HANDLE;
        CHECK_EQ(gr_device_create(&dd, &other), GR_ERROR_UNSUPPORTED);
        CHECK(gr_handle_is_null(other));
    }
    /* A descriptor whose declared size is not this ABI's is refused. */
    dd.backend = GR_BACKEND_NULL;
    {
        gr_handle other = GR_NULL_HANDLE;
        dd.head.size = 8;
        CHECK_EQ(gr_device_create(&dd, &other), GR_ERROR_VERSION_MISMATCH);
        dd.head.size = (uint32_t)sizeof(dd);
    }

    memset(&caps, 0, sizeof(caps));
    caps.head.size = (uint32_t)sizeof(caps);
    CHECK_EQ(gr_device_get_caps(device, &caps), GR_OK);
    CHECK((caps.caps & GR_CAP_BINDLESS) != 0);
    CHECK((caps.caps & GR_CAP_DYNAMIC_RENDERING) != 0);
    CHECK_EQ(caps.max_push_constant_bytes, GR_PUSH_CONSTANT_BYTES);
    CHECK(caps.device_name[0] != '\0');
    CHECK_EQ(caps.depth_range_zero_to_one, 0u); /* reverse-Z by default */

    /* Buffer round trip through host-visible memory. */
    memset(&bd, 0, sizeof(bd));
    bd.head.size = (uint32_t)sizeof(bd);
    bd.size = 64;
    bd.usage = GR_BUFFER_USAGE_VERTEX | GR_BUFFER_USAGE_STORAGE;
    bd.memory = GR_MEMORY_UPLOAD;
    bd.name = (gr_str)GR_STR("test vertex buffer");
    CHECK_EQ(gr_buffer_create(device, &bd, &buffer), GR_OK);
    CHECK_EQ(gr_buffer_write(buffer, 0, (gr_span_u8){ (const uint8_t *)"hello", 5 }), GR_OK);
    memset(out, 0, sizeof(out));
    CHECK_EQ(gr_buffer_read(buffer, 0, (gr_mut_span_u8){ out, 5 }), GR_OK);
    CHECK(memcmp(out, "hello", 5) == 0);
    /* Out-of-range access is refused with a specific status. */
    CHECK_EQ(gr_buffer_write(buffer, 62, (gr_span_u8){ (const uint8_t *)"abc", 3 }),
             GR_ERROR_INVALID_ARGUMENT);
    CHECK(gr_buffer_bindless_index(buffer) != GR_BINDLESS_INDEX_NONE);

    /* A device-memory buffer is not host-writable: the status says so instead of silently
     * discarding the write. */
    {
        gr_handle dev_buffer = GR_NULL_HANDLE;
        bd.memory = GR_MEMORY_DEVICE;
        bd.usage = GR_BUFFER_USAGE_UNIFORM;
        CHECK_EQ(gr_buffer_create(device, &bd, &dev_buffer), GR_OK);
        CHECK_EQ(gr_buffer_write(dev_buffer, 0, (gr_span_u8){ (const uint8_t *)"x", 1 }),
                 GR_ERROR_UNSUPPORTED);
        CHECK_EQ(gr_buffer_device_address(dev_buffer), 0u);
        gr_device_retire(device, dev_buffer, 0);
    }

    /* Texture round trip: a 4x4 RGBA8 image, one row. */
    memset(&td, 0, sizeof(td));
    td.head.size = (uint32_t)sizeof(td);
    td.type = GR_TEXTURE_2D;
    td.format = GR_FORMAT_R8G8B8A8_UNORM;
    td.width = 4;
    td.height = 4;
    td.usage = GR_TEXTURE_USAGE_SAMPLED | GR_TEXTURE_USAGE_TRANSFER_DST;
    CHECK_EQ(gr_texture_create(device, &td, &texture), GR_OK);
    {
        uint8_t pixels[4 * 4 * 4];
        uint8_t readback[sizeof(pixels)];
        uint32_t i;
        for (i = 0; i < sizeof(pixels); ++i)
            pixels[i] = (uint8_t)i;
        CHECK_EQ(gr_texture_write(texture, 0, 0, 0, 0, 4, 4,
                                  (gr_span_u8){ pixels, sizeof(pixels) }), GR_OK);
        memset(readback, 0, sizeof(readback));
        CHECK_EQ(gr_texture_read(texture, 0, 0, 0, 0, 4, 4, GR_STATE_GENERAL,
                                 (gr_mut_span_u8){ readback, sizeof(readback) }), GR_OK);
        CHECK(memcmp(pixels, readback, sizeof(pixels)) == 0);
        /* A wrong-size destination is refused rather than partially filled. */
        CHECK_EQ(gr_texture_read(texture, 0, 0, 0, 0, 4, 4, GR_STATE_GENERAL, (gr_mut_span_u8){ readback, 3 }),
                 GR_ERROR_INVALID_ARGUMENT);
        /* A mip that does not exist is refused. */
        CHECK_EQ(gr_texture_write(texture, 9, 0, 0, 0, 1, 1, (gr_span_u8){ pixels, 4 }),
                 GR_ERROR_INVALID_ARGUMENT);
    }

    /* A view of the texture claims a bindless slot, which is the only way a shader reaches
     * it. */
    {
        gr_texture_view_desc vd;
        gr_handle view = GR_NULL_HANDLE;
        uint32_t slot;
        memset(&vd, 0, sizeof(vd));
        vd.head.size = (uint32_t)sizeof(vd);
        vd.texture = texture;
        vd.type = GR_VIEW_2D;
        vd.format = GR_FORMAT_UNDEFINED;
        CHECK_EQ(gr_texture_view_create(device, &vd, &view), GR_OK);
        slot = gr_texture_view_bindless_sampled(view);
        CHECK(slot != GR_BINDLESS_INDEX_NONE);
        CHECK_EQ(gr_texture_view_bindless_storage(view), GR_BINDLESS_INDEX_NONE);
        gr_device_retire(device, view, 0);
    }

    /* A second sampler lands after the thirteen fixed slots. */
    {
        gr_sampler_desc sd;
        gr_handle sampler = GR_NULL_HANDLE;
        uint32_t slot = 0;
        memset(&sd, 0, sizeof(sd));
        sd.head.size = (uint32_t)sizeof(sd);
        sd.min_filter = GR_FILTER_LINEAR;
        sd.mag_filter = GR_FILTER_LINEAR;
        sd.mip_filter = GR_FILTER_LINEAR;
        sd.max_anisotropy = 8.0f;
        sd.max_lod = 100.0f;
        CHECK_EQ(gr_sampler_create(device, &sd, &sampler, &slot), GR_OK);
        CHECK_EQ(slot, (uint32_t)GR_SAMPLER_SLOT_COUNT);
    }

    {
        gr_bindless_info info;
        memset(&info, 0, sizeof(info));
        info.head.size = (uint32_t)sizeof(info);
        CHECK_EQ(gr_bindless_get_info(gr_device_bindless(device), &info), GR_OK);
        CHECK_EQ(info.capacity[GR_TABLE_SAMPLED_IMAGES], GR_BINDLESS_CAP_SAMPLED_IMAGES);
        CHECK(info.high_water[GR_TABLE_SAMPLERS] >= (uint32_t)GR_SAMPLER_SLOT_COUNT);
        CHECK(info.high_water[GR_TABLE_SAMPLED_IMAGES] >= 1u);
    }

    /* Retirement then collection invalidates the handle: the stale-handle property. */
    CHECK_EQ(gr_device_retire(device, buffer, 0), GR_OK);
    CHECK_EQ(gr_buffer_read(buffer, 0, (gr_mut_span_u8){ out, 4 }), GR_ERROR_INVALID_HANDLE);
    gr_device_destroy(device);
}

static void test_recording(void)
{
    gr_device_desc dd;
    gr_handle device = GR_NULL_HANDLE;
    gr_cmd_pool_desc pd;
    gr_handle pool = GR_NULL_HANDLE;
    gr_cmd_alloc_info ai;
    gr_handle cmd = GR_NULL_HANDLE;
    gr_render_begin rb;
    gr_color_attachment color;
    gr_draw draw;
    float clear[4] = { 0.0f, 0.0f, 0.0f, 1.0f };

    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_NULL;
    dd.flags = GR_DEVICE_HEADLESS;
    CHECK_EQ(gr_device_create(&dd, &device), GR_OK);

    memset(&pd, 0, sizeof(pd));
    pd.head.size = (uint32_t)sizeof(pd);
    pd.queue = GR_QUEUE_GRAPHICS;
    CHECK_EQ(gr_cmd_pool_create(device, &pd, &pool), GR_OK);

    memset(&ai, 0, sizeof(ai));
    ai.head.size = (uint32_t)sizeof(ai);
    ai.pool = pool;
    CHECK_EQ(gr_cmd_alloc(&ai, &cmd), GR_OK);

    /* Recording order is enforced: a draw outside a render scope and without a pipeline is
     * NOT_READY, not an assertion and not a hang. */
    memset(&draw, 0, sizeof(draw));
    draw.head.size = (uint32_t)sizeof(draw);
    draw.vertex_count = 3;
    draw.instance_count = 1;
    CHECK_EQ(gr_cmd_draw(cmd, &draw), GR_ERROR_NOT_READY); /* not recording yet */

    CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
    CHECK_EQ(gr_cmd_begin(cmd), GR_ERROR_NOT_READY);       /* already recording */
    CHECK_EQ(gr_cmd_push_frame_offset(cmd, 0), GR_OK);
    CHECK_EQ(gr_cmd_push_frame_offset(cmd, 99), GR_ERROR_INVALID_ARGUMENT);
    CHECK_EQ(gr_cmd_push_constants(cmd, 0,
                                   (gr_span_u8){ (const uint8_t *)"0123456789abcdef", 16 }), GR_OK);
    CHECK_EQ(gr_cmd_push_constants(cmd, 120,
                                   (gr_span_u8){ (const uint8_t *)"0123456789", 10 }),
             GR_ERROR_INVALID_ARGUMENT);                    /* exceeds 128 bytes */

    memset(&color, 0, sizeof(color));
    color.view = GR_NULL_HANDLE;
    color.load_op = GR_LOAD_CLEAR;
    memcpy(color.clear, clear, sizeof(clear));
    memset(&rb, 0, sizeof(rb));
    rb.head.size = (uint32_t)sizeof(rb);
    rb.colors = &color;
    rb.color_count = 1;
    CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_OK);
    CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_ERROR_VALIDATION_FAILED); /* not re-entrant */
    CHECK_EQ(gr_cmd_set_viewport(cmd, 0.0f, 0.0f, 1280.0f, 720.0f, 0.0f, 1.0f), GR_OK);
    CHECK_EQ(gr_cmd_set_viewport(cmd, 0.0f, 0.0f, 0.0f, 720.0f, 0.0f, 1.0f),
             GR_ERROR_INVALID_ARGUMENT);
    CHECK_EQ(gr_cmd_set_scissor(cmd, 0, 0, 1280, 720), GR_OK);
    CHECK_EQ(gr_cmd_begin_scope(cmd, (gr_str)GR_STR("tonemap")), GR_OK);
    /* Still no pipeline bound: the draw is refused. */
    CHECK_EQ(gr_cmd_draw(cmd, &draw), GR_ERROR_NOT_READY);
    CHECK_EQ(gr_cmd_end_scope(cmd), GR_OK);
    CHECK_EQ(gr_cmd_end_scope(cmd), GR_ERROR_VALIDATION_FAILED);
    CHECK_EQ(gr_cmd_end_render(cmd), GR_OK);
    CHECK_EQ(gr_cmd_end_render(cmd), GR_ERROR_VALIDATION_FAILED);
    CHECK_EQ(gr_cmd_end(cmd), GR_OK);

    /* Submission advances the timeline; the value is observable. */
    {
        gr_submit submit;
        gr_handle queue = GR_NULL_HANDLE;
        uint64_t value = 0;
        CHECK_EQ(gr_device_queue(device, GR_QUEUE_GRAPHICS, &queue), GR_OK);
        memset(&submit, 0, sizeof(submit));
        submit.head.size = (uint32_t)sizeof(submit);
        submit.queue = queue;
        submit.cmds = &cmd;
        submit.cmd_count = 1;
        CHECK_EQ(gr_submit_commands(&submit, &value), GR_OK);
        CHECK(value > 0u);
        CHECK_EQ(gr_queue_submitted(queue), value);
        CHECK_EQ(gr_queue_completed(queue), value);
        /* A command buffer cannot be submitted twice without a reset. */
        CHECK_EQ(gr_submit_commands(&submit, &value), GR_ERROR_NOT_READY);
        CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
        CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
        CHECK_EQ(gr_cmd_end(cmd), GR_OK);
    }

    /* A command buffer left open is refused at end(). */
    CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
    CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
    CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_OK);
    CHECK_EQ(gr_cmd_end(cmd), GR_ERROR_VALIDATION_FAILED);

    gr_device_destroy(device);
}

static void test_pipeline_and_swapchain(void)
{
    gr_device_desc dd;
    gr_handle device = GR_NULL_HANDLE;
    gr_pipeline_desc pdesc;
    gr_handle pipeline = GR_NULL_HANDLE;
    gr_swapchain_desc sd;
    gr_handle swapchain = GR_NULL_HANDLE;
    double seconds = -1.0;
    uint32_t declared = 0, committed = 0;

    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_NULL;
    dd.flags = GR_DEVICE_HEADLESS;
    CHECK_EQ(gr_device_create(&dd, &device), GR_OK);

    /* A pipeline with no shaders is refused: the stage set must be coherent. */
    memset(&pdesc, 0, sizeof(pdesc));
    pdesc.head.size = (uint32_t)sizeof(pdesc);
    pdesc.name = (gr_str)GR_STR("broken");
    CHECK_EQ(gr_pipeline_create(device, &pdesc, &pipeline), GR_ERROR_INVALID_ARGUMENT);

    /* A compute pipeline with no shader handle is refused. */
    pdesc.shaders[GR_SHADER_STAGE_COMPUTE] = GR_NULL_HANDLE;
    CHECK_EQ(gr_pipeline_create(device, &pdesc, &pipeline), GR_ERROR_INVALID_ARGUMENT);

    /* Commit closes the registry: no pipeline may be added after it. */
    CHECK_EQ(gr_pipeline_commit(device, &seconds), GR_OK);
    CHECK(seconds >= 0.0);
    CHECK_EQ(gr_pipeline_commit(device, &seconds), GR_ERROR_NOT_READY);
    CHECK_EQ(gr_pipeline_create(device, &pdesc, &pipeline), GR_ERROR_NOT_READY);
    CHECK_EQ(gr_pipeline_stats(device, &declared, &committed), GR_OK);
    CHECK_EQ(declared, committed);

    /* A headless swapchain needs no window; a windowed one without a window is refused. */
    memset(&sd, 0, sizeof(sd));
    sd.head.size = (uint32_t)sizeof(sd);
    sd.width = 1920;
    sd.height = 1080;
    sd.present_mode = GR_PRESENT_FIFO;
    CHECK_EQ(gr_swapchain_create(device, &sd, &swapchain), GR_OK);
    {
        gr_format format = GR_FORMAT_UNDEFINED;
        uint32_t w = 0, h = 0, n = 0;
        CHECK_EQ(gr_swapchain_info(swapchain, &format, &w, &h, &n), GR_OK);
        CHECK_EQ(w, 1920u);
        CHECK_EQ(h, 1080u);
        CHECK(n >= 2u);
        CHECK_EQ(format, GR_FORMAT_B8G8R8A8_UNORM);
    }
    {
        uint32_t index = 99;
        gr_handle view = GR_NULL_HANDLE;
        int32_t recreate = 1;
        CHECK_EQ(gr_swapchain_acquire(swapchain, 0, &index, &view, &recreate), GR_OK);
        CHECK_EQ(recreate, 0);
        CHECK(index < 4u);
    }
    CHECK_EQ(gr_swapchain_recreate(swapchain, 800, 600, 0), GR_OK);
    gr_device_destroy(device);
}

/* The push-constant stage mask is derived from the layout's declared ranges, so a write naming a
 * narrower (or wider) set of stages is impossible by construction. Vulkan stage bits are used as
 * plain integers here: the function takes and returns masks, not Vulkan types. */
static void test_push_constant_stages(void)
{
    const uint32_t kVertex = 0x1u, kFragment = 0x2u, kCompute = 0x4u, kAll = 0x7FFFFFFFu;

    /* The layout the backend actually declares: one range covering every stage. */
    {
        uint32_t offsets[1] = { 0 }, sizes[1] = { 128 }, stages[1] = { kAll };
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 1, 0, 16), kAll);
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 1, 112, 16), kAll);
    }
    /* A layout split into two ranges with disjoint stages, which is what a caller would use to give
     * the vertex and fragment stages different constants at the same offsets. */
    {
        uint32_t offsets[2] = { 0, 8 }, sizes[2] = { 8, 8 }, stages[2] = { kVertex, kCompute };
        /* Exactly the declared stages for each half. */
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 2, 0, 8), kVertex);
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 2, 8, 8), kCompute);
        /* A write spanning both names both, because it touches both declared ranges. */
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 2, 0, 16),
                 kVertex | kCompute);
        /* A partial overlap still names the range it touches. */
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 2, 4, 8), kVertex | kCompute);
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 2, 0, 4), kVertex);
        /* Beyond every range there is nothing to name, and the backend refuses that as a
         * programming error rather than writing bytes no stage can read. */
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 2, 16, 4), 0u);
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 2, 100, 4), 0u);
    }
    /* Three ranges, to show the union is over all of them rather than the first match. */
    {
        uint32_t offsets[3] = { 0, 0, 32 }, sizes[3] = { 16, 16, 16 };
        uint32_t stages[3] = { kVertex, kFragment, kCompute };
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 3, 0, 16),
                 kVertex | kFragment);
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 3, 0, 48),
                 kVertex | kFragment | kCompute);
    }
    /* A zero-length write names nothing. */
    {
        uint32_t offsets[1] = { 0 }, sizes[1] = { 16 }, stages[1] = { kAll };
        CHECK_EQ(gr_push_constant_stage_mask(offsets, sizes, stages, 1, 0, 0), 0u);
    }
}

int main(void)
{
    test_push_constant_stages();
    test_window();
    test_device_and_resources();
    test_recording();
    test_pipeline_and_swapchain();
    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("device: %d checks passed\n", checks);
    return 0;
}
