// The C twin of bench/simd_aos.grl: xyzw records to four arrays with SSE2 intrinsics, four records
// at a time through the _MM_TRANSPOSE4_PS steps; heap arrays and a count the compiler cannot see.
#include <xmmintrin.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

__attribute__((noinline)) static void split(const float *src, float *x, float *y, float *z, float *w, size_t n) {
    for (size_t i = 0; i + 4 <= n; i += 4) {
        __m128 r0 = _mm_loadu_ps(src + 4 * i), r1 = _mm_loadu_ps(src + 4 * i + 4);
        __m128 r2 = _mm_loadu_ps(src + 4 * i + 8), r3 = _mm_loadu_ps(src + 4 * i + 12);
        __m128 t0 = _mm_unpacklo_ps(r0, r1), t1 = _mm_unpackhi_ps(r0, r1);
        __m128 t2 = _mm_unpacklo_ps(r2, r3), t3 = _mm_unpackhi_ps(r2, r3);
        _mm_storeu_ps(x + i, _mm_movelh_ps(t0, t2));
        _mm_storeu_ps(y + i, _mm_movehl_ps(t2, t0));
        _mm_storeu_ps(z + i, _mm_movelh_ps(t1, t3));
        _mm_storeu_ps(w + i, _mm_movehl_ps(t3, t1));
    }
}

int main(int argc, char **argv) {
    long rounds = argc > 1 ? atol(argv[1]) : 1000;
    size_t count = 4096 + (size_t)(argc > 99);
    float *src = malloc(count * 16), *x = malloc(count * 4), *y = malloc(count * 4), *z = malloc(count * 4), *w = malloc(count * 4);
    for (size_t i = 0; i < count * 4; i++) src[i] = (float)(i % 11) * 0.5f;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (long r = 0; r < rounds; r++) {
        __asm__ volatile("" : : "r"(src), "r"(x), "r"(y), "r"(z), "r"(w) : "memory");
        split(src, x, y, z, w, count);
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double check = 0;
    for (size_t i = 0; i < count; i++) check += x[i] + 2.0 * y[i] + 3.0 * z[i] + 4.0 * w[i];
    double ns = (t1.tv_sec - t0.tv_sec) * 1e9 + (t1.tv_nsec - t0.tv_nsec);
    printf("%.17g\nns/record %.6g\n", check, ns / ((double)rounds * count));
    return 0;
}
