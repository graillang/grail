use std::{
    collections::BTreeMap,
    fs,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
#[test]
#[ignore = "requires Linux clang for independent C and LLVM arithmetic execution"]
fn compound_arithmetic_executes_in_c_and_llvm() {
    let source = "module operators;pub fn run()->num{var n=10;n+=2;n*=3;n-=6;n/=5;n%=4;n**=3;n+=n;assert(2**3**2==512);assert(2*3**2==18);assert(2**64==0);assert(0**0==1);return n+17/5;}";
    let checked = grail_seed::source::compile(source, BTreeMap::new()).unwrap();
    let work = std::env::temp_dir().join(format!(
        "grail-operators-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&work).unwrap();
    let symbol = grail_seed::emit::symbol("operators::run");
    let main = work.join("main.c");
    fs::write(&main,format!("#include <stdint.h>\n#include <stdio.h>\nuint64_t {symbol}(void);int main(void){{printf(\"%llu\\n\",(unsigned long long){symbol}());}}\n")).unwrap();
    for (ext, text) in [
        ("c", grail_seed::emit::module_c(&checked).unwrap()),
        ("ll", grail_seed::emit::module_llvm(&checked).unwrap()),
    ] {
        let input = work.join(format!("operators.{ext}"));
        fs::write(&input, text).unwrap();
        let exe = work.join(format!("run-{ext}"));
        let build = Command::new("clang")
            .arg(&input)
            .arg(&main)
            .arg("-o")
            .arg(&exe)
            .output()
            .unwrap();
        assert!(
            build.status.success(),
            "{}",
            String::from_utf8_lossy(&build.stderr)
        );
        let run = Command::new(exe).output().unwrap();
        assert!(run.status.success());
        assert_eq!(run.stdout, b"19\n");
    }
    fs::remove_dir_all(work).unwrap();
}
