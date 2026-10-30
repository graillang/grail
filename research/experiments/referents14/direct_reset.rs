fn main() {
    let old = String::from("old");
    let new = String::from("new");
    let mut slot = old.as_str();
    {
        let pointer = &mut slot;
        *pointer = new.as_str();
        assert_eq!(*pointer, "new");
    }
    slot = new.as_str();
    drop(old);
    assert_eq!(slot, "new");
}
