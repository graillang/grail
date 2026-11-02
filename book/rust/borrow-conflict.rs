fn main() {
    let mut data: Vec<u8> = Vec::new();
    let reader = &data[..];
    data.push(9);
    println!("{}", reader.len());
}
