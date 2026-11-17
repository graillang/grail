// Rust twin of bench/strings.grl: format! to build, split to cut, parse::<u64> and parse::<f64>.
use std::fmt::Write;
fn xs(mut x: u64) -> u64 {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    x
}
fn main() {
    let n: u64 = 1000000;
    let mut text = String::new();
    let mut x: u64 = 88172645463325252;
    for i in 0..n {
        x = xs(x);
        let a = x % 100000;
        let b = (x >> 20) % 100000;
        writeln!(text, "k{},{},{}.{}{}", i, a, b / 100, (b % 100) / 10, b % 10).unwrap();
    }
    let mut int_sum: u64 = 0;
    let mut float_sum: f64 = 0.0;
    let mut out = String::new();
    for line in text.split('\n') {
        if line.is_empty() {
            continue;
        }
        let fields: Vec<&str> = line.split(',').collect();
        let a: u64 = fields[1].parse().unwrap();
        let f: f64 = fields[2].parse().unwrap();
        int_sum += a;
        float_sum = float_sum + f;
        write!(out, "{}:{};", a * 2, fields[0].len()).unwrap();
    }
    let mut h: u64 = 14695981039346656037;
    for b in out.bytes() {
        h = (h ^ b as u64).wrapping_mul(1099511628211);
    }
    println!("{} {} {} {}", int_sum, float_sum, out.len(), h);
}
