struct Token<'a> {
    span: &'a [u8],
    name: String,
}
fn bad<'a>(token: Token<'a>) -> &'a [u8] {
    token.name.as_bytes()
}
fn main() {}
