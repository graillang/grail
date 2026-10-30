"""Isolated Rust distinctions plus finite permission-algebra comparisons."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

from research.experiments.authority08.permissions import check_finite
from research.experiments.memory01 import sandbox

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "research/evidence/authority08-20261030"
CASES = {
    "fields_disjoint": None,
    "indexes_need_split": "E0499",
    "iterator_items": None,
    "lending_items": "E0499",
    "parent_blocked": "E0506",
    "parent_resumes": None,
    "shared_child_read": None,
    "shared_child_write": "E0506",
    "split_reborrows": None,
    "split_consumes": None,
    "consumed_parent_use": "E0382",
    "reborrow_outlives_handle": None,
    "borrowed_handle_limited": "lifetime",
    "borrowed_handle_scoped": None,
    "move_handle_out": None,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    assert {p.stem for p in HERE.glob("*.rs")} == set(CASES)
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
        errors = [d for d in diagnostics if d.get("level") == "error"]
        codes = {d["code"]["code"] for d in errors if d.get("code")}
        matched = (
            result.returncode == 0
            if expected is None
            else result.returncode != 0
            and (
                expected in codes
                or expected == "lifetime"
                and any("lifetime" in d["message"] for d in errors)
            )
        )
        execution = None
        if result.returncode == 0:
            ran = sandbox.run(["/work/" + name], inputs=HERE, work=HERE / ".work")
            execution = {
                "returncode": ran.returncode,
                "stdout": ran.stdout,
                "stderr": ran.stderr,
            }
            matched &= ran.returncode == 0
        rows.append(
            {
                "name": name,
                "expected_error": expected,
                "matched": matched,
                "command": command,
                "returncode": result.returncode,
                "diagnostics": diagnostics,
                "execution": execution,
            }
        )
        assert matched, (name, result.stderr, execution)
    permissions = check_finite()
    hashes = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(HERE.iterdir())
        if p.suffix in {".py", ".rs"}
    }
    hashes["../memory01/sandbox.py"] = hashlib.sha256(
        (HERE.parent / "memory01/sandbox.py").read_bytes()
    ).hexdigest()
    prior = []
    for repo, paths in [
        ("aeneas", ["README.md", "src/llbc/Values.ml", "src/interp/InterpJoin.mli"]),
        ("hylo-specification", ["spec.md"]),
    ]:
        directory = ROOT / "research/repos" / repo
        prior.append(
            {
                "repository": repo,
                "commit": subprocess.check_output(
                    ["git", "-C", str(directory), "rev-parse", "HEAD"], text=True
                ).strip(),
                "files_sha256": {
                    p: hashlib.sha256((directory / p).read_bytes()).hexdigest()
                    for p in paths
                },
                "scope": "selected source/specification inspection; no toolchain build, benchmark or proof replay",
            }
        )
    report = {
        "scope": "Rust API distinctions and bounded ghost permissions; not a Grail checker or soundness proof",
        "compiler": subprocess.check_output(["rustc", "-Vv"], text=True),
        "cases": rows,
        "permissions": permissions,
        "source_sha256": hashes,
        "precedents": prior,
    }
    (OUT / "checks.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(
        json.dumps(
            {
                "rust_matched": sum(r["matched"] for r in rows),
                "rust_total": len(rows),
                "accepted": sum(v is None for v in CASES.values()),
                "permissions": permissions,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
