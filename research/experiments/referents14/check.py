"""Check the Rust referent boundary and exhaust the finite single-cell policies."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

from research.experiments.memory01 import sandbox
from research.experiments.referents14.model import POLICIES, TRACES, check, trace

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/referents14-20261030"
CASES = {
    "direct_slot": None,
    "direct_temporary": None,
    "temporary_restore": "E0597",
    "temporary_escape": "E0597",
    "direct_reset": None,
    "direct_handle": "E0505",
    "direct_take_old": "E0505",
    "helper_handle": "E0505",
    "helper_replace": "E0505",
    "stored_handle": "E0505",
    "ended_handle": "E0505",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    assert {p.stem for p in HERE.glob("*.rs")} == set(CASES)
    cases = []
    for name, expected in CASES.items():
        command = [
            "rustc",
            "--edition=2024",
            "--error-format=json",
            "/experiment/" + name + ".rs",
            "-o",
            "/work/" + name,
        ]
        result = sandbox.run(command, inputs=HERE, work=HERE / ".work")
        diagnostics = [json.loads(line) for line in result.stderr.splitlines()]
        for d in diagnostics:
            if d.get("code"):
                d["code"].pop("explanation", None)  # omit generic compiler manual prose
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
        if result.returncode == 0:
            ran = sandbox.run(["/work/" + name], inputs=HERE, work=HERE / ".work")
            execution = {
                "exit": ran.returncode,
                "stdout": ran.stdout,
                "stderr": ran.stderr,
            }
            matched &= ran.returncode == 0
        cases.append(
            {
                "name": name,
                "expected": expected,
                "matched": matched,
                "command": command,
                "exit": result.returncode,
                "diagnostics": diagnostics,
                "execution": execution,
            }
        )
        assert matched, cases[-1]
    directory = sandbox.ROOT / "research/repos/aeneas"
    precedent = {
        "repository": "https://github.com/AeneasVerif/aeneas",
        "commit": subprocess.check_output(
            ["git", "-C", str(directory), "rev-parse", "HEAD"], text=True
        ).strip(),
        "selected_files_sha256": {
            name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
            for name in ["src/llbc/Values.ml", "src/interp/InterpBorrows.ml"]
        },
        "scope": "selected mutable-borrow/value and give-back definitions; no build, proof replay or acceptance claim for rejected Rust",
    }
    report = {
        "compiler": subprocess.check_output(["rustc", "-Vv"], text=True),
        "named_traces": {
            name: {
                "commands": commands,
                "policies": {p: trace(p, commands) for p in POLICIES},
            }
            for name, commands in TRACES.items()
        },
        "cases": cases,
        "policies": check(),
        "precedent": precedent,
        "source_sha256": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in HERE.iterdir()
            if p.suffix in {".py", ".rs"}
        },
        "sandbox_sha256": hashlib.sha256(
            Path(sandbox.__file__).read_bytes()
        ).hexdigest(),
        "scope": "complete finite single-cell policy exploration and Rust API probes; not a source checker or general memory proof",
    }
    (OUT / "checks.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(
        json.dumps(
            {
                "rust_matched": len(cases),
                "accepted": sum(v is None for v in CASES.values()),
                "policies": report["policies"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
