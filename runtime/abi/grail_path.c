#include <string.h>

#include "../include/grail/grail_path.h"
#include "grail_internal.h"

/*
 * Build the path module for the Windows rules or the POSIX rules.  Tests set
 * GRAIL_ABI_PATH_WINDOWS=1 to exercise the Windows lexical rules on a POSIX
 * host; the public header does not depend on this switch.
 */
#ifndef GRAIL_ABI_PATH_WINDOWS
#define GRAIL_ABI_PATH_WINDOWS 0
#endif

#define GRAIL_PATH_MAX_COMPONENTS 256u

typedef struct grail_path_prefix {
    uint64_t input;   /* bytes consumed by the prefix */
    uint64_t output;  /* canonical prefix length */
    uint64_t floor;   /* components that ".." may not remove (UNC server/share) */
    int absolute;
    int drive_relative;
} grail_path_prefix;

typedef struct grail_path_component {
    uint64_t start;
    uint64_t end;
} grail_path_component;

static int grail_path_is_separator(uint8_t byte) {
#if GRAIL_ABI_PATH_WINDOWS
    return byte == '/' || byte == '\\';
#else
    (void)byte;
    return byte == '/';
#endif
}

#if GRAIL_ABI_PATH_WINDOWS
static int grail_path_is_letter(uint8_t byte) {
    return (byte >= 'A' && byte <= 'Z') || (byte >= 'a' && byte <= 'z');
}
#endif

static grail_path_prefix grail_path_scan_prefix(const uint8_t *path, uint64_t length) {
    grail_path_prefix prefix;
    prefix.input = 0;
    prefix.output = 0;
    prefix.floor = 0;
    prefix.absolute = 0;
    prefix.drive_relative = 0;
#if GRAIL_ABI_PATH_WINDOWS
    if (length >= 2 && grail_path_is_separator(path[0]) && grail_path_is_separator(path[1])) {
        prefix.input = 2;
        prefix.output = 2; /* "//server/share/..." */
        prefix.floor = 2;
        prefix.absolute = 1;
        return prefix;
    }
    if (length >= 2 && grail_path_is_letter(path[0]) && path[1] == ':') {
        if (length >= 3 && grail_path_is_separator(path[2])) {
            prefix.input = 3;
            prefix.output = 3; /* "C:/" */
            prefix.absolute = 1;
        } else {
            prefix.input = 2;
            prefix.output = 2; /* "C:" drive-relative */
            prefix.drive_relative = 1;
        }
        return prefix;
    }
    if (length >= 1 && grail_path_is_separator(path[0])) {
        prefix.input = 1;
        prefix.output = 1; /* "/" rooted */
        prefix.absolute = 1;
        return prefix;
    }
#else
    if (length >= 1 && path[0] == '/') {
        prefix.input = 1;
        prefix.output = 1;
        prefix.absolute = 1;
        return prefix;
    }
#endif
    return prefix;
}

static uint64_t grail_path_skip_separators(const uint8_t *path, uint64_t length, uint64_t index) {
    while (index < length && grail_path_is_separator(path[index])) {
        index++;
    }
    return index;
}

static uint64_t grail_path_component_end(const uint8_t *path, uint64_t length, uint64_t index) {
    while (index < length && !grail_path_is_separator(path[index])) {
        index++;
    }
    return index;
}

static int grail_path_is_dot(const uint8_t *path, grail_path_component component) {
    return component.end - component.start == 1 && path[component.start] == '.';
}

static int grail_path_is_dot_dot(const uint8_t *path, grail_path_component component) {
    return component.end - component.start == 2 && path[component.start] == '.' &&
           path[component.start + 1] == '.';
}

