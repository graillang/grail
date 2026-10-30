struct Span<'a>(&'a mut [i32]);
impl<'a> Span<'a> {
    fn split(self, at: usize) -> (Span<'a>, Span<'a>) {
        let (left, right) = self.0.split_at_mut(at);
        (Span(left), Span(right))
    }
}
fn main() {
    let mut data = [1, 2, 3, 4];
    let parent = Span(&mut data);
    let (left, right) = parent.split(2);
    left.0[0] += 10;
    right.0[0] += 20;
    parent.0[0] = 0;
}
