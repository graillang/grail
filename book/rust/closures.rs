fn apply_twice(f: impl Fn(u64) -> u64, x: u64) -> u64 {
    f(f(x))
}
fn make_adder(n: u64) -> impl Fn(u64) -> u64 {
    move |x| x + n
}
fn main() {
    let offset = 10;
    let add_offset = move |x: u64| x + offset;
    println!("{}", add_offset(5));
    println!("{}", apply_twice(make_adder(3), 1));
    let words = String::from("grail");
    let length = move || words.len();
    println!("{}", length());
}
