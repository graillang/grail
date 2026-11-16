// The cost of a foreign call: 10M calls of libc's `labs`, best of five rounds (twin of the
// gaps12-sched bench/ffi_call.c). Times to stderr, the checksum to stdout. `no_builtins` is the
// C twin's -fno-builtin: without it LLVM knows `labs` and inlines an abs, and nothing is called.
#![no_builtins]
use std::hint::black_box;
use std::time::Instant;

unsafe extern "C" {
    fn labs(x: i64) -> i64;
}

fn main() {
    let n: i64 = 10000000;
    let mut acc: i64 = 0;
    let mut best = u128::MAX;
    for _ in 0..5 {
        let t0 = Instant::now();
        for i in 0..n {
            acc = acc.wrapping_add(unsafe { labs(i - 5000000) });
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
