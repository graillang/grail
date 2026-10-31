//! Invariant storage bounds, opaque effects, and unique transfer are public safety contracts.
use grail_seed::source;
use std::collections::BTreeMap;
fn accepts(s: &str) {
    let p = source::compile(s, BTreeMap::new()).unwrap_or_else(|e| panic!("{e}\n{s}"));
    grail_seed::emit::module_c(&p).unwrap();
}
fn rejects(s: &str) {
    assert!(source::compile(s, BTreeMap::new()).is_err(), "{s}");
}
#[test]
fn mutable_cells_preserve_the_declared_capture_bound() {
    accepts(
        "module f;struct Cell<a>{source:read<a>}pub fn set<outer,data>(p:ref_mut<outer,Cell<data>>,v:read<data>)->unit{exchange(borrow_mut(p.source),v);return ();}",
    );
    rejects(
        "module f;struct Cell<a>{source:read<a>}pub fn bad<outer,data>(p:ref_mut<outer,Cell<data>>,v:read<outer>,anchor:read<data>)->unit{exchange(borrow_mut(p.source),v);return ();}",
    );
    rejects(
        "module f;struct Cell<a>{source:read<a>}pub fn bad<outer,short,long>(p:ref_mut<outer,Cell<long>>,v:read<short>)->unit{exchange(borrow_mut(p.source),v);return ();}",
    );
}
#[test]
fn opaque_mutation_keeps_incoming_and_old_possible_sources() {
    let s = "module f;struct Cell<a>{source:read<a>}fn set<outer,data>(p:ref_mut<outer,Cell<data>>,v:read<data>)->unit{exchange(borrow_mut(p.source),v);return ();}pub fn run()->num{let a=bytes();push(a,3);let b=bytes();push(b,7);let c=Cell{source:read(a)};set(borrow_mut(c),read(b));return at(read(c.source),0);}";
    accepts(s);
    rejects(&s.replace(
        "return at(read(c.source),0);",
        "push(b,9);return at(read(c.source),0);",
    ));
    rejects(&s.replace(
        "return at(read(c.source),0);",
        "push(a,9);return at(read(c.source),0);",
    ));
    rejects(&s.replace(
        "set(borrow_mut(c),read(b));",
        "{let short=bytes();push(short,9);set(borrow_mut(c),read(short));}",
    ));
}
#[test]
fn unique_capture_transfer_is_not_a_long_reborrow() {
    let s = "module f;struct Cell<a>{source:mut<a>}fn take<outer,data>(p:ref_mut<outer,Cell<data>>,v:mut<data>)->mut<data>{return exchange(borrow_mut(p.source),v);}pub fn run()->num{let a=bytes();push(a,3);let b=bytes();push(b,7);let c=Cell{source:mut(a)};let old=take(borrow_mut(c),mut(b));write(old,0,9);drop(old);return at(read(c.source),0);}";
    accepts(s);
    rejects(
        "module f;struct Cell<a>{source:mut<a>}pub fn bad<outer,data>(p:ref_mut<outer,Cell<data>>)->mut<data>{return mut(p.source);}",
    );
}
#[test]
fn generic_replacement_does_not_capture_the_temporary_slot_borrow() {
    accepts(
        "module f;fn replace<outer,type T>(p:ref_mut<outer,T>,v:T)->T{return exchange(p,v);}pub fn run()->num{let a=bytes();push(a,3);let b=bytes();push(b,7);let v=mut(a);let old=replace(borrow_mut(v),mut(b));write(old,0,9);drop(old);return at(read(v),0);}",
    );
}
#[test]
fn generic_argument_and_callee_lifetime_namespaces_do_not_alias() {
    accepts(
        "module f;fn keep<a,type T>(discard:T,value:read<a>)->read<a>{return value;}fn pass<a>(value:read<a>)->read<a>{let short=bytes();push(short,9);return keep(read(short),read(value));}pub fn run()->num{let b=bytes();push(b,7);return at(pass(read(b)),0);}",
    );
    accepts(
        "module f;fn second<type T,type U>(discard:T,value:U)->U{return value;}fn pass<a>(value:read<a>)->read<a>{let short=bytes();push(short,9);return second(read(short),read(value));}pub fn run()->num{let b=bytes();push(b,7);return at(pass(read(b)),0);}",
    );
}
#[test]
fn mutable_referent_invariance_includes_unused_type_lifetime_slots() {
    rejects(
        "module f;struct Phantom<a>{n:num}pub fn bad<outer,short,long>(p:ref_mut<outer,Phantom<short>>,anchor:read<long>)->ref_mut<outer,Phantom<long>>{return p;}",
    );
    rejects(
        "module f;struct Phantom<type T>{n:num}pub fn bad<outer,short,long>(p:ref_mut<outer,Phantom<read<short>>>,anchor:read<long>)->ref_mut<outer,Phantom<read<long>>>{return p;}",
    );
}
#[test]
fn loop_writes_cannot_leave_stale_external_capture_proofs() {
    let prefix = "module f;struct Cell<a>{source:read<a>}pub fn bad<outer,short,long>(p:ref_mut<outer,Cell<short>>,value:read<short>,anchor:ref<short,read<long>>,n:num)->read<long>{exchange(borrow_mut(p.source),load(anchor));";
    for body in [
        "for i in n{exchange(borrow_mut(p.source),read(value));}",
        "for i in n{exchange(borrow_mut(p.source),read(value));break;}",
        "for i in n{exchange(borrow_mut(p.source),read(value));continue;}",
        "while n{exchange(borrow_mut(p.source),read(value));break;}",
    ] {
        rejects(&format!("{prefix}{body}return read(p.source);}}"));
    }
}
#[test]
fn opaque_typed_result_targets_are_filtered_by_nested_lifetime_invariance() {
    accepts(
        "module f;struct Cell<a>{source:read<a>}struct Pair<a,b>{first:Cell<a>,second:Cell<b>}fn first<outer,a,b>(p:ref_mut<outer,Pair<a,b>>)->ref_mut<outer,Cell<a>>{return borrow_mut(p.first);}pub fn select<a,b>(a:read<a>,b:read<b>)->read<a>{let pair=Pair{first:Cell{source:read(a)},second:Cell{source:read(b)}};let p=first(borrow_mut(pair));return read(p.source);}",
    );
}
