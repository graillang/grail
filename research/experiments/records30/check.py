"""By-value records: native behavior, independent Rust controls, layouts and cleanup."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "research/evidence/records30-20261030"
WORK = HERE / ".work"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
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
            "exit": p.returncode,
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
        rows.append(row)
        assert (p.returncode == 0) == accepted, p.stderr
        print(p.returncode, " ".join(row["command"]), flush=True)
        return row

    run(["cargo", "fmt", "--manifest-path", "seed/Cargo.toml", "--", "--check"])
    run(
        [
            "cargo",
            "test",
            "--manifest-path",
            "seed/Cargo.toml",
            "--offline",
            "--",
            "--include-ignored",
        ]
    )
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
        "GRAIL_TCC_ROOT": str(ROOT / "research/experiments/memory01/.work/goose-build"),
        "GRAIL_RECORD_TEST_BACKEND": "tcc",
        "GRAIL_ARTIFACT_TEST_BACKEND": "tcc",
        "GRAIL_MODULE_TEST_BACKEND": "tcc",
    }
    run(
        [
            "cargo",
            "test",
            "--manifest-path",
            "seed/Cargo.toml",
            "--offline",
            "--test",
            "records_native",
            "--test",
            "artifacts_native",
            "--test",
            "modules_native",
            "--",
            "--include-ignored",
        ],
        tcc,
    )
    run(
        [
            "cargo",
            "test",
            "--manifest-path",
            "seed/Cargo.toml",
            "--offline",
            "--",
            "--include-ignored",
        ],
        {
            "RUSTC": str(NIGHT / "bin/rustc"),
            "RUSTDOC": str(NIGHT / "bin/rustdoc"),
            "CARGO_TARGET_DIR": str(ROOT / "seed/.work/nightly-target"),
        },
    )
    for name, compiler in [("stable", Path("rustc")), ("nightly", NIGHT / "bin/rustc")]:
        run([compiler, "--edition=2024", HERE / "reference.rs", "-o", WORK / name])
        assert run([WORK / name])["stdout"] == "16\n11\n5\n"
        for negative in ["bad_owned_origin", "source_escape"]:
            run(
                [
                    compiler,
                    "--edition=2024",
                    HERE / f"{negative}.rs",
                    "-o",
                    WORK / negative,
                ],
                accepted=False,
            )
    exe = ROOT / "seed/target/release/grail-seed"
    for backend in ["clang", "tcc"]:
        directory = WORK / backend
        directory.mkdir(exist_ok=True)
        run(
            [
                exe,
                "compile",
                "seed/examples/records/tokens.grl",
                directory,
                directory,
                backend,
            ],
            tcc,
        )
        outputs = []
        for name in ["mixed", "unique", "drop_only"]:
            run(
                [
                    exe,
                    "build",
                    f"seed/examples/records/{name}.grl",
                    directory,
                    directory,
                    backend,
                ],
                tcc,
            )
            outputs.append(
                run([directory / name, *(["abc"] if name == "mixed" else [])])["stdout"]
            )
        assert "".join(outputs) == "16\n11\n5\n"
    files = [
        *Path(ROOT / "seed/src").glob("*.rs"),
        *Path(ROOT / "seed/tests").glob("*.rs"),
        *HERE.glob("*.rs"),
        Path(__file__).resolve(),
    ]
    (OUT / "checks.json").write_text(
        json.dumps(
            {
                "passed": True,
                "commands": rows,
                "source_sha256": {
                    str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(files)
                },
                "scope": "by-value field tree/default drops; not general typed references, generics, joins or self-hosting",
            },
            indent=2,
        )
        + "\n"
    )


if __name__ == "__main__":
    main()
