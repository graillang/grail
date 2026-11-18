// C++ twin of bench/ecs.grl: structure-of-arrays entity storage, one std::vector<float> per
// component column, updated by index. The float arithmetic is the C twin's, in the same order
// (built with -ffp-contract=off), so the printed sum is identical.
// clang++ -std=c++20 -O2 -ffp-contract=off ecs.cpp
#include <cstdint>
#include <cstdio>
#include <vector>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
struct Bodies {
    std::vector<float> px, py, pz, vx, vy, vz;
    explicit Bodies(size_t n) : px(n), py(n), pz(n), vx(n), vy(n), vz(n) {}
    size_t size() const { return px.size(); }
};
int main() {
    const uint64_t n = 1000000;
    Bodies w(n);
    uint64_t x = 88172645463325252ull;
    for (size_t i = 0; i < n; i++) {
        x = xs(x);
        w.px[i] = (float)(int64_t)(x % 1000) * 0.5f;
        w.py[i] = (float)(int64_t)((x >> 10) % 1000) * 0.5f;
        w.pz[i] = (float)(int64_t)((x >> 20) % 1000) * 0.5f;
        w.vx[i] = (float)(int64_t)((x >> 30) % 100) * 0.01f;
        w.vy[i] = (float)(int64_t)((x >> 40) % 100) * 0.01f;
        w.vz[i] = (float)(int64_t)((x >> 50) % 100) * 0.01f;
    }
    const float dt = 0.016f, damping = 0.999f, gravity = 0.0981f;
    for (int frame = 0; frame < 100; frame++)
        for (size_t i = 0; i < w.size(); i++) {
            w.vx[i] = w.vx[i] * damping;
            w.vy[i] = w.vy[i] * damping - gravity * dt;
            w.vz[i] = w.vz[i] * damping;
            w.px[i] = w.px[i] + w.vx[i] * dt;
            w.py[i] = w.py[i] + w.vy[i] * dt;
            w.pz[i] = w.pz[i] + w.vz[i] * dt;
        }
    double sum = 0;
    for (size_t i = 0; i < w.size(); i++) sum = sum + (double)w.px[i] + (double)w.py[i] + (double)w.pz[i];
    std::printf("%.17g\n", sum);
}
