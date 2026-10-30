struct Ast<'a>(Vec<&'a str>);
fn view<'a>(ast: &'a Ast<'a>) -> Ast<'a> {
    *ast
}
fn main() {}
