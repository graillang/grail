// 256x256 f32 matrix multiply, 20 times; prints a checksum of the result (twin of bench/matmul.c).
const std = @import("std");

pub fn main() !void {
    const n: usize = 256;
    const allocator = std.heap.page_allocator;
    const a = try allocator.alloc(f32, n * n);
    const b = try allocator.alloc(f32, n * n);
    const c = try allocator.alloc(f32, n * n);
    for (0..n * n) |i| {
        a[i] = @as(f32, @floatFromInt(i % 7)) * 0.25;
        b[i] = @as(f32, @floatFromInt(i % 11)) * 0.5;
    }
    for (0..20) |round| {
        for (0..n) |i| {
            for (0..n) |j| {
                var s: f32 = 0;
                for (0..n) |k| s = s + a[i * n + k] * b[k * n + j];
                c[i * n + j] = s;
            }
        }
        a[round] = c[round];
    }
    var sum: f64 = 0;
    for (c) |value| sum += value;
    try std.io.getStdOut().writer().print("{d}\n", .{sum});
}
