use std::cell::Cell;
fn shorten<'long: 'short, 'short>(value: &'short Cell<&'long str>) -> &'short Cell<&'short str> {
    value
}
fn main() {}
