fn main() {
    let mut data = 1;
    let parent = &mut data;
    let child = &*parent;
    assert_eq!(*parent, 1);
    assert_eq!(*child, 1);
    *parent = 2;
    assert_eq!(data, 2);
}
