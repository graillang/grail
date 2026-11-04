fn main() {
    let small: u8 = 200;
    println!("{}", small + 55);
    let temperature: i32 = -12;
    println!("{}", temperature / 5);
    println!("{}", temperature > -20 && temperature < 0);
    let mask: u64 = 1 << 4 | 1;
    println!("{}", mask);
    println!("{}", u16::from(small) * 2);
    println!("{}", 300u16 as u8);
}
