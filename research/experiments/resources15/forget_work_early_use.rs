fn erase<T>(value: T) {
    std::mem::forget(value);
}
fn main() {
    let mut value = 0;
    std::thread::scope(|scope| {
        let target = &mut value;
        let handle = scope.spawn(move || {
            *target = 7;
        });
        erase(handle);
        assert_eq!(value, 7);
    });
}
