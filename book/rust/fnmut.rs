fn main() {
    let mut count = 0;
    let mut next = || {
        count += 1;
        count
    };
    println!("{}", next());
    println!("{}", next());
    let doubled = |x: u64| x * 2;
    println!("{}", doubled(4));
}
