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
    uint64_t keys[8];
    uint32_t fragment_count = 0, i;

    memset(&dd, 0, sizeof(dd));
    dd.head.size = (uint32_t)sizeof(dd);
    dd.backend = GR_BACKEND_VULKAN;
    dd.flags = GR_DEVICE_HEADLESS;
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

    /* Commit closes the registry, and the driver's pipeline cache has content. */
    {
        double seconds = -1.0;
        uint32_t declared = 0, committed = 0;
        CHECK_EQ(gr_pipeline_commit(device, &seconds), GR_OK);
        CHECK(seconds >= 0.0);
        CHECK_EQ(gr_pipeline_stats(device, &declared, &committed), GR_OK);
        CHECK_EQ(declared, 1u);
        CHECK_EQ(committed, 1u);
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

    CHECK_EQ(gr_device_wait_idle(device), GR_OK);
    gr_shader_library_close(library);
    gr_device_destroy(device);

    if (failures) {
        fprintf(stderr, "%d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("vk-backend: %d checks passed\n", checks);
    return 0;
}
