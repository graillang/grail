"""Lifetime-free typed storage gate; captured-reference invariance is explicitly unfinished."""

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
OUT = ROOT / "research/evidence/references40-20261031"
WORK = HERE / ".work"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)
BASELINE = "85ec12d"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    work = WORK / f"replay-{time.time_ns()}"
    work.mkdir()
    commands, costs, profiles = [], [], []
    artifacts = {}

    def run(cmd: list[str | Path], extra: dict[str, str] | None = None) -> dict:
        t = time.perf_counter()
        p = subprocess.run(
            [str(c) for c in cmd],
            cwd=ROOT,
            env={**os.environ, **(extra or {})},
            text=True,
            capture_output=True,
            check=False,
        )
        row = {
            "command": [str(c) for c in cmd],
            "environment": extra or {},
            "exit": p.returncode,
            "seconds": time.perf_counter() - t,
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
        commands.append(row)
        assert p.returncode == 0, row
        print("ok", " ".join(row["command"]), flush=True)
        return row

    def rust(source: Path, binary: Path, lib: Path) -> None:
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
                "GRAIL_REFERENCE_TEST_BACKEND": backend,
                "GRAIL_REFERENCE_MIXED_BACKEND": "1",
                "GRAIL_REFERENCE_AUDIT_BACKEND": "tcc" if backend == "tcc" else "clang",
            }
            run([*cargo, "--test", "references_native", "--", "--include-ignored"], env)
        run(
            [*cargo, "--", "--include-ignored"],
            {
                "RUSTC": str(NIGHT / "bin/rustc"),
                "RUSTDOC": str(NIGHT / "bin/rustdoc"),
                "CARGO_TARGET_DIR": str(WORK / "nightly-target"),
            },
        )
        references = []
        for label, compiler in [
            ("stable", Path("rustc")),
            ("nightly", NIGHT / "bin/rustc"),
        ]:
            binary = work / f"reference-{label}"
            run([compiler, "--edition=2024", HERE / "reference.rs", "-o", binary])
            references.append(run([binary])["stdout"])
        assert references[0] == references[1]
        assert references[0].startswith("45 [4, 5, 2, 3, 1]\n19\n92\n")
        (OUT / "reference.txt").write_text(references[0])
        frozen = work / "before"
        frozen.mkdir()
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
        probe = work / "probe.rs"
        probe.write_text(
            (ROOT / "research/experiments/state34/probe.rs")
            .read_text()
            .replace(
                "grail_seed::emit::module_c(&p),",
                "grail_seed::emit::module_c(&p).unwrap(),",
            )
        )
        plain = work / "plain.rs"
        plain.write_text(
            (ROOT / "research/experiments/loops38/cost.rs")
            .read_text()
            .replace(
                "let c = grail_seed::emit::module_c(&p);",
                "let c = grail_seed::emit::module_c(&p).unwrap();",
            )
        )
        for label, lib in [
            ("before", target / "release/libgrail_seed.rlib"),
            ("after", ROOT / "seed/target/release/libgrail_seed.rlib"),
        ]:
            binary = work / f"probe-{label}"
            rust(probe, binary, lib)
            dest = work / f"probe-{label}-out"
            row = run([binary, dest])
            artifacts[label] = {
                "acceptance": row["stdout"],
                "summary": row["stderr"],
                "outputs": {
                    p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(dest.iterdir())
                },
            }
            for style, source in [("plain", plain)] + (
                [("references", HERE / "cost.rs")] if label == "after" else []
            ):
                binary = work / f"cost-{label}-{style}"
                rust(source, binary, lib)
                samples = []
                for repeat in range(3):
                    dest = work / f"{label}-{style}-{repeat}"
                    samples.append(
                        [
                            r.split()
                            for r in run([binary, dest, "plain"])["stdout"].splitlines()
                        ]
                    )
                    hashes = {
                        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in sorted(dest.iterdir())
                    }
                    if repeat == 0:
                        artifacts[f"{label}-{style}"] = hashes
                    else:
                        assert artifacts[f"{label}-{style}"] == hashes
                for i, row in enumerate(samples[0]):
                    costs.append(
                        {
                            "version": label,
                            "style": style,
                            "kind": row[0],
                            "count": int(row[1]),
                            "source_bytes": int(row[2]),
                            "c_bytes": int(row[3]),
                            "check": statistics.median(float(r[i][4]) for r in samples),
                            "emit": statistics.median(float(r[i][5]) for r in samples),
                        }
                    )
        assert artifacts["before"] == artifacts["after"]
        assert artifacts["before-plain"] == artifacts["after-plain"]
        (OUT / "differential.json").write_text(json.dumps(artifacts, indent=2) + "\n")
        shim = work / "main.c"
        shim.write_text(
            '#include <stdint.h>\n#include <stdlib.h>\n#include <stdio.h>\n#include <string.h>\ntypedef struct{uint8_t*p;uint64_t n;}gv;uint64_t q_7_counter_3_run(gv);int main(void){const char*s="module parser; let token = value_123; ";size_t n=1048576,len=strlen(s);uint8_t*p=malloc(n);if(!p)abort();for(size_t i=0;i<n;++i)p[i]=s[i%len];printf("%llu\\n",(unsigned long long)q_7_counter_3_run((gv){p,n}));free(p);return 0;}\n'
        )
        expected = references[0].splitlines()[-1].split()[-1] + "\n"
        compiler = ROOT / "seed/target/release/grail-seed"
        for backend in ["clang", "clang-release", "tcc"]:
            dest = work / backend
            dest.mkdir()
            build = []
            objects = []
            sizes = {}
            for name in ["stats", "counter"]:
                source = dest / f"{name}.grl"
                source.write_bytes((HERE / f"{name}.grl").read_bytes())
                samples = []
                ident = None
                for _ in range(3):
                    samples.append(
                        run([compiler, "compile", source, dest, dest, backend], tcc)[
                            "seconds"
                        ]
                    )
                    current = (dest / f"{name}.artifact").read_text().strip()
                    if ident is not None:
                        assert current == ident
                    ident = current
                build.append(samples)
                source.unlink()
                obj = dest / ".grail-store" / str(ident) / f"{name}.o"
                objects.append(obj)
                sizes[name] = obj.stat().st_size
            exe = dest / "counter"
            links = []
            identity = None
            for _ in range(3):
                links.append(run(["clang", *objects, shim, "-o", exe])["seconds"])
                current = hashlib.sha256(exe.read_bytes()).hexdigest()
                if identity is not None:
                    assert identity == current
                identity = current
            times = []
            for _ in range(3):
                row = run([exe])
                assert row["stdout"] == expected, row
                times.append(row["seconds"])
            profiles.append(
                {
                    "backend": backend,
                    "bytes": 1048576,
                    "compile_module_samples": build,
                    "compile_module_medians": [statistics.median(t) for t in build],
                    "link_samples": links,
                    "link_median": statistics.median(links),
                    "runtime_samples": times,
                    "runtime_median": statistics.median(times),
                    "object_bytes": sizes,
                    "executable_bytes": exe.stat().st_size,
                    "executable_hash": identity,
                    "checksum": expected.strip(),
                }
            )
        passed = True
    finally:
        files = [
            *ROOT.glob("seed/src/*"),
            *ROOT.glob("seed/tests/**/*.rs"),
            *ROOT.glob("seed/tests/support/*.c"),
            *ROOT.glob("seed/examples/**/*.grl"),
            *ROOT.glob("seed/std/*.grl"),
            ROOT / "seed/Cargo.toml",
            ROOT / "seed/Cargo.lock",
            *HERE.glob("*.py"),
            *HERE.glob("*.rs"),
            *HERE.glob("*.grl"),
            ROOT / "research/experiments/state34/probe.rs",
            ROOT / "research/experiments/loops38/cost.rs",
        ]
        hashes = {
            str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(files)
            if p.is_file()
        }
        (OUT / "checks.json").write_text(
            json.dumps(
                {
                    "passed": passed,
                    "baseline": BASELINE,
                    "commands": commands,
                    "costs": costs,
                    "profiles": profiles,
                    "hashes": hashes,
                },
                indent=2,
            )
            + "\n"
        )


if __name__ == "__main__":
    main()
