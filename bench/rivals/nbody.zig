// N-body (5 bodies, f64), as in the benchmarks game; prints the energy before and after
// (twin of bench/nbody.c).
const std = @import("std");

fn energy(p: *const [15]f64, v: *const [15]f64, m: *const [5]f64) f64 {
    var e: f64 = 0;
    for (0..5) |i| {
        e = e + 0.5 * m[i] * (v[i * 3] * v[i * 3] + v[i * 3 + 1] * v[i * 3 + 1] + v[i * 3 + 2] * v[i * 3 + 2]);
        for (i + 1..5) |j| {
            const dx = p[i * 3] - p[j * 3];
            const dy = p[i * 3 + 1] - p[j * 3 + 1];
            const dz = p[i * 3 + 2] - p[j * 3 + 2];
            const d2 = dx * dx + dy * dy + dz * dz;
            e = e - m[i] * m[j] / @sqrt(d2);
        }
    }
    return e;
}

pub fn main() !void {
    var p = [15]f64{ 0.0, 0.0, 0.0, 4.84143144246472090, -1.16032004402742839, -0.103622044471123109, 8.34336671824457987, 4.12479856412430479, -0.403523417114321381, 12.8943695621391310, -15.1111514016986312, -0.223307578892655734, 15.3796971148509165, -25.9193146099879641, 0.179258772950371181 };
    var v = [15]f64{ 0.0, 0.0, 0.0, 0.606326392995832, 2.81198684491626, -0.02521836165988763, -1.010774346178792, 1.825662371230411, 0.008415761376584154, 1.082791006441535, 0.8687130181696082, -0.01032737054813680, 0.979090732243898, 0.5946989986476762, -0.03476475593358662 };
    const m = [5]f64{ 39.47841760435743, 0.03769367487038949, 0.011286326131968767, 0.0017237240570597112, 0.0020336868699246304 };
    const out = std.io.getStdOut().writer();
    try out.print("{d}\n", .{energy(&p, &v, &m)});
    const dt: f64 = 0.01;
    for (0..2000000) |_| {
        for (0..5) |i| {
            for (i + 1..5) |j| {
                const dx = p[i * 3] - p[j * 3];
                const dy = p[i * 3 + 1] - p[j * 3 + 1];
                const dz = p[i * 3 + 2] - p[j * 3 + 2];
                const d2 = dx * dx + dy * dy + dz * dz;
                const mag = dt / (d2 * @sqrt(d2));
                for (0..3) |k| {
                    const d = p[i * 3 + k] - p[j * 3 + k];
                    v[i * 3 + k] = v[i * 3 + k] - d * m[j] * mag;
                    v[j * 3 + k] = v[j * 3 + k] + d * m[i] * mag;
                }
            }
        }
        for (0..15) |i| p[i] = p[i] + dt * v[i];
    }
    try out.print("{d}\n", .{energy(&p, &v, &m)});
}
