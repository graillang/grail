"""Compare a frozen checker, preserve generated output and retain full regression evidence."""

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
OUT = ROOT / "research/evidence/state34-20261030"
WORK = HERE / ".work"
CONTROLS = ROOT / "research/experiments/propagate33"
BASELINE = "2dea0f139dd0236b43c60d1c4004660e033acc23"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []

    def run(
        cmd: list[str | Path],
        extra: dict[str, str] | None = None,
        accepted: bool = True,
    ) -> dict:
        env = os.environ.copy()
        env.update(extra or {})
        p = subprocess.run(
            [str(c) for c in cmd],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        row = {
            "command": [str(c) for c in cmd],
            "environment": extra or {},
            "expected_accept": accepted,
            "exit": p.returncode,
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
        rows.append(row)
        assert (p.returncode == 0) == accepted, p.stderr
        print(p.returncode, " ".join(row["command"]), flush=True)
        return row

    passed = False
    try:
        run(["rustc", "-Vv"])
        run([NIGHT / "bin/rustc", "-Vv"])
        run(["clang", "--version"])
        run([ROOT / "research/experiments/memory01/.work/goose-build/tcc/tcc", "-v"])
        run(["cargo", "fmt", "--manifest-path", "seed/Cargo.toml", "--", "--check"])
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
            run(
                [*cargo, "--test", "propagate_native", "--", "--include-ignored"],
                {
                    "GRAIL_PROPAGATE_TEST_BACKEND": backend,
                    "GRAIL_PROPAGATE_MIXED_BACKEND": "1",
                    "GRAIL_TCC_ROOT": str(
                        ROOT / "research/experiments/memory01/.work/goose-build"
                    ),
                },
            )
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
            binary = WORK / label
            run([compiler, "--edition=2024", CONTROLS / "reference.rs", "-o", binary])
            assert run([binary])["stdout"] == "49\n5\n7\n8\n3 2 4 1\n9\nnone\n"
            for case in ["bad_lifetime", "bad_error_type"]:
                run(
                    [
                        compiler,
                        "--edition=2024",
                        CONTROLS / f"{case}.rs",
                        "-o",
                        WORK / case,
                    ],
                    accepted=False,
                )
        isolated = WORK / f"replay-{time.time_ns()}"
        isolated.mkdir()
        archive = subprocess.run(
            [
                "git",
                "archive",
                BASELINE,
                "seed/src",
                "seed/Cargo.toml",
                "seed/Cargo.lock",
            ],
            cwd=ROOT,
            capture_output=True,
            check=True,
        ).stdout
        frozen = isolated / "frozen"
        frozen.mkdir()
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(frozen, filter="data")
        target = isolated / "target"
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
        artifacts = {}
        timings = {}
        for version, lib in [
            ("before", target / "release/libgrail_seed.rlib"),
            ("after", ROOT / "seed/target/release/libgrail_seed.rlib"),
        ]:
            deps = lib.parent / "deps"
            for name in ["probe", "cost"]:
                binary = isolated / f"{name}-{version}"
                run(
                    [
                        "rustc",
                        "--edition=2024",
                        HERE / f"{name}.rs",
                        "--extern",
                        f"grail_seed={lib}",
                        "-L",
                        f"dependency={deps}",
                        "-o",
                        binary,
                    ]
                )
                dest = isolated / f"{name}-{version}-output"
                if name == "probe":
                    result = run([binary, dest])
                    artifacts[version] = {
                        "acceptance": result["stdout"],
                        "outputs": {
                            f.name: hashlib.sha256(f.read_bytes()).hexdigest()
                            for f in sorted(dest.iterdir())
                        },
                    }
                else:
                    samples = []
                    for repeat in range(3):
                        text = run([binary, dest])["stdout"]
                        samples.append(text)
                        (OUT / f"costs-{version}-{repeat}.txt").write_text(text)
                    timings[version] = samples
                    manifest = {
                        f.name: hashlib.sha256(f.read_bytes()).hexdigest()
                        for f in sorted(dest.iterdir())
                    }
                    artifacts[version]["cost_outputs"] = manifest
        assert artifacts["before"] == artifacts["after"], (
            "acceptance or emitted output changed"
        )
        original = json.loads((OUT / "before.json").read_text())
        assert original["outputs"] == artifacts["after"]["cost_outputs"], (
            "original baseline changed"
        )
        manifest = artifacts["after"]
        lines = manifest.pop("acceptance").splitlines()
        manifest["cases"] = len(lines)
        manifest["accepted"] = sum(line.endswith("accept") for line in lines)
        manifest["accepted_raw"] = sum(
            line.endswith("accept") and not line.startswith("source-") for line in lines
        )
        manifest["accepted_source"] = sum(
            line.endswith("accept") and line.startswith("source-") for line in lines
        )
        manifest["acceptance_sha256"] = hashlib.sha256(
            ("\n".join(lines) + "\n").encode()
        ).hexdigest()
        (OUT / "differential.json").write_text(json.dumps(manifest, indent=2) + "\n")
        medians = {}
        for version, samples in timings.items():
            grouped = {}
            for sample in samples:
                for line in sample.splitlines():
                    kind, count, _source, _c, check, emit = line.split()
                    grouped.setdefault(f"{kind}-{count}", []).append(
                        (float(check), float(emit))
                    )
            medians[version] = {
                k: {
                    "check": statistics.median(v[0] for v in values),
                    "emit": statistics.median(v[1] for v in values),
                }
                for k, values in grouped.items()
            }
        (OUT / "medians.json").write_text(json.dumps(medians, indent=2) + "\n")
        passed = True
    finally:
        sources = [
            ROOT / "seed/Cargo.toml",
            ROOT / "seed/Cargo.lock",
            *sorted((ROOT / "seed/examples").rglob("*.grl")),
            *sorted((ROOT / "seed/src").glob("*.h")),
            *sorted((ROOT / "seed/src").glob("*.rs")),
            *sorted((ROOT / "seed/tests").glob("*.rs")),
            ROOT / "seed/tests/support/allocator_audit.c",
            *sorted(HERE.glob("*.rs")),
            Path(__file__).resolve(),
            *sorted(CONTROLS.glob("*.rs")),
            OUT / "before.json",
        ]
        (OUT / "checks.json").write_text(
            json.dumps(
                {
                    "passed": passed,
                    "source_sha256": {
                        str(p.relative_to(ROOT)): hashlib.sha256(
                            p.read_bytes()
                        ).hexdigest()
                        for p in sources
                    },
                    "commands": rows,
                },
                indent=2,
            )
            + "\n"
        )
    assert passed


if __name__ == "__main__":
    main()
