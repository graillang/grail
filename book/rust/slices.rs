fn total(values: &[f32]) -> f32 {
    let mut sum: f32 = 0.0;
    for x in values {
        sum += x;
    }
    sum
}
fn scale(values: &mut [f32], factor: f32) {
    for x in values.iter_mut() {
        *x *= factor;
    }
}
fn main() {
    let mut samples = vec![1.5_f32, 2.0, 4.0, 0.5];
    println!("{}", total(&samples[1..3])); // 2.0 + 4.0
    scale(&mut samples[2..], 10.0); // Only the last two change.
    println!("{:?}", samples);
    let head = &samples[..2];
    let expected = [1.5_f32, 2.0];
    println!("{}", head == expected);
}
