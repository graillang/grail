fn main() {
    let old = String::from("old");
    let mut slot = old.as_str();
    assert_eq!(slot, "old");
    {
        let temporary = String::from("temporary");
        slot = temporary.as_str();
        assert_eq!(slot, "temporary");
        slot = old.as_str();
    }
    assert_eq!(slot, "old");
}
