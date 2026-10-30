fn install<'a>(slots: &mut Vec<&'a str>) {
    let short = String::from("short");
    slots.push(short.as_str());
}
fn main() {
    let mut v = Vec::new();
    install(&mut v);
    println!("{}", v[0]);
}
