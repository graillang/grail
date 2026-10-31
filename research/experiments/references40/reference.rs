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
struct Record {
    count: u64,
    name: Owned<String>,
}
fn replace<T>(slot: &mut T, value: T) -> T {
    std::mem::replace(slot, value)
}
fn update(record: &mut Record, log: &Log) -> u64 {
    let before = replace(&mut record.name, Owned::new("newer".to_owned(), 5, log));
    let count = replace(&mut record.count, 11);
    before.value.len() as u64 + count
}
fn values(log: &Log) -> u64 {
    let mut source = Owned::new(vec![7u8], 1, log);
    let mut left = Owned::new("left".to_owned(), 2, log);
    let right = Owned::new("right".to_owned(), 3, log);
    let old = replace(&mut left, right);
    let mut record = Record {
        count: 7,
        name: Owned::new("data".to_owned(), 4, log),
    };
    let previous = update(&mut record, log);
    source.value.push(9);
    (left.value.len() + old.value.len()) as u64
        + previous
        + record.name.value.len() as u64
        + record.count
        + u64::from(source.value[1])
}
fn choose<'a>(left: &'a mut u64, right: &'a mut u64, flag: bool) -> &'a mut u64 {
    if flag { left } else { right }
}
fn counter(input: &[u8]) -> u64 {
    let mut hash = 0u64;
    for value in input {
        hash = hash.wrapping_mul(33).wrapping_add(u64::from(*value));
    }
    hash.wrapping_add((input.len() as u64).wrapping_mul(65537))
}
fn main() {
    let log = Log::default();
    assert_eq!(values(&log), 45);
    assert_eq!(*log.borrow(), vec![4, 5, 2, 3, 1]);
    println!("45 {:?}", log.borrow());
    for flag in [false, true] {
        let (mut left, mut right) = (1, 2);
        replace(choose(&mut left, &mut right, flag), 9);
        println!("{}", left * 10 + right);
    }
    let pattern = b"module parser; let token = value_123; ";
    let input = pattern
        .iter()
        .copied()
        .cycle()
        .take(1048576)
        .collect::<Vec<_>>();
    println!("counter {}", counter(&input));
}
