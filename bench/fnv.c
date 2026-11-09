#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
int main(void) {
    const size_t n = 67108864;
    unsigned char* data = malloc(n);
    uint64_t x = 88172645463325252ull;
    for (size_t i = 0; i < n; ++i) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; data[i] = (unsigned char)(x & 255); }
    uint64_t h = 14695981039346656037ull;
    for (int round = 0; round < 8; ++round)
        for (size_t i = 0; i < n; ++i) h = (h ^ data[i]) * 1099511628211ull;
    printf("%llu\n", (unsigned long long)h);
    return 0;
}
