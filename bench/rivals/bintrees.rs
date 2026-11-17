// Rust twin of bench/bintrees.grl: Option<Box<Node>>.
struct Node {
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}
fn make(depth: u64) -> Box<Node> {
    if depth == 0 {
        return Box::new(Node { left: None, right: None });
    }
    Box::new(Node { left: Some(make(depth - 1)), right: Some(make(depth - 1)) })
}
fn check(t: &Option<Box<Node>>) -> u64 {
    match t {
        None => 0,
        Some(n) => 1 + check(&n.left) + check(&n.right),
    }
}
fn main() {
    let max: u64 = 16;
    let stretch = Some(make(max + 1));
    println!("{}", check(&stretch));
    drop(stretch);
    let long_lived = Some(make(max));
    let mut d = 4;
    while d <= max {
        let iterations: u64 = 1 << (max - d + 4);
        let mut total = 0;
        for _ in 0..iterations {
            let t = Some(make(d));
            total += check(&t);
        }
        println!("{} {}", iterations, total);
        d += 2;
    }
    println!("{}", check(&long_lived));
}
