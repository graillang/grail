//! Control-flow joins must preserve every feasible source without inventing unique authority.
use grail_seed::source;
use std::collections::BTreeMap;
fn accepts(s: &str) {
    source::compile(s, BTreeMap::new()).unwrap_or_else(|e| panic!("{e}\n{s}"));
}
fn rejects(s: &str) {
    assert!(source::compile(s, BTreeMap::new()).is_err(), "{s}");
}
#[test]
fn branch_updates_join_retained_local_slots_and_release_replaced_sources() {
    let s = "module f;struct Cell<a>{source:read<a>,name:string}pub fn run(n:num)->num{var a =bytes();push(a,1);var b =bytes();push(b,2);var c =bytes();push(c,3);var cell =Cell{source:read(a),name:\"cell\"};if n{exchange(borrow_mut(cell.source),read(b));}else{exchange(borrow_mut(cell.source),read(c));}push(a,9);return at(read(cell.source),0);}";
    accepts(s);
    for owner in ["b", "c"] {
        rejects(&s.replace("push(a,9);", &format!("push({owner},9);")));
    }
}
#[test]
fn branch_updates_join_external_slots_without_losing_incoming_sources() {
    accepts(
        "module f;struct Cell<a>{source:read<a>}pub fn choose<outer,data>(p:ref_mut<outer,Cell<data>>,a:read<data>,b:read<data>,n:num)->read<data>{if n{exchange(borrow_mut(p.source),read(a));}else{exchange(borrow_mut(p.source),read(b));}return read(p.source);}",
    );
}
#[test]
fn branch_writes_do_not_forge_a_longer_current_content_proof() {
    rejects(
        "module f;struct Cell<a>{source:read<a>}pub fn bad<outer,short,long>(p:ref_mut<outer,Cell<short>>,value:read<short>,anchor:ref<short,read<long>>,n:num)->read<long>{if n{exchange(borrow_mut(p.source),load(anchor));}else{exchange(borrow_mut(p.source),read(value));}return read(p.source);}",
    );
}
#[test]
fn loop_updates_widen_retained_sources_across_backedges_and_exits() {
    for body in [
        "for i in n{exchange(borrow_mut(p.source),read(value));}",
        "for i in n{exchange(borrow_mut(p.source),read(value));continue;}",
        "for i in n{exchange(borrow_mut(p.source),read(value));break;}",
        "while n{exchange(borrow_mut(p.source),read(value));break;}",
    ] {
        accepts(&format!(
            "module f;struct Cell<a>{{source:read<a>}}pub fn fill<outer,data>(p:ref_mut<outer,Cell<data>>,value:read<data>,n:num)->read<data>{{{body}return read(p.source);}}"
        ));
    }
    let s = "module f;struct Cell<a>{source:read<a>}pub fn run(n:num)->num{var a =bytes();push(a,1);var b =bytes();push(b,2);var cell =Cell{source:read(a)};for i in n{exchange(borrow_mut(cell.source),read(b));}return at(read(cell.source),0);}";
    accepts(s);
    for owner in ["a", "b"] {
        rejects(&s.replace(
            "return at(read(cell.source),0);",
            &format!("push({owner},9);return at(read(cell.source),0);"),
        ));
    }
}
#[test]
fn later_iterations_recheck_owner_access_under_widened_loans() {
    rejects(
        "module f;struct Cell<a>{source:read<a>}pub fn bad(n:num)->num{var a =bytes();push(a,1);var b =bytes();var cell =Cell{source:read(a)};for i in n{push(b,2);exchange(borrow_mut(cell.source),read(b));}return len(read(cell.source));}",
    );
}
#[test]
fn while_condition_effects_apply_even_on_the_zero_body_path() {
    accepts(
        "module f;struct Cell<a>{source:read<a>}pub fn run()->num{var a =bytes();push(a,1);var b =bytes();push(b,2);var cell =Cell{source:read(a)};while len(exchange(borrow_mut(cell.source),read(b))){break;}push(a,9);return at(read(cell.source),0);}",
    );
}
#[test]
fn loop_ancestry_keeps_live_parents_but_not_destroyed_local_carrier_ids() {
    let s = "module f;struct Cell<a>{source:read<a>}struct Holder<a>{source:mut<a>}pub fn fill<outer,data>(slot:ref_mut<outer,Cell<data>>,parent:mut<data>,other:read<data>,n:num)->read<data>{for i in n{exchange(borrow_mut(slot.source),read(other));holder :=Holder{source:mut(parent)};span :=read(holder.source);drop(holder);exchange(borrow_mut(slot.source),span);}return read(slot.source);}";
    accepts(s);
    rejects(&s.replace("exchange(borrow_mut(slot.source),read(other));", ""));
}
#[test]
fn mixed_break_continue_paths_keep_all_feasible_exit_sources() {
    let s = "module f;struct Cell<a>{source:read<a>}pub fn run(n:num)->num{var a =bytes();push(a,1);var b =bytes();push(b,2);var c =bytes();push(c,3);var cell =Cell{source:read(a)};for i in n{if i{exchange(borrow_mut(cell.source),read(b));break;}else{exchange(borrow_mut(cell.source),read(c));continue;}}return at(read(cell.source),0);}";
    accepts(s);
    for owner in ["a", "b", "c"] {
        rejects(&s.replace(
            "return at(read(cell.source),0);",
            &format!("push({owner},9);return at(read(cell.source),0);"),
        ));
    }
}
#[test]
fn repeated_option_pop_and_carrier_drop_do_not_reuse_dead_parent_authority() {
    accepts(
        "module f;enum Option<a>{None,Some(mut<a>)}struct Cell<a>{source:read<a>}struct Holder<a>{source:mut<a>}fn pop<outer,data>(p:ref_mut<outer,Option<data>>)->Option<data>{return exchange(p,Option<data>::None);}pub fn fill<outer,data>(input:ref_mut<outer,Option<data>>,slot:ref_mut<outer,Cell<data>>,n:num)->read<data>{for i in n{old :=pop(borrow_mut(input));match old{None=>{break;},Some(value)=>{holder :=Holder{source:value};span :=read(holder.source);drop(holder);exchange(borrow_mut(slot.source),span);}}}return read(slot.source);}",
    );
}
