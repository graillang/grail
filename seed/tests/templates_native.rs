#![cfg(target_os = "linux")]
use std::{
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
        "grail-templates-{label}-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&p).unwrap();
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
const LOW: &str =
    "module low;pub fn score<type T>(value:T)->num{return helper();}fn helper()->num{return 7;}";
const API: &str =
    "module api;use low;pub fn score<type T>(value:T)->num{return low::score(value);}";
#[test]
#[ignore = "requires Linux clang; selected tcc requires configured root"]
fn source_hidden_generics_pin_private_helpers_and_transitive_implementations() {
    let backend = std::env::var("GRAIL_TEMPLATE_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let other = if std::env::var_os("GRAIL_TEMPLATE_MIXED_BACKEND").is_some() {
        if backend == "tcc" {
            "clang-release"
        } else {
            "tcc"
        }
    } else {
        &backend
    };
    let dir = dir("pins");
    fs::write(dir.join("low.grl"), LOW).unwrap();
    run(&mut command(&dir, "low", false, &backend));
    let low = grail_seed::artifact::load(&dir, "low").unwrap();
    fs::remove_file(dir.join("low.grl")).unwrap();
    // Generic producer checking/publication needs only imported contracts, not dependency body bytes.
    let ir = low.templates.clone().unwrap();
    let held = ir.with_extension("held");
    fs::rename(&ir, &held).unwrap();
    fs::write(dir.join("api.grl"), API).unwrap();
    run(&mut command(&dir, "api", false, &backend));
    fs::rename(&held, &ir).unwrap();
    let api = grail_seed::artifact::load(&dir, "api").unwrap();
    fs::remove_file(dir.join("api.grl")).unwrap();
    fs::write(dir.join("api.ir"), "corrupt convenience copy").unwrap();
    fs::write(
        dir.join("client.grl"),
        "module client;use api;pub fn run()->num{return api::score(\"owned\")+1;}",
    )
    .unwrap();
    run(&mut command(&dir, "client", true, other));
    assert_eq!(run(&mut Command::new(dir.join("client"))).stdout, b"8\n");
    let c = fs::read_to_string(dir.join("client.c")).unwrap();
    assert!(c.contains("g__helper_"));
    assert!(!c.contains("g_helper("));
    let original = fs::read(dir.join("client")).unwrap();
    let id = grail_seed::artifact::load(&dir, "client").unwrap().id;
    run(&mut command(&dir, "client", true, other));
    assert_eq!(fs::read(dir.join("client")).unwrap(), original);
    assert_eq!(grail_seed::artifact::load(&dir, "client").unwrap().id, id);
    fs::write(
        dir.join("app.grl"),
        "module app;use client;pub fn run()->num{return client::run();}",
    )
    .unwrap();
    run(&mut command(&dir, "app", true, &backend));
    let old = fs::read(dir.join("app.artifact")).unwrap();
    let old_binary = fs::read(dir.join("app")).unwrap();
    fs::write(dir.join("low.grl"), LOW.replace("return 7", "return 9")).unwrap();
    run(&mut command(&dir, "low", false, &backend));
    fs::remove_file(dir.join("low.grl")).unwrap();
    let changed = grail_seed::artifact::load(&dir, "low").unwrap();
    assert_eq!(
        changed.header.fingerprint().unwrap(),
        low.header.fingerprint().unwrap()
    );
    assert_ne!(changed.header.template_hash, low.header.template_hash);
    let fail = command(&dir, "app", true, &backend).output().unwrap();
    assert!(!fail.status.success());
    assert!(String::from_utf8_lossy(&fail.stderr).contains("stale generic implementation"));
    assert_eq!(fs::read(dir.join("app.artifact")).unwrap(), old);
    assert_eq!(fs::read(dir.join("app")).unwrap(), old_binary);
    fs::write(dir.join("api.grl"), API).unwrap();
    run(&mut command(&dir, "api", false, &backend));
    fs::remove_file(dir.join("api.grl")).unwrap();
    let new_api = grail_seed::artifact::load(&dir, "api").unwrap();
    assert_eq!(
        new_api.header.fingerprint().unwrap(),
        api.header.fingerprint().unwrap()
    );
    assert_ne!(
        new_api.header.template_hash, api.header.template_hash,
        "transitive body pin participates in closure hash"
    );
    assert!(
        !command(&dir, "app", true, &backend)
            .output()
            .unwrap()
            .status
            .success()
    );
    assert_eq!(run(&mut Command::new(dir.join("app"))).stdout, b"8\n");
    run(&mut command(&dir, "client", true, other));
    run(&mut command(&dir, "app", true, &backend));
    assert_eq!(run(&mut Command::new(dir.join("app"))).stdout, b"10\n");
    let before = fs::read(dir.join("app.artifact")).unwrap();
    fs::write(changed.templates.unwrap(), "corrupt immutable IR").unwrap();
    assert!(
        !command(&dir, "app", true, &backend)
            .output()
            .unwrap()
            .status
            .success()
    );
    assert_eq!(fs::read(dir.join("app.artifact")).unwrap(), before);
    assert_eq!(run(&mut Command::new(dir.join("app"))).stdout, b"10\n");
    fs::remove_dir_all(dir).unwrap();
}
#[test]
#[ignore = "requires Linux clang; selected tcc requires configured root"]
fn generic_standard_functions_preserve_owned_captures_authority_and_eager_values() {
    let backend = std::env::var("GRAIL_TEMPLATE_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let dir = dir("values");
    fs::write(dir.join("core.grl"), include_str!("../std/core.grl")).unwrap();
    run(&mut command(&dir, "core", false, &backend));
    fs::remove_file(dir.join("core.grl")).unwrap();
    let program = r#"module values;use core;struct Token<a>{span:read<a>,name:string}pub fn run<a>(input:read<a>)->num{let left=bytes();push(left,1);let right=bytes();push(right,2);let pair=core::unwrap_option(core::some(core::pair(mut(left),mut(right))));write(pair.first,0,3);write(pair.second,0,4);core::discard(pair);push(left,7);push(right,8);let token=Token{span:read(input),name:"token"};let result=core::ok<Token<a>,string>(token);let value=core::unwrap_result(result);let name=value.name;let label=core::identity("owned");return len(value.span)+len(name)+len(label)+at(read(left),0)+at(read(right),0)+at(read(left),1)+at(read(right),1);}"#;
    fs::write(dir.join("values.grl"), program).unwrap();
    run(&mut command(&dir, "values", true, &backend));
    for input in ["", "abc", "hé🙂"] {
        assert_eq!(
            run(Command::new(dir.join("values")).arg(input)).stdout,
            format!("{}\n", 32 + input.len()).as_bytes()
        );
    }
    fs::write(dir.join("eager.grl"),"module eager;pub fn run()->num{let b=bytes();push(b,7);return first(at(read(b),0),change(mut(b)));}fn first<type T>(value:T,ignored:num)->T{return value;}fn change<a>(p:mut<a>)->num{write(p,0,99);return 0;}").unwrap();
    run(&mut command(&dir, "eager", true, &backend));
    assert_eq!(run(&mut Command::new(dir.join("eager"))).stdout, b"7\n");
    let numeric = "module numeric;pub fn run()->num{return repeat(7,12);}fn repeat<type T>(value:T,n:num)->num{if n==0{return 0;}return repeat(value,n-1)+1;}";
    fs::write(dir.join("numeric.grl"), numeric).unwrap();
    run(&mut command(&dir, "numeric", true, &backend));
    assert_eq!(run(&mut Command::new(dir.join("numeric"))).stdout, b"12\n");
    let checked = grail_seed::source::compile(numeric, Default::default()).unwrap();
    fs::write(
        dir.join("numeric.ll"),
        grail_seed::emit::module_llvm(&checked).unwrap(),
    )
    .unwrap();
    run(Command::new("clang")
        .args(["-O2", "-Wno-override-module"])
        .arg(dir.join("numeric.ll"))
        .arg(dir.join("numeric-main.c"))
        .arg("-o")
        .arg(dir.join("llvm")));
    assert_eq!(run(&mut Command::new(dir.join("llvm"))).stdout, b"12\n");
    fs::remove_dir_all(dir).unwrap();
}

#[test]
#[ignore = "requires Linux clang, allocator wrapping and ASan/UBSan; optional configured tcc"]
fn generic_helpers_drop_recursive_values_and_propagated_errors_once() {
    let backend = std::env::var("GRAIL_TEMPLATE_AUDIT_BACKEND").unwrap_or_else(|_| "clang".into());
    assert!(matches!(backend.as_str(), "clang" | "tcc"));
    let dir = dir("cleanup");
    fs::write(dir.join("core.grl"), include_str!("../std/core.grl")).unwrap();
    run(&mut command(&dir, "core", false, &backend));
    fs::remove_file(dir.join("core.grl")).unwrap();
    fs::write(
        dir.join("cleanup.grl"),
        include_str!("../../research/experiments/templates39/cleanup.grl"),
    )
    .unwrap();
    run(&mut command(&dir, "cleanup", false, &backend));
    let artifact = grail_seed::artifact::load(&dir, "cleanup").unwrap();
    let symbol = grail_seed::emit::symbol(artifact.header.entry.as_deref().unwrap());
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    for (input, value, order) in [(0, 3, vec![3, 2, 4, 1]), (1, 11, vec![3, 5, 6, 7, 4, 2, 1])] {
        let count = order.len();
        let previous = order[count - 2];
        let sequence = order
            .iter()
            .map(u64::to_string)
            .collect::<Vec<_>>()
            .join(",");
        fs::write(dir.join("main.c"),format!("#include <stdint.h>\nuint64_t {symbol}(uint64_t),g_free_count(void),g_freed(uint64_t);int main(void){{if({symbol}({input})!={value}||g_free_count()!={count})return 90;uint64_t order[{count}]={{{sequence}}};for(unsigned i=0;i<{count};++i)if(g_freed(i)!=order[i])return 91;return 0;}}\n")).unwrap();
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
    }
    fs::remove_dir_all(dir).unwrap();
}
