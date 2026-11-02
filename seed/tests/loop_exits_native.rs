#![cfg(target_os = "linux")]
use std::{
    collections::BTreeMap,
    fs,
    path::{Path, PathBuf},
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
fn dir(label: &str) -> PathBuf {
    let p = std::env::temp_dir().join(format!(
        "grail-exits-{label}-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&p).unwrap();
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
#[ignore = "requires Linux clang; explicit tcc backend needs configured root"]
fn counted_while_nested_and_match_jumps_execute_in_c_and_llvm() {
    let backend = std::env::var("GRAIL_LOOP_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let dir = dir("control");
    let provider = include_str!("../examples/loops/control.grl");
    fs::write(dir.join("control.grl"), provider).unwrap();
    compile(&dir, "control", false, &backend);
    fs::remove_file(dir.join("control.grl")).unwrap();
    let client = "module client;use control;pub fn run<a>(input:read<a>)->num{n :=len(input);return control::counted(n)+64*control::repeated(n)+4096*control::nested(n);}";
    fs::write(dir.join("client.grl"), client).unwrap();
    compile(&dir, "client", true, &backend);
    let p = grail_seed::source::compile(provider, BTreeMap::new()).unwrap();
    let c = grail_seed::source::compile(
        client,
        BTreeMap::from([("control".into(), p.header().clone())]),
    )
    .unwrap();
    fs::write(
        dir.join("control.ll"),
        grail_seed::emit::module_llvm(&p).unwrap(),
    )
    .unwrap();
    fs::write(
        dir.join("client.ll"),
        grail_seed::emit::module_llvm(&c).unwrap(),
    )
    .unwrap();
    for level in ["-O0", "-O2"] {
        run(Command::new("clang")
            .args([level, "-Wno-override-module"])
            .arg(dir.join("control.ll"))
            .arg(dir.join("client.ll"))
            .arg(dir.join("client-main.c"))
            .arg("-o")
            .arg(dir.join(format!("llvm{level}"))));
    }
    for n in 0..12_u64 {
        let counted = (0..n)
            .take_while(|i| *i != 5)
            .filter(|i| *i != 2)
            .sum::<u64>();
        let repeated = (1..=n)
            .take_while(|i| *i != 5)
            .filter(|i| *i != 2)
            .sum::<u64>();
        let mut nested = 0;
        for outer in 0..n {
            for inner in 0..4 {
                if inner == 1 {
                    continue;
                }
                if outer == 2 {
                    break;
                }
                nested += outer * 10 + inner;
            }
            if outer == 3 {
                break;
            }
        }
        let expected = format!("{}\n", counted + 64 * repeated + 4096 * nested);
        for file in ["client", "llvm-O0", "llvm-O2"] {
            assert_eq!(
                run(Command::new(dir.join(file)).arg("x".repeat(n as usize))).stdout,
                expected.as_bytes(),
                "{file} n={n}"
            );
        }
    }
    fs::write(dir.join("unique.grl"),"module unique;use control;pub fn run<a>(p:read<a>)->num{var b =bytes();push(b,7);n :=control::unique(mut(b),len(p));push(b,8);return n+at(read(b),1);}").unwrap();
    compile(&dir, "unique", true, &backend);
    for n in [0, 1, 4] {
        assert_eq!(
            run(Command::new(dir.join("unique")).arg("x".repeat(n))).stdout,
            b"17\n"
        );
    }
    // A match switch must not intercept the enclosing loop's break/continue.
    fs::write(dir.join("tagged.grl"),"module tagged;enum O{Some(num),None}pub fn run<a>(p:read<a>)->num{var sum=0;for i in len(p){value :=O::Some(i);match value{Some(n)=>{if n==3{break;}if n==1{continue;}sum=sum+n;},None=>{break;}}}return sum;}").unwrap();
    compile(&dir, "tagged", true, &backend);
    for n in 0..10 {
        let expected = (0..n)
            .take_while(|i| *i != 3)
            .filter(|i| *i != 1)
            .sum::<usize>();
        assert_eq!(
            run(Command::new(dir.join("tagged")).arg("x".repeat(n))).stdout,
            format!("{expected}\n").as_bytes()
        );
    }
    fs::remove_dir_all(dir).unwrap();
}
fn audit_program(name: &str, source: &str, expected: u64, order: &[u64], backend: &str) {
    let dir = dir(name);
    fs::write(dir.join(format!("{name}.grl")), source).unwrap();
    compile(&dir, name, false, backend);
    let artifact = grail_seed::artifact::load(&dir, name).unwrap();
    let symbol = grail_seed::emit::symbol(artifact.header.entry.as_deref().unwrap());
    let previous = order[order.len() - 2];
    let sequence = order
        .iter()
        .map(u64::to_string)
        .collect::<Vec<_>>()
        .join(",");
    let count = order.len();
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    fs::write(dir.join("main.c"),format!("#include <stdint.h>\nuint64_t {symbol}(void),g_free_count(void),g_freed(uint64_t);int main(void){{if({symbol}()!={expected}||g_free_count()!={count})return 90;uint64_t order[{count}]={{{sequence}}};for(unsigned i=0;i<{count};++i)if(g_freed(i)!=order[i])return 91;return 0;}}\n")).unwrap();
    run(Command::new("clang")
        .arg(format!("-DGRAIL_AUDIT_PREVIOUS={previous}"))
        .arg("-Wl,--wrap=malloc,--wrap=realloc,--wrap=free")
        .arg(&artifact.object)
        .arg(dir.join("main.c"))
        .arg(dir.join("allocator.c"))
        .arg("-o")
        .arg(dir.join("audit")));
    run(&mut Command::new(dir.join("audit")));
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
        .arg(format!("-DGRAIL_AUDIT_PREVIOUS={previous}"))
        .arg(artifact.object.with_extension("c"))
        .arg(dir.join("main.c"))
        .arg(dir.join("allocator.c"))
        .arg("-o")
        .arg(dir.join("sanitize")));
    run(&mut Command::new(dir.join("sanitize")));
    fs::remove_dir_all(dir).unwrap();
}
#[test]
#[ignore = "requires Linux clang; optional selected tcc audit needs configured root"]
fn exits_destroy_local_owners_once_and_break_does_not_retest_condition() {
    let backend = std::env::var("GRAIL_LOOP_AUDIT_BACKEND").unwrap_or_else(|_| "clang".into());
    assert!(
        matches!(backend.as_str(), "clang" | "tcc"),
        "exact allocator observations use development objects; optimized source has its own preserving probe"
    );
    audit_program(
        "cleanup",
        include_str!("../examples/loops/cleanup.grl"),
        2,
        &[2, 3, 4, 5, 6, 7, 1],
        &backend,
    );
    audit_program(
        "matched",
        r#"module matched;enum Signal{Next(string),Stop(string)}pub fn run()->num{var source =bytes();push(source,7);for i in 6{before :="before";event :=choose(i);match event{Next(value)=>{assert(len(value)==4);continue;},Stop(reason)=>{assert(len(reason)==4);break;}}}return len(source);}fn choose(n:num)->Signal{if n==0{return Signal::Next("next");}return Signal::Stop("stop");}"#,
        1,
        &[3, 2, 5, 4, 1],
        &backend,
    );
}
