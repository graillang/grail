"""Measure representation choices, not language-to-language performance."""

from __future__ import annotations

import json
import random
import statistics
from pathlib import Path

import sandbox

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/experiments-20261030"


def main() -> None:
    builds = []
    for instrumented in [False, True]:
        binary = "representation-counted" if instrumented else "representation"
        args = [
            "rustc",
            "/experiment/src/representation.rs",
            "--edition=2024",
            "-D",
            "warnings",
            "-C",
            "opt-level=3",
            "-C",
            "debuginfo=0",
            "-o",
            f"/work/{binary}",
        ]
        if instrumented:
            args += ["--cfg", "count_alloc"]
        result = sandbox.run(args)
        builds.append(
            {"command": args, "returncode": result.returncode, "stderr": result.stderr}
        )
        if result.returncode:
            raise RuntimeError(result.stderr)
    samples = []
    for count in [20_000, 200_000]:
        for mode in ["views", "offsets", "owned"]:
            warmup = sandbox.run(["/work/representation", mode, str(count), "2"])
            if warmup.returncode:
                raise RuntimeError(warmup.stderr)
        # Interleaved deterministic randomized order, seven observations per case.
        order = [mode for _ in range(7) for mode in ["views", "offsets", "owned"]]
        random.Random(20261030 + count).shuffle(order)
        for mode in order:
            args = [
                "/usr/bin/python3",
                "-c",
                (
                    "import subprocess,resource,pathlib,sys; p=subprocess.run(sys.argv[1:]); "
                    'pathlib.Path("/work/rss.txt").write_text(str(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)); '
                    "sys.exit(p.returncode)"
                ),
                "/work/representation",
                mode,
                str(count),
                "12",
            ]
            run = sandbox.run(args)
            if run.returncode:
                raise RuntimeError(run.stderr)
            result = json.loads(run.stdout)
            result["process_peak_rss_kib"] = int((HERE / ".work/rss.txt").read_text())
            result["command"] = args
            samples.append(result)
    allocations = []
    for mode in ["views", "offsets", "owned"]:
        run = sandbox.run(["/work/representation-counted", mode, "200000", "1"])
        if run.returncode:
            raise RuntimeError(run.stderr)
        allocations.append(json.loads(run.stdout))
    summary = []
    for count in [20_000, 200_000]:
        checksums = {v["checksum"] for v in samples if v["tokens"] == count}
        if len(checksums) != 1:
            raise RuntimeError("Representation checksums differ")
        for mode in ["views", "offsets", "owned"]:
            group = [s for s in samples if s["tokens"] == count and s["mode"] == mode]
            row = {"mode": mode, "tokens": count, "observations": len(group)}
            for field in ["parse_ns", "traverse_ns", "drop_ns"]:
                values = [s[field] / s["rounds"] / 1e6 for s in group]
                row[field.replace("_ns", "_ms")] = {
                    "median": statistics.median(values),
                    "min": min(values),
                    "max": max(values),
                }
            row["median_total_ms"] = statistics.median(
                (s["parse_ns"] + s["traverse_ns"] + s["drop_ns"]) / s["rounds"] / 1e6
                for s in group
            )
            row["median_own_vm_hwm_kib"] = statistics.median(
                s["process_vm_hwm_kib"] for s in group
            )
            summary.append(row)
    report = {
        "scope": "Rust implementations of ASCII token representation alternatives; shared loaded host",
        "instrumentation": "Timing binaries uninstrumented; allocations measured separately. Use process_vm_hwm_kib for program memory; process_peak_rss_kib from wait4 may include inherited wrapper high-water and is not used in summaries.",
        "builds": builds,
        "samples": samples,
        "allocation_samples": allocations,
        "summary": summary,
    }
    (OUT / "representations.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"summary": summary, "allocations": allocations}, indent=2))


if __name__ == "__main__":
    main()
