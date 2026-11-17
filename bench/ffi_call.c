// bench-cflags: -fno-builtin
// The C twin of bench/ffi_call.grl: the same 10M calls of libc's `labs`, best of five rounds. Built
// with -fno-builtin so `labs` is a real call through the PLT, as Grail's is, not an inlined abs.
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static unsigned long long now_us(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (unsigned long long)t.tv_sec * 1000000ull + (unsigned long long)t.tv_nsec / 1000ull;
}
int main(void) {
    const long long n = 10000000;
    long long acc = 0;
    unsigned long long best = ~0ull;
    for (int round = 0; round < 5; round++) {
        unsigned long long t0 = now_us();
        for (long long i = 0; i < 10000000; i++) acc = acc + labs(i - 5000000);
        unsigned long long t = now_us() - t0;
        if (t < best) best = t;
    }
    /* The same loop without the call (volatile keeps it a loop): what is left is the call. */
    unsigned long long bare = ~0ull;
    for (int round = 0; round < 5; round++) {
        unsigned long long t0 = now_us();
        for (volatile long long i = 0; i < 10000000; i++) acc = acc + (i - 5000000);
        unsigned long long t = now_us() - t0;
        if (t < bare) bare = t;
    }
    fprintf(stderr, "ffi_call %llu ps\n", best * 1000000ull / (unsigned long long)n);
    fprintf(stderr, "ffi_call_only %llu ps\n", (best > bare ? best - bare : 0) * 1000000ull / (unsigned long long)n);
    printf("checksum %lld\n", acc);
    return 0;
}
