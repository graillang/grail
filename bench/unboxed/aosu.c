#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
typedef struct { uint64_t x, y, z; } P3;
int main(void) {
    size_t n = 1000000, cap = 0, len = 0; P3 *v = 0;
    for (size_t i = 0; i < n; i++) {
        uint64_t f = i % 1000;
        if (len == cap) { cap = cap ? cap * 2 : 8; v = realloc(v, cap * sizeof *v); }
        v[len++] = (P3){f, f * 3, f * 5};
    }
    uint64_t total = 0;
    for (uint64_t pass = 0; pass < 20; pass++) {
        for (size_t i = 0; i < n; i++) { P3 *p = &v[i]; p->x = p->x * 3 + p->y; p->y ^= pass; p->z += 1; }
        for (size_t i = 0; i < n; i++) { P3 *q = &v[i]; total += q->x + q->y + q->z; }
    }
    printf("%llu\n", (unsigned long long)total);
}
