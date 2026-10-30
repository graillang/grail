use self_cell::self_cell;
struct Ast<'a>(Vec<&'a str>);
self_cell!(
    struct Document {
        owner: String,
        #[covariant]
        dependent: Ast,
    }
);
fn load() -> Document {
    Document::new("alpha beta".to_owned(), |source| {
        Ast(source.split_whitespace().collect())
    })
}
fn first(document: &Document) -> &str {
    document.borrow_dependent().0[0]
}
fn main() {
    let document = load();
    let before = document.borrow_owner().as_ptr();
    let moved = Some(document).unwrap();
    assert_eq!(before, moved.borrow_owner().as_ptr());
    assert_eq!(first(&moved).as_ptr(), moved.borrow_owner().as_ptr());
    assert_eq!(first(&moved), "alpha");
    assert_eq!(moved.borrow_dependent().0.len(), 2);
}
