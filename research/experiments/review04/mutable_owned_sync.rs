fn assert_sync<T: Sync>(_: &T) {}
fn main() {
    let mut count = 0;
    let mut f = move || {
        count += 1;
        count
    };
    assert_sync(&f);
    assert_eq!(f(), 1);
    assert_eq!(f(), 2);
}
