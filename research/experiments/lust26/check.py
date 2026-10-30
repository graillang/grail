"""Pinned external checker controls; never execute rejected/unsafe negative cases."""

from __future__ import annotations

import hashlib
import json
import subprocess
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
LUST = ROOT.parent / "lust-lang"
PIN = "240e08d91d4aed0299639f6f11fd522912b248f9"
OUT = ROOT / "research/evidence/lust26-20261030"
WORK = HERE / ".work"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu/bin/rustc"
)
SAFE = {
    "token_collection",
    "partial_cleanup",
    "unique_fields",
    "setter_store",
    "drop_only",
    "conditional_reborrow",
    "get_default",
    "tail_cursor",
    "direct_reset",
}


def run(cmd: list[str]) -> dict:
    start = time.perf_counter()
    p = subprocess.run(
        cmd, cwd=ROOT, text=True, capture_output=True, timeout=90, check=False
    )
    return {
        "command": cmd,
        "exit": p.returncode,
        "stdout": p.stdout,
        "stderr": p.stderr,
        "seconds": time.perf_counter() - start,
    }


def main() -> None:
    assert (
        subprocess.check_output(
            ["git", "-C", str(LUST), "rev-parse", "HEAD"], text=True
        ).strip()
        == PIN
    )
    assert not subprocess.check_output(
        ["git", "-C", str(LUST), "status", "--porcelain"], text=True
    ).strip()
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    inputs = WORK / "inputs"
    inputs.mkdir(exist_ok=True)
    compiler = str(LUST / "target/debug/lust-core")
    sources = [
        *sorted(HERE.glob("*.rs")),
        *sorted((HERE.parent / "rust_next20").glob("*.rs")),
        *[
            HERE.parent / "referents14" / f"{n}.rs"
            for n in [
                "helper_replace",
                "temporary_restore",
                "temporary_escape",
                "direct_reset",
            ]
        ],
    ]
    report = {
        "lust_commit": PIN,
        "rust_version": run([str(NIGHT), "-Vv"]),
        "compiler_sha256": hashlib.sha256(Path(compiler).read_bytes()).hexdigest(),
        "cases": [],
    }
    for src in sources:
        name = src.stem
        isolated = inputs / src.name
        isolated.write_bytes(src.read_bytes())
        rust = run(
            [
                str(NIGHT),
                "--edition=2024",
                str(isolated),
                "-o",
                str(WORK / f"{name}-rust"),
            ]
        )
        check = run([compiler, "check", str(isolated)])
        row = {
            "case": name,
            "source": str(src.relative_to(ROOT)),
            "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
            "known_safe": name in SAFE,
            "rust": rust,
            "lust_check": check,
        }
        if name in SAFE and rust["exit"] == 0 and check["exit"] == 0:
            build = run(
                [compiler, "build", str(isolated), "-o", str(WORK / f"{name}-lust")]
            )
            row["lust_build"] = build
            if build["exit"] == 0:
                reference = run([str(WORK / f"{name}-rust")])
                actual = run([str(WORK / f"{name}-lust")])
                row.update(
                    rust_run=reference,
                    lust_run=actual,
                    output_equal=all(
                        actual[k] == reference[k] for k in ["exit", "stdout", "stderr"]
                    )
                    and reference["exit"] == 0,
                )
        report["cases"].append(row)
        (OUT / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
        print(
            name,
            "rust",
            rust["exit"],
            "lust",
            check["exit"],
            "execution",
            row.get("output_equal", "not run"),
            flush=True,
        )
    assert all((c["rust"]["exit"] == 0) == c["known_safe"] for c in report["cases"])
    assert all(
        c["lust_check"]["exit"] != 0
        for c in report["cases"]
        if c["rust"]["exit"] != 0 and not c["known_safe"]
    )
    assert all(
        c.get("output_equal") is True
        for c in report["cases"]
        if c["known_safe"] and c["lust_check"]["exit"] == 0
    )
    report["passed"] = True
    report["summary"] = {
        "acceptance_pairs": len(report["cases"]),
        "equal_native_runs": sum(
            c.get("output_equal") is True for c in report["cases"]
        ),
        "modern_safe_lust_rejects": [
            c["case"]
            for c in report["cases"]
            if c["known_safe"] and c["lust_check"]["exit"] != 0
        ],
    }
    report["build_rust_version"] = run(["rustc", "-Vv"])
    report["tinycc_commit"] = subprocess.check_output(
        ["git", "-C", str(LUST / "third_party/tinycc"), "rev-parse", "HEAD"], text=True
    ).strip()
    (OUT / "checks.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
