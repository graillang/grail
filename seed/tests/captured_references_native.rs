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
        "grail-captures-{}-{}",
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
#[ignore = "requires clang; optionally configured TinyCC"]
fn hidden_shared_cursors_release_only_the_frame_and_preserve_captured_authority() {
    let backend = std::env::var("GRAIL_CAPTURE_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let other = if std::env::var_os("GRAIL_CAPTURE_MIXED_BACKEND").is_some() {
        if backend == "tcc" {
            "clang-release"
        } else {
            "tcc"
        }
    } else {
        &backend
    };
    let dir = dir();
    fs::write(
        dir.join("views.grl"),
        include_str!("../examples/captures/views.grl"),
    )
    .unwrap();
    compile(&dir, "views", false, &backend);
    fs::remove_file(dir.join("views.grl")).unwrap();
    fs::write(
        dir.join("use_views.grl"),
        include_str!("../examples/captures/use_views.grl"),
    )
    .unwrap();
    compile(&dir, "use_views", true, other);
    assert_eq!(
        run(&mut Command::new(dir.join("use_views"))).stdout,
        b"36\n"
    );
    let id = fs::read(dir.join("use_views.artifact")).unwrap();
    let binary = fs::read(dir.join("use_views")).unwrap();
    compile(&dir, "use_views", true, other);
    assert_eq!(id, fs::read(dir.join("use_views.artifact")).unwrap());
    assert_eq!(binary, fs::read(dir.join("use_views")).unwrap());
    // The same hidden-source library contains generic inspect<T>; loading checked IR must retain
    // universal readonly borrowing, not impose the old mutable/plain kind restriction.
    assert!(grail_seed::artifact::templates(&dir, "views").is_ok());
    fs::remove_dir_all(dir).unwrap();
}
#[test]
#[ignore = "requires clang and LLVM numeric descriptor ABI"]
fn readonly_descriptor_and_nested_pointer_loads_run_in_c_and_llvm() {
    let dir = dir();
    let text = "module descriptors;pub fn copy<outer,data>(slot:ref<outer,read<data>>)->read<data>{return load(slot);}pub fn peek<outer,data>(slot:ref<outer,read<data>>)->read<data>{return read(slot);}pub fn pointer<outer,data>(slot:ref<outer,ref<data,num>>)->ref<data,num>{return load(slot);}";
    let p = grail_seed::source::compile(text, Default::default()).unwrap();
    fs::write(
        dir.join("descriptors.c"),
        grail_seed::emit::module_c(&p).unwrap(),
    )
    .unwrap();
    fs::write(
        dir.join("descriptors.ll"),
        grail_seed::emit::module_llvm(&p).unwrap(),
    )
    .unwrap();
    fs::write(dir.join("main.c"),"#include <stdint.h>\ntypedef struct{uint8_t*p;uint64_t n;}gv;gv q_11_descriptors_4_copy(gv const*),q_11_descriptors_4_peek(gv const*);uint64_t const*q_11_descriptors_7_pointer(uint64_t const*const*);int main(void){uint8_t data[]={7,8};gv input={data,2},a=q_11_descriptors_4_copy(&input),b=q_11_descriptors_4_peek(&input);uint64_t number=11;uint64_t const*value=&number;uint64_t const*out=q_11_descriptors_7_pointer(&value);return a.p!=data||b.p!=data||a.n!=2||b.n!=2||*out!=11;}\n").unwrap();
    for file in ["descriptors.c", "descriptors.ll"] {
        for level in ["-O0", "-O2"] {
            let exe = dir.join("run");
            run(Command::new("clang")
                .args([level, "-Werror", "-Wno-override-module"])
                .arg(dir.join(file))
                .arg(dir.join("main.c"))
                .arg("-o")
                .arg(&exe));
            run(&mut Command::new(exe));
        }
    }
    fs::remove_dir_all(dir).unwrap();
}

