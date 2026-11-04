fn average(values: Vec<f64>) -> f64 {
    let mut total = 0.0;
    for v in &values {
        total += v;
    }
    total / values.len() as f64
}
fn main() {
    println!("{}", 0.1 + 0.2);
    println!("{}", average(vec![2.5, 3.0, 4.75]));
    let side: f64 = 2.0;
    println!("diagonal {}", (side * side * 2.0).sqrt());
    println!("{}", -7.9f64 as i64);
    println!("{}", 1.0f64 / 0.0);
}
