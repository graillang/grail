// Rust twin of bench/iterchain.grl: the standard iterator adapters with closures.
fn main() {
    let n: u64 = 10000000;
    let v: Vec<u64> = (0..n).collect();
    let s: u64 = v.iter().map(|x| x * 2).filter(|x| x % 3 == 0).fold(0u64, |acc, x| acc.wrapping_add(x));
    println!("{}", s);
}
