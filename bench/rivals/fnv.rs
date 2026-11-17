// FNV-1a over 64 MiB of pseudo-random bytes, eight times; prints the final hash (twin of bench/fnv.c).
fn main() {
    let n: usize = 67108864;
    let mut data: Vec<u8> = Vec::with_capacity(n);
    let mut x: u64 = 88172645463325252;
    for _ in 0..n {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        data.push((x & 255) as u8);
    }
    let mut h: u64 = 14695981039346656037;
    for _ in 0..8 {
        for i in 0..n {
            h = (h ^ data[i] as u64).wrapping_mul(1099511628211);
        }
    }
    println!("{}", h);
}
