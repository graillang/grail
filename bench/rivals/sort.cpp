// C++ twin of bench/sort.c: a bottom-up merge sort of 4 million xorshift u64 values, three times;
// prints a checksum. Each pass merges runs with std::merge (stable: equal keys come from the left
// run first, as in the C loop) into the other buffer, then the two are swapped.
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <vector>
int main() {
    const std::size_t n = 4194304;
    std::uint64_t check = 0;
    for (int round = 0; round < 3; ++round) {
        std::vector<std::uint64_t> v(n);
        std::uint64_t x = 2463534242ull + std::uint64_t(round);
        for (auto &e : v) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; e = x; }
        std::vector<std::uint64_t> tmp = v;
        for (std::size_t width = 1; width < n; width *= 2) {
            for (std::size_t lo = 0; lo < n; lo += 2 * width) {
                std::size_t mid = std::min(lo + width, n), hi = std::min(lo + 2 * width, n);
                std::merge(v.begin() + lo, v.begin() + mid, v.begin() + mid, v.begin() + hi, tmp.begin() + lo);
            }
            std::swap(v, tmp);
        }
        check ^= v[0] ^ v[n / 2] ^ v[n - 1];
    }
    std::printf("%llu\n", (unsigned long long)check);
}
