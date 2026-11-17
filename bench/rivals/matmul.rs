// 256x256 f32 matrix multiply, 20 times; prints a checksum of the result (twin of bench/matmul.c).
fn main() {
    const N: usize = 256;
    let mut a = vec![0f32; N * N];
    let mut b = vec![0f32; N * N];
    let mut c = vec![0f32; N * N];
    for i in 0..N * N {
        a[i] = (i % 7) as f32 * 0.25;
        b[i] = (i % 11) as f32 * 0.5;
    }
    for round in 0..20 {
        for i in 0..N {
            for j in 0..N {
                let mut s = 0f32;
                for k in 0..N {
                    s = s + a[i * N + k] * b[k * N + j];
                }
                c[i * N + j] = s;
            }
        }
        a[round] = c[round];
    }
    let mut sum = 0f64;
    for i in 0..N * N {
        sum += c[i] as f64;
    }
    println!("{}", sum);
}
