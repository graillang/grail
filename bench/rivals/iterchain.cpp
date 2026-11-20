// C++ twin of bench/iterchain.grl: 20 rounds over ten million u64 through a C++20 ranges pipeline.
// clang++ -std=c++20 -O2 -ffp-contract=off iterchain.cpp
#include <cstdint>
#include <cstdio>
#include <numeric>
#include <ranges>
#include <vector>
int main() {
    const uint64_t n = 10000000;
    std::vector<uint64_t> v(n);
    std::iota(v.begin(), v.end(), uint64_t{0});
    uint64_t s = 0;
    for (uint64_t round = 0; round < 20; round++) {
        for (uint64_t y : v | std::views::transform([round](uint64_t x) { return (x + round) * 2; })
                            | std::views::filter([](uint64_t y) { return y % 3 == 0; }))
            s += y;
    }
    std::printf("%llu\n", (unsigned long long)s);
}
