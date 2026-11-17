// The C twin of bench/simd_mat4.grl: the same column-major 4x4 products with SSE2 intrinsics, the
// same operations in the same order; heap arrays and a count the compiler cannot see.
#include <emmintrin.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

__attribute__((noinline)) static void mul_all(const float *a, const float *b, float *out, size_t n) {
    for (size_t base = 0; base + 16 <= n; base += 16) {
        __m128 a0 = _mm_loadu_ps(a + base), a1 = _mm_loadu_ps(a + base + 4);
        __m128 a2 = _mm_loadu_ps(a + base + 8), a3 = _mm_loadu_ps(a + base + 12);
        for (int j = 0; j < 4; j++) {
            __m128 bj = _mm_loadu_ps(b + base + 4 * j);
            __m128 col = _mm_add_ps(_mm_add_ps(_mm_add_ps(
                _mm_mul_ps(a0, _mm_shuffle_ps(bj, bj, 0x00)), _mm_mul_ps(a1, _mm_shuffle_ps(bj, bj, 0x55))),
                _mm_mul_ps(a2, _mm_shuffle_ps(bj, bj, 0xaa))), _mm_mul_ps(a3, _mm_shuffle_ps(bj, bj, 0xff)));
            _mm_storeu_ps(out + base + 4 * j, col);
        }
    }
}

int main(int argc, char **argv) {
    long rounds = argc > 1 ? atol(argv[1]) : 1000;
    size_t count = 1024 + (size_t)(argc > 99), n = count * 16;
    float *a = malloc(n * 4), *b = malloc(n * 4), *out = malloc(n * 4);
    for (size_t i = 0; i < n; i++) {
        a[i] = (float)(i % 7) * 0.5f - 1.0f;
        b[i] = (float)(i % 5) * 0.25f;
        out[i] = 0;
    }
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (long r = 0; r < rounds; r++) {
        __asm__ volatile("" : : "r"(a), "r"(b), "r"(out) : "memory");
        mul_all(a, b, out, n);
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);
    double check = 0;
    for (size_t i = 0; i < n; i++) check += out[i];
    double ns = (t1.tv_sec - t0.tv_sec) * 1e9 + (t1.tv_nsec - t0.tv_nsec);
    printf("%.17g\nns/matrix %.6g\n", check, ns / ((double)rounds * count));
    return 0;
}
