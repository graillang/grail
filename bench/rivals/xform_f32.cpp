// C++ twin of bench/xform_f32.c: x[i] = x[i] * a + y[i] over one million float, 200 passes; prints
// the sum of the result. std::transform over the two vectors; without C's restrict the compiler
// checks for overlap at run time before it vectorises.
#include <algorithm>
#include <cstdio>
#include <span>
#include <vector>
[[gnu::noinline]] static void scale_add(std::span<float> x, std::span<const float> y, float a) {
    std::transform(x.begin(), x.end(), y.begin(), x.begin(), [a](float xi, float yi) { return xi * a + yi; });
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
    float a = float(0.999);
    for (int pass = 0; pass < 200; pass++) {
        scale_add(x, y, a);
        a = float(0.999) - x[pass] * float(0.000000001); // the next pass depends on this one
    }
    double sum = 0;
    for (float v : x) sum += double(v);
    std::printf("%.17g\n", sum);
}
