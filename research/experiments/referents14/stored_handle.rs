struct Cursor<'p, 'v> {
    pointer: &'p mut &'v str,
}
fn main() {
    let old = String::from("old");
    let new = String::from("new");
    let mut slot = old.as_str();
    let cursor = Cursor { pointer: &mut slot };
    *cursor.pointer = new.as_str();
    drop(old);
    assert_eq!(*cursor.pointer, "new");
}
