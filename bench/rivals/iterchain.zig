// Zig twin of bench/iterchain.grl. Zig's standard library has no map/filter iterator adapters, so
// the chain is the loop.
const std = @import("std");

pub fn main() !void {
    const n: usize = 10000000;
    const allocator = std.heap.page_allocator;
    const v = try allocator.alloc(u64, n);
    defer allocator.free(v);
    for (v, 0..) |*slot, i| slot.* = i;
    var s: u64 = 0;
    for (v) |x| {
        const y = x * 2;
        if (y % 3 == 0) s +%= y;
    }
    try std.io.getStdOut().writer().print("{d}\n", .{s});
}
