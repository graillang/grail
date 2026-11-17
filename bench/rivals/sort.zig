// Bottom-up merge sort of 4 million pseudo-random u64 values, three times; prints a checksum
// (twin of bench/sort.c).
const std = @import("std");

pub fn main() !void {
    const n: usize = 4194304;
    const allocator = std.heap.page_allocator;
    var check: u64 = 0;
    for (0..3) |round| {
        var v = try allocator.alloc(u64, n);
        var tmp = try allocator.alloc(u64, n);
        var x: u64 = 2463534242 + @as(u64, round);
        for (v) |*slot| {
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            slot.* = x;
        }
        @memcpy(tmp, v);
        var width: usize = 1;
        while (width < n) : (width *= 2) {
            var lo: usize = 0;
            while (lo < n) {
                const mid = @min(lo + width, n);
                const hi = @min(lo + 2 * width, n);
                var i = lo;
                var j = mid;
                for (lo..hi) |k| {
                    if (i < mid and (j >= hi or v[i] <= v[j])) {
                        tmp[k] = v[i];
                        i += 1;
                    } else {
                        tmp[k] = v[j];
                        j += 1;
                    }
                }
                lo = hi;
            }
            const s = v;
            v = tmp;
            tmp = s;
        }
        check ^= v[0] ^ v[n / 2] ^ v[n - 1];
        allocator.free(v);
        allocator.free(tmp);
    }
    try std.io.getStdOut().writer().print("{d}\n", .{check});
}
