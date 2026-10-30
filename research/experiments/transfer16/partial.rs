fn route<'a, T: Default>(left: &'a mut T, right: &'a mut T, flip: bool) -> (&'a mut T, &'a mut T) {
    if flip { (right, left) } else { (left, right) }
}
fn main() {
    for flip in [false, true] {
        let (mut left, mut right) = (1, 2);
        let (a, b) = route(&mut left, &mut right, flip);
        *a = 9;
        assert_eq!(*b, if flip { 1 } else { 2 });
        assert_eq!((left, right), if flip { (1, 9) } else { (9, 2) });
    }
}
