// C++ twin of bench/sieve.c: the Sieve of Eratosthenes up to 50 million, three rounds; prints the
// sum of the prime counts (each round's limit depends on the previous round's count). Uses a
// byte-per-flag std::vector<std::uint8_t>, matching the C, Rust, Zig and Grail twins.
#include <cstdint>
#include <cstdio>
#include <vector>
int main() {
    const unsigned long n = 50000000;
    unsigned long count = 0, total = 0;
    for (int round = 0; round < 3; ++round) {
        unsigned long limit = n - (count & 1);
        std::vector<std::uint8_t> composite(limit + 1, 0);
        count = 0;
        for (unsigned long i = 2; i <= limit; ++i)
            if (!composite[i]) {
                ++count;
                for (unsigned long j = i * i; j <= limit; j += i) composite[j] = 1;
            }
        total += count;
    }
    std::printf("%lu\n", total);
}
