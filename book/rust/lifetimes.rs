fn relay<'a>(value: &'a [u8]) -> &'a [u8] {
    value
}
fn main() {
    let data = vec![42_u8];
    let reader = relay(&data);
    println!("{}", reader[0]);
}
