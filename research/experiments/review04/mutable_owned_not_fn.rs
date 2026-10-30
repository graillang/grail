fn require_fn<F: Fn() -> i32>(f: &F) {
    assert_eq!(f(), 1);
}
fn main() {
    let mut count = 0;
    let f = move || {
        count += 1;
        count
    };
    require_fn(&f);
}
