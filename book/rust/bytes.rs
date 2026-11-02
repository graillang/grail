fn main() {
    let mut data: Vec<u8> = Vec::new();
    data.push(65);
    data.push(66);
    let view = &data[..];
    assert_eq!(view[0], 65);
    println!("{}", view.len());
}
