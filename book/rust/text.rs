fn main() {
    let mut greeting = String::from("Hello");
    greeting.push_str(", Grail!");
    println!("{greeting}");
    println!("{}", greeting.len());
}
