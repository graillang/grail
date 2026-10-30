fn duplicate<T>(value: T) -> (T, T) {
    (value, value)
}
fn main() {
    let _ = duplicate(String::from("owned"));
}
