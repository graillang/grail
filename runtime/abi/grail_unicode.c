#include "../include/grail/grail_unicode.h"

/*
 * Strict UTF-8 decoder.  On success advances *index past one scalar value and
 * stores it in *code_point.  Returns 0 on an invalid or truncated sequence.
 */
static int grail_utf8_next(const uint8_t *text, uint64_t length, uint64_t *index,
                           uint32_t *code_point) {
    const uint64_t i = *index;
    if (i >= length) {
        return 0;
    }
    const uint32_t b0 = text[i];
    if (b0 < 0x80u) {
        *code_point = b0;
        *index = i + 1;
        return 1;
    }
    if (b0 >= 0xC2u && b0 <= 0xDFu) {
        if (i + 1 >= length) {
            return 0;
        }
        const uint32_t b1 = text[i + 1];
        if ((b1 & 0xC0u) != 0x80u) {
            return 0;
        }
        *code_point = ((b0 & 0x1Fu) << 6) | (b1 & 0x3Fu);
        *index = i + 2;
        return 1;
    }
    if (b0 >= 0xE0u && b0 <= 0xEFu) {
        if (i + 2 >= length) {
            return 0;
        }
        const uint32_t b1 = text[i + 1];
        const uint32_t b2 = text[i + 2];
        uint32_t low = 0x80u;
        uint32_t high = 0xBFu;
        if (b0 == 0xE0u) {
            low = 0xA0u;
        } else if (b0 == 0xEDu) {
            high = 0x9Fu;
        }
        if (b1 < low || b1 > high || (b2 & 0xC0u) != 0x80u) {
            return 0;
        }
        *code_point = ((b0 & 0x0Fu) << 12) | ((b1 & 0x3Fu) << 6) | (b2 & 0x3Fu);
        *index = i + 3;
        return 1;
    }
    if (b0 >= 0xF0u && b0 <= 0xF4u) {
        if (i + 3 >= length) {
            return 0;
        }
        const uint32_t b1 = text[i + 1];
        const uint32_t b2 = text[i + 2];
        const uint32_t b3 = text[i + 3];
        uint32_t low = 0x80u;
        uint32_t high = 0xBFu;
        if (b0 == 0xF0u) {
            low = 0x90u;
        } else if (b0 == 0xF4u) {
            high = 0x8Fu;
        }
        if (b1 < low || b1 > high || (b2 & 0xC0u) != 0x80u || (b3 & 0xC0u) != 0x80u) {
            return 0;
        }
        *code_point = ((b0 & 0x07u) << 18) | ((b1 & 0x3Fu) << 12) | ((b2 & 0x3Fu) << 6) |
                      (b3 & 0x3Fu);
        *index = i + 4;
        return 1;
    }
    return 0;
}

grail_status grail_os_utf8_validate(const uint8_t *text, uint64_t length,
                                    uint64_t *error_offset) {
    if (length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (text == NULL && length != 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t index = 0;
    while (index < length) {
        const uint64_t start = index;
        uint32_t code_point = 0;
        if (!grail_utf8_next(text, length, &index, &code_point)) {
            if (error_offset != NULL) {
                *error_offset = start;
            }
            return GRAIL_E_INVALID_UTF8;
        }
    }
    if (error_offset != NULL) {
        *error_offset = 0;
    }
    return GRAIL_OK;
}

grail_result grail_os_utf8_to_utf16(const uint8_t *text, uint64_t length, uint16_t *out,
                                    uint64_t capacity_units) {
    if (length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (text == NULL && length != 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t units = 0;
    uint64_t index = 0;
    while (index < length) {
        uint32_t code_point = 0;
        if (!grail_utf8_next(text, length, &index, &code_point)) {
            return GRAIL_E_INVALID_UTF8;
        }
        units += (code_point >= 0x10000u) ? 2u : 1u;
        if (units > (uint64_t)INT64_MAX) {
            return GRAIL_E_OVERFLOW;
        }
    }
    if (units > capacity_units || out == NULL) {
        return (grail_result)units;
    }
    uint64_t written = 0;
    index = 0;
    while (index < length) {
        uint32_t code_point = 0;
        if (!grail_utf8_next(text, length, &index, &code_point)) {
            return GRAIL_E_INVALID_UTF8;
        }
        if (code_point >= 0x10000u) {
            const uint32_t value = code_point - 0x10000u;
            out[written++] = (uint16_t)(0xD800u | (value >> 10));
            out[written++] = (uint16_t)(0xDC00u | (value & 0x3FFu));
        } else {
            out[written++] = (uint16_t)code_point;
        }
    }
    return (grail_result)units;
}

static int grail_utf16_next(const uint16_t *units, uint64_t count, uint64_t *index,
                            uint32_t *code_point) {
    const uint64_t i = *index;
    if (i >= count) {
        return 0;
    }
    const uint32_t first = units[i];
    if (first >= 0xD800u && first <= 0xDBFFu) {
        if (i + 1 >= count) {
            return 0;
        }
        const uint32_t second = units[i + 1];
        if (second < 0xDC00u || second > 0xDFFFu) {
            return 0;
        }
        *code_point = 0x10000u + ((first - 0xD800u) << 10) + (second - 0xDC00u);
        *index = i + 2;
        return 1;
    }
    if (first >= 0xDC00u && first <= 0xDFFFu) {
        return 0;
    }
    *code_point = first;
    *index = i + 1;
    return 1;
}

grail_result grail_os_utf16_to_utf8(const uint16_t *units, uint64_t count, uint8_t *out,
                                    uint64_t capacity) {
    if (count > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (units == NULL && count != 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t bytes = 0;
    uint64_t index = 0;
    while (index < count) {
        uint32_t code_point = 0;
        if (!grail_utf16_next(units, count, &index, &code_point)) {
            return GRAIL_E_INVALID_UTF8;
        }
        if (code_point < 0x80u) {
            bytes += 1;
        } else if (code_point < 0x800u) {
            bytes += 2;
        } else if (code_point < 0x10000u) {
            bytes += 3;
        } else {
            bytes += 4;
        }
        if (bytes > (uint64_t)INT64_MAX) {
            return GRAIL_E_OVERFLOW;
        }
    }
    if (bytes > capacity || out == NULL) {
        return (grail_result)bytes;
    }
    uint64_t written = 0;
    index = 0;
    while (index < count) {
        uint32_t code_point = 0;
        if (!grail_utf16_next(units, count, &index, &code_point)) {
            return GRAIL_E_INVALID_UTF8;
        }
        if (code_point < 0x80u) {
            out[written++] = (uint8_t)code_point;
        } else if (code_point < 0x800u) {
            out[written++] = (uint8_t)(0xC0u | (code_point >> 6));
            out[written++] = (uint8_t)(0x80u | (code_point & 0x3Fu));
        } else if (code_point < 0x10000u) {
            out[written++] = (uint8_t)(0xE0u | (code_point >> 12));
            out[written++] = (uint8_t)(0x80u | ((code_point >> 6) & 0x3Fu));
            out[written++] = (uint8_t)(0x80u | (code_point & 0x3Fu));
        } else {
            out[written++] = (uint8_t)(0xF0u | (code_point >> 18));
            out[written++] = (uint8_t)(0x80u | ((code_point >> 12) & 0x3Fu));
            out[written++] = (uint8_t)(0x80u | ((code_point >> 6) & 0x3Fu));
            out[written++] = (uint8_t)(0x80u | (code_point & 0x3Fu));
        }
    }
    return (grail_result)bytes;
}
