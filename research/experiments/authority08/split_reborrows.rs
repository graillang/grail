fn split(data: &mut [i32]) -> (&mut [i32], &mut [i32]) {
    data.split_at_mut(2)
}
fn main() {
    let mut data = [1, 2, 3, 4];
    let parent = &mut data[..];
    let (left, right) = split(parent);
    left[0] += 10;
    right[0] += 20;
    assert_eq!(data, [11, 2, 23, 4]);
}
