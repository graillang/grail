/* grail_reflect.c - the reader for the reflection blob of grail_shader.h.
 *
 * One validator, used by every backend and by the offline tool's own tests. It trusts
 * nothing: a blob is a file that arrived from a build machine, so every offset is range
 * checked against the declared length, every table is size checked for overflow, and every
 * string offset must address a terminated string inside the string section. A malformed
 * blob is GR_ERROR_SHADER_INVALID, never a read past the end.
 */
#include "grail_internal.h"

/* Range check that cannot overflow: offset and length are 64-bit, size is the buffer. */
static int range_ok(uint64_t offset, uint64_t length, uint64_t total)
{
    if (offset > total)
        return 0;
    if (length > total - offset)
        return 0;
    return 1;
}

/* A table of `count` records of `record_size` bytes at `offset`, 4-byte aligned. */
static int table_ok(uint64_t offset, uint32_t count, uint64_t record_size, uint64_t total)
{
    uint64_t bytes;
    if (count == 0)
        return 1;
    if (record_size != 0 && count > UINT64_MAX / record_size)
        return 0;
    bytes = (uint64_t)count * record_size;
    if (offset % 4u != 0)
        return 0;
    return range_ok(offset, bytes, total);
}

static int string_ok(const gr_reflect_blob_header *h, uint32_t offset)
{
    const char *base = (const char *)h + h->string_offset;
    uint32_t i;
    if (offset >= h->string_length)
        return 0;
    /* The offset must address the start of a string, not its middle: byte 0 of the section
     * or the byte after a NUL is a start. */
    if (offset != 0 && base[offset - 1] != '\0')
        return 0;
    for (i = offset; i < h->string_length; ++i)
        if (base[i] == '\0')
            return 1;
    return 0; /* not terminated inside the section */
}

