#![cfg(target_os = "linux")]
use std::{
    fs,
    os::unix::process::ExitStatusExt,
    path::Path,
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
fn run(c: &mut Command) -> Output {
    let p = c.output().unwrap();
    assert!(
        p.status.success(),
        "{c:?}\n{}",
        String::from_utf8_lossy(&p.stderr)
    );
    p
}
fn compile(dir: &Path, name: &str, build: bool, backend: &str) {
    run(Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg(if build { "build" } else { "compile" })
        .arg(dir.join(format!("{name}.grl")))
        .arg(dir)
        .arg(dir)
        .arg(backend));
}
#[test]
#[ignore = "requires Linux clang; explicit tcc selection needs configured root"]
fn hidden_sum_payloads_match_unwrap_abort_and_cleanup() {
    let backend = std::env::var("GRAIL_ENUM_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let dir = std::env::temp_dir().join(format!(
        "grail-enums-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    fs::write(
        dir.join("result.grl"),
        include_str!("../examples/enums/result.grl"),
    )
    .unwrap();
    compile(&dir, "result", false, &backend);
    fs::remove_file(dir.join("result.grl")).unwrap();
    for (name, source) in [
        ("unwrap", include_str!("../examples/enums/unwrap.grl")),
        ("recover", include_str!("../examples/enums/recover.grl")),
    ] {
        fs::write(dir.join(format!("{name}.grl")), source).unwrap();
        let client_backend = if std::env::var_os("GRAIL_ENUM_MIXED_BACKEND").is_some() {
            if backend == "tcc" { "clang" } else { "tcc" }
        } else {
            &backend
        };
        compile(&dir, name, true, client_backend);
        assert_eq!(run(Command::new(dir.join(name)).arg("abc")).stdout, b"8\n");
    }
    assert_eq!(
        run(Command::new(dir.join("recover")).arg("")).stdout,
        b"11\n"
    );
    let p = Command::new("bash")
        .args(["-c", "ulimit -c 0; exec \"$@\"", "unwrap-failure"])
        .arg(dir.join("unwrap"))
        .arg("")
        .output()
        .unwrap();
    assert_eq!(
        p.status.signal(),
        Some(6),
        "failure must abort, not yield an arbitrary payload"
    );
    fs::write(
        dir.join("app.grl"),
        "module app;use recover;pub fn run<a>(p:read<a>)->num{return recover(p);}",
    )
    .unwrap();
    compile(&dir, "app", true, &backend);
    let old = fs::read(dir.join("app.artifact")).unwrap();
    let changed = include_str!("../examples/enums/result.grl")
        .replace("Ok(Token<a>),Err(string)", "Err(string),Ok(Token<a>)");
    fs::write(dir.join("result.grl"), changed).unwrap();
    compile(&dir, "result", false, &backend);
    fs::remove_file(dir.join("result.grl")).unwrap();
    let p = Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg("build")
        .arg(dir.join("app.grl"))
        .arg(&dir)
        .arg(&dir)
        .arg(&backend)
        .output()
        .unwrap();
    assert!(!p.status.success());
    assert_eq!(fs::read(dir.join("app.artifact")).unwrap(), old);
    assert_eq!(run(Command::new(dir.join("app")).arg("abc")).stdout, b"8\n");
    // Actual selected-backend objects; nested sums exercise inactive union payload flags.
    fs::write(dir.join("audit.grl"),r#"module audit;enum R{Ok(string),Err(string)}enum Outer{Ok(R),Err(string)}struct Pair{first:R,second:R}pub fn run()->num{let source=bytes();push(source,7);let a=R::Ok("a");let b=R::Err("bb");let pair=Pair{first:a,second:b};for i in 10{let nested=make(i);assert(discard(make(i))==0);}let chained=make(1)!!;assert(len(chained)==1);drop(chained);let b=pair.second;match b{Ok(s)=>{assert(len(s)==1);},Err(e)=>{assert(len(e)==2);}}let s=pair.first!;assert(len(s)==1);drop(s);return len(source);}fn make(n:num)->Outer{if n%2{return Outer::Ok(R::Ok("x"));}return Outer::Err("yy");}fn discard(r:Outer)->num{return 0;}"#).unwrap();
    compile(&dir, "audit", false, &backend);
    let audit = grail_seed::artifact::load(&dir, "audit").unwrap();
    let symbol = grail_seed::emit::symbol(audit.header.entry.as_deref().unwrap());
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
        .arg(&audit.object)
        .arg(dir.join("allocator.c"))
        .arg(dir.join("main.c"))
        .arg("-o")
        .arg(dir.join("audited")));
    run(&mut Command::new(dir.join("audited")));
    let option = r#"module option;enum O{None,Some(string)}enum U{Ok(unit),Err(string)}pub fn run()->num{let none=O::None;match none{None=>{},Some(s)=>{assert(0);}}let some=O::Some("abc");let text=some!;let unit=U::Ok(())!;let passed=carry(unit);return len(text)+number(passed);}fn carry(u:unit)->unit{return u;}fn number(u:unit)->num{return 4;}"#;
    fs::write(dir.join("option.grl"), option).unwrap();
    compile(&dir, "option", true, &backend);
    assert_eq!(run(&mut Command::new(dir.join("option"))).stdout, b"7\n");
    let unit = "module unitabi;pub fn run()->num{let u=carry(());return number(u);}fn carry(u:unit)->unit{return u;}fn number(u:unit)->num{return 4;}";
    fs::write(dir.join("unitabi.grl"), unit).unwrap();
    compile(&dir, "unitabi", true, &backend);
    let checked = grail_seed::source::compile(unit, Default::default()).unwrap();
    fs::write(
        dir.join("unitabi.ll"),
        grail_seed::emit::module_llvm(&checked).unwrap(),
    )
    .unwrap();
    run(Command::new("clang")
        .args(["-O0", "-Wno-override-module"])
        .arg(dir.join("unitabi.ll"))
        .arg(dir.join("unitabi-main.c"))
        .arg("-o")
        .arg(dir.join("unitabi-llvm")));
    assert_eq!(
        run(&mut Command::new(dir.join("unitabi-llvm"))).stdout,
        b"4\n"
    );
    fs::write(
        dir.join("number.grl"),
        include_str!("../examples/enums/number.grl"),
    )
    .unwrap();
    compile(&dir, "number", false, &backend);
    fs::remove_file(dir.join("number.grl")).unwrap();
    fs::write(
        dir.join("parse.grl"),
        include_str!("../examples/enums/parse.grl"),
    )
    .unwrap();
    compile(&dir, "parse", true, &backend);
    for (input, expected) in [
        ("0", "0\n"),
        ("18446744073709551615", "18446744073709551615\n"),
        ("18446744073709551616", "8\n"),
        ("999999999999999999999999999999", "8\n"),
        ("12x", "7\n"),
        ("", "5\n"),
        ("00042", "42\n"),
    ] {
        assert_eq!(
            run(Command::new(dir.join("parse")).arg(input)).stdout,
            expected.as_bytes()
        );
    }
    fs::write(dir.join("status.grl"),"module status;use number;pub fn run<a>(p:read<a>)->num{let r=number::parse(p);match r{Ok(n)=>{return 1;},Err(e)=>{return 0;}}}").unwrap();
    compile(&dir, "status", true, &backend);
    let mut state = 0x9e3779b97f4a7c15u64;
    for _ in 0..32 {
        state = state
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        let input = state.to_string();
        let expected = input.parse::<u64>().unwrap();
        assert_eq!(
            run(Command::new(dir.join("parse")).arg(&input)).stdout,
            format!("{expected}\n").as_bytes()
        );
        assert_eq!(
            run(Command::new(dir.join("status")).arg(&input)).stdout,
            b"1\n"
        );
        let invalid = format!("{input}x");
        assert!(invalid.parse::<u64>().is_err());
        assert_eq!(
            run(Command::new(dir.join("status")).arg(invalid)).stdout,
            b"0\n"
        );
    }
    fs::write(dir.join("emptyarm.grl"),"module emptyarm;enum O<a>{None,Some(read<a>)}pub fn run()->num{let b=bytes();push(b,1);let o=O::Some(read(b));match o{None=>{},Some(_)=>{}}push(b,2);return len(b);}").unwrap();
    compile(&dir, "emptyarm", true, &backend);
    assert_eq!(run(&mut Command::new(dir.join("emptyarm"))).stdout, b"2\n");
    fs::write(
        dir.join("optionfail.grl"),
        "module optionfail;enum O{None,Some(string)}pub fn run()->num{return len(O::None!);}",
    )
    .unwrap();
    compile(&dir, "optionfail", true, &backend);
    let p = Command::new("bash")
        .args(["-c", "ulimit -c 0; exec \"$@\"", "option-failure"])
        .arg(dir.join("optionfail"))
        .output()
        .unwrap();
    assert_eq!(p.status.signal(), Some(6));
    fs::remove_dir_all(dir).unwrap();
}
