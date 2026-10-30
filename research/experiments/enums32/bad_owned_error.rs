enum Parsed<'a> {
    Ok(&'a [u8]),
    Err(String),
}
fn bad<'a>(p: Parsed<'a>) -> &'a [u8] {
    match p {
        Parsed::Ok(s) => s,
        Parsed::Err(s) => s.as_bytes(),
    }
}
fn main() {}
