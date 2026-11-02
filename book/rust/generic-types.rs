struct Pair<T, U> { first: T, second: U }
fn main() {
    let pair = Pair { first: 42_u64, second: Vec::<u8>::new() };
    let some = Some(pair.second);
    match some {
        Some(value) => assert_eq!(value.len(), 0),
        None => unreachable!(),
    }
    let _empty: Option<u64> = None;
    println!("{}", pair.first);
}
