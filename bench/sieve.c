#include <stdio.h>
#include <stdlib.h>
int main(void) {
    const unsigned long n = 50000000;
    unsigned long count = 0;
    for (int round = 0; round < 3; ++round) {
        unsigned char* composite = calloc(n + 1, 1);
        count = 0;
        for (unsigned long i = 2; i <= n; ++i)
            if (!composite[i]) {
                ++count;
                for (unsigned long j = i * i; j <= n; j += i) composite[j] = 1;
            }
        free(composite);
    }
    printf("%lu\n", count);
    return 0;
}
