fn route<'a, T: Default>(left: &'a mut T, right: &'a mut T, flip: bool) -> (&'a mut T, &'a mut T) {
    if flip { (right, left) } else { (left, right) }
}
fn main() {
    let mut value = 0;
    let (a, b) = route(&mut value, &mut value, false);
    *a = 9;
    *b = 9;
}
