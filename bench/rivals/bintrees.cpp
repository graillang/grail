// C++ twin of bench/bintrees.grl: binary trees whose children are std::unique_ptr<Node> (the
// counterpart of the Rust twin's Option<Box<Node>>): one operator new per node, freed by the
// unique_ptr destructors when a tree goes out of scope. Same depths, iterations and output.
// clang++ -std=c++20 -O2 -ffp-contract=off bintrees.cpp
#include <cstdint>
#include <cstdio>
#include <memory>
struct Node {
    std::unique_ptr<Node> left, right;
};
static std::unique_ptr<Node> make(uint64_t depth) {
    auto n = std::make_unique<Node>();
    if (depth > 0) { n->left = make(depth - 1); n->right = make(depth - 1); }
    return n;
}
static uint64_t check(const Node *t) { return t ? 1 + check(t->left.get()) + check(t->right.get()) : 0; }
int main() {
    const uint64_t max = 16;
    {
        auto stretch = make(max + 1);
        std::printf("%llu\n", (unsigned long long)check(stretch.get()));
    }
    auto long_lived = make(max);
    for (uint64_t d = 4; d <= max; d += 2) {
        uint64_t iterations = 1ull << (max - d + 4), total = 0;
        for (uint64_t i = 0; i < iterations; i++) total += check(make(d).get());
        std::printf("%llu %llu\n", (unsigned long long)iterations, (unsigned long long)total);
    }
    std::printf("%llu\n", (unsigned long long)check(long_lived.get()));
}
