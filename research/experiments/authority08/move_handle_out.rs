fn take_inner<'a>(slot: &mut &'a mut i32, replacement: &'a mut i32) -> &'a mut i32 {
    std::mem::replace(slot, replacement)
}
fn main() {
    let mut old = 1;
    let mut new = 2;
    let mut slot = &mut old;
    let returned = take_inner(&mut slot, &mut new);
    *returned += 10;
    *slot += 20;
    assert_eq!((old, new), (11, 22));
}
