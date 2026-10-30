#![cfg(target_os = "linux")]
//! Differential UTF-8 validity, including malformed argv bytes; no invalid pointer is fabricated.
use std::{
    ffi::OsString,
    fs,
    os::{unix::ffi::OsStringExt, unix::process::ExitStatusExt},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
#[test]
#[ignore = "requires Linux clang and bash; runs generated text code"]
fn utf8_constructor_matches_rust_and_owned_calls_preserve_data() {
    let dir = std::env::temp_dir().join(format!(
        "grail-text-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let binary = env!("CARGO_BIN_EXE_grail-seed");
    let backend = std::env::var("GRAIL_NATIVE_TEST_BACKEND").unwrap_or_else(|_| "clang".into());
    let echo = dir.join("echo.grl");
    let app = dir.join("text.grl");
    fs::write(&echo, include_str!("../examples/echo_text.grl")).unwrap();
    fs::write(&app, include_str!("../examples/text_check.grl")).unwrap();
    for (mode, file) in [("compile", &echo), ("build", &app)] {
        let p = Command::new(binary)
            .args([
                mode,
                file.to_str().unwrap(),
                dir.to_str().unwrap(),
                dir.to_str().unwrap(),
                &backend,
            ])
            .output()
            .unwrap();
        assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
        if mode == "compile" {
            fs::remove_file(file).unwrap();
        }
    }
    let cases: Vec<Vec<u8>> = vec![
        vec![],
        b"hello".to_vec(),
        "hé🙂".as_bytes().to_vec(),
        vec![1, 10, 127],
        vec![0xc2, 0x80],
        vec![0xdf, 0xbf],
        vec![0xe0, 0xa0, 0x80],
        vec![0xed, 0x9f, 0xbf],
        vec![0xee, 0x80, 0x80],
        vec![0xef, 0xbf, 0xbf],
        vec![0xf0, 0x90, 0x80, 0x80],
        vec![0xf4, 0x8f, 0xbf, 0xbf],
        vec![0x80],
        vec![0xc0, 0x80],
        vec![0xc1, 0xbf],
        vec![0xc2],
        vec![0xe0, 0x9f, 0xbf],
        vec![0xed, 0xa0, 0x80],
        vec![0xed, 0xbf, 0xbf],
        vec![0xe1, 0x80],
        vec![0xe1, 65, 0x80],
        vec![0xf0, 0x8f, 0xbf, 0xbf],
        vec![0xf4, 0x90, 0x80, 0x80],
        vec![0xf5, 0x80, 0x80, 0x80],
        vec![0xff],
        vec![0xf0, 0x90, 0x80],
    ];
    for data in cases {
        let valid = std::str::from_utf8(&data).is_ok();
        let p = Command::new("bash")
            .args(["-c", "ulimit -c 0; exec \"$@\"", "guard"])
            .arg(dir.join("text_check"))
            .arg(OsString::from_vec(data.clone()))
            .output()
            .unwrap();
        if valid {
            assert!(
                p.status.success(),
                "rejected {data:?}: {}",
                String::from_utf8_lossy(&p.stderr)
            );
            let sum: u64 = data.iter().map(|b| u64::from(*b)).sum::<u64>() + 195 + 169;
            let expected = sum * 257 + data.len() as u64 + 2;
            assert_eq!(
                String::from_utf8(p.stdout).unwrap().trim(),
                expected.to_string(),
                "{data:?}"
            );
        } else {
            assert_eq!(
                p.status.signal(),
                Some(6),
                "invalid UTF-8 must abort: {data:?}"
            );
        }
    }
    // Reuse the independent allocator audit for the distinct String type and owned ABI.
    let audit = dir.join("audit.c");
    fs::write(&audit, include_str!("support/allocator_audit.c")).unwrap();
    let p = Command::new("clang")
        .args(["-O0", "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free"])
        .arg(dir.join("text_check.c"))
        .arg(dir.join("echo_text.c"))
        .arg(dir.join("text_check-main.c"))
        .arg(&audit)
        .arg("-o")
        .arg(dir.join("audited"))
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    let p = Command::new(dir.join("audited"))
        .arg("abc")
        .output()
        .unwrap();
    assert!(
        p.status.success(),
        "string cleanup or ownership transfer failed"
    );
    fs::remove_dir_all(dir).unwrap();
}
