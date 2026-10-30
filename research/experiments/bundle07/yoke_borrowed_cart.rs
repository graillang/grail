use yoke::Yoke;
fn wrap<'a>(source: &'a str) -> Yoke<&'static str, &'a str> {
    Yoke::attach_to_cart(source, |source| source)
}
fn main() {
    let source = "external".to_owned();
    let document = wrap(&source);
    assert_eq!(*document.get(), "external");
    assert_eq!(source.as_ptr(), document.get().as_ptr());
}
