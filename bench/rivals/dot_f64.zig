// The dot product of two vectors of one million f64, 200 passes with one element changed between
// passes; prints the total (twin of bench/dot_f64.c).
const std = @import("std");

noinline fn dot(x: []const f64, y: []const f64) f64 {
    var s: f64 = 0;
    for (x, y) |xi, yi| s = s + xi * yi;
    return s;
}

pub fn main() !void {
    const n: usize = 1000000;
    const allocator = std.heap.page_allocator;
    const x = try allocator.alloc(f64, n);
    const y = try allocator.alloc(f64, n);
    var xv: f64 = 0;
    var yv: f64 = 0;
    for (0..n) |i| {
        x[i] = xv;
        y[i] = yv;
        xv = xv + 0.5;
        if (3.0 < xv) xv = 0;
        yv = yv + 0.25;
        if (1.0 < yv) yv = 0;
    }
    var total: f64 = 0;
    for (0..200) |pass| {
        x[pass] = x[pass] + 1.0;
        total += dot(x, y);
    }
    try std.io.getStdOut().writer().print("{d}\n", .{total});
}
