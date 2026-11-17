// Bottom-up merge sort of 4 million pseudo-random u64 values, three times; prints a checksum
// (twin of bench/sort.c).
fn main() {
    let n: usize = 4194304;
    let mut check: u64 = 0;
    for round in 0..3u64 {
        let mut v: Vec<u64> = Vec::with_capacity(n);
        let mut x: u64 = 2463534242 + round;
        for _ in 0..n {
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            v.push(x);
        }
        let mut tmp = v.clone();
        let mut width = 1;
        while width < n {
            let mut lo = 0;
            while lo < n {
                let mid = (lo + width).min(n);
                let hi = (lo + 2 * width).min(n);
                let (mut i, mut j) = (lo, mid);
                for k in lo..hi {
                    if i < mid && (j >= hi || v[i] <= v[j]) {
                        tmp[k] = v[i];
                        i += 1;
                    } else {
                        tmp[k] = v[j];
                        j += 1;
                    }
                }
                lo = hi;
            }
            std::mem::swap(&mut v, &mut tmp);
            width *= 2;
        }
        check ^= v[0] ^ v[n / 2] ^ v[n - 1];
    }
    println!("{}", check);
}
