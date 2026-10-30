//! Source command driver. Interfaces and objects, never provider source, are imported.
use crate::{Mode, Ty, emit, source};
use std::{collections::BTreeMap, fs, path::Path, process::Command};
fn write(path: &Path, text: &str) -> Result<(), String> {
    fs::write(path, text).map_err(|e| format!("{}: {e}", path.display()))
}
fn command(args: &[String]) -> Result<(), String> {
    let p = Command::new(&args[0])
        .args(&args[1..])
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
fn native(backend: &str, args: Vec<String>, link: bool) -> Result<(), String> {
    let mut cmd = match backend {
        "clang" => vec!["clang".into(), "-O0".into()],
        "tcc" => {
            let root = std::env::var("GRAIL_TCC_ROOT").map_err(
                |_| "tcc requires GRAIL_TCC_ROOT pointing to the configured Goose build",
            )?;
            let root = Path::new(&root);
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
        let root = std::env::var("GRAIL_TCC_ROOT").map_err(|e| e.to_string())?;
        cmd.extend([
            Path::new(&root)
                .join("tcclib/libtcc1.a")
                .display()
                .to_string(),
            "-lc".into(),
            "/usr/lib/crtn.o".into(),
        ]);
    }
    command(&cmd)
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
        let path = imports.join(format!("{n}.api"));
        let sig = crate::module::Interface::decode(
            &fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?,
        )?;
        if sig.name != *n {
            return Err("import name does not match interface".into());
        }
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
    let c = out.join(format!("{name}.c"));
    let object = out.join(format!("{name}.o"));
    write(&c, &emit::module_c(&checked))?;
    native(
        backend,
        vec![
            "-c".into(),
            c.display().to_string(),
            "-o".into(),
            object.display().to_string(),
        ],
        false,
    )?;
    // Publish the signature only after provider checking and object generation succeed.
    write(&out.join(format!("{name}.api")), &checked.interface())?;
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
        let main = out.join(format!("{name}-main.c"));
        write(
            &main,
            &format!(
                "#include <stdint.h>\n#include <stdio.h>\n#include <string.h>\ntypedef struct{{unsigned char*p;uint64_t n;}}gv;\nuint64_t {symbol}({params});\nint main(int argc,char**argv){{{argc}printf(\"%llu\\n\",(unsigned long long){call});return 0;}}\n"
            ),
        )?;
        let mut args = vec![main.display().to_string(), object.display().to_string()];
        for n in &linked {
            args.push(imports.join(format!("{n}.o")).display().to_string());
        }
        args.extend(["-o".into(), out.join(name).display().to_string()]);
        native(backend, args, true)?;
    }
    Ok(())
}

/// Validate the metadata closure before linking. Interface identity is not object authentication;
/// the current flat artifact directory still assumes honest, nonconcurrent producers.
fn dependencies(root: &crate::module::Interface, dir: &Path) -> Result<Vec<String>, String> {
    use std::{
        collections::{BTreeMap, BTreeSet},
        rc::Rc,
    };
    fn visit(
        header: Rc<crate::module::Interface>,
        dir: &Path,
        cache: &mut BTreeMap<String, (Rc<crate::module::Interface>, String)>,
        active: &mut BTreeSet<String>,
        done: &mut BTreeSet<String>,
        order: &mut Vec<String>,
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
            let (child, hash) = if let Some(child) = cache.get(name) {
                child.clone()
            } else {
                if cache.len() >= 4096 {
                    return Err("module dependency count limit".into());
                }
                let path = dir.join(format!("{name}.api"));
                let child = crate::module::Interface::decode(
                    &fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?,
                )?;
                if child.name != *name {
                    return Err("dependency name does not match module interface".into());
                }
                let hash = child.fingerprint()?;
                let child = Rc::new(child);
                cache.insert(name.clone(), (child.clone(), hash.clone()));
                (child, hash)
            };
            if hash != *want {
                return Err(format!(
                    "stale module {}: dependency {name} interface changed; rebuild {}",
                    header.name, header.name
                ));
            }
            visit(child, dir, cache, active, done, order)?;
        }
        active.remove(&header.name);
        done.insert(header.name.clone());
        order.push(header.name.clone());
        Ok(())
    }
    let root = Rc::new(root.clone());
    let mut cache = BTreeMap::from([(root.name.clone(), (root.clone(), root.fingerprint()?))]);
    let mut order = Vec::new();
    visit(
        root.clone(),
        dir,
        &mut cache,
        &mut BTreeSet::new(),
        &mut BTreeSet::new(),
        &mut order,
    )?;
    order.retain(|name| name != &root.name);
    Ok(order)
}
