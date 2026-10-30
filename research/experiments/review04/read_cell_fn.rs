use std::cell::Cell;
fn require_fn<F: Fn() -> i32>(f: &F) {
    assert_eq!(f(), 1);
}
fn main() {
    let state = Cell::new(0);
    let f = move || {
        state.set(state.get() + 1);
        state.get()
    };
    require_fn(&f);
}
