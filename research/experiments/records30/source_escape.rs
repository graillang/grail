struct Token<'a> {
    span: &'a [u8],
    name: String,
}
fn main() {
    let source = vec![7];
    let token = Token {
        span: &source,
        name: String::from("owned"),
    };
    drop(source);
    println!("{}", token.span.len());
}