/* Collects retained components for normalization. */
static grail_status grail_path_collect(const uint8_t *path, uint64_t length,
                                       const grail_path_prefix *prefix,
                                       grail_path_component *components, uint64_t *count) {
    uint64_t index = prefix->input;
    uint64_t top = 0;
    while (index < length) {
        index = grail_path_skip_separators(path, length, index);
        if (index >= length) {
            break;
        }
        const uint64_t end = grail_path_component_end(path, length, index);
        grail_path_component component;
        component.start = index;
        component.end = end;
        if (!grail_path_is_dot(path, component)) {
            if (grail_path_is_dot_dot(path, component)) {
                if (top > prefix->floor) {
                    top--;
                } else if (!prefix->absolute && !prefix->drive_relative) {
                    if (top >= GRAIL_PATH_MAX_COMPONENTS) {
                        return GRAIL_E_OVERFLOW;
                    }
                    components[top++] = component;
                } else if (prefix->drive_relative && top == 0) {
                    if (top >= GRAIL_PATH_MAX_COMPONENTS) {
                        return GRAIL_E_OVERFLOW;
                    }
                    components[top++] = component;
                }
                /* Absolute and UNC roots silently drop ".." above the root. */
            } else {
                if (top >= GRAIL_PATH_MAX_COMPONENTS) {
                    return GRAIL_E_OVERFLOW;
                }
                components[top++] = component;
            }
        }
        index = end;
    }
    *count = top;
    return GRAIL_OK;
}

static uint64_t grail_path_join_length(const grail_path_component *components, uint64_t count,
                                       uint64_t prefix_output) {
    uint64_t total = prefix_output;
    for (uint64_t i = 0; i < count; i++) {
        if (i != 0) {
            total++;
        }
        total += components[i].end - components[i].start;
    }
    return total;
}

static void grail_path_write_prefix(uint8_t *out, const grail_path_prefix *prefix,
                                   const uint8_t *path) {
#if GRAIL_ABI_PATH_WINDOWS
    if (prefix->output == 2 && prefix->floor == 2) {
        out[0] = '/';
        out[1] = '/';
        return;
    }
    if (prefix->output == 3) {
        out[0] = path[0];
        out[1] = ':';
        out[2] = '/';
        return;
    }
    if (prefix->output == 2) {
        out[0] = path[0];
        out[1] = ':';
        return;
    }
    (void)path;
#else
    (void)path;
#endif
    if (prefix->output == 1) {
        out[0] = '/';
    }
}

/* Writes a prefixed component list; capacity must already be sufficient. */
static void grail_path_write_components(uint8_t *out, const grail_path_prefix *prefix,
                                        const uint8_t *path,
                                        const grail_path_component *components, uint64_t count) {
    grail_path_write_prefix(out, prefix, path);
    uint64_t at = prefix->output;
    for (uint64_t i = 0; i < count; i++) {
        if (i != 0) {
            out[at++] = '/';
        }
        const uint64_t size = components[i].end - components[i].start;
        for (uint64_t j = 0; j < size; j++) {
            out[at++] = path[components[i].start + j];
        }
    }
}