gr_result gr_reflect_open(gr_span_u8 blob, gr_reflection *out)
{
    const gr_reflect_blob_header *h;
    uint64_t total;

    if (!out)
        return GR_ERROR_INVALID_ARGUMENT;
    memset(out, 0, sizeof(*out));
    if (!blob.data || blob.len < sizeof(gr_reflect_blob_header))
        return GR_ERROR_SHADER_INVALID;

    total = (uint64_t)blob.len;
    h = (const gr_reflect_blob_header *)(const void *)blob.data;

    if (h->magic != GR_REFLECT_MAGIC)
        return GR_ERROR_SHADER_INVALID;
    if (h->version != GR_REFLECT_VERSION)
        return GR_ERROR_VERSION_MISMATCH;
    if (h->header_size != sizeof(gr_reflect_blob_header))
        return GR_ERROR_VERSION_MISMATCH;
    /* The blob must be exactly as long as it claims; a truncated or padded file is refused
     * here rather than producing subtly wrong reflection later. */
    if (h->blob_length != total)
        return GR_ERROR_SHADER_INVALID;
    if (h->container > GR_CONTAINER_MSL_LIBRARY)
        return GR_ERROR_SHADER_INVALID;
    if (h->stage >= GR_SHADER_STAGE_COUNT)
        return GR_ERROR_SHADER_INVALID;

    /* Bytecode: inside the blob and word-aligned. SPIR-V is a sequence of 4-byte words, so a
     * 4-byte start is the real requirement; DXIL needs no alignment at all. Demanding 8 would
     * reject valid SPIR-V whose length is a multiple of 4 but not of 8. */
    if (h->bytecode_offset % 4u != 0)
        return GR_ERROR_SHADER_INVALID;
    if (!range_ok(h->bytecode_offset, h->bytecode_length, total))
        return GR_ERROR_SHADER_INVALID;
    if (h->bytecode_length == 0)
        return GR_ERROR_SHADER_INVALID;
    if ((h->bytecode_offset + h->bytecode_length) % 4u != 0)
        return GR_ERROR_SHADER_INVALID;

    if (h->string_length == 0)
        return GR_ERROR_SHADER_INVALID;
    if (!range_ok(h->string_offset, h->string_length, total))
        return GR_ERROR_SHADER_INVALID;
    /* The name section must be terminated: the last byte is a NUL, so string_ok() can never
     * run off the section looking for one. */
    if (blob.data[h->string_offset + h->string_length - 1u] != '\0')
        return GR_ERROR_SHADER_INVALID;

    if (!table_ok(h->binding_offset, h->binding_count, sizeof(gr_reflect_binding), total))
        return GR_ERROR_SHADER_INVALID;
    if (!table_ok(h->member_offset, h->member_count, sizeof(gr_reflect_member), total))
        return GR_ERROR_SHADER_INVALID;
    if (!table_ok(h->vertex_offset, h->vertex_count, sizeof(gr_reflect_vertex), total))
        return GR_ERROR_SHADER_INVALID;
    if (!table_ok(h->stage_offset, h->stage_count, sizeof(gr_reflect_stage), total))
        return GR_ERROR_SHADER_INVALID;
    if (!table_ok(h->define_offset, h->define_count, sizeof(gr_reflect_define), total))
        return GR_ERROR_SHADER_INVALID;
    if (h->define_count > GR_REFLECT_MAX_DEFINES)
        return GR_ERROR_SHADER_INVALID;

    out->header = h;
    out->bytecode = blob.data + h->bytecode_offset;
    out->strings = (const char *)h + h->string_offset;
    out->bindings = h->binding_count
        ? (const gr_reflect_binding *)(const void *)(blob.data + h->binding_offset) : NULL;
    out->members = h->member_count
        ? (const gr_reflect_member *)(const void *)(blob.data + h->member_offset) : NULL;
    out->vertices = h->vertex_count
        ? (const gr_reflect_vertex *)(const void *)(blob.data + h->vertex_offset) : NULL;
    out->stages = h->stage_count
        ? (const gr_reflect_stage *)(const void *)(blob.data + h->stage_offset) : NULL;
    out->defines = h->define_count
        ? (const gr_reflect_define *)(const void *)(blob.data + h->define_offset) : NULL;

    /* Every name must be a real string and every member range must be inside its binding. */
    if (!string_ok(h, h->entry_point_name) || !string_ok(h, h->source_name) ||
        !string_ok(h, h->compiler_version) || !string_ok(h, h->compile_flags))
        return GR_ERROR_SHADER_INVALID;

    {
        uint32_t i;
        for (i = 0; i < h->binding_count; ++i) {
            const gr_reflect_binding *b = &out->bindings[i];
            if (b->kind > GR_REFLECT_BIND_PUSH_CONSTANTS)
                return GR_ERROR_SHADER_INVALID;
            if (b->set > 1)
                return GR_ERROR_SHADER_INVALID;
            if (!string_ok(h, b->name) || !string_ok(h, b->type_name))
                return GR_ERROR_SHADER_INVALID;
            if (b->member_count != 0) {
                if (b->member_first >= h->member_count)
                    return GR_ERROR_SHADER_INVALID;
                if (b->member_count > h->member_count - b->member_first)
                    return GR_ERROR_SHADER_INVALID;
            }
        }
        for (i = 0; i < h->member_count; ++i) {
            const gr_reflect_member *m = &out->members[i];
            if (m->type > GR_MEMBER_FLOAT3X3)
                return GR_ERROR_SHADER_INVALID;
            if (!string_ok(h, m->name) || !string_ok(h, m->type_name))
                return GR_ERROR_SHADER_INVALID;
        }
        for (i = 0; i < h->vertex_count; ++i) {
            const gr_reflect_vertex *v = &out->vertices[i];
            if (!string_ok(h, v->semantic))
                return GR_ERROR_SHADER_INVALID;
            if (v->format >= GR_FORMAT_COUNT)
                return GR_ERROR_SHADER_INVALID;
        }
        for (i = 0; i < h->stage_count; ++i) {
            if (out->stages[i].stage >= GR_SHADER_STAGE_COUNT)
                return GR_ERROR_SHADER_INVALID;
        }
        for (i = 0; i < h->define_count; ++i) {
            if (!string_ok(h, out->defines[i].name))
                return GR_ERROR_SHADER_INVALID;
        }
    }

    return GR_OK;
}

gr_result gr_reflection_of(gr_handle shader, gr_reflection *out)
{
    /* Declared in grail_shader.h; the device implementation stores the validated reflection
     * in the shader object. Kept here so the reader is the only file that understands the
     * format, and so a test can open a blob without a device. */
    extern gr_result gr_shader_reflection_span(gr_handle shader, gr_span_u8 *out_span);
    gr_span_u8 span;
    gr_result status = gr_shader_reflection_span(shader, &span);
    if (status != GR_OK)
        return status;
    return gr_reflect_open(span, out);
}

