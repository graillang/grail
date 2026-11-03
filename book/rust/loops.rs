fn main() {
    let mut total = 0_u64;
    for i in 0..6 {
        if i == 2 { continue; }
        total += i;
    }
    let mut n = 0;
    while n < 10 {
        n += 1;
        if n == 3 { break; }
    }
    println!("{}", total + n);
}
