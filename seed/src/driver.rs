//! Source command driver. Interfaces and objects, never provider source, are imported.
use crate::{Mode, Ty, emit, source};
use std::{collections::BTreeMap, fs, path::Path, process::Command};
fn write(path: &Path, text: &str) -> Result<(), String> {
    fs::write(path, text).map_err(|e| format!("{}: {e}", path.display()))
}
fn command(args: &[String], cwd: &Path) -> Result<(), String> {
    let p = Command::new(&args[0])
        .args(&args[1..])
        .current_dir(cwd)
        .output()
        .map_err(|e| e.to_string())?;
    if !p.status.success() {
        return Err(format!(
            "native compiler failed: {}",
            String::from_utf8_lossy(&p.stderr)
        ));
    }
    Ok(())
}
fn native(backend: &str, args: Vec<String>, link: bool, cwd: &Path) -> Result<(), String> {
    let mut cmd = match backend {
        "clang" => vec!["clang".into(), "-O0".into()],
        "tcc" => {
            let root = std::env::var("GRAIL_TCC_ROOT").map_err(
                |_| "tcc requires GRAIL_TCC_ROOT pointing to the configured Goose build",
            )?;
            let root = fs::canonicalize(&root).map_err(|e| e.to_string())?;
            let mut cmd = vec![
                root.join("tcc/tcc").display().to_string(),
                "-B".into(),
                root.join("tcclib").display().to_string(),
                "-I/usr/include".into(),
            ];
            if link {
                cmd.extend([
                    "-L/usr/lib".into(),
                    "-nostdlib".into(),
                    "/usr/lib/crt1.o".into(),
                    "/usr/lib/crti.o".into(),
                ]);
            }
            cmd
        }
        _ => return Err("native backend must be clang or tcc".into()),
    };
    cmd.extend(args);
    if backend == "tcc" && link {
        let root = fs::canonicalize(std::env::var("GRAIL_TCC_ROOT").map_err(|e| e.to_string())?)
            .map_err(|e| e.to_string())?;
        cmd.extend([
            Path::new(&root)
                .join("tcclib/libtcc1.a")
                .display()
                .to_string(),
            "-lc".into(),
            "/usr/lib/crtn.o".into(),
        ]);
    }
    command(&cmd, cwd)
}
pub fn compile(
    file: &Path,
    out: &Path,
    imports: &Path,
    build: bool,
    backend: &str,
) -> Result<(), String> {
    let text = fs::read_to_string(file).map_err(|e| e.to_string())?;
    let names = source::imports(&text)?;
    let mut available = BTreeMap::new();
    for n in &names {
        let sig = crate::artifact::interface(imports, n)?;
        available.insert(n.clone(), sig);
    }
    let checked =
        source::compile(&text, available).map_err(|e| format!("{}: {e}", file.display()))?;
    let linked = if build {
        dependencies(checked.header(), imports)?
    } else {
        Vec::new()
    };
    let name = &checked.header().name;
    fs::create_dir_all(out).map_err(|e| e.to_string())?;
    let work = crate::artifact::Work::new(out)?;
    let c = work.path.join(format!("{name}.c"));
    let object = work.path.join(format!("{name}.o"));
    let text = emit::module_c(&checked);
    write(&c, &text)?;
    native(
        backend,
        vec![
            "-c".into(),
            format!("{name}.c"),
            "-o".into(),
            format!("{name}.o"),
        ],
        false,
        &work.path,
    )?;
    if build {
        let sig = checked.entry_signature();
        let params = match sig.params.as_slice() {
            [] => "void",
            [Ty::View(Mode::Read, _)] => "gv",
            _ => return Err("executable entry needs zero arguments or one read byte view".into()),
        };
        if sig.result != Ty::Num {
            return Err("executable entry must return num".into());
        }
        let symbol = emit::symbol(&sig.name);
        let call = if params == "void" {
            format!("{symbol}()")
        } else {
            format!("{symbol}((gv){{(unsigned char*)argv[1],strlen(argv[1])}})")
        };
        let argc = if params == "void" {
            "(void)argc; (void)argv;"
        } else {
            "if(argc!=2)return 2;"
        };
        let main = work.path.join(format!("{name}-main.c"));
        write(
            &main,
            &format!(
                "#include <stdint.h>\n#include <stdio.h>\n#include <string.h>\ntypedef struct{{unsigned char*p;uint64_t n;}}gv;\nuint64_t {symbol}({params});\nint main(int argc,char**argv){{{argc}printf(\"%llu\\n\",(unsigned long long){call});return 0;}}\n"
            ),
        )?;
        let mut args = vec![format!("{name}-main.c"), format!("{name}.o")];
        for object in &linked {
            args.push(object.display().to_string());
        }
        let binary = work.path.join(format!("{name}.bin"));
        args.extend(["-o".into(), format!("{name}.bin")]);
        native(backend, args, true, &work.path)?;
        crate::artifact::publish(
            out,
            checked.header(),
            text.as_bytes(),
            &fs::read(&object).map_err(|e| e.to_string())?,
        )?;
        fs::rename(main, out.join(format!("{name}-main.c"))).map_err(|e| e.to_string())?;
        fs::rename(binary, out.join(name)).map_err(|e| e.to_string())?;
    } else {
        crate::artifact::publish(
            out,
            checked.header(),
            text.as_bytes(),
            &fs::read(&object).map_err(|e| e.to_string())?,
        )?;
    }
    Ok(())
}

/// Capture each dependency generation once, then validate its contract before linking immutable
/// object paths. Compiler-owned publication never rewrites any of these paths.
fn dependencies(
    root: &crate::module::Interface,
    dir: &Path,
) -> Result<Vec<std::path::PathBuf>, String> {
    use std::{
        collections::{BTreeMap, BTreeSet},
        path::PathBuf,
        rc::Rc,
    };
    fn visit(
        header: &crate::module::Interface,
        object: Option<&Path>,
        dir: &Path,
        cache: &mut BTreeMap<String, (Rc<crate::artifact::Snapshot>, String)>,
        active: &mut BTreeSet<String>,
        done: &mut BTreeSet<String>,
        order: &mut Vec<PathBuf>,
    ) -> Result<(), String> {
        if done.contains(&header.name) {
            return Ok(());
        }
        if !active.insert(header.name.clone()) {
            return Err(format!("cyclic module dependency at {}", header.name));
        }
        if active.len() > 256 {
            return Err("module dependency depth limit".into());
        }
        for (name, want) in &header.dependencies {
            if active.contains(name) {
                return Err(format!("cyclic module dependency at {name}"));
            }
            let (child, hash) = if let Some(child) = cache.get(name) {
                child.clone()
            } else {
                if cache.len() >= 4095 {
                    return Err("module dependency count limit".into());
                }
                let child = Rc::new(crate::artifact::load(dir, name)?);
                let hash = child.header.fingerprint()?;
                cache.insert(name.clone(), (child.clone(), hash.clone()));
                (child, hash)
            };
            if hash != *want {
                return Err(format!(
                    "stale module {}: dependency {name} interface changed; rebuild {}",
                    header.name, header.name
                ));
            }
            visit(
                &child.header,
                Some(&child.object),
                dir,
                cache,
                active,
                done,
                order,
            )?;
        }
        active.remove(&header.name);
        done.insert(header.name.clone());
        if let Some(object) = object {
            order.push(object.to_path_buf());
        }
        Ok(())
    }
    let mut order = Vec::new();
    visit(
        root,
        None,
        dir,
        &mut BTreeMap::new(),
        &mut BTreeSet::new(),
        &mut BTreeSet::new(),
        &mut order,
    )?;
    Ok(order)
}
