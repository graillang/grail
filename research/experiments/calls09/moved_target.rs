fn call(_: &mut Vec<u32>, _: ()) {}
fn main() {
    let mut values = vec![1];
    call(&mut values, drop(values));
}
