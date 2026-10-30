use self_cell::self_cell;
type View<'a> = &'a str;
self_cell!(
    struct Document {
        owner: String,
        #[covariant]
        dependent: View,
    }
);
fn main() {
    let temporary = "outside".to_owned();
    let _document = Document::new("owner".to_owned(), |_owner| temporary.as_str());
}
