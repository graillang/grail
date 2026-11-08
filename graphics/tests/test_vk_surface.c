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
