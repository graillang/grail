use grail_seed::{emit, source};
use std::collections::BTreeMap;
fn compile(s: &str) -> Result<grail_seed::module::CheckedModule, String> {
    source::compile(s, BTreeMap::new())
}
const RECORD: &str = "module f;struct R{a:string,b:string}";
#[test]
fn conditional_moves_keep_disjoint_fields_and_cleanup_obligations() {
    for body in [
        "let r=R{a:\"a\",b:\"bc\"};if n{let x=r.a;}return len(r.b);",
        "let r=R{a:\"a\",b:\"bc\"};if n{let x=r.a;}else{let x=r.b;}return 9;",
        "let r=R{a:\"a\",b:\"bc\"};for i in n{let x=r.a;break;}return len(r.b);",
        "let b=bytes();push(b,9);if n{drop(b);}return 9;",
        "let b=bytes();push(b,9);for i in n{drop(b);break;}return 9;",
        "var v=4;if n{exchange(borrow_mut(v),9);}return v;",
    ] {
        let text = format!("{RECORD}pub fn run(n:num)->num{{{body}}}");
        let p = compile(&text).unwrap_or_else(|e| panic!("{text}: {e}"));
        emit::module_c(&p).unwrap();
    }
}
#[test]
fn maybe_initialized_values_cannot_be_read_borrowed_or_moved() {
    for body in [
        "let r=R{a:\"a\",b:\"bc\"};if n{let x=r.a;}return len(r.a);",
        "let r=R{a:\"a\",b:\"bc\"};if n{drop(r);}return len(r.b);",
        "let r=R{a:\"a\",b:\"bc\"};if n{drop(r);}let p=borrow(r.b);return 9;",
        "let b=bytes();if n{drop(b);}push(b,9);return 9;",
        "let b=bytes();for i in n{drop(b);}return 9;",
        "let r=R{a:\"a\",b:\"bc\"};for i in n{let x=r.a;}return 9;",
        "let b=bytes();if n{drop(b);}drop(b);return 9;",
    ] {
        let text = format!("{RECORD}pub fn run(n:num)->num{{{body}}}");
        assert!(compile(&text).is_err(), "{text}");
    }
}
#[test]
#[ignore = "requires clang and ASan/UBSan"]
fn conditional_destruction_is_balanced_on_all_native_paths() {
    use std::{fs, process::Command};
    let dir = std::env::temp_dir().join(format!("grail-ownership-joins-{}", std::process::id()));
    fs::create_dir_all(&dir).unwrap();
    for body in [
        "let r=R{a:\"a\",b:\"bc\"};if n{let x=r.a;}return len(r.b);",
        "let r=R{a:\"a\",b:\"bc\"};if n{let x=r.a;}else{let x=r.b;}return 2;",
        "let r=R{a:\"a\",b:\"bc\"};for i in n{let x=r.a;break;}return len(r.b);",
        "let b=bytes();push(b,9);if n{drop(b);}return 2;",
        "let b=bytes();push(b,9);for i in n{drop(b);break;}return 2;",
        "var x:string;if n{x=\"a\";}else{x=\"bb\";}x=\"cc\";return len(x);",
        "var x:string;if n{x=\"a\";}return 2;",
        "var x=\"a\";for i in n{x=\"bb\";}x=\"cc\";return len(x);",
        "var r=R{a:\"a\",b:\"b\"};if n{let x=r.a;}r.a=\"cc\";return len(r.a);",
        "var r=R{a:\"a\",b:\"b\"};for i in n{let x=r.a;r.a=\"cc\";}r.a=\"cc\";return len(r.a);",
    ] {
        let p = compile(&format!("{RECORD}pub fn run(n:num)->num{{{body}}}")).unwrap();
        fs::write(dir.join("f.c"), emit::module_c(&p).unwrap()).unwrap();
        fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_1_f_3_run(uint64_t);int main(void){for(uint64_t n=0;n<8;n++)if(q_1_f_3_run(n)!=2)return 1;return 0;}").unwrap();
        for level in ["-O0", "-O2"] {
            let out = Command::new("clang")
                .args([
                    level,
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
                out.status.success(),
                "{}",
                String::from_utf8_lossy(&out.stderr)
            );
            let out = Command::new(dir.join("run"))
                .env("ASAN_OPTIONS", "detect_leaks=1")
                .output()
                .unwrap();
            assert!(
                out.status.success(),
                "{body}: {}",
                String::from_utf8_lossy(&out.stderr)
            );
        }
    }
    fs::remove_dir_all(dir).unwrap();
}
#[test]
fn declared_values_initialize_on_all_paths_and_reassign_with_cleanup() {
    for body in [
        "var x:string;if n{x=\"a\";}else{x=\"bb\";}return len(x);",
        "var x:string;if n{x=\"a\";}return 0;",
        "var x:string;{x=\"a\";}return len(x);",
        "var x:string;for i in n{x=\"a\";}return 0;",
        "var x=\"a\";for i in n{x=\"bb\";}return len(x);",
        "var x:num;if n{x=1;}else{x=2;}return x;",
        "var r=R{a:\"a\",b:\"bb\"};if n{let x=r.a;}r=R{a:\"new\",b:\"record\"};return len(r.b);",
        "var x:string;if n{x=\"a\";}x=\"replaced\";return len(x);",
        "var r=R{a:\"a\",b:\"b\"};if n{let x=r.a;}r.a=\"new\";return len(r.a);",
        "var r=R{a:\"a\",b:\"b\"};for i in n{let x=r.a;r.a=\"new\";}return len(r.a);",
    ] {
        let text = format!("{RECORD}pub fn run(n:num)->num{{{body}}}");
        let p = compile(&text).unwrap_or_else(|e| panic!("{text}: {e}"));
        emit::module_c(&p).unwrap();
    }
    for body in [
        "var x:string;if n{x=\"a\";}return len(x);",
        "var x:string;for i in n{x=\"a\";}return len(x);",
        "var x:string;return len(x);",
        "var x:num;if n{x=1;}return x;",
        "var x=\"a\";let p=read(x);x=\"b\";return at(p,0);",
        "var r=R{a:\"a\",b:\"b\"};let p=read(r.a);r.a=\"new\";return at(p,0);",
        "var r=R{a:\"a\",b:\"b\"};r.a=1;return 0;",
    ] {
        let text = format!("{RECORD}pub fn run(n:num)->num{{{body}}}");
        assert!(compile(&text).is_err(), "{text}");
    }
}
