// Sieve of Eratosthenes up to 50 million, three rounds; prints the sum of the prime counts
// (twin of bench/sieve.c; each round's limit depends on the previous round's count).
fn main() {
    let n: usize = 50000000;
    let mut count: usize = 0;
    let mut total: usize = 0;
    for _ in 0..3 {
        let limit = n - (count & 1);
        let mut composite = vec![false; limit + 1];
        count = 0;
        for i in 2..=limit {
            if !composite[i] {
                count += 1;
                let mut j = i * i;
                while j <= limit {
                    composite[j] = true;
                    j += i;
                }
            }
        }
        total += count;
    }
    println!("{}", total);
}
