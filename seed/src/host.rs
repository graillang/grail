//! Trusted Linux FFI primitives, not checked Grail bodies or compiler logic.
//! `arg` out of range and read/print failures abort. Write returns errno (zero on success).
//! Command consumes every argument: exit code, 128+signal, or 256+errno for setup/wait
//! errors; exec failure exits 127. Paths and command arguments reject embedded NUL.
use crate::{Mode, Sig, Ty, artifact, module::Interface};
use std::{collections::BTreeMap, fs, path::Path, process::Command};

pub fn interface() -> Interface {
    let read = |r| Ty::View(Mode::Read, r);
    let exports = [
        ("argc", vec![], Ty::Num),
        ("arg", vec![Ty::Num], Ty::Bytes),
        ("read_file", vec![read(0)], Ty::Bytes),
        ("write_file", vec![read(0), read(1)], Ty::Num),
        ("print", vec![read(0)], Ty::Unit),
        ("command", vec![Ty::Vector(Box::new(Ty::Bytes))], Ty::Num),
    ]
    .into_iter()
    .map(|(member, params, result)| {
        let name = format!("host::{member}");
        (
            name.clone(),
            Sig {
                name,
                params,
                result,
            },
        )
    })
    .collect();
    Interface {
        name: "host".into(),
        entry: Some("host::argc".into()),
        exports,
        generics: BTreeMap::new(),
        layouts: BTreeMap::new(),
        dependencies: BTreeMap::new(),
        implementations: BTreeMap::new(),
        template_hash: None,
    }
}

/// Explicit clang only; compile in a stable, absolute work directory before atomic publication.
pub fn publish(out: &Path, compiler: &str) -> Result<artifact::Snapshot, String> {
    if !cfg!(target_os = "linux") {
        return Err("host runtime requires Linux".into());
    }
    let opt = match compiler {
        "clang" => "-O0",
        "clang-release" => "-O2",
        _ => return Err("host compiler must be clang or clang-release".into()),
    };
    let work = artifact::Work::new(out)?;
    let source = include_bytes!("host_runtime.c");
    fs::write(work.path.join("host.c"), source).map_err(|e| e.to_string())?;
    let result = Command::new("clang")
        .args([
            "-std=c11", opt, "-Wall", "-Wextra", "-Werror", "-c", "host.c", "-o", "host.o",
        ])
        .current_dir(&work.path)
        .output()
        .map_err(|e| format!("clang: {e}"))?;
    if !result.status.success() {
        return Err(format!(
            "host clang failed: {}",
            String::from_utf8_lossy(&result.stderr)
        ));
    }
    artifact::publish(
        out,
        &interface(),
        source,
        &fs::read(work.path.join("host.o")).map_err(|e| e.to_string())?,
    )
}
