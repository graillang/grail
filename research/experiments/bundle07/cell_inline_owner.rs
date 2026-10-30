use self_cell::self_cell;
struct Inline([u8; 5]);
type View<'a> = &'a str;
self_cell!(
    struct Document {
        owner: Inline,
        #[covariant]
        dependent: View,
    }
);
fn load() -> Document {
    Document::new(Inline(*b"hello"), |owner| {
        std::str::from_utf8(&owner.0).unwrap()
    })
}
fn main() {
    let document = load();
    let before = document.borrow_owner().0.as_ptr();
    let moved = Some(document).unwrap();
    assert_eq!(before, moved.borrow_owner().0.as_ptr());
    assert_eq!(moved.borrow_dependent().as_ptr(), before);
    assert_eq!(*moved.borrow_dependent(), "hello");
    let owner = moved.into_owner();
    assert_eq!(&owner.0, b"hello");
}
