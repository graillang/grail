fn initials(name: String) -> String {
    let mut out = String::new();
    for part in name.split(' ') {
        if !part.is_empty() {
            out = out + &part[..1];
        }
    }
    out.to_uppercase()
}
fn main() {
    let line = String::from("  name = Ada Lovelace  ");
    let clean = line.trim();
    println!("[{}]", clean);
    if clean.starts_with("name") && clean.contains("=") {
        let fields: Vec<&str> = clean.split('=').collect();
        let value = fields[1].trim();
        println!("value: {}", value);
        println!("upper: {}", value.to_uppercase());
        println!("replaced: {}", value.replace("Ada", "Augusta Ada"));
    }
    let greeting = String::from("Hello, ") + "world";
    println!("{}", greeting == "Hello, world");
    println!("{}", "apple" < "banana");
    println!("{}", initials(String::from("ada lovelace")));
}
