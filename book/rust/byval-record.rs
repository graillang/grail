#[repr(C)]
struct Vec2 {
    x: f64,
    y: f64,
}

#[unsafe(no_mangle)]
extern "C" fn c_length(v: Vec2) -> f64 {
    (v.x * v.x + v.y * v.y).sqrt()
}

fn main() {
    let v = Vec2 { x: 3.0, y: 4.0 };
    println!("{}", c_length(v));
}
