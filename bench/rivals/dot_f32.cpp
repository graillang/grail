// C++ twin of bench/dot_f32.c: the dot product of two vectors of one million float, 200 passes with
// one element changed between passes; prints the total. std::inner_product adds in index order, as
// the C loop does, so the sum is the same strict-IEEE serial one.
#include <cstdio>
#include <numeric>
#include <span>
#include <vector>
[[gnu::noinline]] static float dot(std::span<const float> x, std::span<const float> y) {
    return std::inner_product(x.begin(), x.end(), y.begin(), float(0));
}
int main() {
    const std::size_t n = 1000000;
    std::vector<float> x(n), y(n);
    float xv = 0, yv = 0;
    for (std::size_t i = 0; i < n; i++) {
        x[i] = xv; y[i] = yv;
        xv = xv + float(0.5); if (float(3.0) < xv) xv = 0;
        yv = yv + float(0.25); if (float(1.0) < yv) yv = 0;
    }
    double total = 0;
    for (int pass = 0; pass < 200; pass++) {
        x[pass] = x[pass] + float(1.0);
        total += double(dot(x, y));
    }
    std::printf("%.17g\n", total);
}
