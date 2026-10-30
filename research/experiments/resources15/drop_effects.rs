use std::sync::atomic::{AtomicUsize, Ordering};
static DROPS: AtomicUsize = AtomicUsize::new(0);
struct Cursor<'a> {
    target: &'a mut i32,
}
impl Drop for Cursor<'_> {
    fn drop(&mut self) {
        *self.target += 10;
        DROPS.fetch_add(1, Ordering::SeqCst);
    }
}
fn erase<T>(value: T) {
    std::mem::forget(value);
}
fn discard<T>(value: T) {
    drop(value);
}
fn main() {
    let mut value = 0;
    let cursor = Cursor { target: &mut value };
    *cursor.target = 1;
    erase(cursor);
    assert_eq!(DROPS.load(Ordering::SeqCst), 0);
    value = 2;
    discard(Cursor { target: &mut value });
    assert_eq!(value, 12);
    assert_eq!(DROPS.load(Ordering::SeqCst), 1);
}
