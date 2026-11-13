fn rect(area: u64, width: u64, height: u64) -> u64 { area + width * height }
struct Scaled { by: u64, plus: u64 }
impl Default for Scaled { fn default() -> Self { Scaled { by: 2, plus: 0 } } }
fn scaled(value: u64, s: &Scaled) -> u64 { value * s.by + s.plus }
fn main() {
    println!("{}", rect(0, 3, 4));
    println!("{}", rect(1, 5, 2));
    println!("{}", scaled(5, &Scaled::default()));
    println!("{}", scaled(5, &Scaled { plus: 7, ..Scaled::default() }));
}
