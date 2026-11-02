//! A source module's bodies are checked independently against collected signatures.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn forward_mutual_and_self_calls_have_declared_interfaces() {
    assert!(ok(
        "fn entry()->num {return even(8);}fn even(n:num)->num {var out=1;if 0<n {out=odd(n-1);}return out;}fn odd(n:num)->num {var out=0;if 0<n {out=even(n-1);}return out;}"
    ));
    assert!(ok(
        "fn fib(n:num)->num {var out=n;if 1<n {out=fib(n-1)+fib(n-2);}return out;}"
    ));
    assert!(ok(
        "fn entry<a>(p:read<a>)->read<a>{return tail(p);}fn tail<b>(p:read<b>)->read<b>{return slice(p,0,0);}"
    ));
    assert!(ok(
        "fn entry()->num{s :=echo(make());return len(s);}fn make()->string{return \"hé🙂\";}fn echo(s:string)->string{return s;}"
    ));
}
#[test]
fn private_helpers_are_not_trusted_or_shared_variable_scopes() {
    for s in [
        "fn entry()->num{return 0;}fn bad()->num{b :=bytes();drop(b);return len(b);}",
        "fn entry()->num{x :=1;return helper();}fn helper()->num{return x;}",
        "fn entry()->num{return helper(0);}fn helper(x:string)->num{return len(x);}",
        "fn entry()->num{return absent();}",
        "fn entry()->num{return 0;}fn entry()->num{return 1;}",
        "fn entry<a>(p:read<a>)->read<a>{return bad(p);}fn bad<b>(p:read<b>)->read<b>{b :=bytes();return read(b);}",
        "fn entry<a>(p:read<a>)->read<a>{b :=bytes();return entry(read(b));}",
        "fn entry<a>(p:read<a>)->num{return 0;}fn helper(p:read<a>)->num{return 0;}",
    ] {
        assert!(!ok(s), "{s}");
    }
}

#[test]
fn private_heap_code_cannot_bypass_backend_layout_checks() {
    let p = source::compile(
        "fn entry()->num{return hidden();}fn hidden()->num{s :=\"x\";return len(s);}",
        BTreeMap::new(),
    )
    .unwrap();
    assert!(grail_seed::emit::module_llvm(&p).is_err());
}
