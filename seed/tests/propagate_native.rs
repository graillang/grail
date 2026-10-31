#![cfg(target_os = "linux")]
use std::{
    fs,
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
#[ignore = "requires Linux clang; tcc selection needs its configured root"]
fn propagation_uses_normal_returns_across_hidden_modules_and_every_cleanup_frontier() {
    let backend = std::env::var("GRAIL_PROPAGATE_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let dir = std::env::temp_dir().join(format!(
        "grail-propagate-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    fs::write(
        dir.join("number.grl"),
        include_str!("../examples/enums/number.grl"),
    )
    .unwrap();
    compile(&dir, "number", false, &backend);
    fs::remove_file(dir.join("number.grl")).unwrap();
    fs::write(
        dir.join("annotate.grl"),
        include_str!("../examples/enums/annotate.grl"),
    )
    .unwrap();
    let provider = if std::env::var_os("GRAIL_PROPAGATE_MIXED_BACKEND").is_some() {
        if backend == "clang" { "tcc" } else { "clang" }
    } else {
        &backend
    };
    compile(&dir, "annotate", false, provider);
    fs::remove_file(dir.join("annotate.grl")).unwrap();
    fs::write(dir.join("client.grl"),"module client;use annotate;pub fn run<a>(p:read<a>)->num{let result=annotate::parse(p);match result{Ok(t)=>{return t.value+len(t.name)+len(t.span);},Err(e)=>{return len(e);}}}").unwrap();
    compile(&dir, "client", true, &backend);
    for (input, expected) in [
        ("42", b"49\n".as_slice()),
        ("", b"5\n".as_slice()),
        ("bad", b"7\n".as_slice()),
        ("18446744073709551616", b"8\n".as_slice()),
    ] {
        assert_eq!(
            run(Command::new(dir.join("client")).arg(input)).stdout,
            expected
        );
    }
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    let audit = |name: &str, source: &str, previous: u32, expected: u64, frees: &[u64]| {
        fs::write(dir.join(format!("{name}.grl")), source).unwrap();
        compile(&dir, name, false, &backend);
        let own = grail_seed::artifact::load(&dir, name).unwrap();
        let symbol = grail_seed::emit::symbol(own.header.entry.as_deref().unwrap());
        let order = frees
            .iter()
            .enumerate()
            .map(|(i, id)| format!("if(g_freed({i})!={id})return 98;"))
            .collect::<String>();
        fs::write(dir.join("main.c"),format!("#include <stdint.h>\nuint64_t {symbol}(void),g_freed(uint64_t),g_free_count(void);int main(void){{if({symbol}()!={expected})return 97;if(g_free_count()!={})return 99;{order}return 0;}}\n",frees.len())).unwrap();
        run(Command::new("clang")
            .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
            .arg(format!("-DGRAIL_AUDIT_PREVIOUS={previous}"))
            .arg(&own.object)
            .arg(grail_seed::artifact::load(&dir, "annotate").unwrap().object)
            .arg(grail_seed::artifact::load(&dir, "number").unwrap().object)
            .arg(dir.join("allocator.c"))
            .arg(dir.join("main.c"))
            .arg("-o")
            .arg(dir.join("audited")));
        run(&mut Command::new(dir.join("audited")));
    };
    for (input, expected) in [("42", 49), ("bad", 7)] {
        audit(
            "audit",
            &format!(
                "module audit;use annotate;pub fn run()->num{{let source=\"{input}\";let r=annotate::parse(read(source));match r{{Ok(t)=>{{return t.value+len(t.name)+len(t.span);}},Err(e)=>{{return len(e);}}}}}}"
            ),
            3,
            expected,
            &[2, 3, 1],
        );
    }
    audit(
        "args",
        r#"module args;enum R{Ok(num),Err(string)}pub fn run()->num{let source="root";let r=work();match r{Ok(n)=>{return n;},Err(e)=>{return len(e);}}}fn work()->R{let b=bytes();push(b,1);return R::Ok(consume(copy_bytes(b),fail()?));}fn fail()->R{return R::Err("bad");}fn consume(b:bytes,n:num)->num{return len(b)+n;}"#,
        4,
        3,
        &[3, 2, 4, 1],
    );
    audit(
        "condition",
        r#"module condition;enum R{Ok(num),Err(string)}pub fn run()->num{let source="root";let r=work();match r{Ok(n)=>{return n;},Err(e)=>{return len(e);}}}fn work()->R{let b=bytes();push(b,1);var i=0;while test(i)?{let temp=copy_bytes(b);i=i+1;}return R::Ok(len(b));}fn test(n:num)->R{if n==2{return R::Err("bad");}return R::Ok(1);}"#,
        5,
        3,
        &[3, 4, 2, 5, 1],
    );
    audit(
        "option",
        r#"module option;enum O{Some(num),None}pub fn run()->num{let source="root";let r=work();match r{Some(n)=>{return n;},None=>{return 0;}}}fn work()->O{let b=bytes();push(b,1);let n=none()?;return O::Some(n);}fn none()->O{return O::None;}"#,
        2,
        0,
        &[2, 1],
    );
    audit(
        "effects",
        r#"module effects;enum R{Ok(num),Err(string)}pub fn run()->num{let b=bytes();push(b,1);let r=work(mut(b));var n=0;match r{Ok(v)=>{n=v;},Err(e)=>{n=len(e);}}assert(at(read(b),0)==9);return n;}fn work<a>(p:mut<a>)->R{write(p,0,9);let n=fail()?;return R::Ok(n);}fn fail()->R{return R::Err("bad");}"#,
        2,
        3,
        &[2, 1],
    );
    fs::remove_dir_all(dir).unwrap();
}
