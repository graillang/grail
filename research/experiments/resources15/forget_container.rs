struct Cursor<'a> {
    target: &'a mut i32,
}
fn pack<T>(value: T) -> Vec<T> {
    vec![value]
}
fn erase<T>(value: T) {
    std::mem::forget(value);
}
fn main() {
    let mut value = 0;
    let cursor = Cursor { target: &mut value };
    *cursor.target = 1;
    erase(pack(cursor));
    value = 2;
    assert_eq!(value, 2);
}
