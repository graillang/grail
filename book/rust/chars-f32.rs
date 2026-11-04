fn main() {
    let initial: char = 'g';
    println!("{}", initial.to_ascii_uppercase());
    let word = String::from("naïve");
    println!("{}", word.chars().count());
    let accent = 'ï';
    println!("{} is {} bytes", accent, accent.len_utf8());
    let ratio: f32 = 0.1;
    println!("{}", ratio + 0.2);
    println!("{}", ratio as f64);
}
