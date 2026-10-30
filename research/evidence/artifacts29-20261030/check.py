import hashlib
import json
import os
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "research/evidence/artifacts29-20261030"
WORK = ROOT / "seed/.work/artifacts29"
WORK.mkdir(parents=True, exist_ok=True)
NIGHT = (
    ROOT
    / "research/experiments/rust_next20/.work/rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
)
r = []


def run(cmd, extra=None):
    env = os.environ.copy()
    env.update(extra or {})
    t = time.perf_counter()
    p = subprocess.run(
        [str(x) for x in cmd],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )
    row = {
        "command": [str(x) for x in cmd],
        "environment": extra or {},
        "exit": p.returncode,
        "seconds": time.perf_counter() - t,
        "stdout": p.stdout,
        "stderr": p.stderr,
    }
    r.append(row)
    print(p.returncode, " ".join(row["command"]), flush=True)
    assert p.returncode == 0, p.stderr
    return row


run(["cargo", "fmt", "--manifest-path", "seed/Cargo.toml", "--", "--check"])
run(
    [
        "cargo",
        "test",
        "--manifest-path",
        "seed/Cargo.toml",
        "--offline",
        "--",
        "--include-ignored",
    ]
)
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
run(["cargo", "build", "--manifest-path", "seed/Cargo.toml", "--offline", "--release"])
tcc = {"GRAIL_TCC_ROOT": str(ROOT / "research/experiments/memory01/.work/goose-build")}
run(
    [
        "cargo",
        "test",
        "--manifest-path",
        "seed/Cargo.toml",
        "--offline",
        "--test",
        "artifacts_native",
        "--test",
        "modules_native",
        "--",
        "--include-ignored",
    ],
    dict(tcc, GRAIL_ARTIFACT_TEST_BACKEND="tcc", GRAIL_MODULE_TEST_BACKEND="tcc"),
)
run(
    [
        "cargo",
        "test",
        "--manifest-path",
        "seed/Cargo.toml",
        "--offline",
        "--",
        "--include-ignored",
    ],
    {
        "RUSTC": str(NIGHT / "bin/rustc"),
        "RUSTDOC": str(NIGHT / "bin/rustdoc"),
        "CARGO_TARGET_DIR": str(ROOT / "seed/.work/nightly-target"),
    },
)
measurements = {}
identities = {}
for backend in ["clang", "tcc"]:
    samples = []
    out = WORK / backend
    out.mkdir(exist_ok=True)
    for i in range(5):
        t = time.perf_counter()
        run(
            [
                ROOT / "seed/target/release/grail-seed",
                "compile",
                "seed/examples/number.grl",
                out,
                out,
                backend,
            ],
            tcc,
        )
        run(
            [
                ROOT / "seed/target/release/grail-seed",
                "build",
                "seed/examples/sum.grl",
                out,
                out,
                backend,
            ],
            tcc,
        )
        samples.append(time.perf_counter() - t)
        assert run([out / "sum", "12+34+5"])["stdout"] == "51\n"
    measurements[backend] = {
        "build_seconds": samples,
        "median_seconds": statistics.median(samples),
    }
    original = {n: (out / f"{n}.artifact").read_text() for n in ["number", "sum"]}
    night = WORK / f"nightly-{backend}"
    night.mkdir(exist_ok=True)
    run(
        [
            ROOT / "seed/.work/nightly-target/debug/grail-seed",
            "compile",
            "seed/examples/number.grl",
            night,
            night,
            backend,
        ],
        tcc,
    )
    run(
        [
            ROOT / "seed/.work/nightly-target/debug/grail-seed",
            "build",
            "seed/examples/sum.grl",
            night,
            night,
            backend,
        ],
        tcc,
    )
    for name, ident in original.items():
        assert (night / f"{name}.artifact").read_text() == ident
        generation = out / ".grail-store" / ident.strip()
        manifest = (generation / "manifest").read_bytes()
        assert hashlib.sha256(manifest).hexdigest() == ident.strip()
        lines = manifest.decode().splitlines()
        assert lines[:2] == ["grail-seed-artifact-1", name]
        for extension, want in zip(["api", "o", "c"], lines[2:]):
            assert (
                hashlib.sha256(
                    (generation / f"{name}.{extension}").read_bytes()
                ).hexdigest()
                == want
            )
    assert (night / "sum").read_bytes() == (out / "sum").read_bytes()
    identities[backend] = {n: i.strip() for n, i in original.items()}
files = [
    "seed/src/artifact.rs",
    "seed/src/driver.rs",
    "seed/src/lib.rs",
    "seed/tests/artifacts.rs",
    "seed/tests/artifacts_native.rs",
    "seed/tests/modules_native.rs",
    "research/evidence/artifacts29-20261030/check.py",
]
(OUT / "checks.json").write_text(
    json.dumps(
        {
            "passed": True,
            "commands": r,
            "parser_build_measurements": measurements,
            "independently_verified_generation_ids": identities,
            "seed_compiler_control": "stable release versus pinned nightly debug: equal native generations and executable bytes, not self-hosting",
            "source_sha256": {
                f: hashlib.sha256((ROOT / f).read_bytes()).hexdigest() for f in files
            },
        },
        indent=2,
    )
    + "\n"
)
print("MEASUREMENTS", json.dumps(measurements), flush=True)
