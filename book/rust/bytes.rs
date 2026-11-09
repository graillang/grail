fn main() {
    let data: Vec<u8> = vec![65, 66];
    let whole = &data[..];
    assert_eq!(whole[0], 65);
    println!("{}", whole.len());
}
