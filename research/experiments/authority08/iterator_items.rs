fn main() {
    let mut data = [1, 2, 3];
    let mut iterator = data.iter_mut();
    let first = iterator.next().unwrap();
    let second = iterator.next().unwrap();
    drop(iterator);
    *first += 10;
    *second += 20;
    assert_eq!(data, [11, 22, 3]);
}
