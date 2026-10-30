// This is a reference-envelope workaround, not a recommended source idiom or allocation guarantee.
fn reset_views<'a, 'b>(mut values: Vec<&'a str>) -> Vec<&'b str> {
    values.clear();
    values.into_iter().map(|_| unreachable!()).collect()
}
fn main() {
    let a = String::from("old");
    let b = String::from("new");
    let mut cache = Vec::new();
    cache.push(a.as_str());
    assert_eq!(cache[0], "old");
    cache = reset_views(cache);
    drop(a);
    cache.push(b.as_str());
    assert_eq!(cache[0], "new");
}
