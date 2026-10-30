use yoke::Yoke;
fn load() -> Yoke<&'static str, Box<str>> {
    Yoke::attach_to_cart("owner".to_owned().into_boxed_str(), |source| source)
}
fn main() {
    let document = load();
    let before = document.get().as_ptr();
    let moved = Some(document).unwrap();
    assert_eq!(before, moved.get().as_ptr());
    assert_eq!(*moved.get(), "owner");
}