const char *gr_reflect_string(const gr_reflection *refl, uint32_t offset)
{
    if (!refl || !refl->header || offset >= refl->header->string_length)
        return "";
    return refl->strings + offset;
}

const gr_reflect_binding *gr_reflect_find_binding(const gr_reflection *refl, uint32_t set,
                                                 uint32_t binding)
{
    uint32_t i;
    if (!refl || !refl->bindings)
        return NULL;
    for (i = 0; i < refl->header->binding_count; ++i) {
        if (refl->bindings[i].set == set && refl->bindings[i].binding == binding)
            return &refl->bindings[i];
    }
    return NULL;
}

const gr_reflect_member *gr_reflect_find_member(const gr_reflection *refl, gr_str name)
{
    uint32_t i;
    if (!refl || !refl->members || !name.data)
        return NULL;
    for (i = 0; i < refl->header->member_count; ++i) {
        const char *member_name = gr_reflect_string(refl, refl->members[i].name);
        size_t len = strlen(member_name);
        if (len == (size_t)name.len && memcmp(member_name, name.data, len) == 0)
            return &refl->members[i];
    }
    return NULL;
}

uint32_t gr_reflect_frame_constants_size(const gr_reflection *refl)
{
    const gr_reflect_binding *block = gr_reflect_find_binding(refl, GR_BINDLESS_SET_FRAME,
                                                             GR_BINDING_FRAME_CONSTANTS);
    const gr_reflect_member *last;
    if (!block || block->member_count == 0)
        return 0;
    /* The block's size is the end of its last member. A layout with trailing padding is
     * still reported as the member end, which is what a host can compare against; the
     * declared 16-byte alignment is separately enforced by the static_assert in
     * grail_bindless.h. */
    last = &refl->members[block->member_first + block->member_count - 1u];
    return last->offset + last->size;
}

void gr_reflect_layout_hash(const gr_reflection *refl, uint64_t out_hash[2])
{
    if (!out_hash)
        return;
    if (!refl || !refl->header) {
        out_hash[0] = 0;
        out_hash[1] = 0;
        return;
    }
    out_hash[0] = refl->header->layout_hash[0];
    out_hash[1] = refl->header->layout_hash[1];
}

/* The canonical digest. The offline tool computes the same value over the HLSL it compiled,
 * so a host that builds its own structs can prove it agrees with the shaders it loads. The
 * canonical form is the reflection itself: bindings in order, then members in order, then
 * vertices in order, each field folded in with its own width so padding cannot matter.
 * graphics/tools/shader.mjs reimplements this; graphics/src/grail_reflect_tool.c checks the
 * two agree on every built shader. */
gr_result gr_reflect_compute_layout_hash(const gr_reflection *refl, uint64_t out_hash[2])
{
    uint64_t h1 = 0xcbf29ce484222325ull;
    uint64_t h2 = 0x84222325cbf29ce4ull;
    uint32_t i;

    if (!refl || !refl->header || !out_hash)
        return GR_ERROR_INVALID_ARGUMENT;

    for (i = 0; i < refl->header->binding_count; ++i) {
        const gr_reflect_binding *b = &refl->bindings[i];
        h1 = gr_hash_u64(h1, ((uint64_t)b->set << 24) | ((uint64_t)b->binding << 8) | b->kind);
        h1 = gr_hash_u64(h1, (uint64_t)b->array_size);
        h2 = gr_hash_u64(h2, (uint64_t)b->member_count);
        {
            const char *name = gr_reflect_string(refl, b->name);
            h2 = gr_hash_bytes_into(h2, name, strlen(name));
        }
    }
    for (i = 0; i < refl->header->member_count; ++i) {
        const gr_reflect_member *m = &refl->members[i];
        h1 = gr_hash_u64(h1, ((uint64_t)m->offset << 24) | ((uint64_t)m->size << 8) | m->type);
        h2 = gr_hash_u64(h2, ((uint64_t)m->array_size << 16) | m->matrix_major);
    }
    for (i = 0; i < refl->header->vertex_count; ++i) {
        const gr_reflect_vertex *v = &refl->vertices[i];
        h1 = gr_hash_u64(h1, ((uint64_t)v->location << 32) | ((uint64_t)v->format << 8) |
                             ((uint64_t)v->component_count));
        h2 = gr_hash_u64(h2, ((uint64_t)v->offset << 16) | v->semantic_index);
    }
    out_hash[0] = h1;
    out_hash[1] = h2;
    return GR_OK;
}
