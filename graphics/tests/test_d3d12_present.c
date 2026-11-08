/* test_d3d12_present.c - a D3D12 flip-model swapchain on an SDL3 window.
 *
 * Windows only (run under Wine on Linux, on a display). Each frame acquires a back buffer,
 * transitions it PRESENT -> COLOR_ATTACHMENT, clears it to a frame-specific colour, reads the
 * image back exactly, transitions it to PRESENT and presents. The swapchain is then resized and
 * presented again, and every refusal the presentation path promises is exercised. */
#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_window.h"
#include <stdio.h>
#include <string.h>
#include <windows.h>

static int g_checks, g_failures;
#define CHECK(c) do { ++g_checks; if (!(c)) { ++g_failures; printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); } } while (0)
#define CHECK_EQ(a, b) do { long long a_ = (long long)(a), b_ = (long long)(b); ++g_checks; \
    if (a_ != b_) { ++g_failures; printf("FAIL %s:%d: %s == %lld, expected %lld\n", __FILE__, __LINE__, #a, a_, b_); } } while (0)

static uint8_t unorm(float v) { return (uint8_t)(v * 255.0f + 0.5f); }

static void frame(gr_handle device, gr_handle queue, gr_handle swap, gr_handle cmd, uint32_t width,
                  uint32_t height, const float colour[4], uint64_t *last_value, int verbose)
{
    static uint8_t pixels[640 * 480 * 4];
    uint32_t index = 99, wrong = 0, i;
    gr_handle view = GR_NULL_HANDLE;
    int32_t recreate = 1;
    gr_barrier b;
    gr_color_attachment ca;
    gr_render_begin rb;
    gr_submit sub;
    uint64_t value = 0, presented = 0;
    gr_result ws = GR_ERROR_BACKEND;
    (void)device;
    CHECK_EQ(gr_swapchain_acquire(swap, 5000000000ull, &index, &view, &recreate), GR_OK);
    CHECK_EQ(recreate, 0);
    CHECK(view != GR_NULL_HANDLE);
    CHECK_EQ(gr_swapchain_acquire(swap, 0, &index, &view, &recreate), GR_ERROR_NOT_READY); /* one at a time; outputs kept */
    CHECK(view != GR_NULL_HANDLE);
    CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
    CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
    memset(&b, 0, sizeof(b));
    b.resource = view;
    b.src_state = GR_STATE_PRESENT;
    b.dst_state = GR_STATE_COLOR_ATTACHMENT;
    CHECK_EQ(gr_cmd_barrier(cmd, &b, 1), GR_OK);
    memset(&ca, 0, sizeof(ca));
    ca.view = view;
    ca.load_op = GR_LOAD_CLEAR;
    ca.store_op = GR_STORE_STORE;
    memcpy(ca.clear, colour, sizeof(ca.clear));
    memset(&rb, 0, sizeof(rb));
    rb.head.size = (uint32_t)sizeof(rb);
    rb.colors = &ca;
    rb.color_count = 1;
    CHECK_EQ(gr_cmd_begin_render(cmd, &rb), GR_OK);
    CHECK_EQ(gr_cmd_end_render(cmd), GR_OK);
    b.src_state = GR_STATE_COLOR_ATTACHMENT;
    b.dst_state = GR_STATE_TRANSFER_SRC;
    CHECK_EQ(gr_cmd_barrier(cmd, &b, 1), GR_OK);
    CHECK_EQ(gr_cmd_end(cmd), GR_OK);
    memset(&sub, 0, sizeof(sub));
    sub.head.size = (uint32_t)sizeof(sub);
    sub.queue = queue;
    sub.cmds = &cmd;
    sub.cmd_count = 1;
    CHECK_EQ(gr_submit_commands(&sub, &value), GR_OK);
    CHECK_EQ(gr_queue_wait_idle(queue), GR_OK);
    /* The image the swapchain will show holds exactly the clear colour (BGRA order). */
    CHECK_EQ(gr_texture_read(view, 0, 0, 0, 0, width, height, GR_STATE_TRANSFER_SRC,
                             (gr_mut_span_u8){ pixels, sizeof(pixels) }), GR_OK);
    for (i = 0; i < width * height; ++i)
        if (pixels[i * 4] != unorm(colour[2]) || pixels[i * 4 + 1] != unorm(colour[1]) ||
            pixels[i * 4 + 2] != unorm(colour[0]) || pixels[i * 4 + 3] != unorm(colour[3]))
            ++wrong;
    CHECK_EQ(wrong, 0);
    CHECK_EQ(gr_queue_present(queue, swap, index, value, &presented), GR_ERROR_NOT_READY); /* not in PRESENT */
    CHECK_EQ(gr_cmd_reset(cmd), GR_OK);
    CHECK_EQ(gr_cmd_begin(cmd), GR_OK);
    b.src_state = GR_STATE_TRANSFER_SRC;
    b.dst_state = GR_STATE_PRESENT;
    CHECK_EQ(gr_cmd_barrier(cmd, &b, 1), GR_OK);
    CHECK_EQ(gr_cmd_end(cmd), GR_OK);
    CHECK_EQ(gr_submit_commands(&sub, &value), GR_OK);
    CHECK_EQ(gr_queue_present(queue, swap, (index + 1) % 3, value, &presented), GR_ERROR_INVALID_ARGUMENT); /* not acquired */
    CHECK_EQ(gr_queue_present(queue, swap, index, value + 100, &presented), GR_ERROR_INVALID_ARGUMENT); /* never submitted */
    CHECK_EQ(gr_queue_present(queue, swap, index, value, &presented), GR_OK);
    CHECK(presented > value);
    CHECK(presented > *last_value);
    *last_value = presented;
    (void)ws;
    if (verbose)
        printf("d3d12-present: %ux%u image %u cleared to %u %u %u %u (BGRA %u %u %u %u), presented at %llu\n",
               width, height, index, unorm(colour[0]), unorm(colour[1]), unorm(colour[2]), unorm(colour[3]),
               pixels[0], pixels[1], pixels[2], pixels[3], (unsigned long long)presented);
}

int main(void)
{
    static const float colours[4][4] = {
        { 0.25f, 0.5f, 0.75f, 1.0f }, { 1.0f, 0.0f, 0.0f, 1.0f }, { 0.0f, 1.0f, 0.0f, 1.0f }, { 0.0f, 0.0f, 1.0f, 1.0f }
    };
    gr_window_desc wd;
    gr_device_desc dd;
    gr_swapchain_desc sd;
    gr_cmd_pool_desc cpd;
    gr_cmd_alloc_info cai;
    gr_handle window = GR_NULL_HANDLE, device = GR_NULL_HANDLE, queue = GR_NULL_HANDLE;
    gr_handle swap = GR_NULL_HANDLE, bad = GR_NULL_HANDLE, pool = GR_NULL_HANDLE, cmd = GR_NULL_HANDLE;
    gr_window_native native;
    gr_format format = GR_FORMAT_UNDEFINED;
    uint32_t w = 0, h = 0, count = 0, f;
    uint64_t last = 0;

    setvbuf(stdout, NULL, _IONBF, 0); /* a crash must not lose what was already reported */
    printf("d3d12-present: start\n");
    if (gr_window_set_backend(GR_WINDOW_BACKEND_SDL3) != GR_OK) {
        printf("d3d12-present: SDL3.dll not found next to the executable\n");
        return 1;
    }
    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_D3D12;
    dd.api_min_major = 11;
    CHECK_EQ(gr_device_create(&dd, &device), GR_OK);
    if (device == GR_NULL_HANDLE)
        return 1;
    memset(&wd, 0, sizeof(wd));
    wd.head.size = (uint32_t)sizeof(wd);
    wd.title = (gr_str){ "grail d3d12 present", 19, 0 };
    wd.width = 320;
    wd.height = 240;
    CHECK_EQ(gr_window_create(&wd, &window), GR_OK);
    printf("d3d12-present: window created\n");
    CHECK_EQ(gr_window_get_native(window, &native), GR_OK);
    printf("d3d12-present: native %p %p\n", native.handle_a, native.handle_b);
    CHECK_EQ(native.backend, GR_BACKEND_D3D12);
    CHECK(native.handle_a != NULL); /* the HWND */
    CHECK(native.handle_b != NULL); /* the HINSTANCE */
    CHECK_EQ(gr_device_queue(device, GR_QUEUE_GRAPHICS, &queue), GR_OK);
    printf("d3d12-present: queue ok\n");

    memset(&sd, 0, sizeof(sd));
    sd.head.size = (uint32_t)sizeof(sd);
    sd.window = window;
    sd.image_count = 1;
    CHECK_EQ(gr_swapchain_create(device, &sd, &bad), GR_ERROR_INVALID_ARGUMENT); /* flip model needs 2+ */
    sd.image_count = 3;
    sd.format = GR_FORMAT_R16G16B16A16_FLOAT;
    CHECK_EQ(gr_swapchain_create(device, &sd, &bad), GR_ERROR_INVALID_ARGUMENT);
    sd.format = GR_FORMAT_UNDEFINED; /* the backend's preferred: B8G8R8A8_UNORM */
    sd.present_mode = GR_PRESENT_FIFO;
    CHECK_EQ(gr_swapchain_create(device, &sd, &swap), GR_OK);
    printf("d3d12-present: swapchain created\n");
    CHECK_EQ(gr_swapchain_info(swap, &format, &w, &h, &count), GR_OK);
    CHECK_EQ(format, GR_FORMAT_B8G8R8A8_UNORM);
    CHECK_EQ(w, 320);
    CHECK_EQ(h, 240);
    CHECK_EQ(count, 3);

    memset(&cpd, 0, sizeof(cpd));
    cpd.head.size = (uint32_t)sizeof(cpd);
    cpd.queue = GR_QUEUE_GRAPHICS;
    CHECK_EQ(gr_cmd_pool_create(device, &cpd, &pool), GR_OK);
    memset(&cai, 0, sizeof(cai));
    cai.head.size = (uint32_t)sizeof(cai);
    cai.pool = pool;
    CHECK_EQ(gr_cmd_alloc(&cai, &cmd), GR_OK);

    for (f = 0; f < 6; ++f)
        frame(device, queue, swap, cmd, w, h, colours[f % 4], &last, f < 4);

    /* A resize replaces the images; the old view handles are gone. */
    CHECK_EQ(gr_swapchain_recreate(swap, 200, 150, last), GR_OK);
    CHECK_EQ(gr_swapchain_info(swap, &format, &w, &h, &count), GR_OK);
    CHECK_EQ(w, 200);
    CHECK_EQ(h, 150);
    for (f = 0; f < 4; ++f)
        frame(device, queue, swap, cmd, w, h, colours[(f + 1) % 4], &last, f == 0);
    /* Leave the last frame on screen long enough to be captured. */
    frame(device, queue, swap, cmd, w, h, colours[0], &last, 1);

    CHECK_EQ(gr_device_wait_idle(device), GR_OK);
    gr_device_destroy(device);
    gr_window_destroy(window);
    printf("d3d12-present: %d checks, %d failures\n", g_checks, g_failures);
    return g_failures != 0;
}
