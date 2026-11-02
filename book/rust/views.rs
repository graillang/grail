fn main() {
    let data = vec![10_u8, 20, 30];
    let whole = &data[..];
    let middle = &whole[1..2];
    assert_eq!(middle[0], 20);
    println!("{}", middle.len());
}
