// C++ twin of bench/xform_f64.c: x[i] = x[i] * a + y[i] over one million double, 200 passes; prints
// the sum of the result. std::transform over the two vectors; without C's restrict the compiler
// checks for overlap at run time before it vectorises.
#include <algorithm>
#include <cstdio>
#include <span>
#include <vector>
[[gnu::noinline]] static void scale_add(std::span<double> x, std::span<const double> y, double a) {
    std::transform(x.begin(), x.end(), y.begin(), x.begin(), [a](double xi, double yi) { return xi * a + yi; });
}
int main() {
    const std::size_t n = 1000000;
    std::vector<double> x(n), y(n);
    double xv = 0, yv = 0;
    for (std::size_t i = 0; i < n; i++) {
        x[i] = xv; y[i] = yv;
        xv = xv + double(0.5); if (double(3.0) < xv) xv = 0;
        yv = yv + double(0.25); if (double(1.0) < yv) yv = 0;
    }
    double a = double(0.999);
    for (int pass = 0; pass < 200; pass++) {
        scale_add(x, y, a);
        a = double(0.999) - x[pass] * double(0.000000001); // the next pass depends on this one
    }
    double sum = 0;
    for (double v : x) sum += double(v);
    std::printf("%.17g\n", sum);
}
