"""Targeted Goose checks and root-class reuse measurements in isolation."""

from __future__ import annotations

import json
import re
import statistics
import time
from pathlib import Path

import sandbox

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/experiments-20261030"
SOURCE = sandbox.ROOT / "research/repos/goose"


def main() -> None:
    cases = [
        ("borrowed_ast", "/experiment/goose/borrowed_ast.goose", True, "", "beta"),
        ("alias_mutation", "/experiment/goose/alias_mutation.goose", True, "", "2"),
        (
            "local_escape",
            "/experiment/goose/local_escape.goose",
            False,
            "returning a reference rooted",
            None,
        ),
        (
            "retained_element_shrink",
            "/src/test/errors_tc/append_copy_shrink.goose",
            False,
            "cannot pop",
            None,
        ),
        (
            "reference_fields",
            "/src/test/codegen/reference_only_structs.goose",
            True,
            "",
            None,
        ),
        ("root_identity", "/src/test/codegen/root_call_identity.goose", True, "", None),
    ]
    results = []
    for name, path, accept, diagnostic, expected in cases:
        args = ["/work/goose-build/goose", "check", path, "--color", "never", "--stats"]
        checked = sandbox.run(args, source=SOURCE)
        passed = (checked.returncode == 0) == accept and diagnostic in checked.stderr
        execution = None
        if expected is not None and checked.returncode == 0:
            run = sandbox.run(
                ["/work/goose-build/goose", "run", path, "--debug"], source=SOURCE
            )
            execution = {
                "returncode": run.returncode,
                "stdout": run.stdout,
                "stderr": run.stderr,
            }
            passed &= run.returncode == 0 and run.stdout.strip() == expected
        results.append(
            {
                "name": name,
                "accept": accept,
                "passed": passed,
                "command": args,
                "returncode": checked.returncode,
                "stderr": checked.stderr,
                "execution": execution,
            }
        )
    samples = []
    for count in [16, 64, 256]:
        text = [
            "fn head(xs: i64[:]) -> i64& { return xs[0]; }",
            "fn main() { var total:i64=0;",
        ]
        text += [f"var a{i}:i64[1]=[{i}]; total+=head(a{i}[..]);" for i in range(count)]
        text += ["print(total); }"]
        local = HERE / ".work" / f"root_scale_{count}.goose"
        local.write_text("\n".join(text) + "\n")
        for repeat in [-1, 0, 1, 2, 3, 4]:
            args = [
                "/work/goose-build/goose",
                "check",
                f"/work/root_scale_{count}.goose",
                "--stats",
                "--color",
                "never",
                "-O0",
            ]
            start = time.perf_counter()
            run = sandbox.run(args, source=SOURCE)
            elapsed = time.perf_counter() - start
            match = re.search(r"typechecked ok: (\d+) specialization", run.stderr)
            if run.returncode or match is None:
                raise RuntimeError(run.stderr)
            if repeat >= 0:
                samples.append(
                    {
                        "roots": count,
                        "wall_seconds_including_sandbox": elapsed,
                        "specializations": int(match[1]),
                        "stderr": run.stderr,
                        "command": args,
                    }
                )
    summary = [
        {
            "roots": n,
            "reported_specializations": sorted(
                {s["specializations"] for s in samples if s["roots"] == n}
            ),
            "median_wall_ms_including_sandbox": 1000
            * statistics.median(
                s["wall_seconds_including_sandbox"] for s in samples if s["roots"] == n
            ),
        }
        for n in [16, 64, 256]
    ]
    report = {
        "scope": "Goose actual whole-program compiler, not a modular Grail inference implementation",
        "results": results,
        "samples": samples,
        "summary": summary,
    }
    (OUT / "goose-probes.json").write_text(json.dumps(report, indent=2) + "\n")
    print(
        json.dumps(
            {
                "results": [(r["name"], r["passed"]) for r in results],
                "summary": summary,
            },
            indent=2,
        )
    )
    if not all(r["passed"] for r in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
