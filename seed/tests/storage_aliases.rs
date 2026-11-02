//! An opaque pointer selection cannot strongly overwrite every feasible storage target.
use grail_seed::source;
use std::collections::BTreeMap;
const SELECT: &str = "module f;struct Cell<a>{source:read<a>}fn select<outer,data>(left:ref_mut<outer,Cell<data>>,right:ref_mut<outer,Cell<data>>,n:num)->ref_mut<outer,Cell<data>>{if n{return left;}else{return right;}}";
#[test]
fn exchange_keeps_unselected_cells_possible_old_sources() {
    let body = "pub fn bad(n:num)->num{var a =bytes();push(a,1);var b =bytes();push(b,2);var c =bytes();push(c,3);var left =Cell{source:read(a)};var right =Cell{source:read(b)};var chosen =select(borrow_mut(left),borrow_mut(right),n);exchange(borrow_mut(chosen.source),read(c));for i in 256{push(a,9);}return at(read(left.source),0)+at(read(right.source),0);}";
    assert!(source::compile(&format!("{SELECT}{body}"), BTreeMap::new()).is_err());
}
#[test]
fn all_unselected_and_incoming_owners_remain_protected() {
    let body = "pub fn bad(n:num)->num{var a =bytes();push(a,1);var b =bytes();push(b,2);var c =bytes();push(c,3);var left =Cell{source:read(a)};var right =Cell{source:read(b)};var chosen =select(borrow_mut(left),borrow_mut(right),n);exchange(borrow_mut(chosen.source),read(c));push(a,9);return at(read(left.source),0)+at(read(right.source),0);}";
    for owner in ["a", "b", "c"] {
        assert!(
            source::compile(
                &format!(
                    "{SELECT}{}",
                    body.replace("push(a,9);", &format!("push({owner},9);"))
                ),
                BTreeMap::new()
            )
            .is_err()
        );
    }
    assert!(
        source::compile(
            &format!("{SELECT}{}", body.replace("push(a,9);", "")),
            BTreeMap::new()
        )
        .is_ok()
    );
}
#[test]
fn a_single_precise_target_can_release_its_previous_source() {
    source::compile("module f;struct Cell<a>{source:read<a>}pub fn run()->num{var a =bytes();push(a,1);var c =bytes();push(c,3);var cell =Cell{source:read(a)};exchange(borrow_mut(cell.source),read(c));push(a,9);return at(read(cell.source),0);}",BTreeMap::new()).unwrap();
}
#[test]
#[ignore = "requires clang sanitizers and an independent Rust compiler"]
fn safe_ambiguous_updates_execute_both_selections_and_bad_borrows_reject_in_rust() {
    use std::{fs, process::Command};
    let dir = std::env::temp_dir().join(format!(
        "grail-storage-aliases-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let body = "pub fn good(n:num)->num{var a =bytes();push(a,1);var b =bytes();push(b,2);var c =bytes();push(c,3);var left =Cell{source:read(a)};var right =Cell{source:read(b)};var chosen =select(borrow_mut(left),borrow_mut(right),n);exchange(borrow_mut(chosen.source),read(c));return at(read(left.source),0)+at(read(right.source),0);}";
    let p = source::compile(&format!("{SELECT}{body}"), BTreeMap::new()).unwrap();
    fs::write(dir.join("f.c"), grail_seed::emit::module_c(&p).unwrap()).unwrap();
    fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_1_f_4_good(uint64_t);int main(void){return q_1_f_4_good(0)!=4||q_1_f_4_good(1)!=5;}\n").unwrap();
    let build = Command::new("clang")
        .args([
            "-O2",
            "-fsanitize=address,undefined",
            "-fno-omit-frame-pointer",
        ])
        .arg(dir.join("f.c"))
        .arg(dir.join("main.c"))
        .arg("-o")
        .arg(dir.join("run"))
        .output()
        .unwrap();
    assert!(
        build.status.success(),
        "{}",
        String::from_utf8_lossy(&build.stderr)
    );
    let run = Command::new(dir.join("run")).output().unwrap();
    assert!(
        run.status.success(),
        "{}",
        String::from_utf8_lossy(&run.stderr)
    );
    fs::write(
        dir.join("bad.rs"),
        include_str!("support/ambiguous_target.rs"),
    )
    .unwrap();
    let bad = Command::new("rustc")
        .args(["--edition=2024"])
        .arg(dir.join("bad.rs"))
        .arg("-o")
        .arg(dir.join("bad"))
        .output()
        .unwrap();
    assert!(
        !bad.status.success() && String::from_utf8_lossy(&bad.stderr).contains("error[E0502]"),
        "{}",
        String::from_utf8_lossy(&bad.stderr)
    );
    fs::remove_dir_all(dir).unwrap();
}
