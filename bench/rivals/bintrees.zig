// Zig twin of bench/bintrees.grl: create and destroy per node with the general allocator.
const std = @import("std");
const Node = struct { left: ?*Node, right: ?*Node };
const allocator = std.heap.smp_allocator;

fn make(depth: u64) !*Node {
    const n = try allocator.create(Node);
    if (depth == 0) {
        n.* = .{ .left = null, .right = null };
    } else {
        n.* = .{ .left = try make(depth - 1), .right = try make(depth - 1) };
    }
    return n;
}
fn check(t: ?*Node) u64 {
    const n = t orelse return 0;
    return 1 + check(n.left) + check(n.right);
}
fn drop(t: ?*Node) void {
    const n = t orelse return;
    drop(n.left);
    drop(n.right);
    allocator.destroy(n);
}

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const max: u64 = 16;
    const stretch = try make(max + 1);
    try out.print("{d}\n", .{check(stretch)});
    drop(stretch);
    const long_lived = try make(max);
    var d: u64 = 4;
    while (d <= max) : (d += 2) {
        const iterations = @as(u64, 1) << @intCast(max - d + 4);
        var total: u64 = 0;
        for (0..iterations) |_| {
            const t = try make(d);
            total += check(t);
            drop(t);
        }
        try out.print("{d} {d}\n", .{ iterations, total });
    }
    try out.print("{d}\n", .{check(long_lived)});
    drop(long_lived);
}
