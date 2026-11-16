// x[i] = x[i] * a + y[i] over one million f32, 200 passes; prints the sum (twin of bench/xform_f32.c).
#[inline(never)]
fn scale_add(x: &mut [f32], y: &[f32], a: f32) {
    for (xi, yi) in x.iter_mut().zip(y) {
        *xi = *xi * a + *yi;
    }
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
    let a: f32 = 0.999;
    for _ in 0..200 {
        scale_add(&mut x, &y, a);
    }
    let mut sum = 0f64;
    for i in 0..n {
        sum += x[i] as f64;
    }
    println!("{}", sum);
}
