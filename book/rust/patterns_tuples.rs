fn stats(values: Vec<i32>) -> (i32, i32, f64) {
    let mut low = values[0];
    let mut high = values[0];
    let mut total = 0;
    for &v in &values {
        if v < low {
            low = v;
        }
        if v > high {
            high = v;
        }
        total += v;
    }
    (low, high, total as f64 / values.len() as f64)
}
fn label(temp: i32) -> String {
    match temp {
        t if t < 0 => "freezing".into(),
        0..15 => "cold".into(),
        15..25 => "mild".into(),
        _ => "hot".into(),
    }
}
fn main() {
    let (low, high, mean) = stats(vec![12, -3, 21, 30]);
    println!("low {} high {} mean {:.1}", low, high, mean);
    for t in [low, 12, high] {
        println!("{:>4} {}", t, label(t));
    }
    println!("{:?}", (low, high));
}
