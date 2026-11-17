// A C call to C that cannot be inlined: bench/ffi_call.c (gaps12-sched) with `labs` called through a
// function pointer the compiler cannot see through. The reference for ffi_call: what "as cheap as
// a C-to-C call" means when the call stays a call. tools/bench-rivals.mjs, "references".
// The same 10M calls, best of five rounds; no -fno-builtin needed, the pointer hides what it calls.
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static unsigned long long now_us(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (unsigned long long)t.tv_sec * 1000000ull + (unsigned long long)t.tv_nsec / 1000ull;
}
int main(void) {
    /* Read once through a volatile: the compiler cannot know the target, so every call below is an
       indirect call to libc's labs that cannot be inlined, as a call across a library boundary. */
    long (*const volatile pick)(long) = labs;
    long (*call)(long) = pick;
    const long long n = 10000000;
    long long acc = 0;
    unsigned long long best = ~0ull;
    for (int round = 0; round < 5; round++) {
        unsigned long long t0 = now_us();
        for (long long i = 0; i < 10000000; i++) acc = acc + call(i - 5000000);
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
