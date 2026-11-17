// Zig twin of bench/dyncall.grl. Zig has no interface objects in the language: this is the
// pointer-and-vtable pattern the standard library uses (std.mem.Allocator), one allocation per shape.
const std = @import("std");

const Shape = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    const VTable = struct { area: *const fn (*anyopaque) u64 };
    fn area(self: Shape) u64 {
        return self.vtable.area(self.ptr);
    }
};
const Square = struct {
    side: u64,
    fn area(p: *anyopaque) u64 {
        const s: *Square = @ptrCast(@alignCast(p));
        return s.side * s.side;
    }
    const vtable = Shape.VTable{ .area = area };
};
const Rect = struct {
    w: u64,
    h: u64,
    fn area(p: *anyopaque) u64 {
        const r: *Rect = @ptrCast(@alignCast(p));
        return r.w * r.h;
    }
    const vtable = Shape.VTable{ .area = area };
};
const Tri = struct {
    b: u64,
    h: u64,
    fn area(p: *anyopaque) u64 {
        const t: *Tri = @ptrCast(@alignCast(p));
        return t.b * t.h / 2;
    }
    const vtable = Shape.VTable{ .area = area };
};

fn xs(x0: u64) u64 {
    var x = x0;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return x;
}

pub fn main() !void {
    const n: usize = 1000000;
    const allocator = std.heap.smp_allocator;
    var shapes = try std.ArrayList(Shape).initCapacity(allocator, n);
    defer shapes.deinit();
    var x: u64 = 88172645463325252;
    for (0..n) |_| {
        x = xs(x);
        const k = x % 3;
        const a = x % 100;
        const b = (x >> 8) % 100;
        if (k == 0) {
            const s = try allocator.create(Square);
            s.* = .{ .side = a };
            shapes.appendAssumeCapacity(.{ .ptr = s, .vtable = &Square.vtable });
        } else if (k == 1) {
            const r = try allocator.create(Rect);
            r.* = .{ .w = a, .h = b };
            shapes.appendAssumeCapacity(.{ .ptr = r, .vtable = &Rect.vtable });
        } else {
            const t = try allocator.create(Tri);
            t.* = .{ .b = a, .h = b };
            shapes.appendAssumeCapacity(.{ .ptr = t, .vtable = &Tri.vtable });
        }
    }
    var total: u64 = 0;
    for (0..20) |_| {
        for (shapes.items) |s| total +%= s.area();
    }
    try std.io.getStdOut().writer().print("{d}\n", .{total});
}
