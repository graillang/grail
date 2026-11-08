/* grail_vk_probe_main.c - prints the Vulkan probe's report.
 *
 * Exit status is the machine-readable part, so a build or CI step can use it:
 *   0  a device satisfies every requirement in grail_backend_vulkan.h
 *   2  Vulkan is present but a device is missing a required feature (named in the output)
 *   3  no loader, no ICD, or no instance could be created: every test in this repository skips
 */
#include "grail_internal.h"
#include "../include/grail/grail_backend_vulkan.h"

#include <stdio.h>

static const char *device_type_name(uint32_t type)
{
    switch (type) {
    case 1: return "integrated";
    case 2: return "discrete";
    case 3: return "virtual";
    case 4: return "cpu";
    default: return "other";
    }
}

int main(void)
{
    gr_vk_probe_report report;
    gr_result status;
    uint32_t bit;

    memset(&report, 0, sizeof(report));
    report.head.size = (uint32_t)sizeof(report);
    status = gr_vk_probe_run(&report);

    if (status == GR_ERROR_UNSUPPORTED) {
        printf("grail-vk-probe: no Vulkan device (%s)\n",
               report.loader_found ? "loader present, no ICD answered" : "no loader");
        if (report.loader_path[0])
            printf("  loader search: %s\n", report.loader_path);
        return 3;
    }
    if (status != GR_OK) {
        printf("grail-vk-probe: failed (%s)\n", gr_result_name(status));
        return 3;
    }

    printf("grail-vk-probe\n");
    printf("  loader      %s, Vulkan %u.%u.%u\n", report.loader_path, report.loader_api_major,
           report.loader_api_minor, report.loader_api_patch);
    printf("  instance    Vulkan %u.%u\n", report.instance_api_major, report.instance_api_minor);
    printf("  devices     %u\n", report.device_count);
    printf("  device      %s\n", report.device_name);
    printf("  type        %s\n", device_type_name(report.device_type));
    printf("  API         %u.%u.%u  vendor 0x%04x device 0x%04x  driver 0x%08x\n",
           report.api_major, report.api_minor, report.api_patch, report.vendor_id,
           report.device_id, report.driver_version);
    if (report.driver_name[0])
        printf("  driver      %s (%s)\n", report.driver_name, report.driver_info);
    printf("  queues      %u families: graphics %u, compute %u, transfer %u\n",
           report.queue_family_count,
           report.graphics_family == ~0u ? 0u : report.graphics_family,
           report.compute_family == ~0u ? 0u : report.compute_family,
           report.transfer_family == ~0u ? 0u : report.transfer_family);
    printf("  memory      %u MiB device-local\n", report.device_local_heap_bytes);
    printf("  limits      push constants %u, image 2D %u, workgroup %u\n",
           report.max_push_constants, report.max_image_dimension_2d,
           report.max_compute_workgroup_invocations);
    printf("              per stage: %u sampled, %u samplers, %u storage buffers; per set: %u sampled\n",
           report.max_per_stage_sampled_images, report.max_per_stage_samplers,
           report.max_per_stage_storage_buffers, report.max_descriptor_set_sampled_images);
    printf("              subgroup %u, timestamp period %.1f ns\n", report.subgroup_size,
           report.timestamp_period_ns);

    if (report.required_missing == 0) {
        printf("  required    all present\n");
        return 0;
    }
    printf("  required    MISSING:");
    for (bit = 1; bit != 0 && bit <= GR_VK_REQ_SHADER_INT64; bit <<= 1)
        if (report.required_missing & bit)
            printf(" %s", gr_vk_required_name(bit));
    printf("\n");
    return 2;
}
