// C++ twin of bench/dyncall.grl: an abstract Shape with a virtual area(), each shape allocated on
// its own and owned by a std::unique_ptr<Shape> in a std::vector; the call is virtual dispatch.
// Same shapes, same 20 passes, same output.
// clang++ -std=c++20 -O2 -ffp-contract=off dyncall.cpp
#include <cstdint>
#include <cstdio>
#include <memory>
#include <vector>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
struct Shape {
    virtual ~Shape() = default;
    virtual uint64_t area() const = 0;
};
struct Square final : Shape {
    uint64_t side;
    explicit Square(uint64_t s) : side(s) {}
    uint64_t area() const override { return side * side; }
};
struct Rect final : Shape {
    uint64_t w, h;
    Rect(uint64_t w, uint64_t h) : w(w), h(h) {}
    uint64_t area() const override { return w * h; }
};
struct Tri final : Shape {
    uint64_t b, h;
    Tri(uint64_t b, uint64_t h) : b(b), h(h) {}
    uint64_t area() const override { return b * h / 2; }
};
int main() {
    const uint64_t n = 1000000;
    std::vector<std::unique_ptr<Shape>> shapes;
    shapes.reserve(n);
    uint64_t x = 88172645463325252ull;
    for (uint64_t i = 0; i < n; i++) {
        x = xs(x);
        uint64_t k = x % 3, a = x % 100, b = (x >> 8) % 100;
        if (k == 0) shapes.push_back(std::make_unique<Square>(a));
        else if (k == 1) shapes.push_back(std::make_unique<Rect>(a, b));
        else shapes.push_back(std::make_unique<Tri>(a, b));
    }
    uint64_t total = 0;
    for (int pass = 0; pass < 20; pass++)
        for (const auto &s : shapes) total += s->area();
    std::printf("%llu\n", (unsigned long long)total);
}
