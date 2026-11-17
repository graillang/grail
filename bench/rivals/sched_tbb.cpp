// C++/oneTBB twin of the scheduler benchmarks on gaps12-sched (tools/sched-rivals.mjs):
//   sched_tbb sched   join (parallel_invoke), spawn-and-wait (task_group run + wait), a burst of
//                     spawns, fib(32) by nested join (cutoff 12)
//   sched_tbb frame   bench/frame.grl: 600 frames of 32 systems (every third forks four), an
//                     in-place parallel pass over 1M elements in leaves of 4096, a render step on the
//                     main thread, an I/O thread and a background importer in a low-priority arena.
// Build: g++ -O2 -std=c++20 sched_tbb.cpp -ltbb. Output is `name value unit` lines.
#include <oneapi/tbb.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <string>
#include <thread>
#include <vector>

using u64 = std::uint64_t;
using clk = std::chrono::steady_clock;
static long long us_since(clk::time_point t) { return std::chrono::duration_cast<std::chrono::microseconds>(clk::now() - t).count(); }
static long long ns_since(clk::time_point t) { return std::chrono::duration_cast<std::chrono::nanoseconds>(clk::now() - t).count(); }

static u64 fib(u64 n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
// 28 656 joins for n = 32 with the cutoff at 12, as bench/sched.grl.
static u64 pfib(u64 n) {
    if (n < 12) return fib(n);
    u64 a, b;
    tbb::parallel_invoke([&] { a = pfib(n - 1); }, [&] { b = pfib(n - 2); });
    return a + b;
}

static void sched() {
    const u64 n = 100000;
    std::atomic<u64> acc{0};
    tbb::parallel_for(0, 4, [&](int i) { acc += i; }); // start the workers
    auto t = clk::now();
    for (u64 i = 0; i < n; i++) {
        tbb::task_group g;
        u64 r = 0;
        g.run([&] { r = 1; });
        g.wait();
        acc += r;
    }
    std::printf("job_spawn_wait %lld ns\n", ns_since(t) / (long long)n);
    // The main thread is a participant of TBB's default arena: there is no "outside the pool".
    t = clk::now();
    for (u64 i = 0; i < n; i++) {
        u64 a, b;
        tbb::parallel_invoke([&] { a = 1; }, [&] { b = 2; });
        acc += a;
    }
    std::printf("join_main %lld ns\n", ns_since(t) / (long long)n);
    t = clk::now();
    {
        tbb::task_group g;
        g.run([&] {
            u64 s = 0;
            for (u64 i = 0; i < n; i++) {
                u64 a, b;
                tbb::parallel_invoke([&] { a = 1; }, [&] { b = 2; });
                s += a;
            }
            acc += s;
        });
        g.wait();
    }
    std::printf("join %lld ns\n", ns_since(t) / (long long)n);
    t = clk::now();
    {
        tbb::task_group g;
        for (u64 i = 0; i < n; i++) g.run([&acc, i] { acc.fetch_add(i + 1, std::memory_order_relaxed); });
        g.wait();
    }
    std::printf("task_burst %lld ns\n", ns_since(t) / (long long)n);
    t = clk::now();
    u64 s = fib(32);
    std::printf("fib32_serial %lld us\n", us_since(t));
    t = clk::now();
    u64 q = pfib(32);
    std::printf("fib32_join_main %lld us\n", us_since(t));
    t = clk::now();
    u64 r = 0;
    {
        tbb::task_group g;
        g.run([&] { r = pfib(32); });
        g.wait();
    }
    std::printf("fib32_join_task %lld us\n", us_since(t));
    if (s != q || s != r) return;
    std::printf("checksum %llu -\n", (unsigned long long)acc.load());
}

static u64 mix(u64 x) {
    u64 v = x ^ 88172645463325252ull;
    v ^= v << 13; v ^= v >> 7; v ^= v << 17;
    return v;
}
static u64 work(u64 seed, u64 rounds) {
    u64 v = seed;
    for (u64 i = 0; i < rounds; i++) v = mix(v + i);
    return v;
}
static u64 sys(u64 i, u64 frame) {
    if (i % 3 == 0) {
        u64 parts[4];
        u64 seed = i * 31 + frame;
        tbb::parallel_for(0, 4, [&](int k) { parts[k] = work(seed + k, 5000); });
        return parts[0] ^ parts[1] ^ parts[2] ^ parts[3];
    }
    return work(i + frame, 20000);
}
static u64 bg_piece(u64 i, u64 rounds) {
    std::vector<u64> v;
    for (u64 k = 0; k < 2000; k++) v.push_back(mix(k + rounds + i));
    u64 acc = 0;
    for (u64 x : v) acc ^= x;
    return acc;
}
static long threads() {
    std::ifstream f("/proc/self/status");
    std::string line;
    while (std::getline(f, line)) if (line.rfind("Threads:", 0) == 0) return std::stol(line.substr(8));
    return 0;
}

static void frame(bool importer) {
    std::atomic<u64> stop{0}, io_rounds{0}, io_worst{0}, bg_rounds{0};
    std::thread io([&] {
        u64 rounds = 0;
        while (!stop.load()) {
            auto t0 = clk::now();
            std::ifstream f("/proc/self/stat");
            std::string bytes((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
            long long took = us_since(t0), late = took > 5000 ? took - 5000 : 0;
            if ((u64)late > io_worst.load()) io_worst.store(late);
            io_rounds.store(++rounds);
        }
    });
    // The importer runs in an arena of low priority, the frame in one of high priority: oneTBB's
    // equivalent of Grail's Background and Frame classes.
    tbb::task_arena bg_arena(tbb::task_arena::automatic, 1, tbb::task_arena::priority::low);
    tbb::task_arena frame_arena(tbb::task_arena::automatic, 1, tbb::task_arena::priority::high);
    std::thread bg([&] {
        if (!importer) return;
        u64 rounds = 0, acc = 0;
        while (!stop.load()) {
            u64 parts[16];
            bg_arena.execute([&] { tbb::parallel_for(0, 16, [&](int i) { parts[i] = bg_piece(i, rounds); }); });
            for (u64 p : parts) acc ^= p;
            bg_rounds.store(++rounds);
        }
        if (acc == 42) std::puts("");
    });
    const int frames = 600;
    const u64 n = 1000000;
    std::vector<u64> data(n);
    for (u64 i = 0; i < n; i++) data[i] = i * 2654435761ull;
    std::vector<long long> times;
    u64 check = 0;
    auto start = clk::now();
    for (u64 f = 0; f < (u64)frames; f++) {
        auto t0 = clk::now();
        u64 out[32];
        frame_arena.execute([&] {
            tbb::parallel_for(0, 32, [&](int i) { out[i] = sys(i, f); });
            tbb::parallel_for(tbb::blocked_range<u64>(0, n, 4096), [&](const tbb::blocked_range<u64>& r) {
                for (u64 i = r.begin(); i < r.end(); i++) data[i] = mix(data[i]);
            }, tbb::simple_partitioner());
        });
        for (u64 s : out) check ^= s;
        check ^= work(f, 20000); // "render" on this thread
        times.push_back(us_since(t0));
    }
    long long total = us_since(start) / 1000;
    stop.store(1);
    io.join();
    bg.join();
    for (int i = 0; i < 16; i++) check ^= data[i * 1000];
    std::sort(times.begin(), times.end());
    std::printf("frame_median %lld us\nframe_p99 %lld us\nframe_max %lld us\nframes_total %lld ms\n", times[frames / 2], times[frames * 99 / 100], times[frames - 1], total);
    std::printf("io_rounds %llu n\nio_worst_late %llu us\nbg_rounds %llu n\nthreads %ld n\nchecksum %llu -\n",
                (unsigned long long)io_rounds.load(), (unsigned long long)io_worst.load(), (unsigned long long)bg_rounds.load(), threads(), (unsigned long long)check);
}

int main(int argc, char** argv) {
    if (argc > 1 && std::string(argv[1]) == "frame") frame(argc <= 2);
    else sched();
}
