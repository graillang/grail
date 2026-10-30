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
fn project(document: &Document) -> &str {
    document.with_dependent(|_owner, dependent| dependent.get())
}
fn main() {
    let document = Document::new("lifetime".to_owned(), |source| Cell::new(source.as_str()));
    assert_eq!(project(&document), "lifetime");
}
