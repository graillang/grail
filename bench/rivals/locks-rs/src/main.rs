// Rust twin of bench/locks.grl. `std` and `parking_lot` columns: the same workloads, OS threads,
// nanoseconds per operation. Rust has no semaphore in std or parking_lot; the semaphore row is a
// Mutex<usize> + Condvar, the usual hand-written one.
use std::sync::Arc;
use std::time::Instant;

macro_rules! suite {
    ($tag:expr, $M:ident, $RW:ident, $CV:ident, $lock:ident, $read:ident, $write:ident, $wait:ident) => {{
        let tag = $tag;
        let m = Arc::new($M::new(0u64));
        {
            let m = m.clone();
            let t = std::thread::spawn(move || {
                let s = Instant::now();
                for _ in 0..5_000_000u64 { *$lock!(m) += 1; }
                s.elapsed().as_nanos() as u64
            }).join().unwrap();
            println!("{}mutex-uncontended {}", tag, t / 5_000_000);
        }
        let run = |work: u32| -> u64 {
            let m = m.clone();
            let rw = Arc::new($RW::new(0u64));
            let sem = Arc::new(($M::new(2usize), $CV::new()));
            let s = Instant::now();
            let hs: Vec<_> = (0..8).map(|_| {
                let m = m.clone(); let rw = rw.clone(); let sem = sem.clone();
                std::thread::spawn(move || {
                    let mut t = 0u64;
                    match work {
                        0 => for _ in 0..200_000 { let mut g = $lock!(m); *g += 1; t += *g; },
                        1 => for _ in 0..200_000 { t += *$read!(rw); },
                        2 => for k in 0..200_000u64 { if k % 16 == 0 { let mut g = $write!(rw); *g += 1; t += *g; } else { t += *$read!(rw); } },
                        _ => for k in 0..100_000u64 {
                            { let mut g = $lock!(sem.0); while *g == 0 { $wait!(sem.1, g); } *g -= 1; }
                            t += k;
                            { let mut g = $lock!(sem.0); *g += 1; } sem.1.notify_one();
                        },
                    }
                    t
                })
            }).collect();
            for h in hs { std::hint::black_box(h.join().unwrap()); }
            s.elapsed().as_nanos() as u64
        };
        println!("{}mutex-contended {}", tag, run(0) / 1_600_000);
        println!("{}rwlock-read {}", tag, run(1) / 1_600_000);
        println!("{}rwlock-mixed {}", tag, run(2) / 1_600_000);
        {
            let p = Arc::new(($M::new(0u64), $CV::new()));
            let s = Instant::now();
            let hs: Vec<_> = (0..2u64).map(|side| {
                let p = p.clone();
                std::thread::spawn(move || {
                    for _ in 0..100_000 {
                        let mut g = $lock!(p.0);
                        while *g % 2 != side { $wait!(p.1, g); }
                        *g += 1;
                        drop(g);
                        p.1.notify_all();
                    }
                })
            }).collect();
            for h in hs { h.join().unwrap(); }
            println!("{}condition-pingpong {}", tag, s.elapsed().as_nanos() as u64 / 100_000);
        }
        println!("{}semaphore-contended {}", tag, run(3) / 800_000);
    }};
}

macro_rules! std_lock { ($m:expr) => { $m.lock().unwrap() } }
macro_rules! std_read { ($m:expr) => { $m.read().unwrap() } }
macro_rules! std_write { ($m:expr) => { $m.write().unwrap() } }
macro_rules! std_wait { ($c:expr, $g:ident) => { $g = $c.wait($g).unwrap() } }
macro_rules! pl_lock { ($m:expr) => { $m.lock() } }
macro_rules! pl_read { ($m:expr) => { $m.read() } }
macro_rules! pl_write { ($m:expr) => { $m.write() } }
macro_rules! pl_wait { ($c:expr, $g:ident) => { $c.wait(&mut $g) } }

fn main() {
    {
        use std::sync::{Condvar, Mutex, RwLock};
        suite!("std ", Mutex, RwLock, Condvar, std_lock, std_read, std_write, std_wait);
    }
    {
        use parking_lot::{Condvar, Mutex, RwLock};
        suite!("parking_lot ", Mutex, RwLock, Condvar, pl_lock, pl_read, pl_write, pl_wait);
    }
}
