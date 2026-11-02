use grail_seed::{emit, source};
use std::collections::BTreeMap;
fn compile(s: &str) -> Result<grail_seed::module::CheckedModule, String> {
    source::compile(s, BTreeMap::new())
}
#[test]
fn collection_values_and_generic_bodies_are_checked() {
    for s in [
        "fn f()->num{var v =vec<num>();vec_push(v,7);p :=vec_get(v,0);n :=load(p);vec_push(v,9);return n+vec_pop(v);}",
        "fn f()->num{var v =vec<string>();vec_push(v,\"hello\");s :=vec_pop(v);return len(s);}",
        "fn f()->num{var v =vec<vec<string>>();var child =vec<string>();vec_push(child,\"hello\");vec_push(v,child);p :=vec_get(v,0);return len(p);}",
        "module f;struct R{a:string,b:num}pub fn f()->num{var v =vec<R>();vec_push(v,R{a:\"hi\",b:9});p :=vec_get(v,0);n :=p.b;return n;}",
        "module f;pub fn add<a,type T>(v:ref_mut<a,vec<T>>,x:T)->unit{vec_push(v,x);return ();}",
        "module f;pub fn pop<a,type T>(v:ref_mut<a,vec<T>>)->T{return vec_pop(v);}",
        "fn f()->num{var v =vec<num>();vec_push(v,7);p :=vec_get_mut(v,0);exchange(p,8);return vec_pop(v);}",
    ] {
        let p = compile(s).unwrap_or_else(|e| panic!("{s}: {e}"));
        emit::module_c(&p).unwrap();
    }
}
#[test]
fn element_loans_prevent_relocation_and_wrong_mutation() {
    for s in [
        "fn f()->num{var v =vec<num>();vec_push(v,7);p :=vec_get(v,0);vec_push(v,8);return load(p);}",
        "fn f()->num{var v =vec<num>();vec_push(v,7);p :=vec_get(v,0);drop(v);return load(p);}",
        "fn f()->num{var v =vec<num>();vec_push(v,7);p :=vec_get_mut(v,0);q :=vec_get(v,0);exchange(p,8);return load(q);}",
        "fn f()->num{var v =vec<string>();vec_push(v,7);return 0;}",
        "fn f()->num{var v =vec<string>();s :=\"hi\";vec_push(v,s);vec_push(v,s);return 0;}",
        "fn f<a>(p:ref<a,vec<num>>)->num{vec_push(p,8);return len(p);}",
    ] {
        assert!(compile(s).is_err(), "{s}");
    }
}
#[test]
fn stored_capture_sources_survive_collection_transfer_and_pop() {
    let provider=compile("module maker;pub fn make<a>(s:read<a>)->vec<read<a>>{var v =vec<read<a>>();vec_push(v,s);return v;}").unwrap();
    for action in ["push(b,8);", "drop(b);", "moved:=b;"] {
        let text = format!(
            "use maker;fn f()->num{{var b =bytes();push(b,7);var v =maker::make(read(b));{action}s :=vec_pop(v);return at(s,0);}}"
        );
        assert!(
            source::compile(
                &text,
                BTreeMap::from([("maker".into(), provider.header().clone())])
            )
            .is_err(),
            "{text}"
        );
    }
    let text = "use maker;fn f()->num{var b =bytes();push(b,7);var v =maker::make(read(b));s :=vec_pop(v);return at(s,0);}";
    source::compile(
        text,
        BTreeMap::from([("maker".into(), provider.header().clone())]),
    )
    .unwrap();
    assert!(compile("fn bad<a>()->vec<read<a>>{b :=bytes();var v =vec<read<a>>();vec_push(v,read(b));return v;}").is_err());
}
#[test]
#[ignore = "requires Linux clang, allocator wrapping, ASan/UBSan"]
fn hidden_generic_collections_grow_transfer_borrow_and_drop_recursively() {
    use std::{fs, process::Command};
    let dir = std::env::temp_dir().join(format!("grail-vectors-{}", std::process::id()));
    fs::create_dir_all(&dir).unwrap();
    let compile_module = |name: &str, text: &str| {
        let file = dir.join(format!("{name}.grl"));
        fs::write(&file, text).unwrap();
        let p = Command::new(env!("CARGO_BIN_EXE_grail-seed"))
            .arg("compile")
            .arg(&file)
            .arg(&dir)
            .arg(&dir)
            .output()
            .unwrap();
        assert!(
            p.status.success(),
            "{name}: {}",
            String::from_utf8_lossy(&p.stderr)
        );
        fs::remove_file(file).unwrap();
    };
    compile_module("core", include_str!("../std/core.grl"));
    compile_module("collections", include_str!("../std/collections.grl"));
    compile_module(
        "maker",
        "module maker;pub fn make<a>(s:read<a>)->vec<read<a>>{var v =vec<read<a>>();vec_push(v,s);return v;}",
    );
    let text = "module workload;use collections;use maker;struct R{label:string,value:num}pub fn run()->num{var v =collections::new<R>();for i in 100{collections::push(borrow_mut(v),R{label:\"item\",value:i});}var p =collections::get_mut(borrow_mut(v),50);exchange(borrow_mut(p.value),500);s :=collections::pop(borrow_mut(v))!;assert(s.value==99);var nested =vec<vec<R>>();vec_push(nested,v);child :=vec_get(nested,0);item :=collections::get(borrow(child),50);assert(item.value==500);var b =bytes();push(b,7);var spans =maker::make(read(b));span :=vec_pop(spans);assert(at(span,0)==7);return len(child);}";
    compile_module("workload", text);
    fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_8_workload_3_run(void);int main(void){return q_8_workload_3_run()!=99;}").unwrap();
    fs::write(
        dir.join("audit.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    for level in ["-O0", "-O2"] {
        for audit in [false, true] {
            let mut cmd = Command::new("clang");
            cmd.arg(level);
            if audit {
                cmd.arg("-DGRAIL_AUDIT_ORDER=0")
                    .arg("-Wl,--wrap=malloc,--wrap=realloc,--wrap=free")
                    .arg(dir.join("audit.c"));
            } else {
                cmd.args(["-fsanitize=address,undefined", "-fno-omit-frame-pointer"]);
            }
            for name in ["core", "collections", "maker", "workload"] {
                cmd.arg(dir.join(format!("{name}.c")));
            }
            let p = cmd
                .arg(dir.join("main.c"))
                .arg("-o")
                .arg(dir.join("run"))
                .output()
                .unwrap();
            assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
            let p = Command::new(dir.join("run"))
                .env("ASAN_OPTIONS", "detect_leaks=1")
                .output()
                .unwrap();
            assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
        }
    }
    fs::remove_dir_all(dir).unwrap();
}
#[test]
#[ignore = "requires Linux clang"]
fn empty_pop_and_out_of_bounds_abort_without_unchecked_access() {
    use std::{fs, os::unix::process::ExitStatusExt, process::Command};
    let dir = std::env::temp_dir().join(format!("grail-vector-bounds-{}", std::process::id()));
    fs::create_dir_all(&dir).unwrap();
    for body in [
        "return vec_pop(v);",
        "p :=vec_get(v,0);return load(p);",
        "vec_push(v,4);p :=vec_get_mut(v,1);return load(p);",
    ] {
        let p = compile(&format!(
            "module f;pub fn run()->num{{v :=vec<num>();{body}}}"
        ))
        .unwrap();
        fs::write(dir.join("f.c"), emit::module_c(&p).unwrap()).unwrap();
        fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_1_f_3_run(void);int main(void){return (int)q_1_f_3_run();}").unwrap();
        let p = Command::new("clang")
            .arg("-O2")
            .arg(dir.join("f.c"))
            .arg(dir.join("main.c"))
            .arg("-o")
            .arg(dir.join("run"))
            .output()
            .unwrap();
        assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
        let p = Command::new(dir.join("run")).output().unwrap();
        assert_eq!(p.status.signal(), Some(6));
    }
    fs::remove_dir_all(dir).unwrap();
}
