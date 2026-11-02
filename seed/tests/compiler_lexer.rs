//! Real compiler module: no seed lexer internals are used as the oracle.
use grail_seed::{emit, source};
use std::collections::BTreeMap;
const LEXER: &str = include_str!("../../compiler/lexer.grl");
fn lexer() -> grail_seed::module::CheckedModule {
    source::compile(LEXER, BTreeMap::new()).expect("Grail lexer checks")
}
#[test]
fn lexer_checks_and_exports_borrowed_tokens() {
    let module = lexer();
    emit::module_c(&module).unwrap();
    let api = grail_seed::module::Interface::decode(&module.interface()).unwrap();
    let good = "use lexer;fn f()->num{s :=\"abc\";tokens :=lexer::tokenize(read(s));t :=vec_get(tokens,0);return len(t.span)+t.start+t.end+t.kind;}";
    source::compile(good, BTreeMap::from([("lexer".into(), api.clone())])).unwrap();
    for action in ["drop(s);", "moved:=s;", "append_text(s,\"x\");"] {
        let bad = format!(
            "use lexer;fn f()->num{{s :=\"abc\";tokens :=lexer::tokenize(read(s));{action}t :=vec_get(tokens,0);return len(t.span);}}"
        );
        assert!(
            source::compile(&bad, BTreeMap::from([("lexer".into(), api.clone())])).is_err(),
            "{bad}"
        );
    }
    let bad =
        "use lexer;fn bad<a>()->vec<lexer::Token<a>>{s :=\"abc\";return lexer::tokenize(read(s));}";
    assert!(source::compile(bad, BTreeMap::from([("lexer".into(), api)])).is_err());
}
