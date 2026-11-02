fn wrong<'a>() -> &'a [u8] {
    let local: Vec<u8> = Vec::new();
    &local
}
fn main() {}
