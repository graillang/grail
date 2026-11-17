// The C twin of bench/iterchain.grl. C has no iterator adapters: the chain is the loop.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    const uint64_t n = 10000000;
    uint64_t *v = malloc(n * 8);
    for (uint64_t i = 0; i < n; i++) v[i] = i;
    uint64_t s = 0;
    for (uint64_t i = 0; i < n; i++) { uint64_t y = v[i] * 2; if (y % 3 == 0) s += y; }
    printf("%llu\n", (unsigned long long)s);
    return 0;
}
