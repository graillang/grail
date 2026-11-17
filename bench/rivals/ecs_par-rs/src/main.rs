// Rust/rayon twin of bench/ecs_par.grl: bench/rivals/ecs.rs's update as one rayon loop, the six
// columns fused with `par_iter_mut().zip(..)` and pieces of at least 16384 entities
// (`with_min_len`). RAYON_NUM_THREADS sets the workers; the sum is serial, so the checksum is the
// serial one at any thread count.
use rayon::prelude::*;

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
        px.par_iter_mut()
            .zip(py.par_iter_mut())
            .zip(pz.par_iter_mut())
            .zip(vx.par_iter_mut())
            .zip(vy.par_iter_mut())
            .zip(vz.par_iter_mut())
            .with_min_len(16384)
            .for_each(|(((((px, py), pz), vx), vy), vz)| {
                *vx = *vx * damping;
                *vy = *vy * damping - gravity * dt;
                *vz = *vz * damping;
                *px = *px + *vx * dt;
                *py = *py + *vy * dt;
                *pz = *pz + *vz * dt;
            });
    }
    let mut sum = 0f64;
    for i in 0..n {
        sum = sum + px[i] as f64 + py[i] as f64 + pz[i] as f64;
    }
    println!("{}", sum);
}
