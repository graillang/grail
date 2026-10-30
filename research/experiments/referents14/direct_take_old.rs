fn main() {
    let old = String::from("old");
    let new = String::from("new");
    let mut slot = old.as_str();
    let pointer = &mut slot;
    {
        let returned = *pointer;
        *pointer = new.as_str();
        assert_eq!(returned, "old");
    }
    drop(old);
    assert_eq!(*pointer, "new");
}
