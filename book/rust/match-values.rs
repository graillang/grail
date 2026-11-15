enum Kind {
    Rate(u64),
    Empty,
}
fn level(k: Kind) -> u64 {
    match k {
        Kind::Rate(n) => n * 2,
        Kind::Empty => 0,
    }
}
fn main() {
    for n in 0..3 {
        println!(
            "{}",
            match n {
                0 => "none",
                1 => "one",
                _ => "many",
            }
        );
    }
    println!("{}", level(Kind::Rate(21)));
    println!("{}", level(Kind::Empty));
}
