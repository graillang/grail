fn classify(n: u64) -> u64 {
    if n < 10 { 1 } else { 2 }
}

fn main() {
    assert_eq!(classify(7), 1);
    println!("{}", classify(12));
}
