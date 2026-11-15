fn work(flag: bool) -> usize {
    let scratch = vec![1_u8];
    if flag {
        return scratch.len();
    }
    0
}
fn main() {
    for i in 0..3 {
        let temporary = String::from("iteration");
        if i == 1 {
            continue;
        }
        assert_eq!(temporary.len(), 9);
    }
    let finished: Vec<u8> = Vec::new();
    drop(finished);
    println!("{}", work(true));
}
