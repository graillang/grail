// Rust twin of bench/chan.grl: crossbeam_channel::bounded (capacity 64; 1 for ping), OS threads.
use crossbeam_channel::bounded;
use std::thread;

fn spread(producers: u64, consumers: usize, each: u64) -> u64 {
    let (tx, rx) = bounded::<u64>(64);
    let senders: Vec<_> = (0..producers)
        .map(|p| {
            let tx = tx.clone();
            thread::spawn(move || {
                for i in 0..each {
                    tx.send(p * 1000000 + i + 1).unwrap();
                }
            })
        })
        .collect();
    drop(tx);
    let receivers: Vec<_> = (0..consumers)
        .map(|_| {
            let rx = rx.clone();
            thread::spawn(move || rx.iter().sum::<u64>())
        })
        .collect();
    for s in senders {
        s.join().unwrap();
    }
    receivers.into_iter().map(|r| r.join().unwrap()).sum()
}

fn ping(rounds: u64) -> u64 {
    let (tx, rx) = bounded::<u64>(1);
    let (btx, brx) = bounded::<u64>(1);
    let echo = thread::spawn(move || {
        for v in rx.iter() {
            btx.send(v + 1).unwrap();
        }
    });
    let mut v = 0;
    for _ in 0..rounds {
        tx.send(v).unwrap();
        v = brx.recv().unwrap();
    }
    drop(tx);
    echo.join().unwrap();
    v
}

fn main() {
    let only = std::env::var("CHAN_CASE").ok().and_then(|e| e.bytes().next()).map(|b| b - b'0').unwrap_or(0);
    if only == 0 || only == 1 {
        println!("1:1 {}", spread(1, 1, 400000));
    }
    if only == 0 || only == 2 {
        println!("N:1 {}", spread(4, 1, 100000));
    }
    if only == 0 || only == 3 {
        println!("N:M {}", spread(4, 4, 100000));
    }
    if only == 0 || only == 4 {
        println!("ping {}", ping(100000));
    }
}
