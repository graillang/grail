struct Token<'a> {
    view: &'a u8,
}
fn bad<'a>(token: Token<'a>) -> &'a &'a u8 {
    &token.view
}
fn main() {
    let x = 0u8;
    let r = bad(Token { view: &x });
    assert_eq!(**r, 0);
}
