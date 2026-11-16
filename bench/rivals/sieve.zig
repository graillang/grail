// Sieve of Eratosthenes up to 50 million, three times; prints the prime count (twin of bench/sieve.c).
const std = @import("std");

pub fn main() !void {
    const n: usize = 50000000;
    const allocator = std.heap.page_allocator;
    var count: u64 = 0;
    for (0..3) |_| {
        const composite = try allocator.alloc(bool, n + 1);
        defer allocator.free(composite);
        @memset(composite, false);
        count = 0;
        var i: usize = 2;
        while (i <= n) : (i += 1) {
            if (!composite[i]) {
                count += 1;
                var j = i * i;
                while (j <= n) : (j += i) composite[j] = true;
            }
        }
    }
    try std.io.getStdOut().writer().print("{d}\n", .{count});
}
