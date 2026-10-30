struct Lending<'a> {
    data: &'a mut [i32],
}
impl Lending<'_> {
    fn next(&mut self) -> &mut i32 {
        &mut self.data[0]
    }
}
fn main() {
    let mut data = [1, 2, 3];
    let mut iterator = Lending { data: &mut data };
    let first = iterator.next();
    let second = iterator.next();
    *first += 10;
    *second += 20;
}
