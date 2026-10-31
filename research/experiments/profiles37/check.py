"""Actual optimizing driver profiles: reproducibility, guards, hidden-module and scanning controls."""

from __future__ import annotations

import hashlib
import json
import os
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / "research/evidence/profiles37-20261031"
WORK = HERE / ".work"
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)
TCC_ROOT = ROOT / "research/experiments/memory01/.work/goose-build"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    work = WORK / f"replay-{time.time_ns()}"
    work.mkdir()
    commands = []
    measurements = []
    corpus_info = {}

    def run(cmd: list[str | Path], extra: dict[str, str] | None = None) -> dict:
        env = extra or {}
        t = time.perf_counter()
        p = subprocess.run(
            [str(c) for c in cmd],
            cwd=ROOT,
            env={**os.environ, **env},
            text=True,
            capture_output=True,
            check=False,
        )
        row = {
            "command": [str(c) for c in cmd],
            "environment": env,
            "exit": p.returncode,
            "seconds": time.perf_counter() - t,
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
        commands.append(row)
        assert p.returncode == 0, row
        print("ok", " ".join(arg[:180] for arg in row["command"][:8]), flush=True)
        return row

    passed = False
    try:
        run(["rustc", "-Vv"])
        run([NIGHT / "bin/rustc", "-Vv"])
        run(["clang", "--version"])
        run([TCC_ROOT / "tcc/tcc", "-v"])
        run(["cargo", "fmt", "--manifest-path", "seed/Cargo.toml", "--", "--check"])
        run(
            [
                "cargo",
                "clippy",
                "--manifest-path",
                "seed/Cargo.toml",
                "--offline",
                "--all-targets",
                "--",
                "-D",
                "warnings",
            ]
        )
        cargo = ["cargo", "test", "--manifest-path", "seed/Cargo.toml", "--offline"]
        run([*cargo, "--", "--include-ignored"])
        run(
            [
                "cargo",
                "build",
                "--manifest-path",
                "seed/Cargo.toml",
                "--offline",
                "--release",
            ]
        )
        env = {"GRAIL_TCC_ROOT": str(TCC_ROOT), "GRAIL_RELEASE_MIXED_BACKEND": "1"}
        run([*cargo, "--test", "profiles_native", "--", "--include-ignored"], env)
        run(
            [*cargo, "--test", "text_native", "--", "--include-ignored"],
            {"GRAIL_NATIVE_TEST_BACKEND": "clang-release"},
        )
        run(
            [*cargo, "--test", "artifacts_native", "--", "--include-ignored"],
            {"GRAIL_ARTIFACT_TEST_BACKEND": "clang-release"},
        )
        run(
            [*cargo, "--", "--include-ignored"],
            {
                "RUSTC": str(NIGHT / "bin/rustc"),
                "RUSTDOC": str(NIGHT / "bin/rustdoc"),
                "CARGO_TARGET_DIR": str(WORK / "nightly-target"),
            },
        )
        corpus = (ROOT / "seed/src/source.rs").read_text()[:32768].encode()
        (work / "corpus.txt").write_bytes(corpus)
        corpus_info = {
            "source": "seed/src/source.rs",
            "bytes": len(corpus),
            "sha256": hashlib.sha256(corpus).hexdigest(),
            "repeats": 128,
        }
        h = 1469598103934665603
        words = 0
        inside = False
        for _ in range(128):
            for byte in corpus:
                current = (
                    byte == 95
                    or 48 <= byte <= 57
                    or 65 <= byte <= 90
                    or 97 <= byte <= 122
                )
                words += int(current and not inside)
                inside = current
                h = ((h * 1099511628211) & ((1 << 64) - 1)) ^ byte
        expected = f"{h ^ words}\n"
        corpus_info["checksum"] = expected.strip()
        source = HERE / "scan.grl"
        binary = ROOT / "seed/target/release/grail-seed"
        c = None
        for profile in ["clang", "clang-release", "tcc"]:
            directory = work / profile
            directory.mkdir()
            builds = []
            runs = []
            generations = []
            hashes = []
            for _ in range(3):
                row = run(
                    [binary, "build", source, directory, directory, profile],
                    {"GRAIL_TCC_ROOT": str(TCC_ROOT)},
                )
                builds.append(row["seconds"])
                generations.append((directory / "scan.artifact").read_text().strip())
                image = (directory / "scan").read_bytes()
                hashes.append(hashlib.sha256(image).hexdigest())
                row = run([directory / "scan", corpus.decode()])
                assert row["stdout"] == expected
                row["command"][-1] = (
                    f"<corpus:{len(corpus)} bytes sha256:{corpus_info['sha256']}>"
                )
                runs.append(row["seconds"])
            assert len(set(generations)) == len(set(hashes)) == 1
            current = (directory / "scan.c").read_bytes()
            if c is None:
                c = current
            else:
                assert c == current
            measurements.append(
                {
                    "profile": profile,
                    "build_median": statistics.median(builds),
                    "run_median": statistics.median(runs),
                    "executable_bytes": (directory / "scan").stat().st_size,
                    "object_bytes": (directory / "scan.o").stat().st_size,
                    "generation": generations[0],
                    "executable_sha256": hashes[0],
                }
            )
        passed = True
    finally:
        files = [
            *ROOT.glob("seed/src/*.rs"),
            *ROOT.glob("seed/src/*.h"),
            *ROOT.glob("seed/tests/**/*.rs"),
            *ROOT.glob("seed/tests/support/*.c"),
            *ROOT.glob("seed/examples/**/*.grl"),
            *ROOT.glob("seed/std/*.grl"),
            *HERE.glob("*.py"),
            *HERE.glob("*.grl"),
            ROOT / "seed/Cargo.toml",
            ROOT / "seed/Cargo.lock",
        ]
        hashes = {
            str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(files)
        }
        (OUT / "checks.json").write_text(
            json.dumps(
                {
                    "passed": passed,
                    "commands": commands,
                    "hashes": hashes,
                    "corpus": corpus_info,
                    "measurements": measurements,
                },
                indent=2,
            )
            + "\n"
        )


if __name__ == "__main__":
    main()
