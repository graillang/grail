// C++ twin of bench/hashmap.grl: std::unordered_map<uint64_t, uint64_t> with the default hash, the
// standard library's map and the one a C++ program reaches for. It is a node-based chained table
// (one allocation per entry), so it does more work than the C twin's open addressing; that
// difference is the point of the comparison. Same keys, same operations, same output.
// clang++ -std=c++20 -O2 -ffp-contract=off hashmap.cpp
#include <cstdint>
#include <cstdio>
#include <unordered_map>
#include <vector>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
int main() {
    const uint64_t n = 1000000;
    std::unordered_map<uint64_t, uint64_t> m;
    std::vector<uint64_t> keys;
    keys.reserve(n);
    uint64_t x = 88172645463325252ull;
    for (uint64_t i = 0; i < n; i++) { x = xs(x); keys.push_back(x); m.insert_or_assign(x, i); }
    uint64_t sum = 0, removed = 0, found = 0;
    for (uint64_t k : keys) if (auto it = m.find(k); it != m.end()) sum += it->second;
    for (uint64_t i = 0; i < n; i += 2)
        if (auto it = m.find(keys[i]); it != m.end()) { removed += it->second; m.erase(it); }
    for (uint64_t k : keys) if (m.contains(k)) found++;
    std::printf("%llu %llu %llu %llu\n", (unsigned long long)sum, (unsigned long long)removed, (unsigned long long)found,
                (unsigned long long)m.size());
}
