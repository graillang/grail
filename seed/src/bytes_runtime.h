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
static void gr_push(gb *owner, uint64_t value) {
    if (owner->n == owner->c) {
        if (owner->c > SIZE_MAX / 2) abort();
        uint64_t capacity = owner->c ? owner->c * 2 : 8;
        uint8_t *next = (uint8_t *)realloc(owner->p, (size_t)capacity);
        if (!next) abort();
        owner->p = next;
        owner->c = capacity;
    }
    owner->p[owner->n++] = (uint8_t)value;
}
