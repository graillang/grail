struct Token<'a> {
    span: &'a mut [u8],
    name: String,
}
fn bad() {
    let mut b = vec![7];
    let t = Token {
        span: &mut b,
        name: "n".into(),
    };
    let r = &*t.span;
    drop(t.name);
    b[0] = 8;
    println!("{}", r[0]);
}
fn main() {}
