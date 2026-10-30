"""Finite interval/refinement/cache checks plus the shared conditional proof corpus."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

from research.experiments.memory01 import sandbox
from research.experiments.refinement17.model import check

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/refinement17-20261030"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (HERE / ".work").mkdir(exist_ok=True)
    result = subprocess.run(
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
    (HERE / ".work/kernel-stdout.json").write_text(result.stdout)
    assert result.returncode == 0, (result.stdout, result.stderr)
    kernel = json.loads((OUT / "kernel.json").read_text())
    assert kernel["passed"] and kernel["axiom_audit_passed"]
    model = check()
    sources = [
        *HERE.glob("*.py"),
        HERE.parent / "instantiation11/check.py",
        HERE.parent / "transfer16/check.py",
    ]
    report = {
        "model": model,
        "kernel_report": "kernel.json",
        "source_sha256": {
            str(p.relative_to(sandbox.ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sources
        },
        "scope": "all footprint sets in a may/must interval abstraction; toy in-memory cache; not a source contract ABI, ownership proof or compiler cache",
    }
    (OUT / "checks.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(
        json.dumps(
            {
                "interval_pairs": sum(p["pairs"] for p in model["populations"]),
                "bad_may_only_pairs": sum(
                    p["bad_may_only_pairs"] for p in model["populations"]
                ),
                "audited_kernel_targets": len(kernel["theorem_axioms"]),
                "stale_cache_accept": model["cache_case"]["stale_accept"],
                "fresh_cache_accept": model["cache_case"]["fresh_accept"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
