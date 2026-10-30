"""Check concrete API distinctions, not the soundness of the unimplemented proposal."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "research/evidence/review04-20261030"
spec = importlib.util.spec_from_file_location(
    "grail_sandbox", HERE.parent / "memory01/sandbox.py"
)
assert spec and spec.loader
sandbox = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sandbox)


def main() -> None:
    results = []
    for name, expected in [
        ("clear_views", "E0505"),
        ("clear_retyped", None),
        ("mutable_owned_sync", None),
        ("mutable_owned_not_fn", "E0525"),
        ("read_cell_fn", None),
        ("read_cell_not_sync", "E0277"),
    ]:
        args = [
            "rustc",
            "/experiment/" + name + ".rs",
            "--edition=2024",
            "--error-format=json",
            "-o",
            "/work/" + name,
        ]
        result = sandbox.run(args, work=HERE / ".work", inputs=HERE)
        diagnostics = [json.loads(line) for line in result.stderr.splitlines()]
        codes = [d["code"]["code"] for d in diagnostics if d.get("code")]
        matched = (
            (result.returncode == 0)
            if expected is None
            else result.returncode != 0 and expected in codes
        )
        run = None
        if result.returncode == 0:
            execution = sandbox.run(["/work/" + name], work=HERE / ".work", inputs=HERE)
            matched &= execution.returncode == 0
            run = {
                "returncode": execution.returncode,
                "stdout": execution.stdout,
                "stderr": execution.stderr,
            }
        results.append(
            {
                "name": name,
                "expected_error": expected,
                "error_codes": codes,
                "matched": matched,
                "compile_returncode": result.returncode,
                "diagnostics": diagnostics,
                "run": run,
            }
        )
    # Logical limitation of an ADDITIVE contract, not an execution of the proposed language.
    before = {"old_source"}
    concrete_after_clear = set()
    additive_after_clear = before | set()
    assert concrete_after_clear != additive_after_clear
    report = {
        "scope": "Rust API distinctions and a set-theoretic additive-contract limitation; no Grail implementation",
        "proposal_commit": "d7fb6bf",
        "cases": results,
        "clear_contract": {
            "before": sorted(before),
            "actual_after_clear": sorted(concrete_after_clear),
            "additive_no_new_flow_after_clear": sorted(additive_after_clear),
        },
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
    print(
        json.dumps(
            {
                "matched": sum(x["matched"] for x in results),
                "total": len(results),
                "cases": [(x["name"], x["error_codes"]) for x in results],
            },
            indent=2,
        )
    )
    if not all(x["matched"] for x in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
