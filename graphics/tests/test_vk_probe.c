/* setenv/unsetenv are POSIX, and the feature-test macro must come before every system header
 * including the ones the grail headers pull in. */
#define _POSIX_C_SOURCE 200809L

/* test_vk_probe.c - the Vulkan probe.
 *
 * A machine with no Vulkan is a supported state: the probe reports GR_ERROR_UNSUPPORTED and this
 * test passes with a skip message, so the suite runs anywhere. When a device IS present the
 * report must be self-consistent — that is the point of the assertions below, because a probe
 * that silently reports a device with zero limits would be worse than one that fails.
 *
 * This test talks to a driver, so `make test` does not run it. `make vk-probe` runs it under the
 * host's exclusive GPU lock.
 */
#include "../include/grail/grail_backend_vulkan.h"

#include <stdio.h>
#include <stdlib.h>
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

/* The skip path itself, forced: a machine with no loader must produce UNSUPPORTED and a report
 * that says which of the two reasons it was, never a crash or a fabricated device. */
static void test_no_loader_path(void)
{
    gr_vk_probe_report report;
    gr_result status;

    setenv("GRAIL_VK_FORCE_NONE", "1", 1);
    memset(&report, 0, sizeof(report));
    report.head.size = (uint32_t)sizeof(report);
    status = gr_vk_probe_run(&report);
    unsetenv("GRAIL_VK_FORCE_NONE");

    CHECK(status == GR_ERROR_UNSUPPORTED);
    CHECK(report.loader_found == 0u);
    CHECK(report.device_count == 0u);
    CHECK(report.device_name[0] == '\0');
    CHECK(report.loader_path[0] != '\0'); /* it says why, not just "failed" */
    printf("vk-probe: no-loader path reported: %s\n", report.loader_path);
}

int main(void)
{
    gr_vk_probe_report report;
    gr_result status;

    test_no_loader_path();

    memset(&report, 0, sizeof(report));
    report.head.size = (uint32_t)sizeof(report);
    status = gr_vk_probe_run(&report);

    if (status == GR_ERROR_UNSUPPORTED) {
        printf("vk-probe: skipped (no Vulkan device: %s)\n",
               report.loader_found ? "loader present, no ICD answered" : "no loader");
        return 0;
    }
    CHECK(status == GR_OK);
    if (status != GR_OK) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }

    /* The loader answered and a device was chosen. */
    CHECK(report.loader_found == 1u);
    CHECK(report.device_count >= 1u);
    CHECK(report.device_name[0] != '\0');
    CHECK(report.api_major >= 1u);
    CHECK(report.api_minor <= 4u);           /* no implausible version from a bad read */
    CHECK(report.required_missing <= GR_VK_REQ_ALL);

    /* Limits are real values, not zeroed fields: a device that reports none of these could not
     * run the renderer regardless of the feature bits. */
    CHECK(report.max_push_constants >= 128u);
    CHECK(report.max_image_dimension_2d >= 2048u);
    CHECK(report.max_compute_workgroup_invocations >= 128u);
    CHECK(report.subgroup_size >= 1u && report.subgroup_size <= 128u);
    CHECK(report.timestamp_period_ns >= 0.0f);
    CHECK(report.queue_family_count >= 1u);
    CHECK(report.graphics_family != ~0u);    /* a device with no graphics queue is not usable */

    /* A device that satisfies the contract must agree on the two things the bindless table
     * depends on beyond the feature bits: 128 bytes of push constants and a real image limit. */
    if (report.required_missing == 0) {
        CHECK(report.max_push_constants >= 128u);
        CHECK(report.api_major > 1u || report.api_minor >= 3u);
    } else {
        printf("vk-probe: %s\n", report.device_name);
        printf("vk-probe: missing");
        {
            uint32_t bit;
            for (bit = 1; bit <= GR_VK_REQ_SHADER_INT64; bit <<= 1)
                if (report.required_missing & bit)
                    printf(" %s", gr_vk_required_name(bit));
        }
        printf("\n");
    }

    printf("vk-probe: %d checks passed (%s, API %u.%u.%u, driver %s)\n", checks,
           report.device_name, report.api_major, report.api_minor, report.api_patch,
           report.driver_name[0] ? report.driver_name : "unknown");
    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    return 0;
}
