#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_error.h"
#include "grail_internal.h"

uint64_t grail_abi_version(void) {
    return GRAIL_ABI_VERSION;
}

grail_status grail_abi_check(uint64_t required_major, uint64_t required_minor) {
    if (required_major != (uint64_t)GRAIL_ABI_MAJOR) {
        return GRAIL_E_UNSUPPORTED;
    }
    if (required_minor > (uint64_t)GRAIL_ABI_MINOR) {
        return GRAIL_E_UNSUPPORTED;
    }
    return GRAIL_OK;
}

grail_result grail_abi_copy_out(const uint8_t *bytes, uint64_t length, uint8_t *out,
                                uint64_t capacity) {
    if (bytes == NULL || length > capacity || out == NULL) {
        return (grail_result)length;
    }
    for (uint64_t i = 0; i < length; i++) {
        out[i] = bytes[i];
    }
    return (grail_result)length;
}

uint64_t grail_abi_bounded_length(const char *text, uint64_t limit) {
    uint64_t i = 0;
    if (text == NULL) {
        return 0;
    }
    while (i < limit && text[i] != '\0') {
        i++;
    }
    return i;
}
