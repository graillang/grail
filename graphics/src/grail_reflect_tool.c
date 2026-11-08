/* grail_reflect_tool.c - inspect and verify a reflection blob.
 *
 *   grail-reflect <file.refl.bin> [more...]
 *
 * Prints the blob's contents and, crucially, checks that the digest the offline tool stored
 * equals the digest this implementation recomputes from the tables. The tool
 * (graphics/tools/shader.mjs) and this reader are two independent implementations of the
 * same format; if they ever disagree, the build fails here instead of the renderer reading
 * the wrong memory at run time. Exit status 1 on a malformed blob or a digest mismatch.
 */
#include "grail_internal.h"
#include "../include/grail/grail_bindless.h"

#include <stddef.h>
#include <stdio.h>

static const char *kind_name(uint16_t kind)
{
    switch (kind) {
    case GR_REFLECT_BIND_SAMPLED_IMAGE: return "sampled_image";
    case GR_REFLECT_BIND_STORAGE_IMAGE: return "storage_image";
    case GR_REFLECT_BIND_SAMPLER: return "sampler";
    case GR_REFLECT_BIND_STORAGE_BUFFER: return "storage_buffer";
    case GR_REFLECT_BIND_UNIFORM_BUFFER: return "uniform_buffer";
    case GR_REFLECT_BIND_ACCELERATION_STRUCTURE: return "acceleration_structure";
    case GR_REFLECT_BIND_PUSH_CONSTANTS: return "push_constants";
    default: return "unknown";
    }
}

