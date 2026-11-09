fn replace<T>(slot: &mut T, value: T) -> T {
    std::mem::replace(slot, value)
}
fn main() {
    let first = vec![1_u8];
    let second = vec![2_u8];
    let mut current: &[u8] = &first;
    let previous = replace(&mut current, &second);
    assert_eq!(previous[0], 1);
    println!("{}", current[0]);
}
