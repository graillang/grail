fn reborrow(input: &mut i32) -> &mut i32 {
    let result;
    {
        let parent = input;
        result = &mut *parent;
    }
    result
}
fn main() {
    let mut data = 1;
    *reborrow(&mut data) += 10;
    assert_eq!(data, 11);
}
