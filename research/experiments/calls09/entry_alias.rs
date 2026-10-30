fn clear_then_observe(values: &mut Vec<u32>, view: &[u32]) {
    values.clear();
    assert!(!view.is_empty());
}
fn main() {
    let mut values = vec![1];
    clear_then_observe(&mut values, values.as_slice());
}
