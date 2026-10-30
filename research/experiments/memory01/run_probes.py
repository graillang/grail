"""Compile provider once; check isolated clients that cannot access provider sources."""

from __future__ import annotations

import json
import time
from pathlib import Path

import sandbox

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/experiments-20261030"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build = sandbox.run(
        [
            "rustc",
            "/experiment/src/lib.rs",
            "--edition=2024",
            "--crate-name",
            "view_api",
            "--crate-type",
            "rlib",
            "-o",
            "/work/libview_api.rlib",
        ]
    )
    (OUT / "rust-provider-build.log").write_text(build.stdout + build.stderr)
    if build.returncode:
        raise RuntimeError(build.stderr)
    cases = json.loads((HERE / "probes/cases.json").read_text())
    results = []
    for case in cases:
        name = case["name"]
        args = [
            "rustc",
            f"/experiment/{name}.rs",
            "--edition=2024",
            "--error-format=json",
            "--extern",
            "view_api=/work/libview_api.rlib",
            "-o",
            f"/work/{name}",
        ]
        start = time.perf_counter()
        # Only probes are mounted at /experiment. Provider source is NOT mounted.
        result = sandbox.run(args, inputs=HERE / "probes")
        elapsed = time.perf_counter() - start
        (OUT / f"probe-{name}.jsonl").write_text(result.stderr)
        diagnostics = []
        for line in result.stderr.splitlines():
            try:
                diagnostics.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        codes = sorted({d["code"]["code"] for d in diagnostics if d.get("code")})
        passed = (result.returncode == 0) == case["accept"]
        if not case["accept"]:
            passed &= bool(set(codes).intersection(case["expected_error_codes"]))
        execution = None
        if result.returncode == 0:
            run = sandbox.run([f"/work/{name}"], inputs=HERE / "probes")
            execution = {
                "returncode": run.returncode,
                "stdout": run.stdout,
                "stderr": run.stderr,
            }
            passed &= run.returncode == 0
        results.append(
            {
                **case,
                "compile_returncode": result.returncode,
                "error_codes": codes,
                "wall_seconds_with_sandbox": elapsed,
                "passed": passed,
                "execution": execution,
                "command": args,
            }
        )
        print(f"{name}: {'PASS' if passed else 'FAIL'} {codes}", flush=True)
    report = {
        "provider_source_visible_to_clients": False,
        "scope": "Rust reference envelope; no Grail inference or compiler implemented",
        "results": results,
        "passed": sum(r["passed"] for r in results),
        "total": len(results),
    }
    (OUT / "rust-api-probes.json").write_text(json.dumps(report, indent=2) + "\n")
    if report["passed"] != report["total"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