static int check_file(const char *path, int verbose)
{
    FILE *file = fopen(path, "rb");
    long size;
    uint8_t *data;
    gr_span_u8 span;
    gr_reflection refl;
    gr_result status;
    uint64_t computed[2];
    int failures = 0;

    if (!file) {
        fprintf(stderr, "%s: cannot open\n", path);
        return 1;
    }
    fseek(file, 0, SEEK_END);
    size = ftell(file);
    fseek(file, 0, SEEK_SET);
    if (size <= 0) {
        fclose(file);
        fprintf(stderr, "%s: empty\n", path);
        return 1;
    }
    data = (uint8_t *)malloc((size_t)size);
    if (!data) {
        fclose(file);
        return 1;
    }
    if (fread(data, 1, (size_t)size, file) != (size_t)size) {
        fclose(file);
        free(data);
        fprintf(stderr, "%s: short read\n", path);
        return 1;
    }
    fclose(file);

    span.data = data;
    span.len = (size_t)size;
    status = gr_reflect_open(span, &refl);
    if (status != GR_OK) {
        fprintf(stderr, "%s: INVALID (%s)\n", path, gr_result_name(status));
        free(data);
        return 1;
    }

    printf("%s\n", path);
    printf("  stage %s, container %u, bytecode %llu B, entry \"%s\"\n",
           refl.header->stage == GR_SHADER_STAGE_VERTEX ? "vs" :
           refl.header->stage == GR_SHADER_STAGE_FRAGMENT ? "ps" :
           refl.header->stage == GR_SHADER_STAGE_COMPUTE ? "cs" :
           refl.header->stage == GR_SHADER_STAGE_MESH ? "ms" :
           refl.header->stage == GR_SHADER_STAGE_TASK ? "as" : "lib",
           refl.header->container,
           (unsigned long long)refl.header->bytecode_length,
           gr_reflect_string(&refl, refl.header->entry_point_name));
    printf("  compiler %s\n", gr_reflect_string(&refl, refl.header->compiler_version));

    {
        uint32_t i;
        for (i = 0; i < refl.header->binding_count; ++i) {
            const gr_reflect_binding *b = &refl.bindings[i];
            printf("  set %u binding %u  %-22s %-18s %s\n", b->set, b->binding,
                   gr_reflect_string(&refl, b->name), kind_name(b->kind),
                   b->array_size == 0 ? "[]" : "");
        }
    }

    {
        uint32_t d;
        for (d = 0; d < refl.header->define_count; ++d) {
            const gr_reflect_define *define = &refl.defines[d];
            const char *name = gr_reflect_string(&refl, define->name);
            /* The id the tool must have derived for the same name. Comparing these two lines
             * of output is how make shader-check proves the id function has one definition. */
            printf("  define %-26s id=0x%08x default=%u values=[%s] (count %u)\n", name,
                   gr_permutation_name_id((gr_str){ name, (uint32_t)strlen(name), 0 }),
                   define->default_value,
                   gr_reflect_string(&refl, define->values), define->value_count);
        }
    }

    {
        uint32_t frame = gr_reflect_frame_constants_size(&refl);
        if (frame)
            printf("  frame constants: %u B\n", frame);
        /* The host's own size must agree with the shader's, or the renderer must refuse. */
        if (frame && frame != (uint32_t)sizeof(gr_frame_constants)) {
            fprintf(stderr, "  MISMATCH: shader declares %u B, host sizeof %u B\n", frame,
                    (uint32_t)sizeof(gr_frame_constants));
            failures++;
        }
        /* And every member must sit where the host's struct puts it. This is the check that
         * turns "the HLSL mirror and the C struct agree" from a claim into a build failure. */
        if (frame) {
            static const struct { const char *name; uint32_t offset, size; } kExpected[] = {
                { "view",           (uint32_t)offsetof(gr_frame_constants, view),           64 },
                { "proj",           (uint32_t)offsetof(gr_frame_constants, proj),           64 },
                { "view_proj",      (uint32_t)offsetof(gr_frame_constants, view_proj),      64 },
                { "inv_view_proj",  (uint32_t)offsetof(gr_frame_constants, inv_view_proj),  64 },
                { "origin",         (uint32_t)offsetof(gr_frame_constants, origin),         16 },
                { "viewport",       (uint32_t)offsetof(gr_frame_constants, viewport),       16 },
                { "time",           (uint32_t)offsetof(gr_frame_constants, time),           16 },
                { "sun_direction",  (uint32_t)offsetof(gr_frame_constants, sun_direction),  16 },
                { "sun_illuminance",(uint32_t)offsetof(gr_frame_constants, sun_illuminance),16 },
                { "camera_forward", (uint32_t)offsetof(gr_frame_constants, camera_forward), 16 },
                { "jitter",         (uint32_t)offsetof(gr_frame_constants, jitter),         16 },
                { "exposure",       (uint32_t)offsetof(gr_frame_constants, exposure),       16 },
                { "frame_index",    (uint32_t)offsetof(gr_frame_constants, frame_index),     4 },
                { "frame_seed",     (uint32_t)offsetof(gr_frame_constants, frame_seed),      4 },
                { "flags",          (uint32_t)offsetof(gr_frame_constants, flags),           4 },
                { "version",        (uint32_t)offsetof(gr_frame_constants, version),         4 },
                { "light_count",    (uint32_t)offsetof(gr_frame_constants, light_count),     4 },
                { "_reserved0",     (uint32_t)offsetof(gr_frame_constants, _reserved0),     12 },
            };
            const gr_reflect_binding *block =
                gr_reflect_find_binding(&refl, GR_BINDLESS_SET_FRAME, GR_BINDING_FRAME_CONSTANTS);
            uint32_t m;
            for (m = 0; block && m < block->member_count; ++m) {
                const gr_reflect_member *member = &refl.members[block->member_first + m];
                const char *full = gr_reflect_string(&refl, member->name);
                const char *dot = strrchr(full, '.');
                const char *leaf = dot ? dot + 1 : full;
                size_t k;
                for (k = 0; k < sizeof(kExpected) / sizeof(kExpected[0]); ++k) {
                    if (strcmp(kExpected[k].name, leaf) != 0)
                        continue;
                    if (member->offset != kExpected[k].offset) {
                        fprintf(stderr, "  MEMBER OFFSET MISMATCH: %s shader %u, host %u\n",
                                leaf, member->offset, kExpected[k].offset);
                        failures++;
                    }
                    if (member->size != kExpected[k].size) {
                        fprintf(stderr, "  MEMBER SIZE MISMATCH: %s shader %u, host %u\n",
                                leaf, member->size, kExpected[k].size);
                        failures++;
                    }
                    break;
                }
            }
            printf("  frame constants members checked against offsetof\n");
        }
    }

    if (verbose) {
        uint32_t i;
        for (i = 0; i < refl.header->member_count; ++i) {
            const gr_reflect_member *m = &refl.members[i];
            printf("    member %-40s %-10s offset %3u size %3u\n",
                   gr_reflect_string(&refl, m->name), gr_reflect_string(&refl, m->type_name),
                   m->offset, m->size);
        }
    }

    /* The digest: stored versus recomputed by this implementation. */
    if (gr_reflect_compute_layout_hash(&refl, computed) == GR_OK) {
        uint64_t stored[2];
        gr_reflect_layout_hash(&refl, stored);
        if (stored[0] != computed[0] || stored[1] != computed[1]) {
            fprintf(stderr,
                    "  LAYOUT HASH MISMATCH: stored %016llx%016llx, computed %016llx%016llx\n",
                    (unsigned long long)stored[0], (unsigned long long)stored[1],
                    (unsigned long long)computed[0], (unsigned long long)computed[1]);
            failures++;
        } else {
            printf("  layout hash %016llx%016llx (verified)\n",
                   (unsigned long long)computed[0], (unsigned long long)computed[1]);
        }
    }

    free(data);
    return failures;
}

int main(int argc, char **argv)
{
    int verbose = 0, failures = 0, i, files = 0;
    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--verbose") == 0) verbose = 1;
        else { failures += check_file(argv[i], verbose); files++; }
    }
    if (files == 0) {
        fprintf(stderr, "usage: grail-reflect [-v] <file.refl.bin>...\n");
        return 2;
    }
    if (failures) {
        fprintf(stderr, "%d problem(s)\n", failures);
        return 1;
    }
    return 0;
}
