// C++ twin of bench/ecs_par.grl: bench/ecs.c's update split into one static slice per thread each
// frame, std::jthread started and joined per frame (C++ has no parallel-for of its own short of
// the parallel algorithms, which need a TBB back end with libstdc++). CPP_THREADS sets the workers
// (default: std::thread::hardware_concurrency()); each entity's arithmetic is independent and the
// final sum is serial, so the checksum is the serial one at any thread count.
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>
struct Columns {
    std::vector<float> px, py, pz, vx, vy, vz;
    explicit Columns(std::size_t n) : px(n), py(n), pz(n), vx(n), vy(n), vz(n) {}
    void update(std::size_t lo, std::size_t hi) {
        const float dt = 0.016f, damping = 0.999f, gravity = 0.0981f;
        for (std::size_t i = lo; i < hi; i++) {
            vx[i] = vx[i] * damping;
            vy[i] = vy[i] * damping - gravity * dt;
            vz[i] = vz[i] * damping;
            px[i] = px[i] + vx[i] * dt;
            py[i] = py[i] + vy[i] * dt;
            pz[i] = pz[i] + vz[i] * dt;
        }
    }
};
int main() {
    const std::size_t n = 1000000;
    Columns c(n);
    std::uint64_t x = 88172645463325252ull;
    for (std::size_t i = 0; i < n; i++) {
        x ^= x << 13; x ^= x >> 7; x ^= x << 17;
        c.px[i] = float(std::int64_t(x % 1000)) * 0.5f;
        c.py[i] = float(std::int64_t((x >> 10) % 1000)) * 0.5f;
        c.pz[i] = float(std::int64_t((x >> 20) % 1000)) * 0.5f;
        c.vx[i] = float(std::int64_t((x >> 30) % 100)) * 0.01f;
        c.vy[i] = float(std::int64_t((x >> 40) % 100)) * 0.01f;
        c.vz[i] = float(std::int64_t((x >> 50) % 100)) * 0.01f;
    }
    const char *env = std::getenv("CPP_THREADS");
    const std::size_t workers = std::max<std::size_t>(1, env ? std::strtoul(env, nullptr, 10) : std::thread::hardware_concurrency());
    const std::size_t chunk = (n + workers - 1) / workers;
    for (int frame = 0; frame < 100; frame++) {
        std::vector<std::jthread> threads;
        for (std::size_t w = 0; w < workers; w++)
            threads.emplace_back([&c, lo = w * chunk, hi = std::min((w + 1) * chunk, n)] { c.update(lo, hi); });
    } // the jthreads join here, at the end of each frame
    double sum = 0;
    for (std::size_t i = 0; i < n; i++) sum = sum + double(c.px[i]) + double(c.py[i]) + double(c.pz[i]);
    std::printf("%.17g\n", sum);
}
