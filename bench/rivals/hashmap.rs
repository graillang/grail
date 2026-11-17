// Rust twin of bench/hashmap.grl: std::collections::HashMap with its default hasher.
use std::collections::HashMap;
fn xs(mut x: u64) -> u64 {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    x
}
fn main() {
    let n: u64 = 1000000;
    let mut m: HashMap<u64, u64> = HashMap::new();
    let mut keys = Vec::with_capacity(n as usize);
    let mut x: u64 = 88172645463325252;
    for i in 0..n {
        x = xs(x);
        keys.push(x);
        m.insert(x, i);
    }
    let mut sum: u64 = 0;
    for k in &keys {
        if let Some(v) = m.get(k) {
            sum = sum.wrapping_add(*v);
        }
    }
    let mut removed: u64 = 0;
    for (i, k) in keys.iter().enumerate() {
        if i % 2 == 0 {
            if let Some(v) = m.remove(k) {
                removed = removed.wrapping_add(v);
            }
        }
    }
    let found = keys.iter().filter(|k| m.contains_key(k)).count();
    println!("{} {} {} {}", sum, removed, found, m.len());
}
