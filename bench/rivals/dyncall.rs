// Rust twin of bench/dyncall.grl: Vec<Box<dyn Shape>>.
trait Shape {
    fn area(&self) -> u64;
}
struct Square { side: u64 }
struct Rect { w: u64, h: u64 }
struct Tri { b: u64, h: u64 }
impl Shape for Square { fn area(&self) -> u64 { self.side * self.side } }
impl Shape for Rect { fn area(&self) -> u64 { self.w * self.h } }
impl Shape for Tri { fn area(&self) -> u64 { self.b * self.h / 2 } }
fn xs(mut x: u64) -> u64 {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    x
}
fn main() {
    let n = 1000000;
    let mut shapes: Vec<Box<dyn Shape>> = Vec::new();
    let mut x: u64 = 88172645463325252;
    for _ in 0..n {
        x = xs(x);
        let (k, a, b) = (x % 3, x % 100, (x >> 8) % 100);
        if k == 0 {
            shapes.push(Box::new(Square { side: a }));
        } else if k == 1 {
            shapes.push(Box::new(Rect { w: a, h: b }));
        } else {
            shapes.push(Box::new(Tri { b: a, h: b }));
        }
    }
    let mut total: u64 = 0;
    for _ in 0..20 {
        for s in &shapes {
            total = total.wrapping_add(s.area());
        }
    }
    println!("{}", total);
}
