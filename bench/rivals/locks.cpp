// C++ twin of bench/locks.grl: std::mutex, std::shared_mutex, std::condition_variable and
// std::counting_semaphore (C++20). g++ -O2 -std=c++20 -pthread. Nanoseconds per operation.
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <mutex>
#include <semaphore>
#include <shared_mutex>
#include <thread>
#include <vector>
using clk = std::chrono::steady_clock;
static unsigned long long ns(clk::time_point s) { return std::chrono::duration_cast<std::chrono::nanoseconds>(clk::now() - s).count(); }
static volatile unsigned long long sink;
int main() {
    std::mutex m; unsigned long long v = 0;
    {
        unsigned long long t = 0;
        std::thread([&] { auto s = clk::now(); for (int i = 0; i < 5000000; i++) { std::lock_guard<std::mutex> g(m); v++; } t = ns(s); }).join();
        std::printf("mutex-uncontended %llu\n", t / 5000000);
    }
    std::shared_mutex rw; unsigned long long rv = 0;
    std::counting_semaphore<2> sem(2);
    auto run = [&](int work) {
        auto s = clk::now();
        std::vector<std::thread> ts;
        for (int i = 0; i < 8; i++) ts.emplace_back([&, work] {
            unsigned long long t = 0;
            if (work == 0) for (int k = 0; k < 200000; k++) { std::lock_guard<std::mutex> g(m); v++; t += v; }
            if (work == 1) for (int k = 0; k < 200000; k++) { std::shared_lock<std::shared_mutex> g(rw); t += rv; }
            if (work == 2) for (int k = 0; k < 200000; k++) {
                if (k % 16 == 0) { std::unique_lock<std::shared_mutex> g(rw); rv++; t += rv; }
                else { std::shared_lock<std::shared_mutex> g(rw); t += rv; }
            }
            if (work == 3) for (int k = 0; k < 100000; k++) { sem.acquire(); t += k; sem.release(); }
            sink = t;
        });
        for (auto &t : ts) t.join();
        return ns(s);
    };
    std::printf("mutex-contended %llu\n", run(0) / 1600000);
    std::printf("rwlock-read %llu\n", run(1) / 1600000);
    std::printf("rwlock-mixed %llu\n", run(2) / 1600000);
    {
        std::mutex pm; std::condition_variable cv; unsigned long long turn = 0;
        auto s = clk::now();
        std::vector<std::thread> ts;
        for (unsigned long long side = 0; side < 2; side++) ts.emplace_back([&, side] {
            for (int k = 0; k < 100000; k++) {
                std::unique_lock<std::mutex> g(pm);
                cv.wait(g, [&] { return turn % 2 == side; });
                turn++;
                g.unlock();
                cv.notify_all();
            }
        });
        for (auto &t : ts) t.join();
        std::printf("condition-pingpong %llu\n", ns(s) / 100000);
    }
    std::printf("semaphore-contended %llu\n", run(3) / 800000);
}
