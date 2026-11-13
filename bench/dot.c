/* Dot product of two f32 vectors, 16 million lanes, three times: the C side of bench/dot.grl. */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define N 16000000ULL

static float a[N];
static float b[N];

int main(void) {
    uint64_t x = 88172645463325252ULL;
    for (uint64_t i = 0; i < N; i++) {
        x = x ^ (x << 13);
        x = x ^ (x >> 7);
        x = x ^ (x << 17);
        a[i] = (float)(int64_t)(x & 1023) * 0.5f;
        b[i] = (float)(int64_t)((x >> 10) & 1023) * 0.25f;
    }
    double sum = 0.0;
    for (int round = 0; round < 3; round++) {
        sum = 0.0;
        uint64_t i = 0;
        while (i < N) {
            sum = sum + (double)a[i] * (double)b[i];
            i += 1;
        }
    }
    printf("%.17g\n", sum);
    return 0;
}
