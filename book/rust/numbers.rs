fn main() {
    assert_eq!(0_u64.wrapping_sub(1).wrapping_add(1), 0);
    assert_eq!(17 % 5, 2);
    assert_eq!((7 ^ 3) & 6, 4);
    assert!(3 < 4);
    assert!(true);
    assert_eq!(u64::from(false), 0);
    println!("{}", 6 * 7);
}
