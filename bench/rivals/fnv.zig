// FNV-1a over 64 MiB of pseudo-random bytes, eight times; prints the final hash (twin of bench/fnv.c).
const std = @import("std");

pub fn main() !void {
    const n: usize = 67108864;
    const allocator = std.heap.page_allocator;
    var data = try std.ArrayList(u8).initCapacity(allocator, n);
    defer data.deinit();
    var x: u64 = 88172645463325252;
    for (0..n) |_| {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        try data.append(@intCast(x & 255));
    }
    var h: u64 = 14695981039346656037;
    for (0..8) |_| {
        for (0..n) |i| {
            h = (h ^ data.items[i]) *% 1099511628211;
        }
    }
    try std.io.getStdOut().writer().print("{d}\n", .{h});
}
