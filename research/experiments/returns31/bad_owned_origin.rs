struct Token<'a> {
    span: &'a mut [u8],
    name: String,
}
fn bad<'a>(t: Token<'a>, yes: bool) -> &'a [u8] {
    if yes {
        return t.name.as_bytes();
    }
    t.span
}
fn main() {}
