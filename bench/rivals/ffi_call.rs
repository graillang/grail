// The cost of a foreign call: 10M calls of the separately compiled C function grail_bench_abs
// (bench/ffi_target.c -> .work/libffi_target.a), best of five rounds.
use std::hint::black_box;
use std::time::Instant;

unsafe extern "C" {
    fn grail_bench_abs(x: i64) -> i64;
}

fn main() {
    let n: i64 = 10000000;
    let mut acc: i64 = 0;
    let mut best = u128::MAX;
    for _ in 0..5 {
        let t0 = Instant::now();
        for i in 0..n {
            acc = acc.wrapping_add(unsafe { grail_bench_abs(i - 5000000) });
        }
        best = best.min(t0.elapsed().as_micros());
    }
    let mut bare = u128::MAX;
    for _ in 0..5 {
        let t0 = Instant::now();
        for i in 0..black_box(n) {
            acc = acc.wrapping_add(black_box(i - 5000000));
        }
        bare = bare.min(t0.elapsed().as_micros());
    }
    eprintln!("ffi_call {} ps", best * 1000000 / n as u128);
    eprintln!("ffi_call_only {} ps", best.saturating_sub(bare) * 1000000 / n as u128);
    println!("checksum {}", acc);
}
