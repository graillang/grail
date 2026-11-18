// C++ twin of bench/iterchain.grl: a std::vector of ten million values run through a C++20 ranges
// pipeline, std::views::transform (x * 2) then std::views::filter (% 3 == 0), folded with a
// range-for loop (std::ranges::fold_left is C++23). Same work and output as the C twin's loop.
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
    for (uint64_t y : v | std::views::transform([](uint64_t x) { return x * 2; })
                        | std::views::filter([](uint64_t y) { return y % 3 == 0; }))
        s += y;
    std::printf("%llu\n", (unsigned long long)s);
}
