// Zig twin of bench/chan.grl: Zig's standard library has no channel, so this is the bounded ring with
// std.Thread.Mutex and two std.Thread.Condition, as in the C twin. Same cases, same output.
const std = @import("std");

const Chan = struct {
    items: []u64,
    head: usize = 0,
    len: usize = 0,
    closed: bool = false,
    m: std.Thread.Mutex = .{},
    not_empty: std.Thread.Condition = .{},
    not_full: std.Thread.Condition = .{},

    fn send(c: *Chan, v: u64) bool {
        c.m.lock();
        while (!c.closed and c.len == c.items.len) c.not_full.wait(&c.m);
        if (c.closed) {
            c.m.unlock();
            return false;
        }
        c.items[(c.head + c.len) % c.items.len] = v;
        c.len += 1;
        c.m.unlock();
        c.not_empty.signal();
        return true;
    }
    fn recv(c: *Chan) ?u64 {
        c.m.lock();
        while (!c.closed and c.len == 0) c.not_empty.wait(&c.m);
        if (c.len == 0) {
            c.m.unlock();
            return null;
        }
        const v = c.items[c.head];
        c.head = (c.head + 1) % c.items.len;
        c.len -= 1;
        c.m.unlock();
        c.not_full.signal();
        return v;
    }
    fn close(c: *Chan) void {
        c.m.lock();
        c.closed = true;
        c.m.unlock();
        c.not_empty.broadcast();
        c.not_full.broadcast();
    }
};

fn produce(c: *Chan, p: u64, each: u64) void {
    var i: u64 = 0;
    while (i < each) : (i += 1) _ = c.send(p * 1000000 + i + 1);
}
fn consume(c: *Chan, sum: *u64) void {
    while (c.recv()) |v| sum.* += v;
}

fn spread(alloc: std.mem.Allocator, producers: usize, consumers: usize, each: u64) !u64 {
    var c = Chan{ .items = try alloc.alloc(u64, 64) };
    var pt: [8]std.Thread = undefined;
    var ct: [8]std.Thread = undefined;
    var sums = [_]u64{0} ** 8;
    for (0..producers) |p| pt[p] = try std.Thread.spawn(.{}, produce, .{ &c, @as(u64, p), each });
    for (0..consumers) |q| ct[q] = try std.Thread.spawn(.{}, consume, .{ &c, &sums[q] });
    for (0..producers) |p| pt[p].join();
    c.close();
    var total: u64 = 0;
    for (0..consumers) |q| {
        ct[q].join();
        total += sums[q];
    }
    return total;
}

fn echo(there: *Chan, back: *Chan) void {
    while (there.recv()) |v| _ = back.send(v + 1);
}
fn ping(alloc: std.mem.Allocator, rounds: u64) !u64 {
    var there = Chan{ .items = try alloc.alloc(u64, 1) };
    var back = Chan{ .items = try alloc.alloc(u64, 1) };
    const t = try std.Thread.spawn(.{}, echo, .{ &there, &back });
    var v: u64 = 0;
    var i: u64 = 0;
    while (i < rounds) : (i += 1) {
        _ = there.send(v);
        v = back.recv().?;
    }
    there.close();
    t.join();
    return v;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var only: u8 = 0;
    if (std.posix.getenv("CHAN_CASE")) |e| {
        if (e.len > 0) only = e[0] - '0';
    }
    const out = std.io.getStdOut().writer();
    if (only == 0 or only == 1) try out.print("1:1 {d}\n", .{try spread(alloc, 1, 1, 400000)});
    if (only == 0 or only == 2) try out.print("N:1 {d}\n", .{try spread(alloc, 4, 1, 100000)});
    if (only == 0 or only == 3) try out.print("N:M {d}\n", .{try spread(alloc, 4, 4, 100000)});
    if (only == 0 or only == 4) try out.print("ping {d}\n", .{try ping(alloc, 100000)});
}
