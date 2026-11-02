use grail_seed::{emit, source};
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn result_option_matching_and_postfix_unwrap_are_real_operations() {
    for s in [
        "module f;enum O<a>{None,Some(read<a>)}pub fn run()->num{var b =bytes();push(b,1);o :=O::Some(read(b));match o{None=>{},Some(_)=>{}}push(b,2);return len(b);}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R::Ok(3);return r!+R::Ok(4)!*2;}",
        "module f;enum O{Some(string),None}pub fn run()->num{o :=O::Some(\"owned\");s :=o!;return len(s);}",
        "module f;enum O{None,Some(num)}pub fn run()->num{o :=O::None;match o{None=>{return 0;},Some(n)=>{return n;}}}",
        "module f;struct T<a>{span:read<a>,name:string}enum R<a>{Ok(T<a>),Err(string)}pub fn run<a>(p:read<a>)->num{r :=R::Ok(T{span:p,name:\"n\"});match r{Ok(t)=>{s :=t.name;return len(t.span)+len(s);},Err(e)=>{return len(e);}}}",
        "module f;enum R<a>{Ok(read<a>),Err(string)}pub fn error<a>()->R<a>{return R::Err(\"bad\");}",
        "module f;enum R{Ok(unit),Err(string)}pub fn run()->unit{return R::Ok(())!;}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R::Err(\"bad\");var n=0;match r{Ok(x)=>{n=x;},Err(_)=>{n=7;}}return n;}",
    ] {
        let p = source::compile(s, BTreeMap::new()).unwrap_or_else(|e| panic!("{s}\n{e}"));
        emit::module_c(&p).unwrap();
        let header = p.header();
        let wire = header.encode().unwrap();
        assert_eq!(
            *header,
            grail_seed::module::Interface::decode(&wire).unwrap()
        );
    }
}
#[test]
fn payload_modes_moves_and_exhaustiveness_cannot_be_erased() {
    for s in [
        "module f;enum R<a>{Ok(read<a>),Err(read<a>)}pub fn bad<a>(p:read<a>)->R<a>{b :=bytes();return R::Err(read(b));}",
        "module f;enum R<a>{Ok(read<a>),Err(string)}pub fn bad<a>(r:R<a>)->read<a>{match r{Ok(s)=>{return s;},Err(e)=>{return read(e);}}}",
        "module f;enum R{Ok(num),Err(string)}pub fn bad()->num{r :=R::Ok(1);match r{Ok(n)=>{},Err(e)=>{}}return r!;}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R::Ok(3);n :=r!;return r!;}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R::Ok(3);match r{Ok(n)=>{return n;}}}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R::Ok(3);match r{Ok(n)=>{return n;},Ok(m)=>{return m;},Err(e)=>{return len(e);}}}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R::Ok(\"wrong\");return r!;}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R{Ok:3,Err:\"bad\"};return r!;}",
        "module f;enum R{Ok(num),Err(string)}pub fn run()->num{r :=R::Ok(3);return r.Ok;}",
        "module f;enum R{A(num),B(string)}pub fn run()->num{r :=R::A(3);return r!;}",
        "module f;enum R<a>{Ok(read<a>),Err(string)}pub fn bad<a>(p:read<a>)->R<a>{b :=bytes();return R::Ok(read(b));}",
        "module f;enum R<a>{Ok(mut<a>),Err(string)}pub fn bad<a>(p:read<a>)->R<a>{return R::Ok(p);}",
        "module f;enum R{Ok(string),Err(string)}pub fn bad()->num{r :=R::Ok(\"x\");match r{Ok(s)=>{n :=len(s);},Err(e)=>{n :=len(e);}}return len(s);}",
    ] {
        assert!(!ok(s), "{s}");
    }
}
