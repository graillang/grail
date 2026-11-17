// The C twin of bench/simd_dot.grl: the same loop with SSE2 intrinsics, one accumulator, and the same
// halving-tree horizontal sum, so both compute the same float in the same order.
#include <emmintrin.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

__attribute__((noinline)) static float dot(const float *x, const float *y, size_t n) {
    __m128 acc = _mm_setzero_ps();
    for (size_t i = 0; i + 4 <= n; i += 4)
        acc = _mm_add_ps(acc, _mm_mul_ps(_mm_loadu_ps(x + i), _mm_loadu_ps(y + i)));
    __m128 half = _mm_add_ps(acc, _mm_movehl_ps(acc, acc));
    __m128 one = _mm_add_ss(half, _mm_shuffle_ps(half, half, 0x55));
    return _mm_cvtss_f32(one);
}

int main(int argc, char **argv) {
    long rounds = argc > 1 ? atol(argv[1]) : 100000;
    // Heap arrays and a length the compiler cannot see, as the Grail program's slices are: with
    // static arrays and a constant N clang specialises `dot` to them (and unrolls by a known count).
    size_t N = 4096 + (size_t)(argc > 99);
    float *xs = malloc(N * sizeof(float)), *ys = malloc(N * sizeof(float));
    for (size_t i = 0; i < N; i++) {
        xs[i] = (float)(i % 17) * 0.25f;
        ys[i] = (float)(i % 13) * 0.5f - 2.0f;
    }
    double total = 0;
    struct timespec a, b;
    clock_gettime(CLOCK_MONOTONIC, &a);
    for (long r = 0; r < rounds; r++) {
        // The inputs may have changed, as far as the compiler knows: one call per round, as the
        // Grail loop makes (clang would otherwise compute the pure `dot` once).
        __asm__ volatile("" : : "r"(xs), "r"(ys) : "memory");
        total += dot(xs, ys, N);
    }
    clock_gettime(CLOCK_MONOTONIC, &b);
    double ns = (b.tv_sec - a.tv_sec) * 1e9 + (b.tv_nsec - a.tv_nsec);
    printf("%.17g\nns/element %.6g\n", total, ns / ((double)rounds * N));
    return 0;
}
