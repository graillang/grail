#include <stdint.h>
typedef struct { int64_t a, b; } Bv16;
typedef struct { double d; int64_t i; } BvMd;
typedef struct { int64_t a, b, c; } Bv24;
int64_t c_add3(int64_t a, int64_t b, int64_t c) { return a + b + c; }
int64_t c_byval16(Bv16 s) { return s.a + s.b; }
int64_t c_byval_md(BvMd s) { return (int64_t)s.d + s.i; }
int64_t c_byval24(Bv24 s) { return s.a + s.b + s.c; }
Bv16 c_make16(int64_t a, int64_t b) { Bv16 r = {a, b}; return r; }
double c_fma(double a, double b, double c) { return a * b + c; }
float c_fmaf(float a, float b, float c) { return a * b + c; }
int64_t c_sum_view(const unsigned char *p, uint64_t n) { return n ? p[0] + (int64_t)n : 0; }
int64_t c_apply(int64_t (*cb)(int64_t), int64_t v) { return cb(v); }
int64_t c_loop(int64_t (*cb)(int64_t), int64_t n) { int64_t t = 0; for (int64_t i = 0; i < n; i++) t += cb(i); return t; }
