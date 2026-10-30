struct View<'a>(&'a mut u32);
fn duplicate<'a>(value: &'a View<'a>) -> &'a mut u32 {
    value.0
}
fn main() {}
