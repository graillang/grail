#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
int main(void) {
    const size_t n = 4194304;
    uint64_t check = 0;
    for (int round = 0; round < 3; ++round) {
        uint64_t* v = malloc(n * 8); uint64_t* tmp = malloc(n * 8);
        uint64_t x = 2463534242ull + (uint64_t)round;
        for (size_t i = 0; i < n; ++i) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; v[i] = x; }
        memcpy(tmp, v, n * 8);
        for (size_t width = 1; width < n; width *= 2) {
            for (size_t lo = 0; lo < n; ) {
                size_t mid = lo + width > n ? n : lo + width, hi = lo + 2 * width > n ? n : lo + 2 * width;
                size_t i = lo, j = mid;
                for (size_t k = lo; k < hi; ++k) {
                    if (i < mid && (j >= hi || v[i] <= v[j])) tmp[k] = v[i++]; else tmp[k] = v[j++];
                }
                lo = hi;
            }
            uint64_t* s = v; v = tmp; tmp = s;
        }
        check ^= v[0] ^ v[n / 2] ^ v[n - 1];
        free(v); free(tmp);
    }
    printf("%llu\n", (unsigned long long)check);
    return 0;
}
