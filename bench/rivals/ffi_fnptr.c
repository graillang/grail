// A C call to C through an opaque function pointer: bench/ffi_call.c calling grail_bench_abs
// through a volatile function pointer. Reference for ffi_call: indirect C-to-C call cost.
#include <stdint.h>
#include <stdio.h>
#include <time.h>
extern int64_t grail_bench_abs(int64_t x);
static unsigned long long now_us(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (unsigned long long)t.tv_sec * 1000000ull + (unsigned long long)t.tv_nsec / 1000ull;
}
int main(void) {
    int64_t (*const volatile pick)(int64_t) = grail_bench_abs;
    int64_t (*call)(int64_t) = pick;
    const long long n = 10000000;
    long long acc = 0;
    unsigned long long best = ~0ull;
    for (int round = 0; round < 5; round++) {
        unsigned long long t0 = now_us();
        for (long long i = 0; i < 10000000; i++) acc = acc + call(i - 5000000);
        unsigned long long t = now_us() - t0;
        if (t < best) best = t;
    }
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
