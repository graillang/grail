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
    let document = Document::new("lifetime".to_owned(), |source| Cell::new(source.as_str()));
    let length = document.with_dependent(|owner, dependent| {
        dependent.set(&owner[..3]);
        dependent.get().len()
    });
    assert_eq!(length, 3);
    assert_eq!(document.borrow_owner(), "lifetime");
}
