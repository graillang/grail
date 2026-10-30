fn shorten<'long: 'short, 'short>(value: &'short Vec<&'long str>) -> &'short Vec<&'short str> {
    value
}
fn main() {
    let words = vec!["alpha", "beta"];
    assert_eq!(shorten(&words)[0], "alpha");
}
