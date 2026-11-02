fn main() {
    let mut value: u64 = 10;
    value += 2;
    value *= 3;
    value -= 6;
    value /= 5;
    value %= 4;
    value = value.wrapping_pow(3);
    println!("{value}");

    println!("{}", 2_u64.wrapping_pow(3_u32.pow(2)));
    println!("{}", 17 / 5);
    println!("{}", 7 ^ 3);
    assert_eq!(2_u64.wrapping_pow(64), 0);
    assert_eq!(0_u64.wrapping_pow(0), 1);
}
