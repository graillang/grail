fn main() {
    let old = String::from("old");
    let new = String::from("new");
    let mut slot = old.as_str();
    assert_eq!(slot, "old");
    slot = new.as_str();
    drop(old);
    assert_eq!(slot, "new");
}
