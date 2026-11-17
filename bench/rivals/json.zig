// Zig twin of bench/json.grl: std.json.Value, the dynamic document type.
const std = @import("std");

const Totals = struct { ints: u64 = 0, strings: u64 = 0, nodes: u64 = 0 };

fn walk(v: std.json.Value, t: *Totals) void {
    t.nodes += 1;
    switch (v) {
        .integer => |i| t.ints +%= @bitCast(i),
        .string => |s| t.strings += s.len,
        .array => |items| for (items.items) |item| walk(item, t),
        .object => |members| {
            var it = members.iterator();
            while (it.next()) |entry| {
                t.strings += entry.key_ptr.len;
                walk(entry.value_ptr.*, t);
            }
        },
        else => {},
    }
}

pub fn main() !void {
    const n: u64 = 92000;
    const allocator = std.heap.smp_allocator;
    var text = std.ArrayList(u8).init(allocator);
    defer text.deinit();
    const w = text.writer();
    try w.writeAll("{\"items\":[");
    for (0..n) |i| {
        if (i > 0) try w.writeAll(",");
        try w.writeAll("{\"id\":");
        try w.print("{d},\"name\":\"item{d}\",\"tags\":[\"t{d}\",\"u{d}\"],\"value\":{d},\"nested\":", .{ i, i, i % 7, i % 13, i * 37 % 100003 });
        try w.writeAll("{\"a\":");
        try w.print("{d},\"b\":[1,2,3],\"label\":\"n{d}\"", .{ i % 100, i % 1000 });
        try w.writeAll("}}");
    }
    try w.writeAll("]}");
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, text.items, .{});
    defer parsed.deinit();
    var t = Totals{};
    walk(parsed.value, &t);
    const out = try std.json.stringifyAlloc(allocator, parsed.value, .{});
    defer allocator.free(out);
    try std.io.getStdOut().writer().print("{d} {d} {d} {d} {d}\n", .{ text.items.len, t.nodes, t.ints, t.strings, out.len });
}
