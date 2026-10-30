use std::cell::RefCell;
struct Token<'a> {
    span: &'a [u8],
    name: String,
    value: u64,
}
fn parse(p: &[u8]) -> Result<u64, String> {
    let s = std::str::from_utf8(p).unwrap();
    if s.is_empty() {
        return Err("empty".into());
    }
    s.parse().map_err(|_| {
        if s.bytes().all(|b| b.is_ascii_digit()) {
            "overflow".into()
        } else {
            "invalid".into()
        }
    })
}
fn annotate(p: &[u8]) -> Result<Token<'_>, String> {
    let _scratch = "scratch".to_string();
    let value = parse(p)?;
    Ok(Token {
        span: p,
        name: "token".into(),
        value,
    })
}
struct Guard<'a> {
    id: u64,
    events: &'a RefCell<Vec<u64>>,
}
impl Drop for Guard<'_> {
    fn drop(&mut self) {
        self.events.borrow_mut().push(self.id);
    }
}
fn fail(events: &RefCell<Vec<u64>>) -> Result<u64, Guard<'_>> {
    Err(Guard { id: 4, events })
}
fn consume(_b: Guard<'_>, n: u64) -> u64 {
    n
}
fn args(events: &RefCell<Vec<u64>>) -> Result<u64, Guard<'_>> {
    let _b = Guard { id: 2, events };
    Ok(consume(Guard { id: 3, events }, fail(events)?))
}
fn effects(p: &mut [u8]) -> Result<u64, String> {
    p[0] = 9;
    let n = Err::<u64, _>("bad".to_string())?;
    Ok(n)
}
fn optional() -> Option<u64> {
    let n = None::<u64>?;
    Some(n)
}
fn main() {
    for p in [b"42".as_slice(), b"", b"bad", b"18446744073709551616"] {
        println!(
            "{}",
            match annotate(p) {
                Ok(t) => t.value + t.span.len() as u64 + t.name.len() as u64,
                Err(e) => e.len() as u64,
            }
        );
    }
    let events = RefCell::new(Vec::new());
    {
        let _root = Guard {
            id: 1,
            events: &events,
        };
        let error = args(&events).unwrap_err();
        assert_eq!(*events.borrow(), [3, 2]);
        drop(error);
    }
    assert_eq!(*events.borrow(), [3, 2, 4, 1]);
    println!("3 2 4 1");
    let mut b = [1];
    assert!(effects(&mut b).is_err());
    println!("{}", b[0]);
    assert_eq!(optional(), None);
    println!("none");
}
