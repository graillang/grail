// Rust's const generics: `const K: u32` in the parameter list, `rotl::<13>(x)` at the call.
fn rotl<const K: u32>(x: u64) -> u64 {
    const { assert!(K < 64, "rotate amount out of range") };
    if K == 0 {
        return x;
    }
    (x << K) | (x >> (64 - K))
}

fn checksum<const SEED: u64>(bytes: &[u8]) -> u64 {
    let mut h = SEED;
    for b in bytes {
        h = rotl::<5>(h) ^ (*b as u64);
    }
    h
}

fn main() {
    println!("{}", rotl::<13>(1));
    println!("{}", rotl::<17>(1));
    println!("{}", checksum::<7>(&[1, 2, 3]));
}