#[test]
#[ignore = "requires clang allocator wrapping and optimizing ASan/UBSan; optional configured TinyCC"]
fn cursor_cleanup_frees_frames_while_long_sources_and_short_reborrows_stay_valid() {
    let backend = std::env::var("GRAIL_CAPTURE_AUDIT_BACKEND").unwrap_or_else(|_| "clang".into());
    assert!(matches!(backend.as_str(), "clang" | "tcc"));
    let dir = dir();
    for (name, text) in [
        ("views", include_str!("../examples/captures/views.grl")),
        (
            "use_views",
            include_str!("../examples/captures/use_views.grl"),
        ),
    ] {
        fs::write(dir.join(format!("{name}.grl")), text).unwrap();
        compile(&dir, name, false, &backend);
        fs::remove_file(dir.join(format!("{name}.grl"))).unwrap();
    }
    let p = grail_seed::artifact::load(&dir, "views").unwrap();
    let c = grail_seed::artifact::load(&dir, "use_views").unwrap();
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_9_use_views_3_run(void),g_free_count(void),g_freed(uint64_t);int main(void){if(q_9_use_views_3_run()!=36||g_free_count()!=3)return 90;uint64_t order[]={2,3,1};for(unsigned i=0;i<3;++i)if(g_freed(i)!=order[i])return 91;return 0;}\n").unwrap();
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

#[test]
#[ignore = "requires clang allocator wrapping, optimizing sanitizers; optionally configured TinyCC"]
fn hidden_mutable_cells_transfer_captures_and_destroy_owners_once() {
    let backend = std::env::var("GRAIL_CAPTURE_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let other = if std::env::var_os("GRAIL_CAPTURE_MIXED_BACKEND").is_some() {
        if backend == "tcc" {
            "clang-release"
        } else {
            "tcc"
        }
    } else {
        &backend
    };
    let dir = dir();
    fs::write(dir.join("core.grl"), include_str!("../std/core.grl")).unwrap();
    compile(&dir, "core", false, &backend);
    fs::remove_file(dir.join("core.grl")).unwrap();
    fs::write(
        dir.join("cells.grl"),
        include_str!("../examples/mutable_captures/cells.grl"),
    )
    .unwrap();
    compile(&dir, "cells", false, &backend);
    fs::remove_file(dir.join("cells.grl")).unwrap();
    fs::write(
        dir.join("use_cells.grl"),
        include_str!("../examples/mutable_captures/use_cells.grl"),
    )
    .unwrap();
    compile(&dir, "use_cells", true, other);
    assert_eq!(
        run(&mut Command::new(dir.join("use_cells"))).stdout,
        b"46\n"
    );
    let binary = fs::read(dir.join("use_cells")).unwrap();
    let artifact = fs::read(dir.join("use_cells.artifact")).unwrap();
    compile(&dir, "use_cells", true, other);
    assert_eq!(binary, fs::read(dir.join("use_cells")).unwrap());
    assert_eq!(artifact, fs::read(dir.join("use_cells.artifact")).unwrap());
    assert!(grail_seed::artifact::templates(&dir, "cells").is_ok());
    let core = grail_seed::artifact::load(&dir, "core").unwrap();
    let p = grail_seed::artifact::load(&dir, "cells").unwrap();
    let c = grail_seed::artifact::load(&dir, "use_cells").unwrap();
    fs::write(
        dir.join("allocator.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_9_use_cells_3_run(void),g_free_count(void),g_freed(uint64_t);int main(void){if(q_9_use_cells_3_run()!=46||g_free_count()!=6)return 90;uint64_t order[]={3,4,5,6,2,1};for(unsigned i=0;i<6;++i)if(g_freed(i)!=order[i])return 91;return 0;}\n").unwrap();
    fs::write(dir.join("native.c"),"#include <stdint.h>\nuint64_t q_9_use_cells_3_run(void),g_live(void);int main(void){return q_9_use_cells_3_run()!=46||g_live()!=0;}\n").unwrap();
    run(Command::new("clang")
        .args(["-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
        .arg(&core.object)
        .arg(&p.object)
        .arg(&c.object)
        .arg(dir.join("native.c"))
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
        .arg(core.object.with_extension("c"))
        .arg(p.object.with_extension("c"))
        .arg(c.object.with_extension("c"))
        .arg(dir.join("main.c"))
        .arg(dir.join("allocator.c"))
        .arg("-o")
        .arg(dir.join("sanitize")));
    run(&mut Command::new(dir.join("sanitize")));
    fs::remove_dir_all(dir).unwrap();
}
#[test]
#[ignore = "requires clang and LLVM mutable descriptor/pointer ABI"]
fn captured_unique_exchange_runs_in_c_and_llvm() {
    let dir = dir();
    let text = "module swaps;pub fn span<outer,data>(slot:ref_mut<outer,mut<data>>,v:mut<data>)->mut<data>{return exchange(slot,v);}pub fn pointer<outer,data>(slot:ref_mut<outer,ref_mut<data,num>>,v:ref_mut<data,num>)->ref_mut<data,num>{return exchange(slot,v);}";
    let p = grail_seed::source::compile(text, Default::default()).unwrap();
    fs::write(dir.join("swaps.c"), grail_seed::emit::module_c(&p).unwrap()).unwrap();
    fs::write(
        dir.join("swaps.ll"),
        grail_seed::emit::module_llvm(&p).unwrap(),
    )
    .unwrap();
    fs::write(dir.join("main.c"),"#include <stdint.h>\ntypedef struct{uint8_t*p;uint64_t n;}gv;gv q_5_swaps_4_span(gv*,gv);uint64_t*q_5_swaps_7_pointer(uint64_t**,uint64_t*);int main(void){uint8_t a[]={7},b[]={8};gv slot={a,1},next={b,1},old=q_5_swaps_4_span(&slot,next);uint64_t x=3,y=4,*p=&x,*q=q_5_swaps_7_pointer(&p,&y);return old.p!=a||slot.p!=b||old.n!=1||slot.n!=1||q!=&x||p!=&y;}\n").unwrap();
    for file in ["swaps.c", "swaps.ll"] {
        for level in ["-O0", "-O2"] {
            run(Command::new("clang")
                .args([level, "-Werror", "-Wno-override-module"])
                .arg(dir.join(file))
                .arg(dir.join("main.c"))
                .arg("-o")
                .arg(dir.join("run")));
            run(&mut Command::new(dir.join("run")));
        }
    }
    fs::remove_dir_all(dir).unwrap();
}
