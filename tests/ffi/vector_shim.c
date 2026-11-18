/* SIMD vectors by value across the C boundary (docs/design/simd.md, S4c): the real intrinsic types,
 * __m128/__m128d/__m128i and __m256 on x86-64 (SysV: xmm/ymm registers), float32x4_t, float64x2_t and
 * int32x4_t on AArch64 (AAPCS64: q registers), counted with the float arguments. */
#if defined(__x86_64__)
/* The shim is freestanding: immintrin.h's _mm_malloc wrapper (mm_malloc.h) includes <stdlib.h>,
 * which a cross target without its C library headers - Windows MSVC on a Linux host - does not have.
 * Nothing here allocates, so that header is skipped by its include guard. */
#define __MM_MALLOC_H
#include <immintrin.h>
typedef __m128 vf4;
typedef __m128d vd2;
typedef __m128i vi4;
static float vf4_lane(vf4 v, int k) { float f[4]; _mm_storeu_ps(f, v); return f[k]; }
static double vd2_lane(vd2 v, int k) { double d[2]; _mm_storeu_pd(d, v); return d[k]; }
static vf4 vf4_add(vf4 a, vf4 b) { return _mm_add_ps(a, b); }
static vf4 vf4_mul(vf4 a, vf4 b) { return _mm_mul_ps(a, b); }
static vi4 vi4_make(int a, int b, int c, int d) { return _mm_setr_epi32(a, b, c, d); }
#elif defined(__aarch64__)
#include <arm_neon.h>
typedef float32x4_t vf4;
typedef float64x2_t vd2;
typedef int32x4_t vi4;
static float vf4_lane(vf4 v, int k) { float f[4]; vst1q_f32(f, v); return f[k]; }
static double vd2_lane(vd2 v, int k) { double d[2]; vst1q_f64(d, v); return d[k]; }
static vf4 vf4_add(vf4 a, vf4 b) { return vaddq_f32(a, b); }
static vf4 vf4_mul(vf4 a, vf4 b) { return vmulq_f32(a, b); }
static vi4 vi4_make(int a, int b, int c, int d) { int t[4] = {a, b, c, d}; return vld1q_s32(t); }
#endif

#if defined(__x86_64__) || defined(__aarch64__)
vf4 c_vec_add(vf4 a, vf4 b) { return vf4_add(a, b); }
vf4 c_vec_madd(vf4 a, vf4 b, vf4 c) { return vf4_add(vf4_mul(a, b), c); }
/* Scalars and vectors interleaved: x in the first float register, a in the second, b in the third;
 * n and m in the integer registers. */
double c_vec_mix(double x, vf4 a, long n, vd2 b, long m) {
    return x + (double)n * 1000.0 + (double)m * 100000.0
        + vf4_lane(a, 0) + vf4_lane(a, 1) * 10.0 + vf4_lane(a, 2) * 100.0 + vf4_lane(a, 3) * 1000.0
        + vd2_lane(b, 0) * 0.5 + vd2_lane(b, 1) * 0.25;
}
/* Eight vector arguments: every float/vector argument register. */
double c_vec_eight(vf4 a, vf4 b, vf4 c, vf4 d, vf4 e, vf4 f, vf4 g, vf4 h) {
    vf4 v[8] = {a, b, c, d, e, f, g, h};
    double t = 0;
    for (int i = 0; i < 8; i++) t = t * 2 + vf4_lane(v[i], i % 4);
    return t;
}
vi4 c_vec_ints(long k) { return vi4_make((int)k, (int)k + 1, -(int)k, 2147483647); }
vd2 c_vec_swap(vd2 v) { return (vd2){vd2_lane(v, 1), vd2_lane(v, 0)}; }
#endif

