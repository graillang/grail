fn main() {
    let a = String::from("old");
    let b = String::from("new");
    let mut cache = Vec::new();
    cache.push(a.as_str());
    assert_eq!(cache[0], "old");
    cache.clear();
    drop(a);
    cache.push(b.as_str());
    assert_eq!(cache[0], "new");
}
