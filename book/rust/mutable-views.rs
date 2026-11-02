fn main() {
    let mut data = vec![1_u8];
    let writer = &mut data[..];
    let reader = &*writer;
    assert_eq!(reader[0], 1);
    writer[0] = 9;
    println!("{}", writer[0]);
}
