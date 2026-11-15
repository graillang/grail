fn consume(value: Vec<u8>) -> usize {
    value.len()
}
fn main() {
    let original = vec![8_u8];
    let moved = original;
    println!("{}", consume(moved));
}
