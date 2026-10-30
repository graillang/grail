#ifndef GRAIL_BYTES_TYPES_DEFINED
#define GRAIL_BYTES_TYPES_DEFINED
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
typedef struct { uint8_t *p; uint64_t n; } gv;
typedef struct { uint8_t *p; uint64_t n, c; } gb;
#endif
/* Trusted byte-vector primitives. Borrow conflicts are checked statically, not here. */
static gb gr_copy_bytes(gv src) {
    gb result = {0, src.n, src.n};
    if (src.n) {
        if (src.n > SIZE_MAX) abort();
        result.p = (uint8_t *)malloc((size_t)src.n);
        if (!result.p) abort();
        memcpy(result.p, src.p, (size_t)src.n);
    }
    return result;
}
static void gr_reserve(gb *owner, uint64_t needed) {
    if (needed > SIZE_MAX) abort();
    if (needed <= owner->c) return;
    uint64_t capacity = owner->c ? owner->c : 8;
    while (capacity < needed) {
        if (capacity > SIZE_MAX / 2) { capacity = needed; break; }
        capacity *= 2;
    }
    uint8_t *next = (uint8_t *)realloc(owner->p, (size_t)capacity);
    if (!next) abort();
    owner->p = next;
    owner->c = capacity;
}
static void gr_push(gb *owner, uint64_t value) {
    if (owner->n == UINT64_MAX) abort();
    gr_reserve(owner, owner->n + 1);
    owner->p[owner->n++] = (uint8_t)value;
}
static void gr_utf8(gv src) {
    uint64_t i = 0;
    while (i < src.n) {
        uint8_t first = src.p[i++];
        if (first < 128) continue;
        unsigned need; uint32_t cp;
        if (first >= 0xc2 && first <= 0xdf) {need=1;cp=first & 31;}
        else if (first >= 0xe0 && first <= 0xef) {need=2;cp=first & 15;}
        else if (first >= 0xf0 && first <= 0xf4) {need=3;cp=first & 7;}
        else abort();
        if (src.n - i < need) abort();
        for (unsigned j=0;j<need;++j) {
            uint8_t c=src.p[i++]; if ((c & 0xc0) != 0x80) abort();
            cp=(cp << 6) | (c & 63);
        }
        if ((need==2 && cp<0x800) || (need==3 && cp<0x10000) ||
            (cp>=0xd800 && cp<=0xdfff) || cp>0x10ffff) abort();
    }
}
static void gr_append_text(gb *owner, gv src) {
    gr_utf8(src);
    if (src.n > UINT64_MAX - owner->n) abort();
    gr_reserve(owner, owner->n + src.n);
    if (src.n) memcpy(owner->p + owner->n, src.p, (size_t)src.n);
    owner->n += src.n;
}
