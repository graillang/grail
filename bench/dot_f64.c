// The dot product of two vectors of one million double, 200 passes with one element changed between
// passes; prints the total.
#include <stdio.h>
#include <stdlib.h>
__attribute__((noinline)) static double dot(const double *x, const double *y, size_t n) {
    double s = 0;
    for (size_t i = 0; i < n; i++) s = s + x[i] * y[i];
    return s;
}
int main(void) {
    size_t n = 1000000;
    double *x = malloc(n * sizeof *x), *y = malloc(n * sizeof *y);
    double xv = 0, yv = 0;
    for (size_t i = 0; i < n; i++) {
        x[i] = xv; y[i] = yv;
        xv = xv + (double)0.5; if ((double)3.0 < xv) xv = 0;
        yv = yv + (double)0.25; if ((double)1.0 < yv) yv = 0;
    }
    double total = 0;
    for (int pass = 0; pass < 200; pass++) {
        x[pass] = x[pass] + (double)1.0;
        total += (double)dot(x, y, n);
    }
    printf("%.17g\n", total);
    return 0;
}
