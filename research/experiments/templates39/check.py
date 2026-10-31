"""Checked by-value generics: native composition, independent controls and measured limits."""

from __future__ import annotations

import hashlib
import io
import json
import os
import statistics
import subprocess
import tarfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "research/evidence/templates39-20261031"
WORK = HERE / ".work"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)
BASELINE = "a1351ad"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    work = WORK / f"replay-{time.time_ns()}"
    work.mkdir()
    commands, costs, profiles = [], [], []
    differential = {}

    def run(
        cmd: list[str | Path], extra: dict[str, str] | None = None, success: bool = True
    ) -> dict:
        env = extra or {}
        t = time.perf_counter()
        p = subprocess.run(
            [str(c) for c in cmd],
            cwd=ROOT,
            env={**os.environ, **env},
            text=True,
            capture_output=True,
            check=False,
        )
        row = {
            "command": [str(c) for c in cmd],
            "environment": env,
            "exit": p.returncode,
            "seconds": time.perf_counter() - t,
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
        commands.append(row)
        assert (p.returncode == 0) == success, row
        print("ok", " ".join(row["command"]), flush=True)
        return row

    passed = False
    try:
        for cmd in [
            ["rustc", "-Vv"],
            [NIGHT / "bin/rustc", "-Vv"],
            ["clang", "--version"],
            ["cargo", "fmt", "--manifest-path", "seed/Cargo.toml", "--", "--check"],
        ]:
            run(cmd)
        cargo = ["cargo", "test", "--manifest-path", "seed/Cargo.toml", "--offline"]
        run([*cargo, "--", "--include-ignored"])
        run(
            [
                "cargo",
                "clippy",
                "--manifest-path",
                "seed/Cargo.toml",
                "--offline",
                "--all-targets",
                "--",
                "-D",
                "warnings",
            ]
        )
        run(
            [
                "cargo",
                "build",
                "--manifest-path",
                "seed/Cargo.toml",
                "--offline",
                "--release",
            ]
        )
        tcc = {
            "GRAIL_TCC_ROOT": str(
                ROOT / "research/experiments/memory01/.work/goose-build"
            )
        }
        for backend in ["clang", "clang-release", "tcc"]:
            env = {
                **tcc,
                "GRAIL_TEMPLATE_TEST_BACKEND": backend,
                "GRAIL_TEMPLATE_MIXED_BACKEND": "1",
            }
            if backend != "clang-release":
                env["GRAIL_TEMPLATE_AUDIT_BACKEND"] = backend
            run([*cargo, "--test", "templates_native", "--", "--include-ignored"], env)
        run(
            [*cargo, "--", "--include-ignored"],
            {
                "RUSTC": str(NIGHT / "bin/rustc"),
                "RUSTDOC": str(NIGHT / "bin/rustdoc"),
                "CARGO_TARGET_DIR": str(WORK / "nightly-target"),
            },
        )
        references = []
        for label, rustc in [
            ("stable", Path("rustc")),
            ("nightly", NIGHT / "bin/rustc"),
        ]:
            binary = work / f"reference-{label}"
            run([rustc, "--edition=2024", HERE / "reference.rs", "-o", binary])
            references.append(run([binary])["stdout"])
        assert references[0] == references[1]
        (OUT / "reference.txt").write_text(references[0])
        archive = subprocess.check_output(
            [
                "git",
                "archive",
                BASELINE,
                "seed/src",
                "seed/Cargo.toml",
                "seed/Cargo.lock",
            ],
            cwd=ROOT,
        )
        frozen = work / "before"
        frozen.mkdir()
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(frozen, filter="data")
        target = work / "before-target"
        run(
            [
                "cargo",
                "build",
                "--manifest-path",
                frozen / "seed/Cargo.toml",
                "--offline",
                "--release",
                "--target-dir",
                target,
            ]
        )
        probe = (ROOT / "research/experiments/state34/probe.rs").read_text()
        adapter = "trait NativeText{fn text(self)->String;} impl NativeText for String{fn text(self)->String{self}} impl NativeText for Result<String,String>{fn text(self)->String{self.unwrap()}}\n"
        for label, lib in [
            ("before", target / "release/libgrail_seed.rlib"),
            ("after", ROOT / "seed/target/release/libgrail_seed.rlib"),
        ]:
            # Same generated cases; adapt only the public emitter's now-fallible return value.
            source = work / f"probe-{label}.rs"
            source.write_text(
                probe.replace(
                    "grail_seed::emit::module_c(&p),",
                    "grail_seed::emit::module_c(&p).text(),",
                )
                + adapter
            )
            binary = work / f"probe-{label}"
            run(
                [
                    "rustc",
                    "--edition=2024",
                    "-O",
                    source,
                    "--extern",
                    f"grail_seed={lib}",
                    "-L",
                    f"dependency={lib.parent / 'deps'}",
                    "-o",
                    binary,
                ]
            )
            dest = work / f"probe-{label}-out"
            row = run([binary, dest])
            apis = {}
            for path in sorted(dest.glob("*.api")):
                lines = path.read_text().splitlines()
                if label == "after":
                    assert lines[4] == "0" and lines[6] == "0" and lines[8] == ""
                    lines = [lines[i] for i in [0, 1, 2, 3, 5, 7]] + lines[9:]
                lines[0] = "normalized-module-envelope"
                apis[path.name] = hashlib.sha256("\n".join(lines).encode()).hexdigest()
            differential[label] = {
                "acceptance": row["stdout"],
                "summary": row["stderr"],
                "c": {
                    p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(dest.glob("*.c"))
                },
                "normalized_apis": apis,
            }
        assert differential["before"] == differential["after"]
        (OUT / "differential.json").write_text(
            json.dumps(differential, indent=2) + "\n"
        )
        lib = ROOT / "seed/target/release/libgrail_seed.rlib"
        binary = work / "cost"
        run(
            [
                "rustc",
                "--edition=2024",
                "-O",
                HERE / "cost.rs",
                "--extern",
                f"grail_seed={lib}",
                "-L",
                f"dependency={lib.parent / 'deps'}",
                "-o",
                binary,
            ]
        )
        samples = []
        for repeat in range(3):
            dest = work / f"cost-{repeat}"
            samples.append(
                [r.split() for r in run([binary, dest])["stdout"].splitlines()]
            )
        for i, row in enumerate(samples[0]):
            assert all(r[i][:7] == row[:7] for r in samples)
            costs.append(
                {
                    "style": row[0],
                    "count": int(row[1]),
                    "source_bytes": int(row[2]),
                    "c_bytes": int(row[3]),
                    "api_bytes": int(row[4]),
                    "ir_bytes": int(row[5]),
                    "instances": int(row[6]),
                    **{
                        name: statistics.median(float(r[i][col]) for r in samples)
                        for col, name in [
                            (7, "check"),
                            (8, "emit"),
                            (9, "decode_recheck"),
                        ]
                    },
                }
            )
        # Real public-driver objects with hidden providers, linked against a fixed host shim.
        shim = work / "main.c"
        shim.write_text(
            '#include <stdint.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\ntypedef struct{uint8_t*p;uint64_t n;}gv;uint64_t q_7_scanner_3_run(gv);int main(void){const char*s="alpha_1 beta2 gamma_3 delta4 ";size_t len=strlen(s),n=len*32768;uint8_t*p=malloc(n);if(!p)abort();for(size_t i=0;i<32768;++i)memcpy(p+i*len,s,len);printf("%llu\\n",(unsigned long long)q_7_scanner_3_run((gv){p,n}));free(p);}\n'
        )
        expected = references[0].splitlines()[-1].split()[-1] + "\n"
        compiler = ROOT / "seed/target/release/grail-seed"
        for backend in ["clang", "clang-release", "tcc"]:
            dest = work / backend
            dest.mkdir()
            build = []
            build_samples = []
            for name, source in [
                ("core", ROOT / "seed/std/core.grl"),
                ("lexer", HERE / "lexer.grl"),
                ("scanner", HERE / "scanner.grl"),
            ]:
                local = dest / f"{name}.grl"
                local.write_bytes(source.read_bytes())
                timings = []
                ident = None
                for _ in range(3):
                    timings.append(
                        run([compiler, "compile", local, dest, dest, backend], tcc)[
                            "seconds"
                        ]
                    )
                    current = (dest / f"{name}.artifact").read_bytes()
                    if ident is not None:
                        assert ident == current
                    ident = current
                build.append(statistics.median(timings))
                build_samples.append(timings)
                local.unlink()
            objects = []
            sizes = {}
            for name in ["core", "lexer", "scanner"]:
                ident = (dest / f"{name}.artifact").read_text().strip()
                obj = dest / ".grail-store" / ident / f"{name}.o"
                objects.append(obj)
                sizes[name] = obj.stat().st_size
            exe = dest / "scanner"
            links = []
            before = None
            for _ in range(3):
                links.append(run(["clang", *objects, shim, "-o", exe])["seconds"])
                current = hashlib.sha256(exe.read_bytes()).hexdigest()
                if before is not None:
                    assert before == current
                before = current
            link = statistics.median(links)
            shim_bytes = exe.stat().st_size
            runtimes = []
            for _ in range(3):
                row = run([exe])
                assert row["stdout"] == expected, row
                runtimes.append(row["seconds"])
            # CLI entry guards and Result propagation run through the actual build route too.
            local = dest / "scanner.grl"
            local.write_bytes((HERE / "scanner.grl").read_bytes())
            artifact_id = (dest / "scanner.artifact").read_bytes()
            run([compiler, "build", local, dest, dest, backend], tcc)
            assert (dest / "scanner.artifact").read_bytes() == artifact_id
            assert run([exe, "alpha_1 beta2"])["stdout"] == "134853\n"
            run([exe, "bad$"], success=False)
            local.unlink()
            profiles.append(
                {
                    "backend": backend,
                    "input_bytes": 950272,
                    "tokens": 131072,
                    "compile_module_medians": build,
                    "compile_module_samples": build_samples,
                    "link_median": link,
                    "link_samples": links,
                    "object_bytes": sizes,
                    "cli_executable_bytes": len(exe.read_bytes()),
                    "shim_executable_bytes": shim_bytes,
                    "shim_executable_hash": before,
                    "runtime_median": statistics.median(runtimes),
                    "runtime_samples": runtimes,
                    "checksum": expected.strip(),
                }
            )
        passed = True
    finally:
        paths = [
            *ROOT.glob("seed/src/*"),
            *ROOT.glob("seed/tests/**/*.rs"),
            *ROOT.glob("seed/tests/support/*.c"),
            *ROOT.glob("seed/std/*.grl"),
            *HERE.glob("*.py"),
            *HERE.glob("*.rs"),
            *HERE.glob("*.grl"),
            ROOT / "research/experiments/state34/probe.rs",
        ]
        hashes = {
            str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)
            if p.is_file()
        }
        (OUT / "checks.json").write_text(
            json.dumps(
                {
                    "passed": passed,
                    "baseline": BASELINE,
                    "commands": commands,
                    "hashes": hashes,
                    "costs": costs,
                    "profiles": profiles,
                },
                indent=2,
            )
            + "\n"
        )


if __name__ == "__main__":
    main()
