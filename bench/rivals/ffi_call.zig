// The cost of a foreign call: 10M calls of the separately compiled C function grail_bench_abs
// (bench/ffi_target.c -> .work/libffi_target.a), best of five rounds.
const std = @import("std");

extern "c" fn grail_bench_abs(x: i64) i64;

pub fn main() !void {
    const n: i64 = 10000000;
    var acc: i64 = 0;
    var best: u64 = std.math.maxInt(u64);
    for (0..5) |_| {
        var timer = try std.time.Timer.start();
        var i: i64 = 0;
        while (i < n) : (i += 1) acc +%= grail_bench_abs(i - 5000000);
        best = @min(best, timer.read() / 1000);
    }
    var bare: u64 = std.math.maxInt(u64);
    for (0..5) |_| {
        var timer = try std.time.Timer.start();
        var i: i64 = 0;
        while (i < n) : (i += 1) {
            acc +%= i - 5000000;
            std.mem.doNotOptimizeAway(acc);
        }
        bare = @min(bare, timer.read() / 1000);
    }
    const err = std.io.getStdErr().writer();
    try err.print("ffi_call {d} ps\n", .{best * 1000000 / @as(u64, @intCast(n))});
    try err.print("ffi_call_only {d} ps\n", .{(best -| bare) * 1000000 / @as(u64, @intCast(n))});
    try std.io.getStdOut().writer().print("checksum {d}\n", .{acc});
}
