/* Sums every byte of a 64 MiB buffer three times: the C side of bench/bounds.grl. */
#include <stdio.h>
#include <stdint.h>

#define N 67108864ULL

static uint8_t data[N];

int main(void) {
    uint64_t x = 88172645463325252ULL;
    for (uint64_t i = 0; i < N; i++) {
        x = x ^ (x << 13);
        x = x ^ (x >> 7);
        x = x ^ (x << 17);
        data[i] = (uint8_t)(x & 255);
    }
    uint64_t s = 0;
    for (int round = 0; round < 3; round++) {
        s = 0;
        uint64_t i = 0;
        while (i < N) {
            s += (uint64_t)data[i];
            i += 1;
        }
    }
    printf("%llu\n", (unsigned long long)s);
    return 0;
}
