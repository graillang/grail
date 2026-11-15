fn duplicate<T>(value: T) -> T {
    let moved = value;
    value
}
fn main() {
    println!("{}", duplicate(7_u64));
}
