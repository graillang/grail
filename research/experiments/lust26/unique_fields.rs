struct Pair {
    left: Vec<u8>,
    right: Vec<u8>,
}
fn change<'a>(a: &'a mut Vec<u8>, b: &'a mut Vec<u8>) {
    let c = &mut *a;
    c.push(3);
    b.push(4);
    c.push(5);
}
fn main() {
    let mut pair = Pair {
        left: vec![1],
        right: vec![2],
    };
    change(&mut pair.left, &mut pair.right);
    assert_eq!(pair.left, vec![1, 3, 5]);
    assert_eq!(pair.right, vec![2, 4]);
    println!("{}", pair.left.len() + pair.right.len());
}
