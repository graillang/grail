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
fn main() {
    let document = Document::new("owner".to_owned(), |source| Cell::new(source.as_str()));
    let temporary = "temporary".to_owned();
    document.with_dependent(|_owner, dependent| dependent.set(temporary.as_str()));
}
