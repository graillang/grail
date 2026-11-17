// The reference for tests/simd/fma.grl: the same inputs (the same generator, consumed in the same
// order) through C's fmaf/fma on the host, and the same checksum. Regenerate the expected output
// with `cc -O2 -ffp-contract=off tests/simd/fma_reference.c -lm && ./a.out`.
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static uint64_t s = 88172645463325252ull;
static uint64_t next(void) {
    uint64_t x = s;
    x ^= x >> 12; x ^= x << 25; x ^= x >> 27;
    s = x;
    return x * 2685821657736338717ull;
}
static uint32_t pick32(void) {
    uint64_t r = next();
    static const uint32_t edges[12] = {0, 2147483648u, 2139095040u, 4286578688u, 2143289344u, 1, 2155872256u, 2139095039u, 1065353216u, 8388608u, 3212836864u, 1073741824u};
    if (r % 8 == 0) return edges[(r >> 8) % 12];
    if (r % 8 == 1) return (uint32_t)(((r >> 8) & 2155872255u) | (((r >> 40) % 40 + 100) << 23));
    return (uint32_t)(r >> 32);
}
static uint64_t pick64(void) {
    uint64_t r = next();
    static const uint64_t edges[12] = {0, 9223372036854775808ull, 9218868437227405312ull, 18442240474082181120ull, 9221120237041090560ull, 1, 9223372036854775809ull, 9218868437227405311ull, 4607182418800017408ull, 4503599627370496ull, 13830554455654793216ull, 4611686018427387904ull};
    if (r % 8 == 0) return edges[(r >> 8) % 12];
    if (r % 8 == 1) return (r & 9227875636482146303ull) | (((r >> 40) % 80 + 500) << 52);
    return next();
}
static uint64_t mix(uint64_t h, uint64_t v) { return (h ^ v) * 1099511628211ull; }
static float f32(uint32_t b) { float f; memcpy(&f, &b, 4); return f; }
static uint32_t b32(float f) { uint32_t b; memcpy(&b, &f, 4); return b; }
static double f64(uint64_t b) { double f; memcpy(&f, &b, 8); return f; }
static uint64_t b64(double f) { uint64_t b; memcpy(&b, &f, 8); return b; }
static uint64_t nan32(uint32_t b) { return ((b & 2139095040u) == 2139095040u && (b & 8388607u)) ? 2143289344u : b; }
static uint64_t nan64(uint64_t b) { return ((b & 9218868437227405312ull) == 9218868437227405312ull && (b & 4503599627370495ull)) ? 9221120237041090560ull : b; }

int main(void) {
    uint64_t h = 14695981039346656037ull;
    for (int i = 0; i < 50000; i++) {
        uint32_t a[4], b[4], c[4];
        for (int k = 0; k < 4; k++) { a[k] = pick32(); b[k] = pick32(); c[k] = pick32(); }
        for (int k = 0; k < 4; k++) {
            float cc = f32(c[k]);
            if (i % 4 == 3) cc = 0.0f - f32(a[k]) * f32(b[k]);
            h = mix(h, nan32(b32(fmaf(f32(a[k]), f32(b[k]), cc))));
        }
        // The same evaluation order as the Grail program's f64x2::new arguments.
        uint64_t x0 = pick64(), x1 = pick64(), y0 = pick64(), y1 = pick64(), z0 = pick64(), z1 = pick64();
        double wa[2] = {f64(x0), f64(x1)}, wb[2] = {f64(y0), f64(y1)}, wc[2] = {f64(z0), f64(z1)};
        for (int k = 0; k < 2; k++) {
            double cc = wc[k];
            if (i % 4 == 1) cc = 0.0 - wa[k] * wb[k];
            h = mix(h, nan64(b64(fma(wa[k], wb[k], cc))));
        }
    }
    printf("%llu\n", (unsigned long long)h);
    return 0;
}
