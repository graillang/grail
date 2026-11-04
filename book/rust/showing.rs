use std::fmt;

const ORIGIN_NAME: &str = "origin";
const LIMIT: i32 = 10;

struct Point {
    x: i32,
    y: i32,
}
impl fmt::Display for Point {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        if self.x == 0 && self.y == 0 {
            return write!(f, "{}", ORIGIN_NAME);
        }
        write!(f, "({}, {})", self.x, self.y)
    }
}
impl Point {
    fn inside(&self) -> bool {
        self.x >= -LIMIT && self.x <= LIMIT && self.y >= -LIMIT && self.y <= LIMIT
    }
}
fn main() {
    let points = vec![Point { x: 0, y: 0 }, Point { x: 3, y: -4 }, Point { x: 20, y: 1 }];
    for point in &points {
        println!("{} inside: {}", point, point.inside());
    }
    let initial = b'G';
    println!("{}", initial);
}
