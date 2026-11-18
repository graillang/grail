// C++ twin of bench/matmul.c: 256x256 float matrix multiply, 20 times; prints a checksum of the
// result. The matrices are std::vector, as Rust's Vec and Grail's vectors are.
#include <cstdio>
#include <vector>
int main() {
    constexpr int n = 256;
    std::vector<float> a(n * n), b(n * n), c(n * n);
    for (int i = 0; i < n * n; ++i) { a[i] = float(i % 7) * 0.25f; b[i] = float(i % 11) * 0.5f; }
    for (int round = 0; round < 20; ++round) {
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < n; ++j) {
                float s = 0.0f;
                for (int k = 0; k < n; ++k) s = s + a[i * n + k] * b[k * n + j];
                c[i * n + j] = s;
            }
        a[round] = c[round]; // the next round depends on this one: no round is dead code
    }
    double sum = 0.0;
    for (float v : c) sum += v;
    std::printf("%.17g\n", sum);
}
