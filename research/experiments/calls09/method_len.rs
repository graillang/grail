fn main() {
    let mut values = vec![1usize];
    values.push(values.len());
    assert_eq!(values, [1, 1]);
}
