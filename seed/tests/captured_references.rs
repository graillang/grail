use grail_seed::source;
use std::collections::BTreeMap;
#[test]
fn shared_source_descriptors_escape_the_cursor_frame_without_escaping_the_data_owner() {
    let text = "module f;struct Cursor<a>{source:read<a>,name:string}fn source<outer,data>(p:ref<outer,Cursor<data>>)->read<data>{return read(p.source);}pub fn run()->num{let b=bytes();push(b,7);let c=Cursor{source:read(b),name:\"owned\"};let span=source(borrow(c));drop(c);return at(span,0);}";
    assert!(source::compile(text, BTreeMap::new()).is_ok());
    let text = text.replace("drop(c);return", "drop(c);push(b,8);return");
    assert!(source::compile(&text, BTreeMap::new()).is_err());
}
#[test]
fn unique_field_reborrows_need_the_outer_frame_even_when_the_stored_source_is_longer() {
    let good = "module f;struct Cursor<a>{source:mut<a>}pub fn source<outer,data>(p:ref<outer,Cursor<data>>)->read<outer>{return read(p.source);}";
    assert!(source::compile(good, BTreeMap::new()).is_ok());
    let bad = good.replace("->read<outer>", "->read<data>");
    assert!(source::compile(&bad, BTreeMap::new()).is_err());
    let bad = good
        .replace(
            "p:ref<outer,Cursor<data>>",
            "p:ref<outer,Cursor<data>>,anchor:read<data>",
        )
        .replace("->read<outer>", "->read<data>");
    let e = source::compile(&bad, BTreeMap::new())
        .err()
        .expect("extra signature anchor must not excuse wrong body");
    assert!(
        e.contains("outer frame")
            || e.contains("region relationship")
            || e.contains("stored lifetime witness"),
        "{e}"
    );
}
#[test]
fn returning_a_shared_cursor_cannot_widen_its_stored_capture_contract() {
    let bad = "module f;struct Cursor<a>{source:read<a>}pub fn widen<outer,short,long>(p:ref<outer,Cursor<short>>,anchor:read<long>)->ref<outer,Cursor<long>>{return p;}";
    let e = source::compile(bad, BTreeMap::new())
        .err()
        .expect("nested capture bounds must check");
    assert!(
        e.contains("region relationship") || e.contains("stored lifetime witness"),
        "{e}"
    );
}
#[test]
fn a_live_cursor_frame_prevents_early_capture_expiry() {
    let bad = "module f;struct Cursor<a>{source:read<a>}fn source<outer,data>(p:ref<outer,Cursor<data>>)->read<data>{return read(p.source);}pub fn run()->num{let b=bytes();push(b,7);let c=Cursor{source:read(b)};let p=borrow(c);push(b,8);let value=source(p);return at(value,0);}";
    assert!(source::compile(bad, BTreeMap::new()).is_err());
}
#[test]
fn opaque_borrows_accept_captured_referents_without_specialization_requirements() {
    let good = "module f;fn inspect<type T>(v:T)->num{let p=borrow(v);return 7;}pub fn run<a>(input:read<a>)->num{return inspect(read(input));}";
    let p = source::compile(good, BTreeMap::new()).unwrap();
    assert!(grail_seed::emit::module_c(&p).is_ok());
    let mutable = "module f;struct Cursor<a>{source:read<a>}pub fn inspect<outer,data>(p:ref_mut<outer,Cursor<data>>)->num{return 0;}";
    assert!(source::compile(mutable, BTreeMap::new()).is_ok());
}

#[test]
fn explicit_shared_descriptor_loads_keep_nested_targets_and_reject_unique_copies() {
    for text in [
        "module f;pub fn copy<outer,data>(p:ref<outer,read<data>>)->read<data>{return load(p);}",
        "module f;pub fn copy<outer,data>(p:ref<outer,ref<data,num>>)->ref<data,num>{return load(p);}",
    ] {
        let p = source::compile(text, BTreeMap::new()).unwrap();
        assert!(grail_seed::emit::module_c(&p).is_ok());
        assert!(grail_seed::emit::module_llvm(&p).is_ok());
    }
    for text in [
        "module f;pub fn bad<outer,data>(p:ref<outer,mut<data>>)->mut<data>{return load(p);}",
        "module f;pub fn bad<outer,data>(p:ref<outer,ref_mut<data,num>>)->ref_mut<data,num>{return load(p);}",
    ] {
        assert!(source::compile(text, BTreeMap::new()).is_err());
    }
    let p = source::compile(
        "module f;pub fn copy<outer,data>(p:ref<outer,read<data>>)->read<data>{return read(p);}",
        BTreeMap::new(),
    )
    .unwrap();
    assert!(
        grail_seed::emit::module_llvm(&p)
            .unwrap()
            .contains("load { ptr, i64 }, ptr")
    );
}
#[test]
fn typed_field_byte_borrows_require_actual_byte_storage() {
    let text =
        "module f;struct H<a>{p:ref<a,num>}pub fn bad<a>(h:H<a>)->num{return len(read(h.p));}";
    assert!(source::compile(text, BTreeMap::new()).is_err());
}

#[test]
fn unused_slots_and_output_shapes_do_not_supply_unproved_input_bounds() {
    for text in [
        "module f;struct Phantom<a>{value:num}pub fn wrong<short,long>(p:ref<long,Phantom<short>>,value:read<short>,anchor:read<long>)->read<long>{return value;}",
        "module f;struct Cursor<a>{source:read<a>}enum Answer<a,b>{Pointer(ref<a,Cursor<b>>),Span(read<a>)}pub fn wrong<a,b>(value:read<b>,anchor:read<a>)->Answer<a,b>{return Answer<a,b>::Span(value);}",
    ] {
        let e = source::compile(text, BTreeMap::new())
            .err()
            .expect("unproved outlives relationship must reject");
        assert!(
            e.contains("region relationship") || e.contains("stored lifetime witness"),
            "{e}"
        );
    }
}
#[test]
fn recursive_reference_expansion_is_bounded_before_pointee_materialization() {
    let text = "module f;pub struct Node<a>{next:ref<a,Node<a>>}pub fn inspect<a>(p:ref<a,Node<a>>)->num{return 0;}";
    let e = source::compile(text, BTreeMap::new())
        .err()
        .expect("regular recursive graph support is not yet implemented");
    assert!(e.contains("provenance expansion limit"), "{e}");
}
