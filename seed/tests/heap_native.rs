#![cfg(target_os = "linux")]
//! An allocator wrapper checks ownership behavior independently of the checker's abstract state.
use std::{
    fs,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
const AUDIT: &str = r#"
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
void *__real_malloc(size_t);
void *__real_realloc(void*,size_t);
void __real_free(void*);
static long live;
static void *slots[4096];
static unsigned ids[4096], serial, last, previous;
static unsigned find(void*p) {for(unsigned i=0;i<4096;++i)if(slots[i]==p)return i;abort();}
static void track(void*p) {if(!p)return;for(unsigned i=0;i<4096;++i)if(!slots[i]){slots[i]=p;ids[i]=++serial;++live;return;}abort();}
void *__wrap_malloc(size_t n) {void*p=__real_malloc(n);track(p);return p;}
void *__wrap_realloc(void*p,size_t n) {int fresh=p==0;unsigned slot=fresh?0:find(p);void*q=__real_realloc(p,n);if(q){if(fresh)track(q);else slots[slot]=q;}return q;}
void __wrap_free(void*p) {if(p){unsigned i=find(p);previous=last;last=ids[i];slots[i]=0;--live;}__real_free(p);if(live<0)abort();}
uint64_t g_live(void){return (uint64_t)live;}
__attribute__((destructor)) static void check_leaks(void){if(live || previous!=2 || last!=1)abort();}
"#;
#[test]
#[ignore = "requires Linux clang and GNU-compatible linker --wrap"]
fn returned_cloned_and_loop_local_owners_are_freed_once_at_scope_exit() {
    let dir = std::env::temp_dir().join(format!(
        "grail-heap-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let producer = dir.join("make.grl");
    fs::write(&producer, include_str!("../examples/make_bytes.grl")).unwrap();
    let client = dir.join("use.grl");
    fs::write(&client, include_str!("../examples/use_bytes.grl")).unwrap();
    let binary = env!("CARGO_BIN_EXE_grail-seed");
    for (mode, file) in [("compile", &producer), ("build", &client)] {
        let p = Command::new(binary)
            .args([
                mode,
                file.to_str().unwrap(),
                dir.to_str().unwrap(),
                dir.to_str().unwrap(),
            ])
            .output()
            .unwrap();
        assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
        if mode == "compile" {
            fs::remove_file(file).unwrap();
        }
    }
    let audit = dir.join("audit.c");
    fs::write(&audit, AUDIT).unwrap();
    let p = Command::new("clang")
        .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
        .arg(dir.join("use_bytes.c"))
        .arg(dir.join("make.c"))
        .arg(dir.join("use_bytes-main.c"))
        .arg(&audit)
        .arg("-o")
        .arg(dir.join("audited"))
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    let p = Command::new(dir.join("audited")).output().unwrap();
    assert!(
        p.status.success(),
        "heap error: {}",
        String::from_utf8_lossy(&p.stderr)
    );
    assert_eq!(p.stdout, b"125717\n");
    // Observe scope lifetimes from a declared, test-only numeric function. Unused owners must
    // remain live until block exit, rather than being freed by borrowed-value last-use cleanup.
    let live = grail_seed::Sig {
        name: "live".into(),
        params: vec![],
        result: grail_seed::Ty::Num,
    };
    fs::write(dir.join("live.api"), live.encode().unwrap()).unwrap();
    let scope = dir.join("scope.grl");
    fs::write(&scope,"use live; fn scope()->num {let a=bytes();push(a,1);let b=copy_bytes(a);assert(live()==2);for i in 20 {let c=bytes();push(c,i);assert(live()==3);}assert(live()==2);if 1 {let d=bytes();push(d,4);assert(live()==3);}assert(live()==2);return 0;}").unwrap();
    let p = Command::new(binary)
        .args([
            "compile",
            scope.to_str().unwrap(),
            dir.to_str().unwrap(),
            dir.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    fs::write(
        dir.join("scope-main.c"),
        "#include <stdint.h>\nuint64_t g_scope(void);int main(void){return (int)g_scope();}",
    )
    .unwrap();
    let p = Command::new("clang")
        .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
        .arg(dir.join("scope.c"))
        .arg(dir.join("scope-main.c"))
        .arg(&audit)
        .arg("-o")
        .arg(dir.join("scope"))
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    let p = Command::new(dir.join("scope")).output().unwrap();
    assert!(
        p.status.success(),
        "scope cleanup failed: {}",
        String::from_utf8_lossy(&p.stderr)
    );
    fs::remove_dir_all(dir).unwrap();
}
