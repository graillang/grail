fn main() {
    let mut values: Vec<u64> = vec![10, 20];
    let slot = &values[0];
    let first = *slot;
    values.push(30);
    let last = values.pop().unwrap();
    println!("{}", first + last + values.len() as u64);
}
