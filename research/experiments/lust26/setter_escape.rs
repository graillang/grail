fn install<'a>(slot: &mut &'a str, value: &'a str) {
    *slot = value;
}
fn main() {
    let old = String::from("old");
    let new = String::from("new");
    let mut slot = old.as_str();
    install(&mut slot, new.as_str());
    drop(new);
    println!("{}", slot);
}
