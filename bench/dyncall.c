// The C twin of bench/dyncall.grl: each shape allocated on its own behind a pointer to a table of
// function pointers, the C spelling of an interface object.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
typedef struct Shape Shape;
typedef struct { uint64_t (*area)(const Shape *); } ShapeVT;
struct Shape { const ShapeVT *vt; };
typedef struct { Shape base; uint64_t side; } Square;
typedef struct { Shape base; uint64_t w, h; } Rect;
typedef struct { Shape base; uint64_t b, h; } Tri;
static uint64_t square_area(const Shape *s) { const Square *q = (const Square *)s; return q->side * q->side; }
static uint64_t rect_area(const Shape *s) { const Rect *r = (const Rect *)s; return r->w * r->h; }
static uint64_t tri_area(const Shape *s) { const Tri *t = (const Tri *)s; return t->b * t->h / 2; }
static const ShapeVT square_vt = { square_area }, rect_vt = { rect_area }, tri_vt = { tri_area };
int main(void) {
    const uint64_t n = 1000000;
    Shape **shapes = malloc(n * sizeof *shapes);
    uint64_t x = 88172645463325252ull;
    for (uint64_t i = 0; i < n; i++) {
        x = xs(x);
        uint64_t k = x % 3, a = x % 100, b = (x >> 8) % 100;
        if (k == 0) { Square *q = malloc(sizeof *q); q->base.vt = &square_vt; q->side = a; shapes[i] = &q->base; }
        else if (k == 1) { Rect *r = malloc(sizeof *r); r->base.vt = &rect_vt; r->w = a; r->h = b; shapes[i] = &r->base; }
        else { Tri *t = malloc(sizeof *t); t->base.vt = &tri_vt; t->b = a; t->h = b; shapes[i] = &t->base; }
    }
    uint64_t total = 0;
    for (int pass = 0; pass < 20; pass++)
        for (uint64_t i = 0; i < n; i++) total += shapes[i]->vt->area(shapes[i]);
    printf("%llu\n", (unsigned long long)total);
    return 0;
}
