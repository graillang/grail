fn main() {
    let original: Vec<u8> = Vec::new();
    let moved = original;
    println!("{}", original.len());
    drop(moved);
}
