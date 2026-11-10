fn total_lengths(items: Vec<String>) -> usize {
    let mut total = 0;
    for item in items {
        total += item.len();
    }
    total
}
fn main() {
    let mut words: Vec<String> = Vec::new();
    words.push("alpha".to_string());
    words.push("be".to_string());
    println!("{}", total_lengths(words));
    let kept = vec!["one".to_string(), "three".to_string()];
    let mut letters = 0;
    for word in &kept {
        letters += word.len();
    }
    println!("{}", letters);
    println!("{}", kept.len());
}
