const PAGE: u64 = 4096;
static MASK: u64 = PAGE - 1;
static NAME: &str = "grail";
static SQUARES: [u64; 8] = squares();

const fn squares() -> [u64; 8] {
    let mut v = [0u64; 8];
    let mut i = 0;
    while i < 8 {
        v[i] = (i * i) as u64;
        i += 1;
    }
    v
}

fn sum(v: &[u64]) -> u64 {
    v.iter().sum()
}

fn main() {
    println!("{}", MASK);
    println!("{}", NAME);
    println!("{}", SQUARES[3]);
    println!("{}", sum(&SQUARES));
}
