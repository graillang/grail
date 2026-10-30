"""Pinned Rust ownership/resource controls; expected blocking is not completion."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

from research.experiments.memory01 import sandbox

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/resources15-20261030"
CASES = {
    "forget_container": None,
    "drop_effects": None,
    "drop_scoped_work": None,
    "forget_scoped_work": None,
    "forward_container": "E0506",
    "duplicate_generic": "E0382",
    "forget_work_early_use": "E0502",
}


def text(value: str | bytes | None) -> str:
    return value.decode(errors="replace") if isinstance(value, bytes) else value or ""


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    compiler = subprocess.check_output(["rustc", "-Vv"], text=True)
    pin = json.loads((HERE / "std-provenance.json").read_text())
    assert "commit-hash: " + pin["compiler_commit"] in compiler, (
        "revalidate version-specific controls before changing compiler pin"
    )
    root = Path(
        subprocess.check_output(["rustc", "--print", "sysroot"], text=True).strip()
    )
    sources = []
    for row in pin["selected_sources"]:
        path = root / "lib/rustlib/src/rust" / row["path"]
        found = path.is_file()
        if found:
            assert hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"]
        sources.append({**row, "installed_source_available_this_run": found})
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
            try:
                ran = sandbox.run(
                    ["/work/" + name], inputs=HERE, work=HERE / ".work", timeout=8
                )
                execution = {
                    "exit": ran.returncode,
                    "timeout": False,
                    "stdout": ran.stdout,
                    "stderr": ran.stderr,
                }
            except subprocess.TimeoutExpired as error:
                execution = {
                    "exit": None,
                    "timeout": True,
                    "stdout": text(error.stdout),
                    "stderr": text(error.stderr),
                }
            if name == "forget_scoped_work":
                markers = set(execution["stderr"].splitlines())
                matched &= (
                    execution["timeout"]
                    and {"child_done", "scope_body_done"} <= markers
                    and "scope_returned" not in markers
                )
            else:
                matched &= execution["exit"] == 0 and not execution["timeout"]
                if name == "drop_scoped_work":
                    matched &= {
                        "child_done",
                        "scope_body_done",
                        "scope_returned",
                    } <= set(execution["stderr"].splitlines())
        rows.append(
            {
                "name": name,
                "expected_compile_error": expected,
                "expected_runtime": "bounded observation of stalled scope"
                if name == "forget_scoped_work"
                else "success or compile rejection",
                "matched": bool(matched),
                "command": args,
                "compile_exit": result.returncode,
                "diagnostics": diagnostics,
                "execution": execution,
            }
        )
        assert matched, rows[-1]
    residual = []
    for path in Path("/proc").glob("[0-9]*/cmdline"):
        try:
            if path.read_bytes().split(b"\0")[0] == b"/work/forget_scoped_work":
                residual.append(path.parent.name)
        except (OSError, ProcessLookupError):
            pass
    assert not residual, ("owned timeout process still present", residual)
    report = {
        "compiler": compiler,
        "cases": rows,
        "timeout_seconds": 8,
        "source_provenance": sources,
        "residual_owned_test_pids": residual,
        "source_sha256": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in HERE.iterdir()
            if p.suffix in {".py", ".rs", ".json"}
        },
        "sandbox_sha256": hashlib.sha256(
            Path(sandbox.__file__).read_bytes()
        ).hexdigest(),
        "scope": "Rust API/resource observations plus pinned source explanation; no Grail implementation, general proof or performance claim",
    }
    (OUT / "checks.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(
        json.dumps(
            {
                "matched": sum(r["matched"] for r in rows),
                "total": len(rows),
                "runtime_completed": sum(
                    r["execution"] is not None and r["execution"]["exit"] == 0
                    for r in rows
                ),
                "expected_stall_observations": sum(
                    r["execution"] is not None and r["execution"]["timeout"]
                    for r in rows
                ),
                "compile_rejects": sum(r["compile_exit"] != 0 for r in rows),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
