struct Owned(u32);
impl Drop for Owned {
    fn drop(&mut self) {
        println!("{}", self.0);
    }
}
struct Pair {
    left: Owned,
    right: Owned,
}
fn choose(left: bool) -> Owned {
    let p = Pair {
        left: Owned(1),
        right: Owned(2),
    };
    if left { p.left } else { p.right }
}
fn main() {
    let x = choose(true);
    assert_eq!(x.0, 1);
    drop(x);
    let y = choose(false);
    assert_eq!(y.0, 2);
    drop(y);
}
