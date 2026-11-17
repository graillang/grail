// Zig twin of bench/strings.grl: a writer to build, splitScalar to cut, parseInt and parseFloat.
const std = @import("std");

fn xs(x0: u64) u64 {
    var x = x0;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return x;
}

pub fn main() !void {
    const n: u64 = 1000000;
    const allocator = std.heap.smp_allocator;
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    var x: u64 = 88172645463325252;
    for (0..n) |i| {
        x = xs(x);
        const a = x % 100000;
        const b = (x >> 20) % 100000;
        try text.writer().print("k{d},{d},{d}.{d}{d}\n", .{ i, a, b / 100, (b % 100) / 10, b % 10 });
    }
    var int_sum: u64 = 0;
    var float_sum: f64 = 0;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    var lines = std.mem.splitScalar(u8, text.items, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, ',');
        const name = fields.next().?;
        const a = try std.fmt.parseInt(u64, fields.next().?, 10);
        const f = try std.fmt.parseFloat(f64, fields.next().?);
        int_sum += a;
        float_sum = float_sum + f;
        try out.writer().print("{d}:{d};", .{ a * 2, name.len });
    }
    var h: u64 = 14695981039346656037;
    for (out.items) |c| h = (h ^ c) *% 1099511628211;
    try std.io.getStdOut().writer().print("{d} {d} {d} {d}\n", .{ int_sum, float_sum, out.items.len, h });
}
