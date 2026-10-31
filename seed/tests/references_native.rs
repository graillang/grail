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
        "{c:?}: {}\n{}",
        p.status,
        String::from_utf8_lossy(&p.stderr)
    );
    p
}
fn dir() -> PathBuf {
    let p = std::env::temp_dir().join(format!(
        "grail-references-{}-{}",
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
#[ignore = "requires Linux clang; optional configured TinyCC"]
fn hidden_reference_functions_transfer_owners_and_update_scalar_storage_in_c_and_llvm() {
    let backend = std::env::var("GRAIL_REFERENCE_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let other = if std::env::var_os("GRAIL_REFERENCE_MIXED_BACKEND").is_some() {
        if backend == "tcc" {
            "clang-release"
        } else {
            "tcc"
        }
    } else {
        &backend
    };
    let dir = dir();
    let provider = include_str!("../examples/references/ops.grl");
    fs::write(dir.join("ops.grl"), provider).unwrap();
    compile(&dir, "ops", false, &backend);
    fs::remove_file(dir.join("ops.grl")).unwrap();
    fs::write(
        dir.join("values.grl"),
        include_str!("../examples/references/values.grl"),
    )
    .unwrap();
    compile(&dir, "values", true, other);
    assert_eq!(run(&mut Command::new(dir.join("values"))).stdout, b"45\n");
    let id = fs::read(dir.join("values.artifact")).unwrap();
    let binary = fs::read(dir.join("values")).unwrap();
    compile(&dir, "values", true, other);
    assert_eq!(fs::read(dir.join("values.artifact")).unwrap(), id);
    assert_eq!(fs::read(dir.join("values")).unwrap(), binary);
    let numeric = include_str!("../examples/references/numeric.grl");
    fs::write(dir.join("numeric.grl"), numeric).unwrap();
    compile(&dir, "numeric", true, other);
    for (input, result) in [("", "19\n"), ("x", "92\n")] {
        assert_eq!(
            run(Command::new(dir.join("numeric")).arg(input)).stdout,
            result.as_bytes()
        );
    }
    // LLVM comparison keeps the numeric subset, with real indirect loads/stores and pointer returns.
    let numbers = "module nums;pub fn choose<a>(left:ref_mut<a,num>,right:ref_mut<a,num>,flag:num)->ref_mut<a,num>{if flag{return left;}return right;}";
    let client = numeric
        .replace("use ops;", "use nums;")
        .replace("ops::choose", "nums::choose");
    let p = grail_seed::source::compile(numbers, Default::default()).unwrap();
    let c = grail_seed::source::compile(
        &client,
        std::collections::BTreeMap::from([("nums".into(), p.header().clone())]),
    )
    .unwrap();
    fs::write(
        dir.join("nums.ll"),
        grail_seed::emit::module_llvm(&p).unwrap(),
    )
    .unwrap();
    fs::write(
        dir.join("numeric.ll"),
        grail_seed::emit::module_llvm(&c).unwrap(),
    )
    .unwrap();
    for level in ["-O0", "-O2"] {
        let exe = dir.join(format!("llvm{level}"));
        run(Command::new("clang")
            .args([level, "-Wno-override-module"])
            .arg(dir.join("nums.ll"))
            .arg(dir.join("numeric.ll"))
            .arg(dir.join("numeric-main.c"))
            .arg("-o")
            .arg(&exe));
        for (input, result) in [("", b"19\n"), ("x", b"92\n")] {
            assert_eq!(run(Command::new(&exe).arg(input)).stdout, result);
        }
    }
    fs::remove_dir_all(dir).unwrap();
}
#[test]
#[ignore = "requires Linux clang allocator wrapping and ASan/UBSan; optional configured TinyCC"]
fn reference_exchanges_destroy_replaced_and_residual_heap_values_exactly_once() {
    let backend = std::env::var("GRAIL_REFERENCE_AUDIT_BACKEND").unwrap_or_else(|_| "clang".into());
    assert!(matches!(backend.as_str(), "clang" | "tcc"));
    let dir = dir();
    for (name, text) in [
        ("ops", include_str!("../examples/references/ops.grl")),
        ("values", include_str!("../examples/references/values.grl")),
    ] {
        fs::write(dir.join(format!("{name}.grl")), text).unwrap();
        compile(&dir, name, false, &backend);
        fs::remove_file(dir.join(format!("{name}.grl"))).unwrap();
    }
    let p = grail_seed::artifact::load(&dir, "ops").unwrap();
    let c = grail_seed::artifact::load(&dir, "values").unwrap();
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_6_values_3_run(void),g_free_count(void),g_freed(uint64_t);int main(void){if(q_6_values_3_run()!=45||g_free_count()!=5)return 90;uint64_t order[]={4,5,2,3,1};for(unsigned i=0;i<5;++i)if(g_freed(i)!=order[i])return 91;return 0;}\n").unwrap();
    run(Command::new("clang")
        .args([
            "-DGRAIL_AUDIT_PREVIOUS=3",
            "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free",
        ])
        .arg(&p.object)
        .arg(&c.object)
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
            "-DGRAIL_AUDIT_PREVIOUS=3",
            "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free",
        ])
        .arg(p.object.with_extension("c"))
        .arg(c.object.with_extension("c"))
        .arg(dir.join("main.c"))
        .arg(dir.join("allocator.c"))
        .arg("-o")
        .arg(dir.join("sanitize")));
    run(&mut Command::new(dir.join("sanitize")));
    fs::remove_dir_all(dir).unwrap();
}
