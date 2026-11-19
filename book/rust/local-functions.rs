fn sum_by(prices: &[u64], f: impl Fn(u64) -> u64) -> u64 {
    let mut total = 0;
    for &p in prices {
        total += f(p);
    }
    total
}
fn twice(f: fn(u64) -> u64, x: u64) -> u64 {
    f(f(x))
}
fn main() {
    let prices = vec![10u64, 25, 40];
    println!("{}", sum_by(&prices, |p: u64| -> u64 { p + p / 5 }));
    let rate = 10u64;
    let with_rate = |p: u64| -> u64 { p + p * rate / 100 };
    println!("{}", sum_by(&prices, with_rate));
    fn fact(n: u64) -> u64 {
        if n == 0 { 1 } else { n * fact(n - 1) }
    }
    println!("{}", fact(5));
    println!("{}", twice(|x| x * 3, 2));
}
