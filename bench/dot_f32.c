// The dot product of two vectors of one million float, 200 passes with one element changed between
// passes; prints the total.
#include <stdio.h>
#include <stdlib.h>
__attribute__((noinline)) static float dot(const float *x, const float *y, size_t n) {
    float s = 0;
    for (size_t i = 0; i < n; i++) s = s + x[i] * y[i];
    return s;
}
int main(void) {
    size_t n = 1000000;
    float *x = malloc(n * sizeof *x), *y = malloc(n * sizeof *y);
    float xv = 0, yv = 0;
    for (size_t i = 0; i < n; i++) {
        x[i] = xv; y[i] = yv;
        xv = xv + (float)0.5; if ((float)3.0 < xv) xv = 0;
        yv = yv + (float)0.25; if ((float)1.0 < yv) yv = 0;
    }
    double total = 0;
    for (int pass = 0; pass < 200; pass++) {
        x[pass] = x[pass] + (float)1.0;
        total += (double)dot(x, y, n);
    }
    printf("%.17g\n", total);
    return 0;
}
