// C++ twin of bench/ffi_call.c: 10M calls of the separately compiled extern "C" function
// grail_bench_abs (bench/ffi_target.c -> .work/libffi_target.a), best of five rounds.
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
extern "C" std::int64_t grail_bench_abs(std::int64_t x);
using clk = std::chrono::steady_clock;
static unsigned long long us(clk::time_point t0) { return std::chrono::duration_cast<std::chrono::microseconds>(clk::now() - t0).count(); }
int main() {
    const long long n = 10000000;
    long long acc = 0;
    unsigned long long best = ~0ull;
    for (int round = 0; round < 5; round++) {
        auto t0 = clk::now();
        for (long long i = 0; i < 10000000; i++) acc = acc + grail_bench_abs(i - 5000000);
        best = std::min(best, us(t0));
    }
    // The same loop without the call (volatile keeps it a loop): what is left is the call.
    unsigned long long bare = ~0ull;
    for (int round = 0; round < 5; round++) {
        auto t0 = clk::now();
        for (volatile long long i = 0; i < 10000000; i = i + 1) acc = acc + (i - 5000000);
        bare = std::min(bare, us(t0));
    }
    std::fprintf(stderr, "ffi_call %llu ps\n", best * 1000000ull / (unsigned long long)n);
    std::fprintf(stderr, "ffi_call_only %llu ps\n", (best > bare ? best - bare : 0) * 1000000ull / (unsigned long long)n);
    std::printf("checksum %lld\n", acc);
}
