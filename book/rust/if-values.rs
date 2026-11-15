fn word(n: u64) -> &'static str {
    if n == 0 {
        "zero"
    } else if n == 1 {
        "one"
    } else {
        "many"
    }
}
fn show(n: u64) {
    println!("{}", n);
}
fn main() {
    for i in 0..3 {
        println!("{}", word(i));
    }
    show(if 2 < 3 { 42 } else { 0 });
}
