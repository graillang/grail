// Zig twin of bench/ecs_par.grl: 1M entities, 600 frames split across a persistent pool of
// ZIG_THREADS workers synchronized with an atomic sense-reversing barrier (threads spawned once
// before the loop, matching OpenMP, rayon, C++ std::barrier and Grail's pool).
const std = @import("std");

const Cols = struct { px: []f32, py: []f32, pz: []f32, vx: []f32, vy: []f32, vz: []f32 };

const Barrier = struct {
    total: u32,
    arrived: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    gen: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    fn wait(self: *Barrier) void {
        const g = self.gen.load(.acquire);
        const prev = self.arrived.fetchAdd(1, .acq_rel);
        if (prev + 1 == self.total) {
            self.arrived.store(0, .monotonic);
            self.gen.store(g +% 1, .release);
        } else {
            var spin: u32 = 0;
            while (self.gen.load(.acquire) == g) {
                if (spin < 4096) {
                    std.atomic.spinLoopHint();
                    spin += 1;
                } else {
                    std.Thread.yield() catch {};
                }
            }
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

fn updateSlices(noalias px: []f32, noalias py: []f32, noalias pz: []f32, noalias vx: []f32, noalias vy: []f32, noalias vz: []f32) void {
    const dt: f32 = 0.016;
    const damping: f32 = 0.999;
    const gravity: f32 = 0.0981;
    for (0..px.len) |i| {
        vx[i] = vx[i] * damping;
        vy[i] = vy[i] * damping - gravity * dt;
        vz[i] = vz[i] * damping;
        px[i] = px[i] + vx[i] * dt;
        py[i] = py[i] + vy[i] * dt;
        pz[i] = pz[i] + vz[i] * dt;
    }
}

fn update(c: Cols, lo: usize, hi: usize) void {
    updateSlices(c.px[lo..hi], c.py[lo..hi], c.pz[lo..hi], c.vx[lo..hi], c.vy[lo..hi], c.vz[lo..hi]);
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
        var barrier = Barrier{ .total = @intCast(workers) };
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
