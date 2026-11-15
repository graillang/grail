use std::collections::HashMap;

struct Score {
    name: String,
    points: u32,
}
fn main() {
    let mut counts: HashMap<String, u64> = HashMap::from([
        ("the".to_string(), 2),
        ("cat".to_string(), 1),
        ("hat".to_string(), 1),
    ]);
    println!("{}", counts.len());
    println!("{}", counts["the"]);
    *counts.get_mut("cat").unwrap() += 1;
    println!("{}", counts["cat"]);
    counts.insert("dog".to_string(), 2);
    println!("{}", counts["dog"]);
    println!("{}", counts.contains_key("cat"));
    println!("{}", counts["the"]);
    match counts.get("hat") {
        Some(value) => println!("hat {}", value),
        None => println!("absent"),
    }
    println!("{}", counts.remove("hat").unwrap());
    println!("{}", counts.len());
    let empty: HashMap<String, u64> = HashMap::new();
    println!("{}", empty.len());
    let mut scores = vec![
        Score {
            name: "ada".into(),
            points: 7,
        },
        Score {
            name: "bo".into(),
            points: 12,
        },
    ];
    scores.push(Score {
        name: "cy".into(),
        points: 9,
    });
    scores.sort_by(|a, b| b.points.cmp(&a.points));
    for s in &scores {
        println!("{} {}", s.name, s.points);
    }
    let mut primes = vec![7u64, 2, 5, 3];
    primes.sort();
    println!("{:?}", primes);
}
