// The Rust twin of examples/pool-chunks-mut.grl. Rust has no pool in `std`, so the equivalent of
// `parallel_for_chunks` is `chunks_mut` plus one scoped thread per chunk: `chunks_mut(size)` is the
// same arithmetic split (4, 4, 2 then 5, 5), each thread gets an exclusive borrow of its own chunk,
// and `thread::scope` joins them all before the vector is read again.
fn triple(s: &mut [u64]) {
    for x in s.iter_mut() {
        *x *= 3;
    }
}

fn main() {
    let mut data: Vec<u64> = (1..=10).collect();

    std::thread::scope(|scope| {
        for chunk in data.chunks_mut(4) {
            scope.spawn(move || triple(chunk));
        }
    });

    std::thread::scope(|scope| {
        for chunk in data.chunks_mut(5) {
            scope.spawn(move || {
                for x in chunk.iter_mut() {
                    *x += 1;
                }
            });
        }
    });

    for x in &data {
        println!("{x}");
    }
}
