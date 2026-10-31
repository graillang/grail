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
        "{c:?} status={}\n{}",
        p.status,
        String::from_utf8_lossy(&p.stderr)
    );
    p
}
fn command(dir: &Path, name: &str, build: bool, backend: &str) -> Command {
    let mut c = Command::new(env!("CARGO_BIN_EXE_grail-seed"));
    c.arg(if build { "build" } else { "compile" })
        .arg(dir.join(format!("{name}.grl")))
        .arg(dir)
        .arg(dir)
        .arg(backend);
    c
}
#[test]
#[ignore = "requires Linux clang; explicit mixed tcc needs configured root"]
fn hidden_generic_types_owned_payloads_mixed_abis_and_stale_layouts() {
    let backend = std::env::var("GRAIL_GENERIC_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let other = if std::env::var_os("GRAIL_GENERIC_MIXED_BACKEND").is_some() {
        if backend == "tcc" { "clang" } else { "tcc" }
    } else {
        &backend
    };
    let dir = std::env::temp_dir().join(format!(
        "grail-generic-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    fs::write(dir.join("core.grl"), include_str!("../std/core.grl")).unwrap();
    run(&mut command(&dir, "core", false, &backend));
    let core = grail_seed::artifact::load(&dir, "core").unwrap();
    assert!(core.header.entry.is_none());
    let manifest = fs::read(dir.join("core.artifact")).unwrap();
    let fail = command(&dir, "core", true, &backend).output().unwrap();
    assert!(!fail.status.success());
    assert!(String::from_utf8_lossy(&fail.stderr).contains("no executable entry"));
    assert_eq!(fs::read(dir.join("core.artifact")).unwrap(), manifest);
    fs::remove_file(dir.join("core.grl")).unwrap();
    fs::write(
        dir.join("parse.grl"),
        include_str!("../examples/generics/parse.grl"),
    )
    .unwrap();
    run(&mut command(&dir, "parse", false, &backend));
    fs::remove_file(dir.join("parse.grl")).unwrap();
    fs::write(
        dir.join("client.grl"),
        include_str!("../examples/generics/client.grl"),
    )
    .unwrap();
    run(&mut command(&dir, "client", true, other));
    for input in [
        "",
        "0",
        "42",
        "00042",
        "18446744073709551615",
        "18446744073709551616",
        "bad",
    ] {
        let expected = if input.is_empty() {
            5
        } else {
            match input.parse::<u64>() {
                Ok(n) => n.wrapping_add(3 + input.len() as u64),
                Err(_) => {
                    if input.bytes().all(|b| b.is_ascii_digit()) {
                        8
                    } else {
                        7
                    }
                }
            }
        };
        assert_eq!(
            run(Command::new(dir.join("client")).arg(input)).stdout,
            format!("{expected}\n").as_bytes()
        );
    }
    for i in 0..32_u64 {
        let n = i.wrapping_mul(1469598103934665603);
        let input = n.to_string();
        let expected = n.wrapping_add(3 + input.len() as u64);
        assert_eq!(
            run(Command::new(dir.join("client")).arg(&input)).stdout,
            format!("{expected}\n").as_bytes()
        );
    }
    // Real selected-backend objects and a complete independently specified release sequence.
    for (name, source) in [
        (
            "audit",
            r#"module audit;use core;pub fn run()->num{let source=bytes();push(source,7);let one=core::Result<core::Pair<string,string>,string>::Ok(core::Pair<string,string>{first:"a",second:"bb"});let two=core::Option<core::Result<string,string>>::Some(core::Result<string,string>::Err("ccc"));let pair=one!;let first=pair.first;drop(pair);let inner=two!;match inner{Ok(s)=>{assert(len(s)==0);},Err(e)=>{assert(len(e)==3);}}drop(first);return len(source);}"#,
        ),
        (
            "propagate",
            r#"module propagate;use core;pub fn run()->num{let source=bytes();push(source,7);let keep="keep";let value=fail();match value{Ok(n)=>{assert(n==0);},Err(e)=>{assert(len(e)==3);}}drop(keep);return len(source);}fn fail()->core::Result<num,string>{let scratch="scratch";let error=core::Result<num,string>::Err("err");let n=error?;return core::Result::Ok(n);}"#,
        ),
    ] {
        fs::write(dir.join(format!("{name}.grl")), source).unwrap();
        run(&mut command(&dir, name, false, &backend));
        let artifact = grail_seed::artifact::load(&dir, name).unwrap();
        let symbol = grail_seed::emit::symbol(artifact.header.entry.as_deref().unwrap());
        fs::write(dir.join("main.c"),format!("#include <stdint.h>\nuint64_t {symbol}(void),g_freed(uint64_t),g_free_count(void);int main(void){{if({symbol}()!=1||g_free_count()!=4)return 90;uint64_t expected[4]={{3,4,2,1}};for(unsigned i=0;i<4;++i)if(g_freed(i)!=expected[i])return 91;return 0;}}\n")).unwrap();
        fs::write(
            dir.join("allocator.c"),
            include_str!("support/allocator_audit.c"),
        )
        .unwrap();
        run(Command::new("clang")
            .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
            .arg(&artifact.object)
            .arg(dir.join("allocator.c"))
            .arg(dir.join("main.c"))
            .arg("-o")
            .arg(dir.join("audit-run")));
        run(&mut Command::new(dir.join("audit-run")));
        // Preserve allocator calls for observation: otherwise valid allocation elision defeats
        // the wrapper's exact trace (generic36 retains the optimized zero-allocation control).
        // This is a C lowering probe, not a delivered release native driver profile.
        let store = artifact.object.parent().unwrap();
        run(Command::new("clang")
            .args([
                "-O2",
                "-fsanitize=address,undefined",
                "-fno-omit-frame-pointer",
                "-fno-builtin-malloc",
                "-fno-builtin-realloc",
                "-fno-builtin-free",
                "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free",
            ])
            .arg(store.join(format!("{name}.c")))
            .arg(dir.join("allocator.c"))
            .arg(dir.join("main.c"))
            .arg("-o")
            .arg(dir.join("sanitize")));
        run(&mut Command::new(dir.join("sanitize")));
    }
    fs::write(
        dir.join("app.grl"),
        "module app;use client;pub fn run<a>(p:read<a>)->num{return client(p);}",
    )
    .unwrap();
    run(&mut command(&dir, "app", true, &backend));
    let old = fs::read(dir.join("app.artifact")).unwrap();
    let changed = include_str!("../std/core.grl").replace("{ Ok(T), Err(E) }", "{ Err(E), Ok(T) }");
    assert_ne!(changed, include_str!("../std/core.grl"));
    fs::write(dir.join("core.grl"), changed).unwrap();
    run(&mut command(&dir, "core", false, &backend));
    fs::remove_file(dir.join("core.grl")).unwrap();
    assert!(
        !command(&dir, "app", true, &backend)
            .output()
            .unwrap()
            .status
            .success()
    );
    assert_eq!(fs::read(dir.join("app.artifact")).unwrap(), old);
    assert_eq!(run(Command::new(dir.join("app")).arg("42")).stdout, b"47\n");
    fs::remove_dir_all(dir).unwrap();
}
