// Instruction-count probes for oneTBB: `prog MODE N`, one thread (global_control).
#include <oneapi/tbb.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
static unsigned long fib(unsigned long n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
static unsigned long pfib(unsigned long n) {
    if (n < 12) return fib(n);
    unsigned long a, b;
    tbb::parallel_invoke([&] { a = pfib(n - 1); }, [&] { b = pfib(n - 2); });
    return a + b;
}
int main(int argc, char** argv) {
    tbb::global_control gc(tbb::global_control::max_allowed_parallelism, 1);
    unsigned long n = strtoul(argv[2], 0, 10), acc = 0;
    if (!strcmp(argv[1], "join")) {
        for (unsigned long i = 0; i < n; i++) { unsigned long a, b; tbb::parallel_invoke([&] { a = 1; }, [&] { b = 2; }); acc += a + b; }
    } else if (!strcmp(argv[1], "spawn")) {
        for (unsigned long i = 0; i < n; i++) { tbb::task_group g; unsigned long r = 0; g.run([&] { r = 1; }); g.wait(); acc += r; }
    } else if (!strcmp(argv[1], "fib")) {
        for (unsigned long i = 0; i < n; i++) acc += pfib(20);
    }
    printf("%lu\n", acc);
}
