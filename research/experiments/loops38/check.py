"""Loop exits, cleanup, independent controls and frozen-checker regression gates."""

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
OUT = ROOT / "research/evidence/loops38-20261031"
WORK = HERE / ".work"
OLD = ROOT / "research/experiments/state34"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)
BASELINE = "a1dd4ee"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    work = WORK / f"replay-{time.time_ns()}"
    work.mkdir()
    commands = []
    medians = []
    artifacts = {}

    def run(cmd: list[str | Path], extra: dict[str, str] | None = None) -> dict:
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
        root = str(ROOT / "research/experiments/memory01/.work/goose-build")
        for backend in ["clang", "clang-release", "tcc"]:
            run(
                [
                    *cargo,
                    "--test",
                    "loop_exits_native",
                    "counted_while",
                    "--",
                    "--include-ignored",
                ],
                {"GRAIL_TCC_ROOT": root, "GRAIL_LOOP_TEST_BACKEND": backend},
            )
        for backend in ["clang", "tcc"]:
            run(
                [
                    *cargo,
                    "--test",
                    "loop_exits_native",
                    "exits_destroy",
                    "--",
                    "--include-ignored",
                ],
                {"GRAIL_TCC_ROOT": root, "GRAIL_LOOP_AUDIT_BACKEND": backend},
            )
        run(
            [*cargo, "--", "--include-ignored"],
            {
                "RUSTC": str(NIGHT / "bin/rustc"),
                "RUSTDOC": str(NIGHT / "bin/rustdoc"),
                "CARGO_TARGET_DIR": str(WORK / "nightly-target"),
            },
        )
        reference = []
        for label, compiler in [
            ("stable", Path("rustc")),
            ("nightly", NIGHT / "bin/rustc"),
        ]:
            binary = work / f"reference-{label}"
            run([compiler, "--edition=2024", HERE / "reference.rs", "-o", binary])
            reference.append(run([binary])["stdout"])
        assert reference[0] == reference[1]
        (OUT / "reference.txt").write_text(reference[0])
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
            for tool, source in [
                ("probe", OLD / "probe.rs"),
                ("cost", HERE / "cost.rs"),
            ]:
                binary = work / f"{tool}-{label}"
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
                if tool == "probe":
                    dest = work / f"probe-{label}-out"
                    row = run([binary, dest])
                    artifacts[label] = {
                        "acceptance": row["stdout"],
                        "outputs": {
                            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sorted(dest.iterdir())
                        },
                    }
                else:
                    for style in ["plain"] if label == "before" else ["plain", "exits"]:
                        samples = []
                        for repeat in range(3):
                            dest = work / f"{label}-{style}-{repeat}"
                            rows = run([binary, dest, style])["stdout"].splitlines()
                            samples.append([r.split() for r in rows])
                            hashes = {
                                p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in sorted(dest.iterdir())
                            }
                            if repeat == 0:
                                artifacts[f"{label}-{style}"] = hashes
                            else:
                                assert artifacts[f"{label}-{style}"] == hashes
                        for i, row in enumerate(samples[0]):
                            medians.append(
                                {
                                    "version": label,
                                    "style": style,
                                    "kind": row[0],
                                    "count": int(row[1]),
                                    "source_bytes": int(row[2]),
                                    "c_bytes": int(row[3]),
                                    "check": statistics.median(
                                        float(r[i][4]) for r in samples
                                    ),
                                    "emit": statistics.median(
                                        float(r[i][5]) for r in samples
                                    ),
                                }
                            )
        assert artifacts["before"] == artifacts["after"]
        assert artifacts["before-plain"] == artifacts["after-plain"]
        (OUT / "differential.json").write_text(json.dumps(artifacts, indent=2) + "\n")
        passed = True
    finally:
        files = [
            *ROOT.glob("seed/src/*.rs"),
            *ROOT.glob("seed/src/*.h"),
            *ROOT.glob("seed/tests/**/*.rs"),
            *ROOT.glob("seed/tests/support/*.c"),
            *ROOT.glob("seed/examples/**/*.grl"),
            *ROOT.glob("seed/std/*.grl"),
            *HERE.glob("*.py"),
            *HERE.glob("*.rs"),
            OLD / "probe.rs",
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
                    "commands": commands,
                    "hashes": hashes,
                    "medians": medians,
                },
                indent=2,
            )
            + "\n"
        )


if __name__ == "__main__":
    main()
