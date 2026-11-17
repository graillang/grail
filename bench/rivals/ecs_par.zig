// Zig twin of bench/ecs_par.grl: bench/rivals/ecs.zig's update split into one static chunk per
// thread each frame, std.Thread spawned and joined - Zig's standard library has no parallel-for.
// ZIG_THREADS sets the workers (default: the CPU count); the sum is serial.
const std = @import("std");

const Cols = struct { px: []f32, py: []f32, pz: []f32, vx: []f32, vy: []f32, vz: []f32 };

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

pub fn main() !void {
    const n: usize = 1000000;
    const allocator = std.heap.page_allocator;
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
    const workers: usize = blk: {
        const v = std.process.getEnvVarOwned(allocator, "ZIG_THREADS") catch break :blk try std.Thread.getCpuCount();
        break :blk std.fmt.parseInt(usize, v, 10) catch try std.Thread.getCpuCount();
    };
    const chunk = (n + workers - 1) / workers;
    const threads = try allocator.alloc(std.Thread, workers);
    for (0..100) |_| {
        for (threads, 0..) |*t, w| t.* = try std.Thread.spawn(.{}, update, .{ c, w * chunk, @min((w + 1) * chunk, n) });
        for (threads) |t| t.join();
    }
    var sum: f64 = 0;
    for (0..n) |i| sum = sum + @as(f64, c.px[i]) + @as(f64, c.py[i]) + @as(f64, c.pz[i]);
    try std.io.getStdOut().writer().print("{d}\n", .{sum});
}
