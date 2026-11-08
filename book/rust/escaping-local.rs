fn wrong(value: &[u8]) -> &[u8] {
    let local: Vec<u8> = Vec::new();
    let _ = value;
    &local
}
fn main() {}
