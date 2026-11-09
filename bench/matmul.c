#include <stdio.h>
int main(void) {
    enum { n = 256 };
    static float a[n * n], b[n * n], c[n * n];
    for (int i = 0; i < n * n; ++i) { a[i] = (float)(i % 7) * 0.25f; b[i] = (float)(i % 11) * 0.5f; }
    for (int round = 0; round < 20; ++round)
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < n; ++j) {
                float s = 0.0f;
                for (int k = 0; k < n; ++k) s = s + a[i * n + k] * b[k * n + j];
                c[i * n + j] = s;
            }
    double sum = 0.0;
    for (int i = 0; i < n * n; ++i) sum += c[i];
    printf("%.17g\n", sum);
    return 0;
}
