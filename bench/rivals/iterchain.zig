// Zig twin of bench/iterchain.grl: 20 rounds over ten million u64.
const std = @import("std");

pub fn main() !void {
    const n: usize = 10000000;
    const allocator = std.heap.page_allocator;
    const v = try allocator.alloc(u64, n);
    defer allocator.free(v);
    for (v, 0..) |*slot, i| slot.* = i;
    var s: u64 = 0;
    for (0..20) |round| {
        const r: u64 = @intCast(round);
        for (v) |x| {
            const y = (x + r) * 2;
            if (y % 3 == 0) s +%= y;
        }
    }
    try std.io.getStdOut().writer().print("{d}\n", .{s});
}
