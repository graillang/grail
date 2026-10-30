struct Token<'a> {
    span: &'a [u8],
    name: String,
    offset: u64,
}
fn make<'a>(p: &'a [u8]) -> Token<'a> {
    Token {
        span: p,
        name: String::from("hé🙂"),
        offset: 3,
    }
}
fn carry<'a>(t: Token<'a>) -> Token<'a> {
    t
}
fn mixed(p: &[u8]) -> u64 {
    let t = carry(make(p));
    let name = t.name;
    let n = t.span.len();
    let span = t.span;
    let offset = t.offset;
    (name.len() + n + span.len()) as u64 + offset
}
struct Pair<'a> {
    left: &'a mut u8,
    right: &'a mut u8,
}
fn pair<'a>(x: &'a mut u8, y: &'a mut u8) -> Pair<'a> {
    Pair { left: x, right: y }
}
fn unique() -> u64 {
    let mut a = vec![1];
    let mut b = vec![2];
    let p = pair(&mut a[0], &mut b[0]);
    let l = &mut *p.left;
    let r = &mut *p.right;
    *l = 3;
    *r = 4;
    a.push(5);
    b.push(6);
    (a[0] + b[0]) as u64 + (a.len() + b.len()) as u64
}
fn drop_only() -> u64 {
    let source = vec![7];
    let t = Token {
        span: &source,
        name: String::from("owned"),
        offset: 0,
    };
    let n = t.name.len();
    drop(source);
    n as u64
}
fn main() {
    println!("{}", mixed(b"abc"));
    println!("{}", unique());
    println!("{}", drop_only());
}
