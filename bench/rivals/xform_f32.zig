// x[i] = x[i] * a + y[i] over one million f32, 2000 passes; prints the sum (twin of bench/xform_f32.c).
const std = @import("std");

noinline fn scaleAdd(noalias x: []f32, noalias y: []const f32, a: f32) void {
    for (x, y) |*xi, yi| xi.* = xi.* * a + yi;
}

pub fn main() !void {
    const n: usize = 1000000;
    const allocator = std.heap.page_allocator;
    const x = try allocator.alloc(f32, n);
    const y = try allocator.alloc(f32, n);
    var xv: f32 = 0;
    var yv: f32 = 0;
    for (0..n) |i| {
        x[i] = xv;
        y[i] = yv;
        xv = xv + 0.5;
        if (3.0 < xv) xv = 0;
        yv = yv + 0.25;
        if (1.0 < yv) yv = 0;
    }
    var a: f32 = 0.999;
    for (0..2000) |pass| {
        scaleAdd(x, y, a);
        a = 0.999 - x[pass] * 0.000000001;
    }
    var sum: f64 = 0;
    for (x) |value| sum += value;
    try std.io.getStdOut().writer().print("{d}\n", .{sum});
}
