use grail_seed::{emit, source};
use std::collections::BTreeMap;
#[test]
fn question_mark_is_checked_match_with_cleanup_on_failure() {
    for s in [
        "module f;enum R{Ok(num),Err(string)}pub fn run(r:R)->R{let b=bytes();push(b,1);let n=r?;return R::Ok(n+len(b));}",
        "module f;enum A{Ok(num),Err(string)}enum B{Err(string),Ok(string)}pub fn run(a:A)->B{let n=a?;return B::Ok(\"name\");}",
        "module f;enum A{None,Some(num)}enum B{Some(string),None}pub fn run(a:A)->B{let n=a?;return B::Some(\"name\");}",
        "module f;enum A<a>{Ok(num),Err(read<a>)}enum B<a>{Err(read<a>),Ok(string)}pub fn run<a>(a:A<a>)->B<a>{let n=a?;return B::Ok(\"name\");}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->R{let b=bytes();push(b,1);while condition()?{push(b,2);}return R::Ok(len(b));}fn condition()->R{return R::Ok(0);}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->R{let b=bytes();push(b,1);for i in condition()?{push(b,2);}return R::Ok(len(b));}fn condition()->R{return R::Ok(0);}",
        "module f;enum Inner{Ok(num),Err(string)}enum Outer{Ok(Inner),Err(string)}pub fn run(o:Outer)->Inner{return Inner::Ok(o??);}",
    ] {
        let p = source::compile(s, BTreeMap::new()).unwrap_or_else(|e| panic!("{s}\n{e}"));
        emit::module_c(&p);
    }
}
#[test]
fn propagation_cannot_convert_error_types_or_launder_error_lifetimes() {
    for s in [
        "module f;enum R{Ok(num),Err(string)}pub fn run(r:R)->num{return r?;}",
        "module f;enum A{Ok(num),Err(string)}enum B{Ok(num),Err(num)}pub fn run(a:A)->B{let n=a?;return B::Ok(n);}",
        "module f;enum A{Ok(num),Err(string)}enum B{Some(num),None}pub fn run(a:A)->B{let n=a?;return B::Some(n);}",
        "module f;enum R{Ok(num),Err(string)}pub fn run(r:R)->R{let n=r?;let bad=r!;return R::Ok(n);}",
        "module f;enum A<a>{Ok(num),Err(read<a>)}enum B<a>{Ok(num),Err(read<a>)}pub fn bad<a,b>(r:A<a>,p:read<b>)->B<b>{let n=r?;return B::Ok(n);}",
    ] {
        assert!(source::compile(s, BTreeMap::new()).is_err(), "{s}");
    }
}
