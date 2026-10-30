fn main() {
    let mut data = 1;
    let parent = &mut data;
    let child = &mut *parent;
    *child += 10;
    assert_eq!(*child, 11);
    *parent += 20;
    assert_eq!(data, 31);
}
