// The Rust twin of examples/pool-job-handle.grl: `std::thread::spawn` is `parallel_spawn` and
// `JoinHandle::join` is `parallel_join`. A job handle is a `JoinHandle` - move-only, owned by the
// thread that waits on it - so two live handles joined out of order is the same program in both
// languages.
fn main() {
    let job = std::thread::spawn(|| {
        let mut total: u64 = 0;
        for i in 0..1000 {
            total += i;
        }
        total
    });

    let mut squares: Vec<u64> = Vec::new();
    for i in 0..4 {
        squares.push(i * i);
    }

    println!("{}", job.join().unwrap());
    println!("{}", squares.len());

    let a = std::thread::spawn(|| {
        let mut p: u64 = 1;
        for _ in 0..7 {
            p *= 6;
        }
        p
    });
    let b = std::thread::spawn(|| {
        let mut p: u64 = 1;
        for _ in 0..5 {
            p *= 4;
        }
        p
    });
    println!("{}", b.join().unwrap());
    println!("{}", a.join().unwrap());
}
