struct Cursor<'a> {
    target: &'a mut i32,
}
fn pack<T>(value: T) -> Vec<T> {
    vec![value]
}
fn forward<T>(value: T) -> T {
    value
}
fn main() {
    let mut value = 0;
    let returned = forward(pack(Cursor { target: &mut value }));
    value = 2;
    assert_eq!(*returned[0].target, 2);
}
