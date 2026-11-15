enum Outcome {
    Good(Vec<u8>),
    Empty,
}
fn make(flag: bool) -> Outcome {
    if flag {
        Outcome::Good(vec![7])
    } else {
        Outcome::Empty
    }
}
fn main() {
    match make(true) {
        Outcome::Good(data) => println!("{}", data.len()),
        Outcome::Empty => println!("0"),
    }
}
