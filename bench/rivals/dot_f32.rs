// The dot product of two vectors of one million f32, 200 passes with one element changed between
// passes; prints the total (twin of bench/dot_f32.c).
#[inline(never)]
fn dot(x: &[f32], y: &[f32]) -> f32 {
    let mut s: f32 = 0.0;
    for (xi, yi) in x.iter().zip(y) {
        s = s + xi * yi;
    }
    s
}
fn main() {
    let n: usize = 1000000;
    let mut x: Vec<f32> = Vec::with_capacity(n);
    let mut y: Vec<f32> = Vec::with_capacity(n);
    let (mut xv, mut yv): (f32, f32) = (0.0, 0.0);
    for _ in 0..n {
        x.push(xv);
        y.push(yv);
        xv = xv + 0.5;
        if 3.0 < xv { xv = 0.0; }
        yv = yv + 0.25;
        if 1.0 < yv { yv = 0.0; }
    }
    let mut total = 0f64;
    for pass in 0..200 {
        x[pass] = x[pass] + 1.0;
        total += dot(&x, &y) as f64;
    }
    println!("{}", total);
}
