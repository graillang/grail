use std::cell::Cell;
fn assert_sync<T: Sync>(_: &T) {}
fn main() {
    let state = Cell::new(0);
    let f = move || {
        state.set(state.get() + 1);
        state.get()
    };
    assert_sync(&f);
}
