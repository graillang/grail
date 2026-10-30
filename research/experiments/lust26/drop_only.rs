struct Token<'a> {
    span: &'a str,
    name: String,
}
fn main() {
    let tokens;
    {
        let source = String::from("abc");
        tokens = vec![Token {
            span: source.as_str(),
            name: String::from("name"),
        }];
        assert_eq!(tokens[0].span, "abc");
        assert_eq!(tokens[0].name, "name");
    }
    // Only implicit recursive destruction follows; it must not read the dangling span.
}
