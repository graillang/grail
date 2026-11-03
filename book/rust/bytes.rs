fn main() {
    let data: Vec<u8> = vec![65, 66];
    let view = &data[..];
    assert_eq!(view[0], 65);
    println!("{}", view.len());
}
