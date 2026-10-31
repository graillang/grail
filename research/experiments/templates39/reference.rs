use std::{cell::RefCell, rc::Rc};
type Log = Rc<RefCell<Vec<u64>>>;
struct Owned<T> {
    value: T,
    id: u64,
    log: Log,
}
impl<T> Owned<T> {
    fn new(value: T, id: u64, log: &Log) -> Self {
        Self {
            value,
            id,
            log: log.clone(),
        }
    }
}
impl<T> Drop for Owned<T> {
    fn drop(&mut self) {
        self.log.borrow_mut().push(self.id);
    }
}
struct Token<'a> {
    span: &'a [u8],
    name: Owned<String>,
}
fn id<T>(value: T) -> T {
    value
}
fn parse<'a>(span: &'a [u8], log: &Log) -> Result<Token<'a>, Owned<String>> {
    let _local = Owned::new("parse".to_owned(), 3, log);
    if span.is_empty() {
        return Err(Owned::new("bad".to_owned(), 4, log));
    }
    Ok(Token {
        span,
        name: Owned::new("token".to_owned(), 4, log),
    })
}
fn relay<T>(value: T, n: u64) -> T {
    if n == 0 {
        return value;
    }
    relay(value, n - 1)
}
fn process(input: &[u8], log: &Log) -> Result<usize, Owned<String>> {
    let _before = Owned::new("before".to_owned(), 2, log);
    let token = parse(input, log)?;
    drop((
        Owned::new("first".to_owned(), 5, log),
        Owned::new("second".to_owned(), 6, log),
    ));
    let copied = relay(id(Owned::new(token.name.value.clone(), 7, log)), 4);
    Ok(token.span.len() + token.name.value.len() + copied.value.len())
}
fn scanner(input: &[u8]) -> Result<u64, &'static str> {
    let mut index = 0;
    let mut count = 0u64;
    let mut hash = 0u64;
    while index < input.len() {
        if input[index] == 32 {
            index += 1;
            continue;
        }
        let start = index;
        while index < input.len() && input[index] != 32 {
            index += 1;
        }
        let span = &input[start..index];
        if !span
            .iter()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == b'_')
        {
            return Err("invalid token");
        }
        let spelling = String::from_utf8(span.to_vec()).unwrap();
        let value = id(Some((span, spelling, start))).unwrap();
        hash = hash.wrapping_mul(33).wrapping_add(
            (value.0.len() + value.1.len() + value.2 + value.1.as_bytes()[0] as usize) as u64,
        );
        count += 1;
    }
    Ok(hash.wrapping_add(count.wrapping_mul(65537)))
}
fn main() {
    for n in [0, 1] {
        let log = Log::default();
        let value = {
            let source = Owned::new(vec![7u8], 1, &log);
            match process(&source.value[..n], &log) {
                Ok(n) => n,
                Err(e) => e.value.len(),
            }
        };
        println!("cleanup {n} {value} {:?}", log.borrow());
        assert_eq!(value, if n == 0 { 3 } else { 11 });
        assert_eq!(
            *log.borrow(),
            if n == 0 {
                vec![3, 2, 4, 1]
            } else {
                vec![3, 5, 6, 7, 4, 2, 1]
            }
        );
    }
    let pattern = b"alpha_1 beta2 gamma_3 delta4 ";
    let input = pattern.repeat(32768);
    let value = scanner(&input).unwrap();
    println!("scanner {} {value}", input.len());
    assert!(scanner(b"bad$").is_err());
}
