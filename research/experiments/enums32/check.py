"""Retain tagged ownership, unwrap, native ABI and Rust differential evidence."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "research/evidence/enums32-20261030"
WORK = HERE / ".work"
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
                [*cargo, "--test", "enums_native", "--", "--include-ignored"],
                {
                    "GRAIL_ENUM_TEST_BACKEND": backend,
                    "GRAIL_ENUM_MIXED_BACKEND": "1",
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
            run([compiler, "--edition=2024", HERE / "reference.rs", "-o", binary])
            assert (
                run([binary])["stdout"]
                == "8\n11\n7\n0\n18446744073709551615\n8\n8\n7\n5\n42\n"
            )
            for case in ["bad_owned_error", "bad_local_error"]:
                run(
                    [
                        compiler,
                        "--edition=2024",
                        HERE / f"{case}.rs",
                        "-o",
                        WORK / case,
                    ],
                    accepted=False,
                )
        run(
            [
                "rustc",
                "--edition=2024",
                OUT / "cost_harness.rs",
                "--extern",
                "grail_seed=seed/target/release/libgrail_seed.rlib",
                "-L",
                "dependency=seed/target/release/deps",
                "-o",
                WORK / "cost",
            ]
        )
        costs = run([WORK / "cost"])["stdout"]
        (OUT / "costs.txt").write_text(costs)
        passed = True
    finally:
        sources = [
            *sorted((ROOT / "seed/src").glob("*.rs")),
            *sorted((ROOT / "seed/tests").glob("*.rs")),
            ROOT / "seed/tests/support/allocator_audit.c",
            *sorted(HERE.glob("*.rs")),
            Path(__file__).resolve(),
            OUT / "cost_harness.rs",
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
