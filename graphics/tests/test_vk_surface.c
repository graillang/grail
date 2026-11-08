/* test_vk_surface.c - an SDL3 window and a Vulkan surface on top of it.
 *
 * The first piece of the window path: create a hidden SDL3 window, create a Vulkan instance that
 * carries the platform's surface extensions and the validation layer, make a VkSurfaceKHR from the
 * window, and destroy both. No swapchain yet.
 *
 * Skips (exit 0) when SDL3, a display or a device is missing, so the suite still runs anywhere.
 * `make vk-surface` runs it under the exclusive GPU lock with the validation layer pointed at the
 * pinned SDK, which is where VK_LAYER_KHRONOS_validation lives on this host.
 */
#include "../include/grail/grail_backend_vulkan.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_window.h"
#include "../include/grail/grail_graph.h"
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

static int32_t last_severity = -1;
static void on_log(void *user, int32_t severity, gr_str message)
{
    (void)user;
    last_severity = severity;
    fprintf(stderr, "grail[%d]: %.*s\n", (int)severity, (int)message.len, message.data);
}

int main(void)
{
    gr_window_desc wd;
    gr_handle window = GR_NULL_HANDLE;
    gr_window_size size;
    gr_device_desc dd;
    gr_handle device = GR_NULL_HANDLE;
    void *instance = NULL, *physical = NULL, *surface = NULL;
    uint32_t extension_count = 0;
    const char *const *extensions = NULL;

    /* The null window backend is the default; this test opts into SDL3 explicitly. A machine
     * without SDL3, or without a display, skips rather than fails. */
    if (gr_window_set_backend(GR_WINDOW_BACKEND_SDL3) != GR_OK) {
        printf("vk-surface: skipped (SDL3 unavailable)\n");
        return 0;
    }

    memset(&wd, 0, sizeof(wd));
    wd.head.size = (uint32_t)sizeof(wd);
    wd.title.data = "grail-surface";
    wd.title.len = 13;
    wd.width = 320;
    wd.height = 240;
    wd.flags = GR_WINDOW_VULKAN | GR_WINDOW_HIDDEN;
    if (gr_window_create(&wd, &window) != GR_OK) {
        printf("vk-surface: skipped (no SDL3 window: no display?)\n");
        return 0;
    }
    CHECK(window != GR_NULL_HANDLE);

    /* A hidden window still reports a real framebuffer size. */
    memset(&size, 0, sizeof(size));
    CHECK_EQ(gr_window_get_size(window, &size), GR_OK);
    CHECK_EQ(size.pixel_width, 320u);
    CHECK_EQ(size.pixel_height, 240u);

    /* The instance must carry the platform's surface extensions, so the device is created with the
     * window and with validation requested. If the layer or an extension is missing, instance
     * creation fails and the device creation reports why through the log callback. */
    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_VULKAN;
    dd.flags = GR_DEVICE_VALIDATION;
    dd.window = window;
    dd.app_name.data = "grail-vk-surface-test";
    dd.app_name.len = 21;
    dd.log = on_log;
    if (gr_device_create(&dd, &device) != GR_OK) {
        printf("vk-surface: skipped (no Vulkan device with a surface instance)\n");
        gr_window_destroy(window);
        return 0;
    }
    CHECK(device != GR_NULL_HANDLE);
    CHECK_EQ(last_severity, -1); /* no failure was logged */

    /* The instance and physical device are published for exactly this handshake. */
    CHECK_EQ(gr_vk_instance(device, &instance, &physical), GR_OK);
    CHECK(instance != NULL);
    CHECK(physical != NULL);

    /* What the platform asks the instance for: at least one extension, with real names. */
    CHECK_EQ(gr_vk_window_extensions(&extension_count, &extensions), GR_OK);
    CHECK(extension_count >= 1u);
    CHECK(extensions != NULL && extensions[0] != NULL && extensions[0][0] != '\0');
    if (extensions && extension_count)
        printf("vk-surface: platform asks for %u instance extension(s): %s%s\n", extension_count,
               extensions[0], extension_count > 1u ? " ..." : "");

    /* The surface, twice: create, destroy, create again, so a stale or double-free handle shows up
     * as a failure instead of surviving until the first swapchain. */
    CHECK_EQ(gr_vk_create_surface(device, window, &surface), GR_OK);
    CHECK(surface != NULL);
    printf("vk-surface: VkSurfaceKHR %p from a hidden SDL3 window\n", surface);
    CHECK_EQ(gr_vk_destroy_surface(device, surface), GR_OK);

    surface = NULL;
    CHECK_EQ(gr_vk_create_surface(device, window, &surface), GR_OK);
    CHECK(surface != NULL);
    CHECK_EQ(gr_vk_destroy_surface(device, surface), GR_OK);

    /* A null-backend window has no platform handle, so a surface from it is refused rather than
     * built on a fabricated pointer. */
    CHECK_EQ(gr_vk_create_surface(device, GR_NULL_HANDLE, &surface), GR_ERROR_INVALID_HANDLE);

    /* -----------------------------------------------------------------------------------
     * A swapchain: acquire, render a graph pass into the acquired image, present, recreate.
     * --------------------------------------------------------------------------------- */
    {
        gr_swapchain_desc sd;
        gr_handle swapchain = GR_NULL_HANDLE;
        gr_format swap_format = GR_FORMAT_UNDEFINED;
        uint32_t sw_width = 0, sw_height = 0, sw_images = 0;
        gr_handle library = GR_NULL_HANDLE;
        gr_shader_library_desc ld;
        gr_handle pipeline = GR_NULL_HANDLE;
        gr_handle pool = GR_NULL_HANDLE, cmd = GR_NULL_HANDLE;
        uint32_t pass_index;

        memset(&sd, 0, sizeof(sd));
        sd.head.size = (uint32_t)sizeof(sd);
        sd.window = window;
        sd.width = 320;
        sd.height = 240;
        sd.present_mode = GR_PRESENT_FIFO;
        {
            gr_result swap_status = gr_swapchain_create(device, &sd, &swapchain);
        if (swap_status != GR_OK) {
            printf("vk-surface: swapchain unavailable (%s), skipping the swapchain half\n",
                   gr_result_name(swap_status));
        } else {
            CHECK_EQ(gr_swapchain_info(swapchain, &swap_format, &sw_width, &sw_height, &sw_images),
                     GR_OK);
            CHECK(sw_width > 0u && sw_height > 0u);
            CHECK(sw_images >= 2u);
            CHECK(swap_format != GR_FORMAT_UNDEFINED);
            printf("vk-surface: swapchain %ux%u, %u images, format %d\n", sw_width, sw_height,
                   sw_images, (int)swap_format);

            /* The shaders and the one pipeline this frame needs. */
            memset(&ld, 0, sizeof(ld));
            ld.head.size = (uint32_t)sizeof(ld);
            ld.root.data = "../.work/shaders";
            ld.root.len = 16; /* "../.work/shaders" */
            CHECK_EQ(gr_shader_library_open(&ld, &library), GR_OK);
            if (library != GR_NULL_HANDLE) {
                gr_handle vs = GR_NULL_HANDLE, fs = GR_NULL_HANDLE;
                gr_pipeline_desc pd;
                gr_str vs_name = { "core/fullscreen", 15, 0 };
                gr_str fs_name = { "core/solid", 10, 0 };
                CHECK_EQ(gr_shader_create_resolved(device, library, vs_name, GR_SHADER_STAGE_VERTEX,
                                                   0, &vs), GR_OK);
                CHECK_EQ(gr_shader_create_resolved(device, library, fs_name,
                                                   GR_SHADER_STAGE_FRAGMENT, 0, &fs), GR_OK);
                memset(&pd, 0, sizeof(pd));
                pd.head.size = (uint32_t)sizeof(pd);
                pd.name = (gr_str){ "vk/present", 10, 0 };
                pd.shaders[GR_SHADER_STAGE_VERTEX] = vs;
                pd.shaders[GR_SHADER_STAGE_FRAGMENT] = fs;
                pd.color_formats = &swap_format; /* the swapchain's own format */
                pd.color_count = 1;
                pd.depth_format = GR_FORMAT_UNDEFINED;
                pd.topology = GR_TOPOLOGY_TRIANGLE_LIST;
                pd.cull = GR_CULL_NONE;
                pd.front_face_ccw = 1;
                pd.samples = 1;
                CHECK_EQ(gr_pipeline_create(device, &pd, &pipeline), GR_OK);
                CHECK_EQ(gr_pipeline_commit(device, NULL), GR_OK);
            }

            {
                gr_cmd_pool_desc cpd;
                gr_cmd_alloc_info cai;
                memset(&cpd, 0, sizeof(cpd));
                cpd.head.size = (uint32_t)sizeof(cpd);
                cpd.queue = GR_QUEUE_GRAPHICS;
                CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
                memset(&cai, 0, sizeof(cai));
                cai.head.size = (uint32_t)sizeof(cai);
                cai.pool = pool;
                CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);
            }

            for (pass_index = 0; pass_index < 2u && pipeline != GR_NULL_HANDLE; ++pass_index) {
                uint32_t image_index = 0xFFFFFFFFu;
                gr_handle image_view = GR_NULL_HANDLE;
                int32_t needs_recreate = 0;
                gr_graph_desc gd;
                gr_handle graph = GR_NULL_HANDLE;
                gr_graph_resource image_res;
                gr_graph_pass render_pass;
                gr_graph_compile_report report;
                gr_barrier barriers[4];
                uint32_t barrier_count = 0;
                gr_result status;

                status = gr_swapchain_acquire(swapchain, 1000ull * 1000ull * 1000ull, &image_index,
                                              &image_view, &needs_recreate);
                CHECK_EQ(status, GR_OK);
                CHECK_EQ(needs_recreate, 0);
                CHECK(image_index < sw_images);
                CHECK(image_view != GR_NULL_HANDLE);
                if (status != GR_OK)
                    break;

                /* The graph owns the transition into the acquired image; the final step to
                 * PRESENT_SRC is host work like the readback pair, because nothing reads a
                 * presented image. */
                memset(&gd, 0, sizeof(gd));
                gd.head.size = (uint32_t)sizeof(gd);
                CHECK(gr_graph_create(&gd, &graph) != GR_NULL_HANDLE);
                CHECK_EQ(gr_graph_add_resource(graph, (gr_str){ "swap", 4, 0 },
                                               GR_GRAPH_RESOURCE_TEXTURE, image_view, &image_res),
                         GR_OK);
                CHECK_EQ(gr_graph_add_pass(graph, (gr_str){ "present-pass", 12, 0 }, &render_pass),
                         GR_OK);
                CHECK_EQ(gr_graph_pass_write(graph, render_pass, image_res,
                                             GR_STATE_COLOR_ATTACHMENT), GR_OK);
                CHECK_EQ(gr_graph_pass_set_side_effect(graph, render_pass, 1), GR_OK);
                memset(&report, 0, sizeof(report));
                report.head.size = (uint32_t)sizeof(report);
                CHECK_EQ(gr_graph_compile(graph, &report), GR_OK);
                CHECK_EQ(report.live_count, 1u);

                CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
                CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
                CHECK_EQ(gr_cmd_push_frame_offset(cmd, 0), GR_OK);
                CHECK_EQ(gr_graph_pass_barriers(graph, 0, barriers, 4, &barrier_count), GR_OK);
                CHECK_EQ(barrier_count, 1u);
                CHECK_EQ(gr_cmd_barrier(cmd, barriers, barrier_count), GR_OK);
                {
                    gr_render_begin rb;
                    gr_color_attachment color;
                    gr_draw draw;
                    float tint[4];
                    uint32_t push[4];
                    memset(&color, 0, sizeof(color));
                    color.view = image_view;
                    color.load_op = GR_LOAD_CLEAR;
                    color.store_op = GR_STORE_STORE;
                    color.clear[3] = 1.0f;
                    memset(&rb, 0, sizeof(rb));
                    rb.head.size = (uint32_t)sizeof(rb);
                    rb.colors = &color;
                    rb.color_count = 1;
                    rb.render_w = sw_width;
                    rb.render_h = sw_height;
                    CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_OK);
                    CHECK_EQ(gr_cmd_set_viewport(cmd, 0.0f, 0.0f, (float)sw_width, (float)sw_height,
                                                 0.0f, 1.0f), GR_OK);
                    CHECK_EQ(gr_cmd_set_scissor(cmd, 0, 0, sw_width, sw_height), GR_OK);
                    CHECK_EQ(gr_cmd_bind_pipeline(cmd, pipeline), GR_OK);
                    tint[0] = 0.9f; tint[1] = 0.5f; tint[2] = 0.25f; tint[3] = 1.0f;
                    memcpy(push, tint, sizeof(push));
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
                {
                    /* The one transition the graph does not derive: the image becomes presentable
                     * because this pass is the last thing to write it. */
                    gr_barrier present_barrier;
                    memset(&present_barrier, 0, sizeof(present_barrier));
                    present_barrier.resource = image_view;
                    present_barrier.src_state = GR_STATE_COLOR_ATTACHMENT;
                    present_barrier.dst_state = GR_STATE_PRESENT;
                    CHECK_EQ(gr_cmd_barrier(cmd, &present_barrier, 1), GR_OK);
                }
                CHECK_EQ(gr_cmd_end(cmd), GR_OK);

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
                    CHECK_EQ(gr_queue_present(queue, swapchain, image_index, value, NULL), GR_OK);
                }
                gr_graph_destroy(graph);
            }

            /* Recreate at a different size: the surface decides the extent, so the check is that
             * the new swapchain exists and reports a sane one. */
            {
                uint32_t w2 = 0, h2 = 0;
                gr_format f2 = GR_FORMAT_UNDEFINED;
                CHECK_EQ(gr_swapchain_recreate(swapchain, 256, 200, 0), GR_OK);
                CHECK_EQ(gr_swapchain_info(swapchain, &f2, &w2, &h2, NULL), GR_OK);
                CHECK(w2 > 0u && h2 > 0u);
                printf("vk-surface: swapchain recreated at %ux%u\n", w2, h2);
            }

            if (library != GR_NULL_HANDLE)
                gr_shader_library_close(library);
        }
        }
    }

    /* What the layer said, captured in-process rather than left on stderr. A functional check
     * cannot see a validation error - the anisotropic samplers proved that - so this is the only
     * assertion that would have caught it. */
    {
        gr_vk_validation_report report;
        memset(&report, 0, sizeof(report));
        report.head.size = (uint32_t)sizeof(report);
        CHECK_EQ(gr_vk_validation(device, &report), GR_OK);
        CHECK_EQ(report.enabled, 1u); /* the messenger exists, so validation really is on */
        printf("vk-surface: validation errors=%u warnings=%u infos=%u messages=%u\n",
               report.error_count, report.warning_count, report.info_count, report.message_count);
        /* The surface path itself must be clean. A warning is recorded and printed rather than
         * failed on: the layer's warnings are advisory, and this test's subject is the errors. */
        CHECK_EQ(report.error_count, 0u);
        CHECK_EQ(report.warning_count, 0u); /* the surface path is clean, not merely non-fatal */
        {
            uint32_t i;
            for (i = 0; i < report.message_count && i < GR_VK_VALIDATION_MESSAGES; ++i) {
                gr_str message;
                if (gr_vk_validation_message(device, i, &message) == GR_OK)
                    printf("  layer[%u]: %.*s\n", i, (int)message.len, message.data);
            }
        }
    }

    gr_device_destroy(device);
    gr_window_destroy(window);

    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("vk-surface: %d checks passed\n", checks);
    return 0;
}
