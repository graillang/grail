"""Rust target-transfer contrasts, finite policies and conditional coverage proofs."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

from research.experiments.memory01 import sandbox
from research.experiments.transfer16.model import check

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/transfer16-20261030"
CASES = {
    "permute": None,
    "fresh": None,
    "partial": None,
    "alias_call": "E0499",
    "duplicate_return": "E0499",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    assert {p.stem for p in HERE.glob("*.rs")} == set(CASES)
    rows = []
    for name, expected in CASES.items():
        args = [
            "rustc",
            "--edition=2024",
            "--error-format=json",
            "/experiment/" + name + ".rs",
            "-o",
            "/work/" + name,
        ]
        result = sandbox.run(args, inputs=HERE, work=HERE / ".work")
        diagnostics = [json.loads(line) for line in result.stderr.splitlines()]
        for d in diagnostics:
            if d.get("code"):
                d["code"].pop("explanation", None)
        codes = {
            d["code"]["code"]
            for d in diagnostics
            if d.get("level") == "error" and d.get("code")
        }
        matched = (
            result.returncode == 0
            if expected is None
            else result.returncode != 0 and expected in codes
        )
        execution = None
        if result.returncode == 0 and expected is None:
            ran = sandbox.run(["/work/" + name], inputs=HERE, work=HERE / ".work")
            execution = {
                "exit": ran.returncode,
                "stdout": ran.stdout,
                "stderr": ran.stderr,
            }
            matched &= ran.returncode == 0
        rows.append(
            {
                "name": name,
                "expected_error": expected,
                "matched": bool(matched),
                "command": args,
                "compile_exit": result.returncode,
                "diagnostics": diagnostics,
                "execution": execution,
            }
        )
        assert matched, rows[-1]
    kernel = subprocess.run(
        [
            sys.executable,
            "-m",
            "research.experiments.instantiation11.check",
            "--output",
            str(OUT / "kernel.json"),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    (HERE / ".work/kernel-stdout.json").write_text(kernel.stdout)
    assert kernel.returncode == 0, (kernel.stdout, kernel.stderr)
    report = {
        "compiler": subprocess.check_output(["rustc", "-Vv"], text=True),
        "cases": rows,
        "model": check(),
        "kernel_report": "kernel.json",
        "source_sha256": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in HERE.iterdir()
            if p.suffix in {".py", ".rs"}
        },
        "sandbox_sha256": hashlib.sha256(
            Path(sandbox.__file__).read_bytes()
        ).hexdigest(),
        "scope": "same Rust type signature with different target transfer; finite injective maps; conditional mathematical cover/post-bound proof, not a Grail contract checker",
    }
    (OUT / "checks.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(
        json.dumps(
            {
                "rust_matched": len(rows),
                "runtime_completed": 3,
                "finite_cases": report["model"]["cases"],
                "audited_kernel_targets": 34,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
