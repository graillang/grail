fn main() {
    let base: u64 = 40;
    let mut answer = base;
    answer += 2;
    assert_eq!(answer, 42);
    println!("{answer}");
}
