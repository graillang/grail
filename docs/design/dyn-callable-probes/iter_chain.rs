use std::time::Instant;
#[inline(never)]
fn via_callbacks(v: &[u64], f: &dyn Fn(u64) -> u64, keep: &dyn Fn(u64) -> bool) -> u64 {
    let mut s: u64 = 0;
    for &x in v { let y = f(x); if keep(y) { s = s.wrapping_add(y); } }
    s
}
fn main() {
    let n = 10_000_000u64;
    let v: Vec<u64> = (0..n).collect();
    let (mut bi, mut bl, mut bc) = (u128::MAX, u128::MAX, u128::MAX);
    let (mut a, mut b, mut d) = (0u64, 0u64, 0u64);
    for _ in 0..5 {
        let t0 = Instant::now();
        a = std::hint::black_box(&v).iter().map(|x| x * 2).filter(|x| x % 3 == 0).fold(0u64, |s, x| s.wrapping_add(x));
        let t1 = Instant::now();
        let mut s = 0u64;
        for &x in std::hint::black_box(&v).iter() { let y = x * 2; if y % 3 == 0 { s = s.wrapping_add(y); } }
        b = s;
        let t2 = Instant::now();
        d = via_callbacks(std::hint::black_box(&v), &|x| x * 2, &|y| y % 3 == 0);
        let t3 = Instant::now();
        bi = bi.min((t1 - t0).as_micros()); bl = bl.min((t2 - t1).as_micros()); bc = bc.min((t3 - t2).as_micros());
    }
    println!("{} {} {}", a, b, d);
    println!("iter chain {} us, hand loop {} us, dyn callbacks {} us", bi, bl, bc);
}
