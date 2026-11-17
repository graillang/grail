// Rust twin of bench/ecs.grl: structure-of-arrays Vec<f32> columns.
fn xs(mut x: u64) -> u64 {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    x
}
fn main() {
    let n = 1000000usize;
    let (mut px, mut py, mut pz) = (Vec::with_capacity(n), Vec::with_capacity(n), Vec::with_capacity(n));
    let (mut vx, mut vy, mut vz) = (Vec::with_capacity(n), Vec::with_capacity(n), Vec::with_capacity(n));
    let mut x: u64 = 88172645463325252;
    for _ in 0..n {
        x = xs(x);
        px.push((x % 1000) as i64 as f32 * 0.5);
        py.push(((x >> 10) % 1000) as i64 as f32 * 0.5);
        pz.push(((x >> 20) % 1000) as i64 as f32 * 0.5);
        vx.push(((x >> 30) % 100) as i64 as f32 * 0.01);
        vy.push(((x >> 40) % 100) as i64 as f32 * 0.01);
        vz.push(((x >> 50) % 100) as i64 as f32 * 0.01);
    }
    let (dt, damping, gravity): (f32, f32, f32) = (0.016, 0.999, 0.0981);
    for _ in 0..100 {
        for i in 0..n {
            vx[i] = vx[i] * damping;
            vy[i] = vy[i] * damping - gravity * dt;
            vz[i] = vz[i] * damping;
            px[i] = px[i] + vx[i] * dt;
            py[i] = py[i] + vy[i] * dt;
            pz[i] = pz[i] + vz[i] * dt;
        }
    }
    let mut sum = 0f64;
    for i in 0..n {
        sum = sum + px[i] as f64 + py[i] as f64 + pz[i] as f64;
    }
    println!("{}", sum);
}
