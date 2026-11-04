use std::collections::HashMap;

struct Score {
    name: String,
    points: u32,
}
fn main() {
    // Rust's HashMap has no defined order; this keeps first-insertion order to match Grail.
    let mut counts: HashMap<String, u64> = HashMap::new();
    let mut order: Vec<String> = Vec::new();
    for word in "the cat and the hat".split(' ') {
        if let Some(n) = counts.get_mut(word) {
            *n += 1;
        } else {
            counts.insert(word.to_string(), 1);
            order.push(word.to_string());
        }
    }
    for word in &order {
        println!("{}: {}", word, counts[word]);
    }
    let mut scores = vec![Score { name: "ada".into(), points: 7 }, Score { name: "bo".into(), points: 12 }];
    scores.push(Score { name: "cy".into(), points: 9 });
    scores.sort_by(|a, b| b.points.cmp(&a.points));
    for s in &scores {
        println!("{} {}", s.name, s.points);
    }
    let mut primes = vec![7u64, 2, 5, 3];
    primes.sort();
    println!("{:?}", primes);
}
