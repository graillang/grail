// C++ twin of bench/chan.grl. C++ has no standard channel: this is the textbook bounded queue
// written as a class, a ring in a std::vector guarded by one std::mutex and two
// std::condition_variable (not_empty, not_full), notified after unlocking like the C twin. Same
// cases (1:1, N:1, N:M producer/consumer counts and a ping-pong), same capacities, same output;
// threads are std::thread running lambdas. CHAN_CASE=N runs one case, as in the C twin.
// clang++ -std=c++20 -O2 -ffp-contract=off -pthread chan.cpp
// bench-cflags: -pthread
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <mutex>
#include <optional>
#include <thread>
#include <vector>

class Channel {
    std::vector<uint64_t> items;
    size_t head = 0, len = 0;
    bool closed = false;
    std::mutex m;
    std::condition_variable not_empty, not_full;
public:
    explicit Channel(size_t cap) : items(cap) {}
    bool send(uint64_t v) {
        std::unique_lock lk(m);
        not_full.wait(lk, [&] { return closed || len < items.size(); });
        if (closed) return false;
        items[(head + len) % items.size()] = v;
        len++;
        lk.unlock();
        not_empty.notify_one();
        return true;
    }
    std::optional<uint64_t> recv() {
        std::unique_lock lk(m);
        not_empty.wait(lk, [&] { return closed || len > 0; });
        if (len == 0) return std::nullopt;
        uint64_t v = items[head];
        head = (head + 1) % items.size();
        len--;
        lk.unlock();
        not_full.notify_one();
        return v;
    }
    void close() {
        {
            std::lock_guard lk(m);
            closed = true;
        }
        not_empty.notify_all();
        not_full.notify_all();
    }
};

static uint64_t spread(int producers, int consumers, uint64_t each) {
    Channel c(64);
    std::vector<std::thread> pt, ct;
    std::vector<uint64_t> sums(consumers);
    for (int p = 0; p < producers; p++)
        pt.emplace_back([&c, p, each] { for (uint64_t i = 0; i < each; i++) c.send((uint64_t)p * 1000000 + i + 1); });
    for (int q = 0; q < consumers; q++)
        ct.emplace_back([&c, &sums, q] { uint64_t sum = 0; while (auto v = c.recv()) sum += *v; sums[q] = sum; });
    for (auto &t : pt) t.join();
    c.close();
    uint64_t total = 0;
    for (int q = 0; q < consumers; q++) { ct[q].join(); total += sums[q]; }
    return total;
}

static uint64_t ping(uint64_t rounds) {
    Channel there(1), back(1);
    std::thread echo([&] { while (auto v = there.recv()) back.send(*v + 1); });
    uint64_t v = 0;
    for (uint64_t i = 0; i < rounds; i++) { there.send(v); v = *back.recv(); }
    there.close();
    echo.join();
    return v;
}

int main() {
    const char *e = std::getenv("CHAN_CASE");
    int only = e && *e ? *e - '0' : 0;
    if (!only || only == 1) std::printf("1:1 %llu\n", (unsigned long long)spread(1, 1, 400000));
    if (!only || only == 2) std::printf("N:1 %llu\n", (unsigned long long)spread(4, 1, 100000));
    if (!only || only == 3) std::printf("N:M %llu\n", (unsigned long long)spread(4, 4, 100000));
    if (!only || only == 4) std::printf("ping %llu\n", (unsigned long long)ping(100000));
}
