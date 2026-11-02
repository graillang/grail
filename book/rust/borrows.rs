fn main() {
    let mut data = vec![7_u8];
    let reader = &data[..];
    assert_eq!(reader[0], 7);
    data.push(9);
    println!("{}", data.len());
}
