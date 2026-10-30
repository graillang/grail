#![cfg(target_os = "linux")]
//! Heap/capture composition through real by-value record ABIs, not just type-shape checks.
use std::{
    fs,
    path::Path,
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
fn run(c: &mut Command) -> Vec<u8> {
    let p = c.output().unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    p.stdout
}
fn compile(dir: &Path, file: &Path, build: bool, backend: &str) -> Output {
    Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg(if build { "build" } else { "compile" })
        .arg(file)
        .arg(dir)
        .arg(dir)
        .arg(backend)
        .output()
        .unwrap()
}
fn success(p: Output) {
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
}
#[test]
#[ignore = "requires Linux clang; explicit record backend tcc needs configured root"]
fn record_abi_hidden_sources_partial_moves_and_allocator_balance() {
    let backend = std::env::var("GRAIL_RECORD_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let dir = std::env::temp_dir().join(format!(
        "grail-records-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let provider = dir.join("tokens.grl");
    fs::write(&provider,"module tokens;struct Token<a>{span:read<a>,name:string,offset:num}pub fn make<a>(p:read<a>)->Token<a>{return Token{span:p,name:\"hé🙂\",offset:3};}pub fn carry<a>(t:Token<a>)->Token<a>{return t;}").unwrap();
    success(compile(&dir, &provider, false, &backend));
    fs::remove_file(&provider).unwrap();
    let client = dir.join("client.grl");
    fs::write(&client,"use tokens;fn client<a>(p:read<a>)->num{let t=tokens::carry(tokens::make(read(p)));let name=t.name;let n=len(t.span);let span=read(t.span);let offset=t.offset;drop(t);return len(name)+n+len(span)+offset;}").unwrap();
    success(compile(&dir, &client, true, "clang"));
    assert_eq!(run(Command::new(dir.join("client")).arg("abc")), b"16\n");
    // Rebuild the provider with clang before the selected caller backend, covering the reverse ABI.
    fs::write(&provider,"module tokens;struct Token<a>{span:read<a>,name:string,offset:num}pub fn make<a>(p:read<a>)->Token<a>{return Token{span:p,name:\"hé🙂\",offset:3};}pub fn carry<a>(t:Token<a>)->Token<a>{return t;}").unwrap();
    success(compile(&dir, &provider, false, "clang"));
    fs::remove_file(&provider).unwrap();
    success(compile(&dir, &client, true, &backend));
    assert_eq!(run(Command::new(dir.join("client")).arg("abc")), b"16\n");
    let app = dir.join("app.grl");
    fs::write(
        &app,
        "use client;fn app<a>(p:read<a>)->num{return client(p);}",
    )
    .unwrap();
    success(compile(&dir, &app, true, &backend));
    assert_eq!(run(Command::new(dir.join("app")).arg("abc")), b"16\n");
    let old = fs::read(dir.join("app.artifact")).unwrap();
    fs::write(&provider,"module tokens;struct Token<a>{name:string,span:read<a>,offset:num}pub fn make<a>(p:read<a>)->Token<a>{return Token{span:p,name:\"hé🙂\",offset:3};}pub fn carry<a>(t:Token<a>)->Token<a>{return t;}").unwrap();
    success(compile(&dir, &provider, false, &backend));
    fs::remove_file(&provider).unwrap();
    let failed = compile(&dir, &app, true, &backend);
    assert!(!failed.status.success());
    assert_eq!(fs::read(dir.join("app.artifact")).unwrap(), old);
    assert_eq!(run(Command::new(dir.join("app")).arg("abc")), b"16\n");
    let live = grail_seed::module::Interface::single(grail_seed::Sig {
        name: "live".into(),
        params: vec![],
        result: grail_seed::Ty::Num,
    });
    fs::write(dir.join("live.api"), live.encode().unwrap()).unwrap();
    let audit = dir.join("audit.grl");
    fs::write(&audit,"module audit;use live;struct Inner{name:string}struct Token<a>{inner:Inner,span:read<a>}pub fn run()->num{let source=bytes();push(source,7);let t=make(read(source));assert(live()==2);let t=carry(t);assert(live()==2);for i in 10 {let local=make(read(source));assert(live()==3);assert(len(local.span)==1);}assert(live()==2);let name=t.inner.name;let span=read(t.span);drop(t);assert(live()==2);assert(at(span,0)==7);drop(name);assert(live()==1);return len(source);}fn make<a>(p:read<a>)->Token<a>{return Token{inner:Inner{name:\"owned\"},span:p};}fn carry<a>(t:Token<a>)->Token<a>{return t;}").unwrap();
    success(compile(&dir, &audit, false, &backend));
    let header =
        grail_seed::module::Interface::decode(&fs::read_to_string(dir.join("audit.api")).unwrap())
            .unwrap();
    let symbol = grail_seed::emit::symbol(&header.entry);
    fs::write(
        dir.join("main.c"),
        format!(
            "#include <stdint.h>\nuint64_t {symbol}(void);int main(void){{return {symbol}()!=1;}}\n"
        ),
    )
    .unwrap();
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    run(Command::new("clang")
        .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
        .arg(grail_seed::artifact::load(&dir, "audit").unwrap().object)
        .arg(dir.join("main.c"))
        .arg(dir.join("allocator.c"))
        .arg("-o")
        .arg(dir.join("audited")));
    run(&mut Command::new(dir.join("audited")));
    let pair = dir.join("pairs.grl");
    fs::write(&pair,"module pairs;struct Pair<a>{left:mut<a>,right:mut<a>}pub fn run()->num{let a=bytes();push(a,1);let b=bytes();push(b,2);let p=pair(mut(a),mut(b));let l=mut(p.left);let r=mut(p.right);write(l,0,3);write(r,0,4);push(a,5);push(b,6);return at(read(a),0)+at(read(b),0)+len(a)+len(b);}fn pair<a>(x:mut<a>,y:mut<a>)->Pair<a>{return Pair{left:x,right:y};}").unwrap();
    success(compile(&dir, &pair, true, &backend));
    assert_eq!(run(&mut Command::new(dir.join("pairs"))), b"11\n");
    fs::remove_dir_all(dir).unwrap();
}
