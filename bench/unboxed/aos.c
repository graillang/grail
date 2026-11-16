#include <stdio.h>
#include <stdlib.h>
typedef struct { float x, y, z; } V3;
int main(void) {
    size_t n = 1000000, cap = 0, len = 0; V3 *v = 0;
    for (size_t i = 0; i < n; i++) {
        float f = (float)(i % 1000);
        if (len == cap) { cap = cap ? cap * 2 : 8; v = realloc(v, cap * sizeof *v); }
        v[len++] = (V3){f, f * 0.5f, f * 0.25f};
    }
    float total = 0;
    for (int pass = 0; pass < 20; pass++) {
        for (size_t i = 0; i < n; i++) { V3 *p = &v[i]; p->x = p->x * 1.0001f + p->y; p->y *= 0.9999f; p->z += 1.0f; }
        for (size_t i = 0; i < n; i++) { V3 *q = &v[i]; total = total + q->x + q->y + q->z; }
    }
    printf("%g\n", total);
}
