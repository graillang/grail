fn set<'v>(pointer: &mut &'v str, new: &'v str) {
    *pointer = new;
}
fn main() {
    let old = String::from("old");
    let new = String::from("new");
    let mut slot = old.as_str();
    let pointer = &mut slot;
    set(pointer, new.as_str());
    drop(old);
    assert_eq!(*pointer, "new");
}
