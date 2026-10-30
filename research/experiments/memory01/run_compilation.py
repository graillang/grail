"""Measure front-end versus codegen costs of a controlled Rust dispatch workload."""

from __future__ import annotations

import json
import random
import statistics
from pathlib import Path

import sandbox

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/experiments-20261030"
WORK = HERE / ".work"
WRAPPER = """import subprocess,time,resource,json,sys
start=time.perf_counter()
p=subprocess.run(sys.argv[1:],capture_output=True,text=True)
print(json.dumps(dict(wall_seconds=time.perf_counter()-start,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr,peak_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)))
"""


def expected(count: int, seed: int) -> int:
    mask = (1 << 64) - 1
    total = 0
    for i in range(count):
        value = seed + i
        result = value
        for k in range(64):
            result = (((result << 3) | (result >> 61)) + (value ^ k)) & mask
        total = (total + result) & mask
    return total


def main() -> None:
    generated = WORK / "dispatch"
    generated.mkdir(exist_ok=True)
    build = sandbox.run(
        [
            "rustc",
            "/experiment/src/dispatch_api.rs",
            "--edition=2024",
            "--crate-name",
            "dispatch_api",
            "--crate-type",
            "rlib",
            "-C",
            "opt-level=3",
            "-o",
            "/work/libdispatch_api.rlib",
        ]
    )
    if build.returncode:
        raise RuntimeError(build.stderr)
    for n in [16, 64, 256]:
        for mode in ["generic", "erased"]:
            text = ["use dispatch_api::{Value," + mode + "};"]
            for i in range(n):
                text += [
                    f"struct S{i}(u64); impl Value for S{i} {{ fn value(&self)->u64 {{ self.0.wrapping_add({i}) }} }}"
                ]
            text += [
                "fn main() { let seed:u64=std::env::args().nth(1).unwrap().parse().unwrap(); let mut total=0u64;"
            ]
            for i in range(n):
                text += [
                    f"total=total.wrapping_add({mode}(&S{i}(std::hint::black_box(seed))));"
                ]
            text += ['println!("{total}"); }']
            (generated / f"{mode}-{n}.rs").write_text("\n".join(text) + "\n")
    jobs = [
        (n, mode, stage, opt)
        for n in [16, 64, 256]
        for mode in ["generic", "erased"]
        for stage, opt in [("metadata", 0), ("link", 0), ("link", 3)]
    ]
    samples = []
    # One warmup for every job followed by three interleaved observations.
    for repeat in [-1, 0, 1, 2]:
        order = jobs.copy()
        random.Random(311 + repeat).shuffle(order)
        for n, mode, stage, opt in order:
            output = f"/work/dispatch/{mode}-{n}-{stage}-{opt}"
            args = [
                "rustc",
                f"/work/dispatch/{mode}-{n}.rs",
                "--crate-name",
                "dispatch_client",
                "--edition=2024",
                "--extern",
                "dispatch_api=/work/libdispatch_api.rlib",
                "--emit=" + stage,
                "-C",
                f"opt-level={opt}",
                "-C",
                "debuginfo=0",
                "-o",
                output,
            ]
            run = sandbox.run(["/usr/bin/python3", "-c", WRAPPER, *args])
            if run.returncode:
                raise RuntimeError(run.stderr)
            result = json.loads(run.stdout)
            if result["returncode"]:
                raise RuntimeError(result["stderr"])
            if stage == "link" and repeat == -1:
                executed = sandbox.run([output, "7"])
                if executed.returncode or int(executed.stdout.strip()) != expected(
                    n, 7
                ):
                    raise RuntimeError("Generated dispatch fixture has wrong result")
            if repeat >= 0:
                artifact = WORK / output.removeprefix("/work/")
                samples.append(
                    {
                        **result,
                        "types": n,
                        "dispatch": mode,
                        "stage": stage,
                        "opt_level": opt,
                        "artifact_bytes": artifact.stat().st_size,
                        "command": args,
                    }
                )
    summary = []
    for n, mode, stage, opt in jobs:
        group = [
            r
            for r in samples
            if (r["types"], r["dispatch"], r["stage"], r["opt_level"])
            == (n, mode, stage, opt)
        ]
        values = [r["wall_seconds"] for r in group]
        summary.append(
            {
                "types": n,
                "dispatch": mode,
                "stage": stage,
                "opt_level": opt,
                "median_seconds": statistics.median(values),
                "min_seconds": min(values),
                "max_seconds": max(values),
                "artifact_bytes": group[0]["artifact_bytes"],
            }
        )
    report = {
        "scope": "Synthetic Rust generic versus trait-object dispatch; warm OS caches, no cargo incremental cache",
        "provider": "Precompiled optimized rlib; no LTO. Does not measure a Grail compiler or compare languages.",
        "samples": samples,
        "summary": summary,
    }
    (OUT / "compilation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
