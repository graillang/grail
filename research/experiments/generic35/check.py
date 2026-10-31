"""Preimplementation native ABI comparison and independent typed-reference requirements."""

from __future__ import annotations

import hashlib
import json
import os
import re
import statistics
import subprocess
import time
from pathlib import Path

from cases import CASES
from generate import generate

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "research/evidence/generic35-20261030"
WORK = HERE / ".work"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu/bin/rustc"
)
TCC_ROOT = ROOT / "research/experiments/memory01/.work/goose-build"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    work = WORK / f"replay-{time.time_ns()}"
    work.mkdir(parents=True)
    commands = []
    results = []
    input_info = {}

    def run(
        cmd: list[str | Path],
        accepted: bool = True,
        extra: dict[str, str] | None = None,
    ) -> dict:
        env = os.environ.copy()
        env.update(extra or {})
        t = time.perf_counter()
        p = subprocess.run(
            [str(c) for c in cmd],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        row = {
            "command": [str(c) for c in cmd],
            "seconds": time.perf_counter() - t,
            "exit": p.returncode,
            "expected_accept": accepted,
            "environment": extra or {},
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
        commands.append(row)
        assert (p.returncode == 0) == accepted, row
        return row

    passed = False
    try:
        for compiler in [Path("rustc"), NIGHT]:
            run([compiler, "-Vv"])
        run(["clang", "--version"])
        run([TCC_ROOT / "tcc/tcc", "-v"])
        controls = work / "controls"
        controls.mkdir()
        for name, (accepted, source) in CASES.items():
            path = controls / f"{name}.rs"
            path.write_text(source + "\n")
            for label, compiler in [("stable", Path("rustc")), ("nightly", NIGHT)]:
                binary = controls / f"{name}-{label}"
                run([compiler, "--edition=2024", path, "-o", binary], accepted)
                if accepted:
                    run([binary])
        snapshot = work / "snapshot"
        run(["clang", "-O0", HERE / "snapshot.c", "-o", snapshot])
        assert run([snapshot])["stdout"] == "7 99 7\n"

        inputs = sorted((ROOT / "seed/src").glob("*.rs"))
        inputs += sorted((ROOT / "seed/examples").rglob("*.grl"))
        data = b"\n".join(p.read_bytes() for p in inputs)
        corpus = work / "corpus.txt"
        corpus.write_bytes(data)
        matches = list(re.finditer(rb"[A-Za-z_][A-Za-z0-9_]*|[0-9]+", data))
        tokens = [
            (m.start(), m.end(), 2 if m[0][0] in b"0123456789" else 1) for m in matches
        ]
        input_info = {
            "revision": subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
            ).strip(),
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "tokens": len(tokens),
            "sources": {
                str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in inputs
            },
        }
        token_sum = sum(
            4 * (end - start) + kind + start + end + 2 * i + 1
            for i, (start, end, kind) in enumerate(tokens)
        )
        token_sum += sum(
            kind for _, _, kind in tokens[len(tokens) - len(tokens) // 2 :]
        )
        count = 1_000_000
        expected = count * (count - 1) + token_sum
        profiles = {
            "clang-dev": ["clang", "-O0"],
            "tcc-dev": [
                str(TCC_ROOT / "tcc/tcc"),
                "-B",
                str(TCC_ROOT / "tcclib"),
                "-I/usr/include",
                "-fno-asynchronous-unwind-tables",
            ],
            "clang-release": ["clang", "-O2"],
        }
        for instances in [0, 16, 64, 256]:
            generated = work / f"types-{instances}"
            generate(generated, instances)
            for profile, flags in profiles.items():
                for mode in ["specialized", "erased"]:
                    dest = generated / f"{profile}-{mode}"
                    dest.mkdir()
                    erased = int(mode == "erased")
                    binary = dest / "bench"
                    build_samples = []
                    for repeat in range(3):
                        elapsed = []
                        for source in [f"{mode}.c", "bench.c", "stress.c"]:
                            target = dest / (Path(source).stem + ".o")
                            row = run(
                                [
                                    *flags,
                                    f"-DERASED={erased}",
                                    "-c",
                                    generated / source,
                                    "-o",
                                    target,
                                ]
                            )
                            elapsed.append(row["seconds"])
                        link = run(
                            [
                                "clang",
                                dest / f"{mode}.o",
                                dest / "bench.o",
                                dest / "stress.o",
                                "-o",
                                binary,
                            ]
                        )
                        build_samples.append(
                            {
                                "provider": elapsed[0],
                                "consumer": elapsed[1] + elapsed[2],
                                "link": link["seconds"],
                            }
                        )
                    runtime = []
                    for _ in range(3):
                        fields = run([binary, corpus, str(count)])["stdout"].split()
                        checksum, token_count, allocs, nums_ns, objects_ns = map(
                            int, fields
                        )
                        assert checksum == expected + instances * (instances - 1)
                        assert token_count == len(tokens)
                        assert allocs == 3 * len(tokens) + 4 + instances
                        runtime.append(
                            {"numeric_ns": nums_ns, "objects_ns": objects_ns}
                        )
                    symbols = run(["nm", "--defined-only", dest / f"{mode}.o"])[
                        "stdout"
                    ]
                    results.append(
                        {
                            "profile": profile,
                            "mode": mode,
                            "extra_types": instances,
                            "build_samples": build_samples,
                            "runtime_samples": runtime,
                            "provider_bytes": (dest / f"{mode}.o").stat().st_size,
                            "consumer_bytes": sum(
                                (dest / f).stat().st_size
                                for f in ["bench.o", "stress.o"]
                            ),
                            "executable_bytes": binary.stat().st_size,
                            "provider_symbols": symbols,
                            "median": {
                                **{
                                    k: statistics.median(s[k] for s in build_samples)
                                    for k in ["provider", "consumer", "link"]
                                },
                                **{
                                    k: statistics.median(s[k] for s in runtime)
                                    for k in ["numeric_ns", "objects_ns"]
                                },
                            },
                        }
                    )
                    print(profile, mode, instances, flush=True)
        # Mixed compiler ABI checks are execution controls, not additional timing comparisons.
        generated = work / "types-16"
        for provider, consumer in [("tcc-dev", "clang-dev"), ("clang-dev", "tcc-dev")]:
            for mode in ["specialized", "erased"]:
                dest = work / f"mixed-{provider}-{consumer}-{mode}"
                dest.mkdir()
                flag = f"-DERASED={int(mode == 'erased')}"
                run(
                    [
                        *profiles[provider],
                        flag,
                        "-c",
                        generated / f"{mode}.c",
                        "-o",
                        dest / "provider.o",
                    ]
                )
                for source in ["bench", "stress"]:
                    run(
                        [
                            *profiles[consumer],
                            flag,
                            "-c",
                            generated / f"{source}.c",
                            "-o",
                            dest / f"{source}.o",
                        ]
                    )
                binary = dest / "bench"
                run(
                    [
                        "clang",
                        dest / "provider.o",
                        dest / "bench.o",
                        dest / "stress.o",
                        "-o",
                        binary,
                    ]
                )
                fields = list(
                    map(int, run([binary, corpus, str(count)])["stdout"].split())
                )
                assert fields[:3] == [
                    expected + 16 * 15,
                    len(tokens),
                    3 * len(tokens) + 4 + 16,
                ]
        for profile in ["clang-dev", "tcc-dev"]:
            obj = work / f"dynamic-{profile}.o"
            binary = work / f"dynamic-{profile}"
            run([*profiles[profile], "-c", HERE / "dynamic.c", "-o", obj])
            run(["clang", obj, "-o", binary])
            assert run([binary])["stdout"] == "11 7 4 2\n"
        # Separate sanitizer run is evidence about these C prototypes, not a language proof.
        for mode in ["specialized", "erased"]:
            generated = work / "types-16"
            binary = work / f"asan-{mode}"
            run(
                [
                    "clang",
                    "-O1",
                    "-fsanitize=address,undefined",
                    "-fno-omit-frame-pointer",
                    f"-DERASED={int(mode == 'erased')}",
                    generated / f"{mode}.c",
                    generated / "bench.c",
                    generated / "stress.c",
                    "-o",
                    binary,
                ]
            )
            run([binary, corpus, str(count)], extra={"ASAN_OPTIONS": "detect_leaks=1"})
        dynamic = work / "asan-dynamic"
        run(
            [
                "clang",
                "-O1",
                "-fsanitize=address,undefined",
                "-fno-omit-frame-pointer",
                HERE / "dynamic.c",
                "-o",
                dynamic,
            ]
        )
        assert (
            run([dynamic], extra={"ASAN_OPTIONS": "detect_leaks=1"})["stdout"]
            == "11 7 4 2\n"
        )
        passed = True
    finally:
        sources = [
            *sorted(HERE.glob("*.py")),
            *sorted(HERE.glob("*.c")),
            HERE / "api.h",
        ]
        (OUT / "checks.json").write_text(
            json.dumps(
                {
                    "passed": passed,
                    "source_sha256": {
                        str(p.relative_to(ROOT)): hashlib.sha256(
                            p.read_bytes()
                        ).hexdigest()
                        for p in sources
                    },
                    "commands": commands,
                    "input": input_info,
                    "results": results,
                },
                indent=2,
            )
            + "\n"
        )
    assert passed


if __name__ == "__main__":
    main()
