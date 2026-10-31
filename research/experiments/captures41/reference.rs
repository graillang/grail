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
struct Cursor<'a> {
    source: &'a [u8],
    _name: Owned<String>,
}
struct Unique<'a> {
    source: &'a mut [u8],
    _name: Owned<String>,
}
fn source<'data>(cursor: &Cursor<'data>) -> &'data [u8] {
    cursor.source
}
fn short<'outer>(cursor: &'outer Unique<'_>) -> &'outer [u8] {
    cursor.source
}
fn inspect<T>(_value: T) -> u64 {
    7
}
fn main() {
    let log = Log::default();
    let result = {
        let mut data = Owned::new(vec![7u8], 1, &log);
        let cursor = Cursor {
            source: &data.value,
            _name: Owned::new("owned".to_owned(), 2, &log),
        };
        let span = source(&cursor);
        drop(cursor);
        let first = u64::from(span[0]) + span.len() as u64;
        data.value.push(8);
        let unique = Unique {
            source: &mut data.value,
            _name: Owned::new("unique".to_owned(), 3, &log),
        };
        let child = short(&unique);
        let second = u64::from(child[1]) + child.len() as u64;
        drop(unique);
        data.value.push(9);
        let number = 11;
        let holder = &number;
        let pointer = holder;
        first + second + *pointer + inspect(&data.value)
    };
    assert_eq!(result, 36);
    assert_eq!(*log.borrow(), vec![2, 3, 1]);
    println!("{result} {:?}", log.borrow());
}
