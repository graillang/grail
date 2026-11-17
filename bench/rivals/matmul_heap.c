// bench/matmul.c with a, b and c malloc'd instead of static arrays: the data structure the Rust, Go,
// Zig and Grail twins use. tools/bench-rivals.mjs, "language gaps".
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    enum { n = 256 };
    float *a = malloc(sizeof(float) * n * n), *b = malloc(sizeof(float) * n * n), *c = malloc(sizeof(float) * n * n);
    for (int i = 0; i < n * n; ++i) { a[i] = (float)(i % 7) * 0.25f; b[i] = (float)(i % 11) * 0.5f; }
    for (int round = 0; round < 20; ++round) {
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < n; ++j) {
                float s = 0.0f;
                for (int k = 0; k < n; ++k) s = s + a[i * n + k] * b[k * n + j];
                c[i * n + j] = s;
            }
        a[round] = c[round]; // the next round depends on this one: no round is dead code
    }
    double sum = 0.0;
    for (int i = 0; i < n * n; ++i) sum += c[i];
    printf("%.17g\n", sum);
    return 0;
}
