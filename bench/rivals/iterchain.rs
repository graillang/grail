// Rust twin of bench/iterchain.grl: 20 rounds over ten million u64 with standard iterator adapters.
fn main() {
    let n: u64 = 10000000;
    let v: Vec<u64> = (0..n).collect();
    let mut s: u64 = 0;
    for round in 0..20u64 {
        s = s.wrapping_add(
            v.iter()
                .map(|x| (x + round) * 2)
                .filter(|x| x % 3 == 0)
                .fold(0u64, |acc, x| acc.wrapping_add(x)),
        );
    }
    println!("{}", s);
}
