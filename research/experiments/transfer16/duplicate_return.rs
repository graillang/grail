fn route<'a, T: Default>(
    left: &'a mut T,
    _right: &'a mut T,
    _flip: bool,
) -> (&'a mut T, &'a mut T) {
    (left, left)
}
fn main() {
    let _ = route(&mut 1, &mut 2, false);
}
