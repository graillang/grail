struct Token<'a> {
    span: &'a str,
    name: String,
}
fn carry<T>(value: T) -> T {
    value
}
fn span<'a>(token: &Token<'a>) -> &'a str {
    token.span
}
fn collect<'a>(source: &'a str) -> Vec<Token<'a>> {
    let mut out = Vec::new();
    out.push(Token {
        span: &source[0..2],
        name: String::from("one"),
    });
    out.push(Token {
        span: &source[2..4],
        name: String::from("two"),
    });
    carry(out)
}
fn main() {
    let source = String::from("abcd");
    let view = {
        let tokens = collect(&source);
        assert_eq!(source.len(), 4);
        assert_eq!(tokens.len(), 2);
        let mut iter = tokens.into_iter();
        let token = carry(iter.next().unwrap());
        let view = span(&token);
        let name = token.name;
        assert_eq!(name, "one");
        view
    };
    assert_eq!(view, "ab");
    println!("{}", view);
}
