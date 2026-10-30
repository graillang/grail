fn route<'a, T: Default>(left: &'a mut T, _right: &'a mut T, flip: bool) -> (&'a mut T, &'a mut T) {
    let fresh = Box::leak(Box::new(T::default()));
    if flip { (fresh, left) } else { (left, fresh) }
}
fn main() {
    for flip in [false, true] {
        let (mut left, mut right) = (1, 2);
        let (a, b) = route(&mut left, &mut right, flip);
        *a = 9;
        *b = 9;
        assert_eq!((left, right), (9, 2));
    }
}
