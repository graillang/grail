fn main() {
    let old = String::from("old");
    let mut slot = old.as_str();
    let pointer = &mut slot;
    {
        let temporary = String::from("temporary");
        *pointer = temporary.as_str();
    }
    assert_eq!(*pointer, "temporary");
}
