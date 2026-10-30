fn main() {
    let mut data = [1, 2, 3];
    let first = &mut data[0];
    let second = &mut data[1];
    *first += 10;
    *second += 20;
}
