use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};
struct Shared { counter: AtomicU64, total: Mutex<u64> }
fn work(id: u64, shared: &Shared) -> u64 {
    for _ in 0..1000 {
        shared.counter.fetch_add(1, Ordering::SeqCst);
        *shared.total.lock().unwrap() += 1;
    }
    id * id
}
fn main() {
    let shared = Shared { counter: AtomicU64::new(0), total: Mutex::new(0) };
    let squares: Vec<u64> = std::thread::scope(|s| {
        let handles: Vec<_> = [1, 2, 3, 4]
            .into_iter()
            .map(|id| {
                let shared = &shared;
                s.spawn(move || work(id, shared))
            })
            .collect();
        handles.into_iter().map(|h| h.join().unwrap()).collect()
    });
    println!("{}", squares[3]);
    println!("{}", shared.counter.load(Ordering::SeqCst));
    println!("{}", *shared.total.lock().unwrap());
}
