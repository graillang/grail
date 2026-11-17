fn length(v: &[f32; 3]) -> f32 {
    (v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).sqrt()
}
fn scale(v: &mut [f32; 3], k: f32) {
    for i in 0..3 {
        v[i] = v[i] * k;
    }
}
fn main() {
    let mut v: [f32; 3] = [3.0, 0.0, 4.0];
    println!("{}", length(&v));
    scale(&mut v, 2.0);
    println!("{:?}", v);
    let identity: [[f32; 4]; 4] = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]];
    let mut trace: f32 = 0.0;
    for i in 0..identity.len() {
        trace = trace + identity[i][i];
    }
    println!("{}", trace);
    let w = v;
    println!("{}", w == v);
}
