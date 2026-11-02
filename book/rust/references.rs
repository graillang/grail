fn main() {
    let mut value: u64 = 5;
    let before = std::mem::replace(&mut value, 12);
    assert_eq!(before, 5);
    let reader = &value;
    println!("{}", *reader);
}
