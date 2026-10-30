use self_cell::self_cell;
use std::sync::atomic::{AtomicUsize, Ordering};
static PHASE: AtomicUsize = AtomicUsize::new(0);
struct Owner {
    value: u32,
}
struct Dependent<'a>(&'a Owner);
impl Drop for Dependent<'_> {
    fn drop(&mut self) {
        assert_eq!(PHASE.load(Ordering::SeqCst), 0);
        assert_eq!(self.0.value, 7);
        PHASE.store(1, Ordering::SeqCst);
    }
}
impl Drop for Owner {
    fn drop(&mut self) {
        assert_eq!(PHASE.load(Ordering::SeqCst), 1);
        PHASE.store(2, Ordering::SeqCst);
    }
}
self_cell!(
    struct Document {
        owner: Owner,
        #[covariant]
        dependent: Dependent,
    }
);
fn main() {
    let document = Document::new(Owner { value: 7 }, |owner| Dependent(owner));
    drop(document);
    assert_eq!(PHASE.load(Ordering::SeqCst), 2);
}
