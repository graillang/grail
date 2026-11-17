// Sieve of Eratosthenes up to 50 million, three rounds; prints the sum of the prime counts
// (twin of bench/sieve.c; each round's limit depends on the previous round's count).
const std = @import("std");

pub fn main() !void {
    const n: usize = 50000000;
    const allocator = std.heap.page_allocator;
    var count: usize = 0;
    var total: usize = 0;
    for (0..3) |_| {
        const limit = n - (count & 1);
        const composite = try allocator.alloc(bool, limit + 1);
        defer allocator.free(composite);
        @memset(composite, false);
        count = 0;
        var i: usize = 2;
        while (i <= limit) : (i += 1) {
            if (!composite[i]) {
                count += 1;
                var j = i * i;
                while (j <= limit) : (j += i) composite[j] = true;
            }
        }
        total += count;
    }
    try std.io.getStdOut().writer().print("{d}\n", .{total});
}
