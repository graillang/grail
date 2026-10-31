"""Generic layout/interface/native regression gate; no generic-function/reference completion claim."""

from __future__ import annotations

import hashlib
import io
import json
import os
import re
import statistics
import subprocess
import tarfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "research/evidence/generic36-20261031"
WORK = HERE / ".work"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)
BASELINE = "889bb45"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    work = WORK / f"replay-{time.time_ns()}"
    work.mkdir()
    commands = []
    measurements = []

    def run(cmd: list[str | Path], env: dict[str, str] | None = None) -> dict:
        extra = env or {}
        t = time.perf_counter()
        p = subprocess.run(
            [str(c) for c in cmd],
            cwd=ROOT,
            env={**os.environ, **extra},
            text=True,
            capture_output=True,
            check=False,
        )
        row = {
            "command": [str(c) for c in cmd],
            "environment": extra,
            "exit": p.returncode,
            "seconds": time.perf_counter() - t,
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
        commands.append(row)
        assert p.returncode == 0, row
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
        for backend in ["clang", "tcc"]:
            env = {
                "GRAIL_TCC_ROOT": str(
                    ROOT / "research/experiments/memory01/.work/goose-build"
                ),
                "GRAIL_GENERIC_TEST_BACKEND": backend,
                "GRAIL_GENERIC_MIXED_BACKEND": "1",
                "GRAIL_ENUM_TEST_BACKEND": backend,
                "GRAIL_ENUM_MIXED_BACKEND": "1",
                "GRAIL_PROPAGATE_TEST_BACKEND": backend,
                "GRAIL_PROPAGATE_MIXED_BACKEND": "1",
                "GRAIL_RECORD_TEST_BACKEND": backend,
                "GRAIL_RETURN_TEST_BACKEND": backend,
            }
            for test in [
                "generic_types_native",
                "enums_native",
                "propagate_native",
                "records_native",
                "returns_native",
            ]:
                run([*cargo, "--test", test, "--", "--include-ignored"], env)
        run(
            [*cargo, "--", "--include-ignored"],
            {
                "RUSTC": str(NIGHT / "bin/rustc"),
                "RUSTDOC": str(NIGHT / "bin/rustdoc"),
                "CARGO_TARGET_DIR": str(WORK / "nightly-target"),
            },
        )
        for label, compiler in [
            ("stable", Path("rustc")),
            ("nightly", NIGHT / "bin/rustc"),
        ]:
            binary = work / f"reference-{label}"
            run([compiler, "--edition=2024", HERE / "reference.rs", "-o", binary])
            assert (
                run([binary])["stdout"] == "5\n4\n47\n50\n22\n8\n7\n3 4 2 1\n3 4 2 1\n"
            )
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
        target = work / "target"
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
        for label, lib in [
            ("before", target / "release/libgrail_seed.rlib"),
            ("after", ROOT / "seed/target/release/libgrail_seed.rlib"),
        ]:
            binary = work / f"cost-{label}"
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
            for style in ["expanded"] if label == "before" else ["expanded", "generic"]:
                repeats = []
                for repeat in range(3):
                    directory = work / f"{label}-{style}-{repeat}"
                    row = run([binary, directory, style])
                    data = [line.split() for line in row["stdout"].splitlines()]
                    repeats.append(data)
                    for count, *_ in data:
                        for suffix in ["grl", "c", "api"]:
                            content = (directory / f"{count}.{suffix}").read_bytes()
                            first = work / f"{label}-{style}-0" / f"{count}.{suffix}"
                            assert content == first.read_bytes()
                for i in range(len(repeats[0])):
                    row = repeats[0][i]
                    measurements.append(
                        {
                            "version": label,
                            "style": style,
                            "count": int(row[0]),
                            "source_bytes": int(row[1]),
                            "c_bytes": int(row[2]),
                            "api_bytes": int(row[3]),
                            "check_median": statistics.median(
                                float(r[i][4]) for r in repeats
                            ),
                            "emit_median": statistics.median(
                                float(r[i][5]) for r in repeats
                            ),
                            "interface_median": statistics.median(
                                float(r[i][6]) for r in repeats
                            ),
                        }
                    )
        native_costs = []
        for count in [8, 256]:
            before = (work / f"before-expanded-0/{count}.c").read_text()
            after = (work / f"after-expanded-0/{count}.c").read_text()
            layout = re.compile(
                r"typedef struct \{\n.*?\n\} t_[A-Za-z0-9_]+;", re.DOTALL
            )
            assert sorted(layout.findall(before)) == sorted(layout.findall(after))
            assert layout.sub("", before) == layout.sub("", after)
            for label, style in [
                ("before", "expanded"),
                ("after", "expanded"),
                ("after", "generic"),
            ]:
                c = work / f"{label}-{style}-0/{count}.c"
                tccroot = ROOT / "research/experiments/memory01/.work/goose-build"
                profiles = [
                    ("clang-dev", ["clang", "-O0"]),
                    ("clang-release", ["clang", "-O2"]),
                    (
                        "tcc",
                        [
                            str(tccroot / "tcc/tcc"),
                            "-B",
                            str(tccroot / "tcclib"),
                            "-I/usr/include",
                            "-fno-asynchronous-unwind-tables",
                        ],
                    ),
                ]
                for profile, compiler in profiles:
                    samples = []
                    hashes = []
                    sizes = []
                    for repeat in range(3):
                        obj = work / f"{label}-{style}-{count}-{profile}-{repeat}.o"
                        row = run([*compiler, "-c", c, "-o", obj])
                        samples.append(row["seconds"])
                        data = obj.read_bytes()
                        hashes.append(hashlib.sha256(data).hexdigest())
                        sizes.append(len(data))
                    assert len(set(hashes)) == 1
                    native_costs.append(
                        {
                            "version": label,
                            "style": style,
                            "count": count,
                            "profile": profile,
                            "seconds_median": statistics.median(samples),
                            "object_bytes": sizes[0],
                            "object_sha256": hashes[0],
                        }
                    )
        (OUT / "native-costs.json").write_text(
            json.dumps(native_costs, indent=2) + "\n"
        )
        passed = True
    finally:
        files = [
            *ROOT.glob("seed/src/*.rs"),
            *ROOT.glob("seed/tests/**/*.rs"),
            *ROOT.glob("seed/tests/support/*.c"),
            *ROOT.glob("seed/examples/**/*.grl"),
            *ROOT.glob("seed/std/*.grl"),
            *HERE.glob("*.py"),
            *HERE.glob("*.rs"),
            ROOT / "seed/src/bytes_runtime.h",
            ROOT / "seed/Cargo.toml",
            ROOT / "seed/Cargo.lock",
        ]
        hashes = {
            str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(files)
        }
        (OUT / "checks.json").write_text(
            json.dumps(
                {
                    "passed": passed,
                    "baseline": BASELINE,
                    "hashes": hashes,
                    "commands": commands,
                    "measurements": measurements,
                },
                indent=2,
            )
            + "\n"
        )
        (OUT / "costs.tsv").write_text(
            "version\tstyle\tcount\tsource_bytes\tc_bytes\tapi_bytes\tcheck_s\temit_s\tinterface_s\n"
            + "".join(
                "\t".join(
                    str(r[k])
                    for k in [
                        "version",
                        "style",
                        "count",
                        "source_bytes",
                        "c_bytes",
                        "api_bytes",
                        "check_median",
                        "emit_median",
                        "interface_median",
                    ]
                )
                + "\n"
                for r in measurements
            )
        )


if __name__ == "__main__":
    main()
