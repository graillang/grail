fn lend<'short>(slot: &'short mut &mut i32) -> &'short mut i32 {
    &mut **slot
}
fn main() {
    let mut data = 1;
    let mut parent = &mut data;
    *lend(&mut parent) += 10;
    *parent += 20;
    assert_eq!(data, 31);
}
