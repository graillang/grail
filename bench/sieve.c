// Sieve of Eratosthenes up to 50 million, three rounds; prints the sum of the prime counts. Each
// round's limit depends on the previous round's count, so no round is dead code a compiler may drop.
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    const unsigned long n = 50000000;
    unsigned long count = 0, total = 0;
    for (int round = 0; round < 3; ++round) {
        unsigned long limit = n - (count & 1);
        unsigned char* composite = calloc(limit + 1, 1);
        count = 0;
        for (unsigned long i = 2; i <= limit; ++i)
            if (!composite[i]) {
                ++count;
                for (unsigned long j = i * i; j <= limit; j += i) composite[j] = 1;
            }
        free(composite);
        total += count;
    }
    printf("%lu\n", total);
    return 0;
}
