fn observe(view: &[u32], _: ()) {
    assert!(!view.is_empty());
}
fn grow(values: &mut Vec<u32>) {
    values.push(2);
}
fn main() {
    let mut values = vec![1];
    observe(values.as_slice(), grow(&mut values));
}
