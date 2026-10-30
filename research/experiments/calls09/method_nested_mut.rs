fn main() {
    let mut values = vec![1usize];
    values.push({
        values.push(2);
        3
    });
}
