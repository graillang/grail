// Zig twin of bench/hashmap.grl: std.AutoHashMap.
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
    var m = std.AutoHashMap(u64, u64).init(allocator);
    defer m.deinit();
    const keys = try allocator.alloc(u64, n);
    defer allocator.free(keys);
    var x: u64 = 88172645463325252;
    for (0..n) |i| {
        x = xs(x);
        keys[i] = x;
        try m.put(x, i);
    }
    var sum: u64 = 0;
    for (keys) |k| {
        if (m.get(k)) |v| sum +%= v;
    }
    var removed: u64 = 0;
    for (keys, 0..) |k, i| {
        if (i % 2 == 0) {
            if (m.fetchRemove(k)) |kv| removed +%= kv.value;
        }
    }
    var found: u64 = 0;
    for (keys) |k| {
        if (m.contains(k)) found += 1;
    }
    try std.io.getStdOut().writer().print("{d} {d} {d} {d}\n", .{ sum, removed, found, m.count() });
}
