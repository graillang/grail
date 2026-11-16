// x[i] = x[i] * a + y[i] over one million float, 200 passes; prints the sum of the result.
#include <stdio.h>
#include <stdlib.h>
__attribute__((noinline)) static void scale_add(float *restrict x, const float *restrict y, float a, size_t n) {
    for (size_t i = 0; i < n; i++) x[i] = x[i] * a + y[i];
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
    float a = (float)0.999;
    for (int pass = 0; pass < 200; pass++) scale_add(x, y, a, n);
    double sum = 0;
    for (size_t i = 0; i < n; i++) sum += (double)x[i];
    printf("%.17g\n", sum);
    return 0;
}
