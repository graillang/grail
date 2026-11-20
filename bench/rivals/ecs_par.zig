// Zig twin of bench/ecs_par.grl: 1M entities, 600 frames split across a persistent pool of
// ZIG_THREADS workers synchronized with a reusable barrier (threads spawned once before the loop,
// matching OpenMP, rayon and Grail's pool).
const std = @import("std");

const Cols = struct { px: []f32, py: []f32, pz: []f32, vx: []f32, vy: []f32, vz: []f32 };

const Barrier = struct {
    total: usize,
    arrived: usize = 0,
    gen: usize = 0,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},

    fn wait(self: *Barrier) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const g = self.gen;
        self.arrived += 1;
        if (self.arrived == self.total) {
            self.arrived = 0;
            self.gen +%= 1;
            self.cond.broadcast();
        } else {
            while (self.gen == g) self.cond.wait(&self.mutex);
        }
    }
};

fn xs(x0: u64) u64 {
    var x = x0;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return x;
}

fn update(c: Cols, lo: usize, hi: usize) void {
    const dt: f32 = 0.016;
    const damping: f32 = 0.999;
    const gravity: f32 = 0.0981;
    var i = lo;
    while (i < hi) : (i += 1) {
        c.vx[i] = c.vx[i] * damping;
        c.vy[i] = c.vy[i] * damping - gravity * dt;
        c.vz[i] = c.vz[i] * damping;
        c.px[i] = c.px[i] + c.vx[i] * dt;
        c.py[i] = c.py[i] + c.vy[i] * dt;
        c.pz[i] = c.pz[i] + c.vz[i] * dt;
    }
}

fn workerLoop(c: Cols, lo: usize, hi: usize, frames: usize, barrier: *Barrier) void {
    for (0..frames) |_| {
        update(c, lo, hi);
        barrier.wait();
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const n: usize = 1000000;
    const frames: usize = 600;
    const c = Cols{
        .px = try allocator.alloc(f32, n), .py = try allocator.alloc(f32, n), .pz = try allocator.alloc(f32, n),
        .vx = try allocator.alloc(f32, n), .vy = try allocator.alloc(f32, n), .vz = try allocator.alloc(f32, n),
    };
    var x: u64 = 88172645463325252;
    for (0..n) |i| {
        x = xs(x);
        c.px[i] = @as(f32, @floatFromInt(@as(i64, @intCast(x % 1000)))) * 0.5;
        c.py[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 10) % 1000)))) * 0.5;
        c.pz[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 20) % 1000)))) * 0.5;
        c.vx[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 30) % 100)))) * 0.01;
        c.vy[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 40) % 100)))) * 0.01;
        c.vz[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 50) % 100)))) * 0.01;
    }
    const workers: usize = @max(1, blk: {
        const v = std.process.getEnvVarOwned(allocator, "ZIG_THREADS") catch break :blk try std.Thread.getCpuCount();
        break :blk std.fmt.parseInt(usize, v, 10) catch try std.Thread.getCpuCount();
    });
    const chunk = (n + workers - 1) / workers;
    if (workers == 1) {
        for (0..frames) |_| update(c, 0, n);
    } else {
        var barrier = Barrier{ .total = workers };
        const threads = try allocator.alloc(std.Thread, workers - 1);
        for (1..workers) |w| {
            threads[w - 1] = try std.Thread.spawn(.{}, workerLoop, .{ c, w * chunk, @min((w + 1) * chunk, n), frames, &barrier });
        }
        const hi0 = @min(chunk, n);
        for (0..frames) |_| {
            update(c, 0, hi0);
            barrier.wait();
        }
        for (threads) |t| t.join();
    }
    var sum: f64 = 0;
    for (0..n) |i| sum = sum + @as(f64, c.px[i]) + @as(f64, c.py[i]) + @as(f64, c.pz[i]);
    try std.io.getStdOut().writer().print("{d}\n", .{sum});
}
