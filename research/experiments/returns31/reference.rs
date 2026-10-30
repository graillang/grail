struct Inner {
    a: String,
    b: String,
}
struct Token<'a> {
    inner: Inner,
    span: &'a [u8],
}
fn pick(t: Token<'_>, n: bool) -> String {
    let _trash = vec![9u8];
    if n {
        return t.inner.a;
    }
    for i in 0..2 {
        if i != 0 {
            return t.inner.b;
        }
    }
    "fallback".into()
}
struct Mutable<'a> {
    span: &'a mut [u8],
    name: String,
}
fn span<'a>(t: Mutable<'a>, n: bool) -> &'a [u8] {
    if n {
        return &*t.span;
    }
    t.span
}
fn main() {
    for n in [false, true] {
        let source = [7];
        let t = Token {
            inner: Inner {
                a: "a".into(),
                b: "bb".into(),
            },
            span: &source,
        };
        assert_eq!(t.span[0], 7);
        println!("{}", pick(t, n).len());
    }
    let mut b = vec![7];
    let t = Mutable {
        span: &mut b,
        name: "n".into(),
    };
    assert_eq!(t.name, "n");
    assert_eq!(span(t, true)[0], 7);
    b.push(8);
    println!("{}", b.len());
}
