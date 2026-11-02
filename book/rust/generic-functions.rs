fn identity<T>(value: T) -> T { value }
fn main() {
    let data = identity(Vec::<u8>::new());
    assert_eq!(data.len(), 0);
    println!("{}", identity::<u64>(42));
}
