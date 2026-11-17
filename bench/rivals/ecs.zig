// Zig twin of bench/ecs.grl: structure-of-arrays f32 slices.
const std = @import("std");

fn xs(x0: u64) u64 {
    var x = x0;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return x;
}

pub fn main() !void {
    const n: usize = 1000000;
    const allocator = std.heap.page_allocator;
    const px = try allocator.alloc(f32, n);
    const py = try allocator.alloc(f32, n);
    const pz = try allocator.alloc(f32, n);
    const vx = try allocator.alloc(f32, n);
    const vy = try allocator.alloc(f32, n);
    const vz = try allocator.alloc(f32, n);
    var x: u64 = 88172645463325252;
    for (0..n) |i| {
        x = xs(x);
        px[i] = @as(f32, @floatFromInt(@as(i64, @intCast(x % 1000)))) * 0.5;
        py[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 10) % 1000)))) * 0.5;
        pz[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 20) % 1000)))) * 0.5;
        vx[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 30) % 100)))) * 0.01;
        vy[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 40) % 100)))) * 0.01;
        vz[i] = @as(f32, @floatFromInt(@as(i64, @intCast((x >> 50) % 100)))) * 0.01;
    }
    const dt: f32 = 0.016;
    const damping: f32 = 0.999;
    const gravity: f32 = 0.0981;
    for (0..100) |_| {
        for (0..n) |i| {
            vx[i] = vx[i] * damping;
            vy[i] = vy[i] * damping - gravity * dt;
            vz[i] = vz[i] * damping;
            px[i] = px[i] + vx[i] * dt;
            py[i] = py[i] + vy[i] * dt;
            pz[i] = pz[i] + vz[i] * dt;
        }
    }
    var sum: f64 = 0;
    for (0..n) |i| sum = sum + @as(f64, px[i]) + @as(f64, py[i]) + @as(f64, pz[i]);
    try std.io.getStdOut().writer().print("{d}\n", .{sum});
}
