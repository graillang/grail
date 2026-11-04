fn half(level: u8) -> u8 {
    level / 2
}

fn main() {
    let full = 200;
    println!("{}", half(full));
    let readings: Vec<i32> = vec![-3, 5, 10];
    let mut sum = 0;
    for x in readings {
        sum += x;
    }
    println!("{}", sum);
}
