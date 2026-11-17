// Rust/rayon twin of the scheduler benchmarks on gaps12-sched (tools/sched-rivals.mjs):
//   sched-rayon sched   join, spawn-and-wait, a burst of spawns, fib(32) by nested join (cutoff 12)
//   sched-rayon frame   bench/frame.grl: 600 frames of 32 systems (every third forks four), an
//                       in-place parallel pass over 1M elements in leaves of 4096, a render step on
//                       the main thread, an I/O thread and a background importer.
// Output is `name value unit` lines, as the Grail programs print.
use rayon::prelude::*;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

fn fib(n: u64) -> u64 {
    if n < 2 { n } else { fib(n - 1) + fib(n - 2) }
}
// 28 656 joins for n = 32 with the cutoff at 12, as bench/sched.grl.
fn pfib(n: u64) -> u64 {
    if n < 12 {
        return fib(n);
    }
    let (a, b) = rayon::join(|| pfib(n - 1), || pfib(n - 2));
    a + b
}
fn per(t: Instant, n: u64) -> u128 {
    t.elapsed().as_nanos() / n as u128
}

fn sched() {
    let n: u64 = 100000;
    let mut acc: u64 = (0..4u64).into_par_iter().sum(); // start the pool
    // A job spawned and waited for: rayon's spawn-and-wait is a scope with one spawn.
    let t = Instant::now();
    for _ in 0..n {
        let mut r = 0;
        rayon::scope(|s| s.spawn(|_| r = 1));
        acc += r;
    }
    println!("job_spawn_wait {} ns", per(t, n));
    // join called from the main thread, which is not one of rayon's workers (each call is injected).
    let t = Instant::now();
    for _ in 0..n {
        let (a, _) = rayon::join(|| 1u64, || 2u64);
        acc += a;
    }
    println!("join_main {} ns", per(t, n));
    // join called on a worker: the cost a nested join pays.
    let t = Instant::now();
    acc += rayon::scope(|_| {
        let mut a = 0;
        for _ in 0..n {
            a += rayon::join(|| 1u64, || 2u64).0;
        }
        a
    });
    println!("join {} ns", per(t, n));
    // 100 000 spawns, then all of them waited for.
    let t = Instant::now();
    let total = AtomicU64::new(0);
    rayon::scope(|s| {
        for i in 0..n {
            let total = &total;
            s.spawn(move |_| { total.fetch_add(i + 1, Ordering::Relaxed); });
        }
    });
    acc += total.load(Ordering::Relaxed);
    println!("task_burst {} ns", per(t, n));
    let t = Instant::now();
    let s = fib(32);
    println!("fib32_serial {} us", t.elapsed().as_micros());
    let t = Instant::now();
    let q = pfib(32);
    println!("fib32_join_main {} us", t.elapsed().as_micros());
    let t = Instant::now();
    let r = rayon::scope(|_| pfib(32));
    println!("fib32_join_task {} us", t.elapsed().as_micros());
    assert!(s == q && s == r);
    println!("checksum {} -", acc);
}

fn mix(x: u64) -> u64 {
    let mut v = x ^ 88172645463325252;
    v ^= v << 13;
    v ^= v >> 7;
    v ^= v << 17;
    v
}
fn work(seed: u64, rounds: u64) -> u64 {
    let mut v = seed;
    for i in 0..rounds {
        v = mix(v.wrapping_add(i));
    }
    v
}
fn system(i: u64, frame: u64) -> u64 {
    if i % 3 == 0 {
        let seed = i * 31 + frame;
        let parts: Vec<u64> = (0..4u64).into_par_iter().map(|k| work(seed + k, 5000)).collect();
        return parts[0] ^ parts[1] ^ parts[2] ^ parts[3];
    }
    work(i + frame, 20000)
}
fn bg_piece(i: u64, rounds: u64) -> u64 {
    let v: Vec<u64> = (0..2000).map(|k| mix(k + rounds + i)).collect();
    v.iter().fold(0, |a, x| a ^ x)
}
fn threads() -> u64 {
    let s = std::fs::read_to_string("/proc/self/status").unwrap();
    s.lines().find_map(|l| l.strip_prefix("Threads:")).map(|v| v.trim().parse().unwrap()).unwrap_or(0)
}

fn frame() {
    let stop = AtomicU64::new(0);
    let io_rounds = AtomicU64::new(0);
    let io_worst = AtomicU64::new(0);
    let bg_rounds = AtomicU64::new(0);
    let without_importer = std::env::args().count() > 2;
    std::thread::scope(|scope| {
        // The I/O task: reads a file, sleeps 5 ms, records how late it woke.
        scope.spawn(|| {
            let mut rounds = 0;
            while stop.load(Ordering::Relaxed) == 0 {
                let t0 = Instant::now();
                let _bytes = std::fs::read("/proc/self/stat").unwrap();
                std::thread::sleep(Duration::from_millis(5));
                let late = (t0.elapsed().as_micros() as u64).saturating_sub(5000);
                io_worst.fetch_max(late, Ordering::Relaxed);
                rounds += 1;
                io_rounds.store(rounds, Ordering::Relaxed);
            }
        });
        // The importer: rayon has no priorities, so it forks onto the same pool as the frame.
        scope.spawn(|| {
            if without_importer {
                return;
            }
            let mut rounds = 0;
            let mut acc = 0;
            while stop.load(Ordering::Relaxed) == 0 {
                let parts: Vec<u64> = (0..16u64).into_par_iter().map(|i| bg_piece(i, rounds)).collect();
                for p in parts { acc ^= p; }
                rounds += 1;
                bg_rounds.store(rounds, Ordering::Relaxed);
            }
            std::hint::black_box(acc);
        });
        let frames = 600;
        let n = 1000000u64;
        let mut data: Vec<u64> = (0..n).map(|i| i * 2654435761).collect();
        let mut times = Vec::with_capacity(frames);
        let mut check = 0u64;
        let start = Instant::now();
        for f in 0..frames as u64 {
            let t0 = Instant::now();
            let sys: Vec<u64> = (0..32u64).into_par_iter().map(|i| system(i, f)).collect();
            for s in sys { check ^= s; }
            data.par_chunks_mut(4096).for_each(|leaf| for x in leaf.iter_mut() { *x = mix(*x); });
            check ^= work(f, 20000); // "render" on this thread
            times.push(t0.elapsed().as_micros() as u64);
        }
        let total = start.elapsed().as_millis();
        stop.store(1, Ordering::Relaxed);
        for i in 0..16 { check ^= data[i * 1000]; }
        times.sort();
        println!("frame_median {} us", times[frames / 2]);
        println!("frame_p99 {} us", times[frames * 99 / 100]);
        println!("frame_max {} us", times[frames - 1]);
        println!("frames_total {} ms", total);
        println!("io_rounds {} n", io_rounds.load(Ordering::Relaxed));
        println!("io_worst_late {} us", io_worst.load(Ordering::Relaxed));
        println!("bg_rounds {} n", bg_rounds.load(Ordering::Relaxed));
        println!("threads {} n", threads());
        println!("checksum {} -", check);
    });
}

fn main() {
    match std::env::args().nth(1).as_deref() {
        Some("frame") => frame(),
        _ => sched(),
    }
}
