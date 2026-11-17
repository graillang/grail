// x[i] = x[i] * a + y[i] over one million double, 200 passes; prints the sum of the result.
#include <stdio.h>
#include <stdlib.h>
__attribute__((noinline)) static void scale_add(double *restrict x, const double *restrict y, double a, size_t n) {
    for (size_t i = 0; i < n; i++) x[i] = x[i] * a + y[i];
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
    double a = (double)0.999;
    for (int pass = 0; pass < 200; pass++) {
        scale_add(x, y, a, n);
        a = (double)0.999 - x[pass] * (double)0.000000001; // the next pass depends on this one
    }
    double sum = 0;
    for (size_t i = 0; i < n; i++) sum += (double)x[i];
    printf("%.17g\n", sum);
    return 0;
}
