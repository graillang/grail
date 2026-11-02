//! Independent backend: Grail source -> x86-64 assembly -> GNU as -> native executable.
#![cfg(all(target_os = "linux", target_arch = "x86_64"))]
use std::{
    fs,
    path::{Path, PathBuf},
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
fn run(c: &mut Command) -> Output {
    let o = c.output().unwrap();
    assert!(
        o.status.success(),
        "{c:?}: {:?}\n{}{}",
        o.status,
        String::from_utf8_lossy(&o.stdout),
        String::from_utf8_lossy(&o.stderr)
    );
    o
}
fn seed() -> Command {
    Command::new(env!("CARGO_BIN_EXE_grail-seed"))
}
fn root_runtime() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../compiler/runtime.grl")
}
fn assemble(w: &Path, compiler: &Path, sources: &[PathBuf]) -> PathBuf {
    let asm = w.join("program.s");
    let obj = w.join("program.o");
    let exe = w.join("program");
    run(Command::new(compiler)
        .arg(&asm)
        .args(sources)
        .arg(root_runtime()));
    run(Command::new("as").arg("-o").arg(&obj).arg(&asm));
    run(Command::new("ld").arg(&obj).arg("-o").arg(&exe));
    exe
}
#[test]
#[ignore = "requires Linux x86-64, clang for the legacy bootstrap check, GNU as and ld"]
fn independent_native_backend_selfhosts_and_matches_seed() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let w = std::env::temp_dir().join(format!(
        "grail-native-codegen-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&w).unwrap();
    run(seed().arg("host").arg(&w));
    run(seed()
        .arg("compile")
        .arg(root.join("compiler/lexer.grl"))
        .arg(&w)
        .arg(&w));
    run(seed()
        .arg("compile")
        .arg(root.join("compiler/ownership.grl"))
        .arg(&w)
        .arg(&w));
    run(seed()
        .arg("build")
        .arg(root.join("compiler/native.grl"))
        .arg(&w)
        .arg(&w));
    let compiler = w.join("native");
    let sources = [
        root.join("compiler/native.grl"),
        root.join("compiler/lexer.grl"),
        root.join("compiler/ownership.grl"),
    ];
    // Native stage 2 and 3, including equality with the delivered assembly bootstrap.
    let native2 = assemble(&w, &compiler, &sources);
    let stage2 = w.join("native2");
    fs::copy(native2, &stage2).unwrap();
    let assembly2 = fs::read(w.join("program.s")).unwrap();
    let native3 = assemble(&w, &stage2, &sources);
    let stage3 = w.join("native3");
    fs::copy(native3, &stage3).unwrap();
    assert_eq!(
        assembly2,
        fs::read(w.join("program.s")).unwrap(),
        "native stage 2/3 differ"
    );
    assert_eq!(
        assembly2,
        fs::read(root.join("compiler/bootstrap/native.s")).unwrap(),
        "native bootstrap artifact is stale"
    );
    // The existing C bootstrap can also build the native compiler: no Rust dependency.
    let c_boot = w.join("c_boot");
    run(Command::new("cc")
        .arg("-O1")
        .arg("-I")
        .arg(root.join("compiler"))
        .arg(root.join("compiler/bootstrap/grailc.c"))
        .arg("-o")
        .arg(&c_boot));
    let native_c = w.join("native.c");
    run(Command::new(&c_boot).arg(&native_c).args(&sources));
    let from_c = w.join("from_c");
    run(Command::new("cc")
        .arg("-O1")
        .arg("-I")
        .arg(root.join("compiler"))
        .arg(&native_c)
        .arg("-o")
        .arg(&from_c));
    assemble(&w, &from_c, &sources);
    assert_eq!(
        assembly2,
        fs::read(w.join("program.s")).unwrap(),
        "C-bootstrap and seed-built native backends differ"
    );
    let compiler = stage3;
    let example = root.join("compiler/examples/native_numbers.grl");
    let exe = assemble(&w, &compiler, std::slice::from_ref(&example));
    assert_eq!(run(&mut Command::new(exe)).stdout, b"171\n");
    run(seed().arg("build").arg(&example).arg(&w).arg(&w));
    assert_eq!(
        run(&mut Command::new(w.join("native_numbers"))).stdout,
        b"171\n"
    );
    let asm = fs::read_to_string(w.join("program.s")).unwrap();
    assert!(asm.contains("divq %rcx") && asm.contains("call f_native_numbers_fib"));
    assert!(!asm.contains("#include"));
    // Aborts are explicit native guards, including unsigned remainder by zero.
    for source in [
        "module probe;pub fn run()->num{return 42%0;}",
        "module probe;pub fn run()->num{assert(0);return 0;}",
    ] {
        let src = w.join("probe.grl");
        fs::write(&src, source).unwrap();
        let exe = assemble(&w, &compiler, &[src]);
        use std::os::unix::process::ExitStatusExt;
        assert_eq!(Command::new(exe).output().unwrap().status.signal(), Some(6));
    }
    // Unknown types must fail, rather than silently emitting numeric code.
    let bad = w.join("bad.grl");
    fs::write(
        &bad,
        "module bad;pub fn run(x:unknown_type)->num{return 0;}",
    )
    .unwrap();
    assert!(!Command::new(&compiler)
        .arg(w.join("bad.s"))
        .arg(bad)
        .output()
        .unwrap()
        .status
        .success());
    // Native-built C backend must still reproduce the checked-in C bootstrap too.
    let c_sources = [
        root.join("compiler/grailc.grl"),
        root.join("compiler/lexer.grl"),
    ];
    let executable = assemble(&w, &compiler, &c_sources);
    let c_output = w.join("reproduced.c");
    run(Command::new(executable).arg(&c_output).args(&c_sources));
    assert_eq!(
        fs::read(c_output).unwrap(),
        fs::read(root.join("compiler/bootstrap/grailc.c")).unwrap()
    );
    let raw = w.join("raw.grl");
    fs::write(&raw, "module raw;pub fn run()->num{return raw_load(0);}").unwrap();
    assert!(!Command::new(&compiler)
        .arg(w.join("raw.s"))
        .arg(raw)
        .arg(root_runtime())
        .output()
        .unwrap()
        .status
        .success());
    // Cross-module calls, loops, record fields and enum recovery against the checked seed.
    let cases: &[(&[&str], Option<&str>)] = &[
        (&["loops/cleanup"], None),
        (&["records/unique"], None),
        (&["modules/middle", "modules/arithmetic"], None),
        (
            &["enums/recover", "enums/number", "enums/result"],
            Some("42"),
        ),
        (
            &["enums/unwrap", "enums/number", "enums/result"],
            Some("4x2"),
        ),
    ];
    for (modules, arg) in cases {
        let files = modules
            .iter()
            .map(|m| root.join(format!("seed/examples/{m}.grl")))
            .collect::<Vec<_>>();
        for dep in files[1..].iter().rev() {
            run(seed().arg("compile").arg(dep).arg(&w).arg(&w));
        }
        run(seed().arg("build").arg(&files[0]).arg(&w).arg(&w));
        let name = Path::new(modules[0]).file_name().unwrap();
        let expected = run(Command::new(w.join(name)).args(*arg)).stdout;
        let exe = assemble(&w, &compiler, &files);
        assert_eq!(
            run(Command::new(exe).args(*arg)).stdout,
            expected,
            "{modules:?}"
        );
    }
    let audit = assemble(
        &w,
        &compiler,
        &[root.join("compiler/tests/runtime_audit.grl")],
    );
    assert_eq!(run(&mut Command::new(audit)).stdout, b"0\n");
    // The ownership graph is checked and executed by both independent compiler paths.
    run(seed()
        .arg("compile")
        .arg(root.join("compiler/ownership.grl"))
        .arg(&w)
        .arg(&w));
    run(seed()
        .arg("build")
        .arg(root.join("compiler/tests/ownership_core.grl"))
        .arg(&w)
        .arg(&w));
    assert_eq!(
        run(&mut Command::new(w.join("ownership_core"))).stdout,
        b"1\n"
    );
    let core = assemble(
        &w,
        &compiler,
        &[
            root.join("compiler/tests/ownership_core.grl"),
            root.join("compiler/ownership.grl"),
        ],
    );
    assert_eq!(run(&mut Command::new(core)).stdout, b"1\n");
    run(seed()
        .arg("build")
        .arg(root.join("compiler/tests/generic_types.grl"))
        .arg(&w)
        .arg(&w));
    assert_eq!(
        run(&mut Command::new(w.join("generic_types"))).stdout,
        b"818\n"
    );
    let generics = assemble(
        &w,
        &compiler,
        &[root.join("compiler/tests/generic_types.grl")],
    );
    assert_eq!(run(&mut Command::new(generics)).stdout, b"818\n");
    let inferred = w.join("inferred_generic.grl");
    fs::write(&inferred,"module inferred_generic;struct Pair<type T,type U>{first:T,second:U}enum Option<type T>{Some(T),None}pub fn run()->num{let p=Pair{first:bytes(),second:17};let some=Option::Some(bytes());match some{Some(b)=>{assert(len(b)==0);},None=>{assert(0);}}let q=generic_types::Pair<num,bytes>{first:p.second,second:bytes()};return q.first;}").unwrap();
    let inferred = assemble(
        &w,
        &compiler,
        &[inferred, root.join("compiler/tests/generic_types.grl")],
    );
    assert_eq!(run(&mut Command::new(inferred)).stdout, b"17\n");
    for body in [
        "struct Box<type T>{value:T}fn take(b:Box<bytes>)->num{return len(b.value);}pub fn run()->num{return take(Box<num>{value:1});}",
        "struct Pair<type T>{first:T,second:T}pub fn run()->num{let p=Pair{first:1,second:bytes()};return 0;}",
        "enum Option<type T>{Some(T),None}pub fn run()->num{let x=Option::None;return 0;}",
        "struct Box<type T>{value:T}fn bad<a>()->Box<read<a>>{let b=bytes();return Box{value:read(b)};}pub fn run()->num{return 0;}",
        "struct Pair<type T>{first:T,second:T}pub fn run()->num{let b=bytes();let p=Pair{first:b,second:b};return 0;}",
        "struct Refs<a,type T>{r:ref_mut<a,T>}fn bad<a>(r:ref<a,num>)->num{let b=Refs{r:r};return 0;}pub fn run()->num{return 0;}",
        "struct Pair<type T,type U>{first:T,second:U}pub fn run()->num{let b=bytes();let p=Pair{first:read(b),second:mut(b)};return 0;}",
        "fn noop()->num{return 0;}fn conflict<a,b>(x:ref_mut<a,bytes>,n:num,y:read<b>)->num{return 0;}pub fn run()->num{let b=bytes();return conflict(borrow_mut(b),noop(),read(b));}",
    ] {
        let src = w.join("bad_generic.grl");
        fs::write(&src, format!("module bad_generic;{body}")).unwrap();
        let output = w.join("bad_generic.s");
        fs::write(&output, b"prior valid artifact").unwrap();
        let result = Command::new(&compiler)
            .arg(&output)
            .arg(&src)
            .arg(root_runtime())
            .output()
            .unwrap();
        assert!(!result.status.success(), "accepted invalid generic: {body}");
        assert_eq!(fs::read(&output).unwrap(), b"prior valid artifact");
    }
    run(seed()
        .arg("build")
        .arg(root.join("compiler/tests/generic_functions.grl"))
        .arg(&w)
        .arg(&w));
    assert_eq!(
        run(&mut Command::new(w.join("generic_functions"))).stdout,
        b"919\n"
    );
    let functions = assemble(
        &w,
        &compiler,
        &[root.join("compiler/tests/generic_functions.grl")],
    );
    assert_eq!(run(&mut Command::new(functions)).stdout, b"919\n");
    let imported = w.join("imported_generic.grl");
    fs::write(&imported,"module imported_generic;use generic_functions;pub fn run()->num{let b=generic_functions::identity<bytes>(bytes());return len(b)+33;}").unwrap();
    let imported = assemble(
        &w,
        &compiler,
        &[imported, root.join("compiler/tests/generic_functions.grl")],
    );
    assert_eq!(run(&mut Command::new(imported)).stdout, b"33\n");
    for body in [
        "fn bad<type T>(x:T)->T{let y=x;return x;}pub fn run()->num{return bad(7);}",
        "fn bad<type T>(x:T)->T{return x+x;}pub fn run()->num{return bad(7);}",
        "fn unused<type T>(x:T)->T{let y=x;return x;}pub fn run()->num{return 0;}",
        "fn unused<type T>(x:T)->num{return x+1;}pub fn run()->num{return 0;}",
        "fn wrong<type T,type U>(x:T,y:U)->T{return y;}pub fn run()->num{return wrong(1,2);}",
        "fn id<type T>(x:T)->T{return x;}fn bad<a>()->read<a>{let b=bytes();return id(read(b));}pub fn run()->num{return 0;}",
        "fn id<type T>(x:T)->T{return x;}pub fn run()->num{let b=bytes();let v=id(read(b));push(b,1);return len(v);}",
        "fn bad<type T>(x:T)->T{return load(borrow(x));}pub fn run()->num{return bad(1);}",
        "fn phantom<type T>()->num{return 0;}pub fn run()->num{return phantom();}",
    ] {
        let src=w.join("bad_generic_fn.grl");fs::write(&src,format!("module bad_generic_fn;{body}")).unwrap();
        let output=w.join("bad_generic_fn.s");fs::write(&output,b"prior valid artifact").unwrap();
        let result=Command::new(&compiler).arg(&output).arg(&src).arg(root_runtime()).output().unwrap();
        assert!(!result.status.success(),"accepted invalid generic function: {body}");
        assert_eq!(fs::read(output).unwrap(),b"prior valid artifact");
    }
    run(seed()
        .arg("build")
        .arg(root.join("compiler/tests/writeback.grl"))
        .arg(&w)
        .arg(&w));
    assert_eq!(run(&mut Command::new(w.join("writeback"))).stdout, b"626\n");
    let writeback = assemble(&w, &compiler, &[root.join("compiler/tests/writeback.grl")]);
    assert_eq!(run(&mut Command::new(writeback)).stdout, b"626\n");
    for body in [
        "fn set<a,b>(r:ref_mut<a,read<b>>,v:read<b>)->num{let old=exchange(r,v);return 0;}fn bad<a,b>(r:ref_mut<a,read<b>>)->num{let local=bytes();return set(r,read(local));}pub fn run()->num{return 0;}",
        "fn replace<a,type T>(r:ref_mut<a,T>,v:T)->T{return exchange(r,v);}fn bad<a,b>(r:ref_mut<a,read<b>>)->num{let local=bytes();let old=replace(r,read(local));return 0;}pub fn run()->num{return 0;}",
        "struct Cell<a>{v:read<a>}fn bad<a,b>(r:ref_mut<a,Cell<b>>)->num{var p=r;let local=bytes();p.v=read(local);return 0;}pub fn run()->num{return 0;}",
        "fn set<a,b>(r:ref_mut<a,read<b>>,v:read<b>)->num{let old=exchange(r,v);return 0;}pub fn run()->num{let a=bytes();let b=bytes();var v=read(a);set(borrow_mut(v),read(b));push(b,1);return len(v);}",
        "fn add<a,b>(r:ref_mut<a,vec<read<b>>>,v:read<b>)->num{vec_push(r,v);return 0;}fn bad<a,b>(r:ref_mut<a,vec<read<b>>>)->num{let local=bytes();return add(r,read(local));}pub fn run()->num{return 0;}",
        "fn pop<a,b>(r:ref_mut<a,vec<read<b>>>)->read<b>{return vec_pop(r);}fn bad<a>()->read<a>{let local=bytes();let v=vec<read<a>>();vec_push(v,read(local));return pop(borrow_mut(v));}pub fn run()->num{return 0;}",
        "pub fn run()->num{let a=bytes();let b=bytes();var v=read(a);v=read(b);push(b,1);return len(v);}",
        "struct Cell<a>{v:read<a>}fn access<a,b>(r:ref_mut<a,Cell<b>>)->ref_mut<a,read<b>>{return borrow_mut(r.v);}pub fn run()->num{let a=bytes();let b=bytes();var p=Cell{v:read(a)};let old=exchange(access(borrow_mut(p)),read(b));drop(old);push(b,1);return len(p.v);}",
        "struct Cell<a>{v:read<a>}fn access<a,b>(r:ref_mut<a,Cell<b>>)->ref_mut<a,read<b>>{return borrow_mut(r.v);}fn bad<a,b>(r:ref_mut<a,Cell<b>>)->num{let local=bytes();let old=exchange(access(r),read(local));return 0;}pub fn run()->num{return 0;}",
    ] {
        let src=w.join("bad_writeback.grl");fs::write(&src,format!("module bad_writeback;{body}")).unwrap();
        let output=w.join("bad_writeback.s");fs::write(&output,b"prior valid artifact").unwrap();
        let result=Command::new(&compiler).arg(&output).arg(&src).arg(root_runtime()).output().unwrap();
        assert!(!result.status.success(),"accepted invalid writeback: {body}");
        assert_eq!(fs::read(output).unwrap(),b"prior valid artifact");
    }
    let cleanup = assemble(&w, &compiler, &[root.join("compiler/tests/cleanup.grl")]);
    assert_eq!(run(&mut Command::new(cleanup)).stdout, b"777\n");
    let rejected = [
        "let b=bytes();let moved=b;return len(b);",
        "let b=bytes();drop(b);drop(b);return 0;",
        "let b=bytes();if 1{let moved=b;}return len(b);",
        "let b=bytes();while 1{let moved=b;continue;}return 0;",
        "var b:bytes;return len(b);",
        "let b=bytes();while 1{let moved=b;}return 0;",
        "return missing(1);",
        "return 1+bytes();",
    ];
    for body in rejected {
        let src = w.join("rejected.grl");
        fs::write(&src, format!("module rejected;pub fn run()->num{{{body}}}")).unwrap();
        let output = w.join("rejected.s");
        fs::write(&output, b"prior valid artifact").unwrap();
        let rejected = Command::new(&compiler)
            .arg(&output)
            .arg(src)
            .arg(root_runtime())
            .output()
            .unwrap();
        assert!(
            !rejected.status.success(),
            "accepted unsafe program: {body}"
        );
        assert_eq!(fs::read(output).unwrap(), b"prior valid artifact");
    }
    run(seed()
        .arg("build")
        .arg(root.join("compiler/tests/borrows.grl"))
        .arg(&w)
        .arg(&w));
    assert_eq!(run(&mut Command::new(w.join("borrows"))).stdout, b"4242\n");
    let borrows = assemble(&w, &compiler, &[root.join("compiler/tests/borrows.grl")]);
    assert_eq!(run(&mut Command::new(borrows)).stdout, b"4242\n");
    let unsafe_sources: &[(&str, &str)] = &[
        (
            "pub fn run()->num{let b=bytes();let r=read(b);drop(b);return len(r);}",
            "drop",
        ),
        (
            "pub fn run()->num{let b=bytes();let r=read(b);push(b,1);return len(r);}",
            "borrow",
        ),
        (
            "pub fn run()->num{let v=vec<num>();vec_push(v,1);let r=vec_get(v,0);vec_push(v,2);return load(r);}",
            "borrow",
        ),
        (
            "pub fn run()->num{let b=bytes();push(b,0);let r=read(b);write(r,0,7);return 0;}",
            "mutable byte view",
        ),
        (
            "pub fn run()->num{var n=1;let r=borrow(n);exchange(r,2);return n;}",
            "readonly",
        ),
        (
            "pub fn run()->num{var n=1;let r=borrow_mut(n);let q=borrow(n);return load(r)+load(q);}",
            "borrow",
        ),
        (
            "fn bad<a>()->read<a>{let b=bytes();return read(b);}pub fn run()->num{return 0;}",
            "escapes",
        ),
        (
            "fn bad<a>()->ref<a,num>{var n=7;return borrow(n);}pub fn run()->num{return 0;}",
            "escapes",
        ),
        (
            "fn bad<a,b>(x:read<a>)->read<b>{return x;}pub fn run()->num{return 0;}",
            "escapes",
        ),
        (
            "struct R<a>{s:read<a>}fn bad<a>()->R<a>{let b=bytes();return R{s:read(b)};}pub fn run()->num{return 0;}",
            "escapes",
        ),
        (
            "struct R<a>{s:read<a>}fn bad<a>()->vec<R<a>>{let b=bytes();let v=vec<R<a>>();vec_push(v,R{s:read(b)});return v;}pub fn run()->num{return 0;}",
            "escapes",
        ),
        (
            "struct R<a>{s:read<a>}pub fn run()->num{let b=bytes();let r=R{s:read(b)};drop(b);return len(r.s);}",
            "drop",
        ),
        (
            "pub fn run<a>()->num{let v=vec<read<a>>();{let b=bytes();vec_push(v,read(b));}return len(v);}",
            "cleanup",
        ),
        (
            "struct R{b:bytes}pub fn run()->num{var r=R{b:bytes()};let v=read(r.b);r.b=bytes();return len(v);}",
            "borrow",
        ),
        (
            "struct P<a>{s:mut<a>}pub fn run()->num{let b=bytes();let p=P{s:mut(b)};let q=read(p.s);let other=p;return len(q);}",
            "suspended",
        ),
        (
            "struct P<a>{s:mut<a>}fn peek<o,d>(p:ref<o,P<d>>)->num{return at(read(p.s),0);}pub fn run()->num{let b=bytes();push(b,1);let p=P{s:mut(b)};let q=mut(p.s);let r=borrow(p);let n=peek(r);write(q,0,2);return n;}",
            "suspended",
        ),
        (
            "fn freeze<a>(r:ref_mut<a,bytes>)->ref<a,bytes>{return borrow(r);}pub fn run()->num{var b=bytes();let r=freeze(borrow_mut(b));push(r,1);return 0;}",
            "readonly",
        ),
        (
            "struct I{n:num}struct O{left:I,right:I}fn choose<a>(r:ref<a,O>)->ref<a,I>{return borrow(r.right);}pub fn run()->num{var p=O{left:I{n:1},right:I{n:2}};let r=choose(borrow(p));let c=borrow(r.n);drop(r);p.right=I{n:8};return load(c);}",
            "borrow",
        ),
        (
            "fn bad<a,b,c>(v:ref_mut<a,vec<read<b>>>,r:read<c>)->unit{vec_push(v,r);return ();}pub fn run()->num{return 0;}",
            "writeback",
        ),
        (
            "pub fn run()->num{var b=bytes();exchange(borrow_mut(b),1);return len(b);}",
            "type mismatch",
        ),
        (
            "struct R{b:bytes}pub fn run()->num{let r=R{};return 0;}",
            "omits fields",
        ),
        (
            "struct R{b:bytes}pub fn run()->num{let r=R{b:bytes(),b:bytes()};return 0;}",
            "duplicate",
        ),
        (
            "enum E{A(num),B(num),C(bytes)}pub fn run()->num{let e=E{A:2,B:1,C:bytes()};return 0;}",
            "variant constructor",
        ),
        (
            "struct R{a:bytes,b:num}pub fn run()->num{let r=R::b(1);return 0;}",
            "requires enum",
        ),
        (
            "enum E{Some(bytes),None}pub fn run()->num{let e=E::Some(bytes());return len(e.Some);}",
            "requires match",
        ),
        (
            "struct R{x:num,y:num}pub fn run()->num{return 1!;}",
            "requires enum",
        ),
        ("pub fn run()->num{return load(1);}", "typed reference"),
        (
            "struct R{n:num}pub fn run()->num{let r=R{n:7};return len(read(r.n));}",
            "requires sequence",
        ),
        ("pub fn run()->num{var n:num;return n;}", "initialized"),
        ("pub fn run()->num{let n=1;n=2;return n;}", "requires var"),
        ("pub fn run()->num{let n=1;}", "fall through"),
        (
            "fn addr<a>(r:ref<a,read<a>>)->ref<a,read<a>>{return r;}fn bad<a>()->read<a>{let b=bytes();let v=read(b);return load(addr(borrow(v)));}pub fn run()->num{return 0;}",
            "escapes",
        ),
    ];
    for (source, diagnostic) in unsafe_sources {
        let input = w.join("unsafe_source.grl");
        fs::write(&input, format!("module unsafe_source;{source}")).unwrap();
        let output = w.join("unsafe_source.s");
        fs::write(&output, b"prior valid artifact").unwrap();
        let result = Command::new(&compiler)
            .arg(&output)
            .arg(input)
            .arg(root_runtime())
            .output()
            .unwrap();
        assert!(!result.status.success(), "accepted: {source}");
        assert!(
            String::from_utf8_lossy(&result.stdout).contains(diagnostic),
            "wrong rejection for {source}: {}",
            String::from_utf8_lossy(&result.stdout)
        );
        assert_eq!(fs::read(output).unwrap(), b"prior valid artifact");
    }
    // Execute binary I/O, argv, malformed paths and process status on the Grail runtime.
    let exe = assemble(
        &w,
        &compiler,
        &[root.join("compiler/examples/native_io.grl")],
    );
    let input = w.join("input ; literal.bin");
    let output = w.join("output.bin");
    fs::write(&input, [0, 1, 128, 0, 255]).unwrap();
    let io = run(Command::new(exe).arg(&input).arg(&output).arg(""));
    assert_eq!(io.stdout, [0, 1, 128, 0, 255, b'1', b'9', b'\n']);
    assert_eq!(fs::read(output).unwrap(), [0, 1, 128, 0, 255]);
    fs::remove_dir_all(w).unwrap();
}
