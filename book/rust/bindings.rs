fn main() {
    let base = 40;
    let mut answer = base;
    answer += 2;
    let total: u64 = 42;
    assert_eq!(answer, total);
    println!("{answer}");
}
