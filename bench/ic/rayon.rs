// Instruction-count probes: `prog MODE N`. Run under callgrind with one thread; per-op cost is
// (count at 2N - count at N) / N, which removes startup.
fn fib(n: u64) -> u64 { if n < 2 { n } else { fib(n - 1) + fib(n - 2) } }
fn pfib(n: u64) -> u64 { if n < 12 { return fib(n); } let (a, b) = rayon::join(|| pfib(n - 1), || pfib(n - 2)); a + b }
fn main() {
    let a: Vec<String> = std::env::args().collect();
    let n: u64 = a[2].parse().unwrap();
    let mut acc = 0u64;
    match a[1].as_str() {
        "join" => { acc = rayon::scope(|_| { let mut x = 0; for _ in 0..n { x += rayon::join(|| 1u64, || 2u64).0; } x }); }
        "spawn" => { for _ in 0..n { let mut r = 0; rayon::scope(|s| s.spawn(|_| r = 1)); acc += r; } }
        "fib" => { for _ in 0..n { acc += rayon::scope(|_| pfib(20)); } }
        _ => {}
    }
    println!("{}", acc);
}
