struct View<'a>(&'a mut u32);
fn read<'a>(value: &'a View<'_>) -> &'a u32 {
    &*value.0
}
fn main() {
    let mut number = 7;
    let view = View(&mut number);
    assert_eq!(*read(&view), 7);
}
