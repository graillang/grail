struct Token<'a> {
    span: &'a [u8],
    name: String,
}
enum Parsed<'a> {
    Ok(Token<'a>),
    Err(String),
}
fn parse(p: &[u8]) -> Parsed<'_> {
    if p.is_empty() {
        return Parsed::Err("empty input".into());
    }
    Parsed::Ok(Token {
        span: p,
        name: "owned".into(),
    })
}
fn recover(p: &[u8]) -> usize {
    match parse(p) {
        Parsed::Ok(t) => t.span.len() + t.name.len(),
        Parsed::Err(e) => e.len(),
    }
}
fn error<'a>() -> Result<&'a [u8], String> {
    Err("bad".into())
}
fn main() {
    assert!(error().is_err());
    println!("{}", recover(b"abc"));
    println!("{}", recover(b""));
    let text = Some("abc".to_string()).unwrap();
    println!("{}", text.len() + 4);
    for s in [
        "0",
        "18446744073709551615",
        "18446744073709551616",
        "999999999999999999999999999999",
        "12x",
        "",
        "00042",
    ] {
        let value = match s.parse::<u64>() {
            Ok(v) => v,
            Err(_) => {
                if s.is_empty() {
                    5
                } else if s.len() > 20 || s == "18446744073709551616" {
                    8
                } else {
                    7
                }
            }
        };
        println!("{value}");
    }
}
