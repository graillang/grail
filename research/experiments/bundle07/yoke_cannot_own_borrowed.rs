use yoke::Yoke;
fn wrong<'a>(source: &'a str) -> Yoke<&'static str, &'static str> {
    Yoke::attach_to_cart(source, |source| source)
}
fn main() {}