grail_status grail_os_path_is_absolute(const uint8_t *path, uint64_t length,
                                       uint64_t *is_absolute) {
    if ((path == NULL && length != 0) || is_absolute == NULL || length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const grail_path_prefix prefix = grail_path_scan_prefix(path, length);
    *is_absolute = (uint64_t)(prefix.absolute != 0);
    return GRAIL_OK;
}

grail_result grail_os_path_join(const uint8_t *base, uint64_t base_length, const uint8_t *child,
                                uint64_t child_length, uint8_t *out, uint64_t capacity) {
    if ((base == NULL && base_length != 0) || (child == NULL && child_length != 0) ||
        base_length > (uint64_t)INT64_MAX || child_length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t absolute = 0;
    if (grail_os_path_is_absolute(child, child_length, &absolute) != GRAIL_OK) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (absolute) {
        return grail_abi_copy_out(child, child_length, out, capacity);
    }
    if (base_length == 0) {
        return grail_abi_copy_out(child, child_length, out, capacity);
    }
    if (child_length == 0) {
        return grail_abi_copy_out(base, base_length, out, capacity);
    }
    /*
     * A drive-relative base ("C:") must not gain a separator, otherwise the
     * result would silently become drive-absolute.
     */
    int needs_separator = !grail_path_is_separator(base[base_length - 1]);
#if GRAIL_ABI_PATH_WINDOWS
    if (base_length == 2 && grail_path_is_letter(base[0]) && base[1] == ':') {
        needs_separator = 0;
    }
#endif
    const uint64_t total = base_length + (uint64_t)needs_separator + child_length;
    if (total > (uint64_t)INT64_MAX) {
        return GRAIL_E_OVERFLOW;
    }
    if (total > capacity || out == NULL) {
        return (grail_result)total;
    }
    uint64_t at = 0;
    memcpy(out, base, base_length);
    at += base_length;
    if (needs_separator) {
        out[at++] = '/';
    }
    memcpy(out + at, child, child_length);
    return (grail_result)total;
}

static void grail_path_span_metrics(const uint8_t *path, uint64_t begin, uint64_t end,
                                   uint64_t *count, uint64_t *bytes) {
    uint64_t components = 0;
    uint64_t total = 0;
    uint64_t index = begin;
    while (index < end) {
        index = grail_path_skip_separators(path, end, index);
        if (index >= end) {
            break;
        }
        const uint64_t component_end = grail_path_component_end(path, end, index);
        components++;
        total += component_end - index;
        index = component_end;
    }
    *count = components;
    *bytes = total;
}

static grail_result grail_path_write_span(uint8_t *out, const grail_path_prefix *prefix,
                                          const uint8_t *path, uint64_t begin, uint64_t end,
                                          uint64_t canonical_length) {
    grail_path_write_prefix(out, prefix, path);
    uint64_t at = prefix->output;
    uint64_t index = begin;
    int wrote_component = 0;
    while (index < end) {
        index = grail_path_skip_separators(path, end, index);
        if (index >= end) {
            break;
        }
        const uint64_t component_end = grail_path_component_end(path, end, index);
        if (wrote_component) {
            out[at++] = '/';
        }
        for (uint64_t i = index; i < component_end; i++) {
            out[at++] = path[i];
        }
        wrote_component = 1;
        index = component_end;
    }
    return (grail_result)canonical_length;
}

grail_result grail_os_path_parent(const uint8_t *path, uint64_t length, uint8_t *out,
                                  uint64_t capacity) {
    if ((path == NULL && length != 0) || length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const grail_path_prefix prefix = grail_path_scan_prefix(path, length);
    uint64_t end = length;
    while (end > prefix.input && grail_path_is_separator(path[end - 1])) {
        end--;
    }
    if (end <= prefix.input) {
        if (prefix.output > 0) {
            uint8_t root[3];
            grail_path_prefix root_prefix = prefix;
            grail_path_write_prefix(root, &root_prefix, path);
            return grail_abi_copy_out(root, prefix.output, out, capacity);
        }
        return grail_abi_copy_out((const uint8_t *)".", 1, out, capacity);
    }
    uint64_t cut = end;
    while (cut > prefix.input && !grail_path_is_separator(path[cut - 1])) {
        cut--;
    }
    if (cut == prefix.input) {
        if (prefix.output > 0) {
            uint8_t root[3];
            grail_path_prefix root_prefix = prefix;
            grail_path_write_prefix(root, &root_prefix, path);
            return grail_abi_copy_out(root, prefix.output, out, capacity);
        }
        return grail_abi_copy_out((const uint8_t *)".", 1, out, capacity);
    }
    uint64_t parent_end = cut;
    while (parent_end > prefix.input && grail_path_is_separator(path[parent_end - 1])) {
        parent_end--;
    }
    if (parent_end <= prefix.input) {
        if (prefix.output > 0) {
            uint8_t root[3];
            grail_path_prefix root_prefix = prefix;
            grail_path_write_prefix(root, &root_prefix, path);
            return grail_abi_copy_out(root, prefix.output, out, capacity);
        }
        return grail_abi_copy_out((const uint8_t *)".", 1, out, capacity);
    }
    uint64_t count = 0;
    uint64_t bytes = 0;
    grail_path_span_metrics(path, prefix.input, parent_end, &count, &bytes);
    if (prefix.floor > 0 && count < prefix.floor) {
        /* A UNC anchor such as //server/share is its own parent. */
        parent_end = end;
        grail_path_span_metrics(path, prefix.input, parent_end, &count, &bytes);
    }
    if (count == 0) {
        if (prefix.output > 0) {
            uint8_t root[3];
            grail_path_prefix root_prefix = prefix;
            grail_path_write_prefix(root, &root_prefix, path);
            return grail_abi_copy_out(root, prefix.output, out, capacity);
        }
        return grail_abi_copy_out((const uint8_t *)".", 1, out, capacity);
    }
    const uint64_t canonical = prefix.output + bytes + (count - 1);
    if (canonical > capacity || out == NULL) {
        return (grail_result)canonical;
    }
    return grail_path_write_span(out, &prefix, path, prefix.input, parent_end, canonical);
}

static void grail_path_final_component(const uint8_t *path, uint64_t length,
                                       const grail_path_prefix *prefix, uint64_t *start,
                                       uint64_t *end) {
    uint64_t stop = length;
    while (stop > prefix->input && grail_path_is_separator(path[stop - 1])) {
        stop--;
    }
    uint64_t begin = stop;
    while (begin > prefix->input && !grail_path_is_separator(path[begin - 1])) {
        begin--;
    }
    *start = begin;
    *end = stop;
}

grail_result grail_os_path_file_name(const uint8_t *path, uint64_t length, uint8_t *out,
                                     uint64_t capacity) {
    if ((path == NULL && length != 0) || length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const grail_path_prefix prefix = grail_path_scan_prefix(path, length);
    uint64_t start = 0;
    uint64_t end = 0;
    grail_path_final_component(path, length, &prefix, &start, &end);
    return grail_abi_copy_out(path + start, end - start, out, capacity);
}

grail_result grail_os_path_extension(const uint8_t *path, uint64_t length, uint8_t *out,
                                     uint64_t capacity) {
    if ((path == NULL && length != 0) || length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const grail_path_prefix prefix = grail_path_scan_prefix(path, length);
    uint64_t start = 0;
    uint64_t end = 0;
    grail_path_final_component(path, length, &prefix, &start, &end);
    uint64_t dot = end;
    for (uint64_t i = start; i < end; i++) {
        if (path[i] == '.') {
            dot = i;
        }
    }
    if (dot == end || dot == start) {
        return grail_abi_copy_out(NULL, 0, out, capacity);
    }
    return grail_abi_copy_out(path + dot + 1, end - dot - 1, out, capacity);
}

grail_result grail_os_path_normalize(const uint8_t *path, uint64_t length, uint8_t *out,
                                     uint64_t capacity) {
    if ((path == NULL && length != 0) || length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const grail_path_prefix prefix = grail_path_scan_prefix(path, length);
    grail_path_component components[GRAIL_PATH_MAX_COMPONENTS];
    uint64_t count = 0;
    const grail_status collected = grail_path_collect(path, length, &prefix, components, &count);
    if (collected != GRAIL_OK) {
        return collected;
    }
    uint64_t total = grail_path_join_length(components, count, prefix.output);
    if (total == 0) {
        return grail_abi_copy_out((const uint8_t *)".", 1, out, capacity);
    }
    if (total > capacity || out == NULL) {
        return (grail_result)total;
    }
    grail_path_write_components(out, &prefix, path, components, count);
    return (grail_result)total;
}
