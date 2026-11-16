// Sieve of Eratosthenes up to 50 million, three times; prints the prime count (twin of bench/sieve.c).
fn main() {
    let n: usize = 50000000;
    let mut count: u64 = 0;
    for _ in 0..3 {
        let mut composite = vec![false; n + 1];
        count = 0;
        for i in 2..=n {
            if !composite[i] {
                count += 1;
                let mut j = i * i;
                while j <= n {
                    composite[j] = true;
                    j += i;
                }
            }
        }
    }
    println!("{}", count);
}
