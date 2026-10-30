fn main() {
    let mut data = 1;
    let parent = &mut data;
    let child = &*parent;
    *parent = 2;
    assert_eq!(*child, 1);
}
