fn discard<T>(value: T) {
    drop(value);
}
fn main() {
    let mut value = 0;
    std::thread::scope(|scope| {
        let (ready_tx, ready_rx) = std::sync::mpsc::sync_channel(0);
        let (release_tx, release_rx) = std::sync::mpsc::sync_channel(0);
        let target = &mut value;
        let handle = scope.spawn(move || {
            ready_tx.send(()).unwrap();
            release_rx.recv().unwrap();
            *target = 7;
            eprintln!("child_done");
        });
        ready_rx.recv().unwrap();
        discard(handle);
        // The child cannot finish its write until this explicit release.
        release_tx.send(()).unwrap();
        eprintln!("scope_body_done");
    });
    eprintln!("scope_returned");
    assert_eq!(value, 7);
}
