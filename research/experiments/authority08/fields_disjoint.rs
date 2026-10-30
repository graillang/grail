struct Pair {
    left: i32,
    right: i32,
}
fn main() {
    let mut data = Pair { left: 1, right: 2 };
    let first = &mut data.left;
    let second = &mut data.right;
    *first += 10;
    *second += 20;
    assert_eq!((data.left, data.right), (11, 22));
}
