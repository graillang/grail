#![cfg(target_os = "linux")]
use std::{
    fs,
    path::Path,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
fn run(c: &mut Command) -> Vec<u8> {
    let p = c.output().unwrap();
    assert!(
        p.status.success(),
        "{c:?}\n{}",
        String::from_utf8_lossy(&p.stderr)
    );
    p.stdout
}
fn compile(dir: &Path, file: &str, backend: &str) {
    run(Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg("compile")
        .arg(dir.join(file))
        .arg(dir)
        .arg(dir)
        .arg(backend));
}
#[test]
#[ignore = "requires Linux clang; tcc selection requires its configured root"]
fn early_returns_cleanup_selected_backend_objects_and_llvm_terminators() {
    let backend = std::env::var("GRAIL_RETURN_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let dir = std::env::temp_dir().join(format!(
        "grail-returns-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let live = grail_seed::module::Interface::single(grail_seed::Sig {
        name: "live".into(),
        params: vec![],
        result: grail_seed::Ty::Num,
    });
    fs::write(dir.join("live.api"), live.encode().unwrap()).unwrap();
    fs::write(dir.join("choice.grl"),"module choice;use live;struct Inner{a:string,b:string}struct Token<a>{inner:Inner,span:read<a>}pub fn make<a>(p:read<a>)->Token<a>{return Token{inner:Inner{a:\"a\",b:\"bb\"},span:p};}pub fn pick<a>(t:Token<a>,n:num)->string{var trash =bytes();push(trash,9);assert(live()==4);if n{return t.inner.a;}for i in 2{if i{return t.inner.b;}}return \"fallback\";}").unwrap();
    compile(&dir, "choice.grl", &backend);
    fs::remove_file(dir.join("choice.grl")).unwrap();
    fs::write(dir.join("audit.grl"),"module audit;use choice;use live;pub fn run(n:num)->num{var source =bytes();push(source,7);t :=choice::make(read(source));assert(live()==3);name :=choice::pick(t,n);assert(live()==2);assert(len(name)==2-n);drop(name);assert(live()==1);return len(source);}").unwrap();
    compile(&dir, "audit.grl", &backend);
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    let header = grail_seed::artifact::load(&dir, "audit").unwrap();
    let symbol = grail_seed::emit::symbol(header.header.entry.as_deref().unwrap());
    for (n, previous) in [(0, 3), (1, 2)] {
        fs::write(dir.join("main.c"),format!("#include <stdint.h>\nuint64_t {symbol}(uint64_t);int main(void){{return {symbol}({n})!=1;}}\n")).unwrap();
        run(Command::new("clang")
            .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
            .arg(format!("-DGRAIL_AUDIT_PREVIOUS={previous}"))
            .arg(&header.object)
            .arg(grail_seed::artifact::load(&dir, "choice").unwrap().object)
            .arg(dir.join("allocator.c"))
            .arg(dir.join("main.c"))
            .arg("-o")
            .arg(dir.join("audited")));
        run(&mut Command::new(dir.join("audited")));
    }
    fs::write(dir.join("capture.grl"),"module capture;struct T<a>{span:mut<a>,name:string}pub fn run()->num{var b =bytes();push(b,7);t :=T{span:mut(b),name:\"n\"};r :=span(t,1);assert(at(r,0)==7);push(b,8);return len(b);}fn span<a>(t:T<a>,n:num)->read<a>{if n{return read(t.span);}return read(t.span);}").unwrap();
    compile(&dir, "capture.grl", &backend);
    let capture = grail_seed::artifact::load(&dir, "capture").unwrap();
    let symbol = grail_seed::emit::symbol(capture.header.entry.as_deref().unwrap());
    fs::write(
        dir.join("capture-main.c"),
        format!(
            "#include <stdint.h>\nuint64_t {symbol}(void);int main(void){{return {symbol}()!=2;}}\n"
        ),
    )
    .unwrap();
    run(Command::new("clang")
        .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
        .arg(&capture.object)
        .arg(dir.join("allocator.c"))
        .arg(dir.join("capture-main.c"))
        .arg("-o")
        .arg(dir.join("capture")));
    run(&mut Command::new(dir.join("capture")));
    let control = "module control;pub fn run<a>(p:read<a>)->num{n :=len(p);if n==0{return both(0);} {for i in n{if at(p,i)==120{return from_while(n);}}}return both(n);}fn both(n:num)->num{if n{return 7;}else{return 8;}}fn from_while(n:num)->num{while n{return 9;}return 10;}";
    fs::write(dir.join("control.grl"), control).unwrap();
    run(Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg("build")
        .arg(dir.join("control.grl"))
        .arg(&dir)
        .arg(&dir)
        .arg(&backend));
    let checked = grail_seed::source::compile(control, Default::default()).unwrap();
    fs::write(
        dir.join("control.ll"),
        grail_seed::emit::module_llvm(&checked).unwrap(),
    )
    .unwrap();
    run(Command::new("clang")
        .args(["-O0", "-Wno-override-module"])
        .arg(dir.join("control.ll"))
        .arg(dir.join("control-main.c"))
        .arg("-o")
        .arg(dir.join("llvm")));
    for (input, expected) in [
        ("", b"8\n".as_slice()),
        ("x", b"9\n".as_slice()),
        ("abc", b"7\n".as_slice()),
    ] {
        for binary in ["control", "llvm"] {
            assert_eq!(run(Command::new(dir.join(binary)).arg(input)), expected);
        }
    }
    fs::remove_dir_all(dir).unwrap();
}
