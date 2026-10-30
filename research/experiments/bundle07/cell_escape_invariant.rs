use self_cell::self_cell;
use std::cell::Cell;
type Slots<'a> = Cell<&'a str>;
self_cell!(
    struct Document {
        owner: String,
        #[not_covariant]
        dependent: Slots,
    }
);
fn project<'a>(document: &'a Document) -> &'a Cell<&'a str> {
    document.with_dependent(|_owner, dependent| dependent)
}
fn main() {}
