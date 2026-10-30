fn selector(source: &str) -> impl Fn(usize) -> &str { move |n| &source[n..] }
fn main() {}
