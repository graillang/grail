// C++ twin of bench/fnv.c: 64 MiB of xorshift bytes, then eight rounds of FNV-1a over them.
#include <cstdint>
#include <cstdio>
#include <vector>
int main() {
    const std::size_t n = 67108864;
    std::vector<std::uint8_t> data(n);
    std::uint64_t x = 88172645463325252ull;
    for (auto &b : data) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; b = std::uint8_t(x & 255); }
    std::uint64_t h = 14695981039346656037ull;
    for (int round = 0; round < 8; ++round)
        for (std::uint8_t b : data) h = (h ^ b) * 1099511628211ull;
    std::printf("%llu\n", (unsigned long long)h);
}
