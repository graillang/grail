"""Reproducible seed/backend/edit-loop probes, not full-language performance claims."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from research.experiments.memory01 import sandbox

SEED = ROOT / "seed"
WORK = SEED / ".work/measure"
BASE = "d6ac951"
BIN = SEED / "target/release/grail-seed"
TCCROOT = ROOT / "research/experiments/memory01/.work/goose-build"
MASK = (1 << 64) - 1
MAIN = """#include <stdint.h>
#include <stdio.h>
uint64_t g_entry(void);
int main(void) { printf("%llu\\n", (unsigned long long)g_entry()); }
"""
RUST = """fn scan(input: &[u8], salt: u64) -> u64 {
 let mut hash=14695981039346656037u64; let mut words=0u64; let mut prev=true;
 let mut table=[0u8;128]; let mut j=0;
 while j<128 {table[j]=((j*17)%251) as u8;j+=1;}
 let mut i=0;
 while i<input.len() {let b=input[i]; hash=(hash ^ u64::from(b)).wrapping_mul(1099511628211);
 words+=u64::from(b!=32 && prev);prev=b==32;
 let index=usize::from(b)%128; table[index]=table[index].wrapping_add(1);i+=1;}
 for value in table {hash ^= u64::from(value);}
 hash.wrapping_add(words).wrapping_add(salt)
}
fn main() {
 let mut input=[0u8; LENGTH]; let mut i=0;
 while i<input.len() {input[i]=((i*17+7)%251) as u8;i+=1;}
 let mut sum=0u64;let mut j=0;
 while j<REPEATS {sum=sum.wrapping_add(scan(&input,9));j+=1;}
 println!("{sum}");
}
"""


def oracle(length: int, repeats: int, bias: int) -> int:
    h, words, previous = 14695981039346656037, 0, True
    table = [(i * 17) % 251 for i in range(128)]
    for i in range(length):
        b = (i * 17 + 7) % 251
        h = ((h ^ b) * 1099511628211) & MASK
        words += b != 32 and previous
        previous = b == 32
        table[b % 128] = (table[b % 128] + 1) & 255
    for value in table:
        h ^= value
    return ((h + words + 9 + bias) * repeats) & MASK


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "research/evidence/seed18-20261030/checks.json",
    )
    parser.add_argument("--pairs", type=int, default=10)
    parser.add_argument("--length", type=int, default=65536)
    parser.add_argument("--repeats", type=int, default=32)
    opts = parser.parse_args()
    assert opts.pairs >= 2 and 0 <= opts.length <= 1024 * 1024 and opts.repeats > 0
    WORK.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    report: dict = {
        "passed": False,
        "commands": rows,
        "scope": "fixed typed-IR workloads, Linux x86-64, warm filesystem, shared host; runtime includes process/isolation startup; not complete Grail or a matched Rust compiler benchmark",
        "baseline": BASE,
        "pairs": opts.pairs,
        "environment": {
            k: os.environ.get(k)
            for k in [
                "RUSTFLAGS",
                "CARGO_ENCODED_RUSTFLAGS",
                "CFLAGS",
                "CPATH",
                "C_INCLUDE_PATH",
                "LIBRARY_PATH",
                "LD_LIBRARY_PATH",
            ]
        },
        "length": opts.length,
        "repeats": opts.repeats,
        "host": {
            "arch": platform.machine(),
            "kernel": platform.release(),
            "cpu": next(
                (
                    s.split(":", 1)[1].strip()
                    for s in Path("/proc/cpuinfo").read_text().splitlines()
                    if s.startswith("model name")
                ),
                "",
            ),
            "load_start": os.getloadavg(),
        },
    }

    def run(cmd: list[str], phase: str, **tags) -> dict:
        inputs = {
            arg: hashlib.sha256(Path(arg).read_bytes()).hexdigest()
            for arg in cmd
            if Path(arg).suffix in {".c", ".ll", ".rs", ".api", ".o", ".a"}
            and Path(arg).is_file()
        }
        started = time.perf_counter_ns()

        def timeout(_signum, _frame):
            raise TimeoutError("measurement process exceeded 180 seconds")

        with (
            tempfile.TemporaryFile(mode="w+") as stdout,
            tempfile.TemporaryFile(mode="w+") as stderr,
        ):
            p = subprocess.Popen(
                cmd, stdout=stdout, stderr=stderr, start_new_session=True
            )
            old_handler = signal.signal(signal.SIGALRM, timeout)
            signal.setitimer(signal.ITIMER_REAL, 180)
            try:
                _, status, usage = os.wait4(p.pid, 0)
            except TimeoutError:
                os.killpg(p.pid, signal.SIGKILL)
                _, status, usage = os.wait4(p.pid, 0)
                raise
            finally:
                signal.setitimer(signal.ITIMER_REAL, 0)
                signal.signal(signal.SIGALRM, old_handler)
            p.returncode = os.waitstatus_to_exitcode(status)
            elapsed = time.perf_counter_ns() - started
            stdout.seek(0)
            stderr.seek(0)
            row = {
                "phase": phase,
                **tags,
                "command": cmd,
                "wall_ns": elapsed,
                "exit": p.returncode,
                "stdout": stdout.read(),
                "stderr": stderr.read(),
                "input_sha256": inputs,
                "maxrss_kib": usage.ru_maxrss,
                "user_seconds": usage.ru_utime,
                "system_seconds": usage.ru_stime,
            }
        rows.append(row)
        assert row["exit"] == 0, row
        return row

    try:
        run(
            [
                "cargo",
                "build",
                "--manifest-path",
                str(SEED / "Cargo.toml"),
                "--release",
                "--offline",
            ],
            "build-seed",
        )
        report["versions"] = {
            tool: run([tool, "--version"], "version")["stdout"]
            for tool in ["rustc", "clang", "llc", "gcc"]
        }
        report["tinycc"] = {
            "binary_sha256": hashlib.sha256(
                (TCCROOT / "tcc/tcc").read_bytes()
            ).hexdigest(),
            "version": run([str(TCCROOT / "tcc/tcc"), "-v"], "version")["stderr"],
            "source_revision": (
                ROOT / "research/repos/goose/third_party/tinycc/README.md"
            ).read_text()[:2000],
        }
        # Rebuild the delivered scan-based implementation, without touching the worktree.
        old = WORK / "baseline"
        for name in [
            "Cargo.toml",
            "Cargo.lock",
            "src/lib.rs",
            "src/main.rs",
            "src/fixture.rs",
            "src/emit.rs",
        ]:
            path = old / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(
                subprocess.check_output(
                    ["git", "show", f"{BASE}:seed/{name}"], cwd=ROOT
                )
            )
        run(
            [
                "cargo",
                "build",
                "--manifest-path",
                str(old / "Cargo.toml"),
                "--release",
                "--offline",
            ],
            "build-baseline",
        )
        binaries = {"before": old / "target/release/grail-seed", "after": BIN}
        report["seed_binary_sha256"] = {
            k: hashlib.sha256(v.read_bytes()).hexdigest() for k, v in binaries.items()
        }
        for size in [16, 64, 256, 1024, 4096]:
            for pair in range(opts.pairs + 1):
                for variant in (
                    ["before", "after"] if pair % 2 == 0 else ["after", "before"]
                ):
                    row = run(
                        [str(binaries[variant]), "scale", str(size)],
                        "scaling",
                        pair=pair,
                        warmup=pair == 0,
                        variant=variant,
                        size=size,
                    )
                    row["internal"] = [
                        json.loads(line) for line in row["stdout"].splitlines()
                    ]
        report["scaling"] = [
            {
                "size": size,
                "fanout": fanout,
                **{
                    variant + "_median_ns": statistics.median(
                        point["check_ns"]
                        for row in rows
                        if row["phase"] == "scaling"
                        and row["size"] == size
                        and row["variant"] == variant
                        and not row["warmup"]
                        for point in row["internal"]
                        if point["fanout"] == fanout
                    )
                    for variant in binaries
                },
            }
            for size in [16, 64, 256, 1024, 4096]
            for fanout in [False, True]
        ]

        configs = [
            ("tcc", "c", []),
            ("clang-c-O0", "c", ["clang", "-O0"]),
            ("clang-ir-O0", "llvm", ["clang", "-O0", "-Wno-override-module"]),
            ("clang-c-O2", "c", ["clang", "-O2"]),
            ("clang-ir-O2", "llvm", ["clang", "-O2", "-Wno-override-module"]),
        ]

        def native_compile(
            source: Path, obj: Path, name: str, flags: list[str], phase: str, **tags
        ) -> None:
            cmd = (
                [
                    str(TCCROOT / "tcc/tcc"),
                    "-B",
                    str(TCCROOT / "tcclib"),
                    "-I/usr/include",
                ]
                if name == "tcc"
                else flags
            )
            run([*cmd, "-c", str(source), "-o", str(obj)], phase, backend=name, **tags)

        def link(d: Path, name: str, flags: list[str], **tags) -> None:
            objects = [str(d / f"{s}.o") for s in ["scan", "entry", "main"]]
            if name == "tcc":
                cmd = [
                    str(TCCROOT / "tcc/tcc"),
                    "-B",
                    str(TCCROOT / "tcclib"),
                    "-L/usr/lib",
                    "-nostdlib",
                    "/usr/lib/crt1.o",
                    "/usr/lib/crti.o",
                    *objects,
                    str(TCCROOT / "tcclib/libtcc1.a"),
                    "-lc",
                    "/usr/lib/crtn.o",
                ]
            else:
                cmd = [*flags, *objects]
            run([*cmd, "-o", str(d / "run")], "link", backend=name, **tags)

        def execute(d: Path, expected: int, **tags) -> None:
            # Same isolation envelope for all native backends, including Rust.
            row = run(
                sandbox.command(["/work/run"], work=d, rust=False), "runtime", **tags
            )
            assert row["stdout"].strip() == str(expected), row

        for pair in range(opts.pairs + 1):
            order = configs if pair % 2 == 0 else list(reversed(configs))
            for name, backend, flags in order:
                d = WORK / name
                d.mkdir(exist_ok=True)
                ext = "c" if backend == "c" else "ll"
                tags = {"pair": pair, "warmup": pair == 0}
                started = time.perf_counter_ns()
                run(
                    [str(BIN), "provider", str(d), "0", "1", backend],
                    "check-emit-provider",
                    backend=name,
                    **tags,
                )
                api = (d / "scan.api").read_bytes()
                # Client accepts only the public signature. No provider body is an input to check().
                run(
                    [
                        str(BIN),
                        "client",
                        str(d),
                        str(d / "scan.api"),
                        f"{opts.length}:{opts.repeats}",
                        backend,
                    ],
                    "check-emit-client",
                    backend=name,
                    **tags,
                )
                (d / "main.c").write_text(MAIN)
                for unit in ["scan", "entry", "main"]:
                    source = d / (unit + (".c" if unit == "main" else "." + ext))
                    native_compile(
                        source,
                        d / f"{unit}.o",
                        name,
                        flags,
                        "compile-clean",
                        unit=unit,
                        **tags,
                    )
                link(d, name, flags, edit="clean", **tags)
                rows.append(
                    {
                        "phase": "pipeline",
                        "backend": name,
                        "edit": "clean",
                        "wall_ns": time.perf_counter_ns() - started,
                        **tags,
                    }
                )
                execute(
                    d,
                    oracle(opts.length, opts.repeats, 0),
                    backend=name,
                    edit="clean",
                    **tags,
                )
                client_hash = hashlib.sha256((d / "entry.o").read_bytes()).hexdigest()
                started = time.perf_counter_ns()
                run(
                    [str(BIN), "provider", str(d), "1", "1", backend],
                    "check-emit-provider",
                    backend=name,
                    edit="body",
                    **tags,
                )
                assert api == (d / "scan.api").read_bytes()
                native_compile(
                    d / f"scan.{ext}", d / "scan.o", name, flags, "compile-body", **tags
                )
                link(d, name, flags, edit="body", **tags)
                assert (
                    client_hash
                    == hashlib.sha256((d / "entry.o").read_bytes()).hexdigest()
                )
                rows.append(
                    {
                        "phase": "pipeline",
                        "backend": name,
                        "edit": "body",
                        "client": "not rechecked/emitted/compiled; object reused",
                        "wall_ns": time.perf_counter_ns() - started,
                        **tags,
                    }
                )
                execute(
                    d,
                    oracle(opts.length, opts.repeats, 1),
                    backend=name,
                    edit="body",
                    **tags,
                )
                started = time.perf_counter_ns()
                run(
                    [str(BIN), "provider", str(d), "0", "2", backend],
                    "check-emit-provider",
                    backend=name,
                    edit="signature",
                    **tags,
                )
                assert api != (d / "scan.api").read_bytes()
                run(
                    [
                        str(BIN),
                        "client",
                        str(d),
                        str(d / "scan.api"),
                        f"{opts.length}:{opts.repeats}",
                        backend,
                    ],
                    "check-emit-client",
                    backend=name,
                    edit="signature",
                    **tags,
                )
                for unit in ["scan", "entry"]:
                    native_compile(
                        d / f"{unit}.{ext}",
                        d / f"{unit}.o",
                        name,
                        flags,
                        "compile-signature",
                        unit=unit,
                        **tags,
                    )
                link(d, name, flags, edit="signature", **tags)
                rows.append(
                    {
                        "phase": "pipeline",
                        "backend": name,
                        "edit": "signature",
                        "client": "rechecked/emitted/compiled",
                        "wall_ns": time.perf_counter_ns() - started,
                        **tags,
                    }
                )
                execute(
                    d,
                    oracle(opts.length, opts.repeats, 0),
                    backend=name,
                    edit="signature",
                    **tags,
                )
        # An actual Rust executable for runtime context, not an apples-to-apples compiler comparison.
        for opt in [0, 2]:
            d = WORK / f"rust-O{opt}"
            d.mkdir(exist_ok=True)
            (d / "main.rs").write_text(
                RUST.replace("LENGTH", str(opts.length)).replace(
                    "REPEATS", str(opts.repeats)
                )
            )
            run(
                [
                    "rustc",
                    "--edition=2024",
                    "-C",
                    f"opt-level={opt}",
                    "-C",
                    "panic=abort",
                    str(d / "main.rs"),
                    "-o",
                    str(d / "run"),
                ],
                "rust-build-context",
                backend=f"rust-O{opt}",
            )
        runtime_names = [*(config[0] for config in configs), "rust-O0", "rust-O2"]
        for pair in range(opts.pairs + 1):
            for name in (
                runtime_names if pair % 2 == 0 else list(reversed(runtime_names))
            ):
                execute(
                    WORK / name,
                    oracle(opts.length, opts.repeats, 0),
                    backend=name,
                    edit="runtime-paired",
                    pair=pair,
                    warmup=pair == 0,
                )
        # Edge lengths: emit/check/build independently; oracle is not derived from either emitter.
        for length in [0, 1, 1024, 65537]:
            for name, backend, flags in configs:
                d = WORK / ("edge-" + name)
                d.mkdir(exist_ok=True)
                ext = "c" if backend == "c" else "ll"
                run(
                    [str(BIN), "provider", str(d), "0", "1", backend],
                    "edge-emit",
                    backend=name,
                    length=length,
                )
                run(
                    [
                        str(BIN),
                        "client",
                        str(d),
                        str(d / "scan.api"),
                        f"{length}:2",
                        backend,
                    ],
                    "edge-emit",
                    backend=name,
                    length=length,
                )
                (d / "main.c").write_text(MAIN)
                for unit in ["scan", "entry", "main"]:
                    native_compile(
                        d / (unit + (".c" if unit == "main" else "." + ext)),
                        d / f"{unit}.o",
                        name,
                        flags,
                        "edge-compile",
                        length=length,
                    )
                link(d, name, flags, length=length)
                execute(
                    d, oracle(length, 2, 0), backend=name, length=length, edit="edge"
                )
        report["summary"] = [
            {
                "backend": name,
                "edit": edit,
                "median_ms": statistics.median(
                    row["wall_ns"]
                    for row in rows
                    if row["phase"] == "pipeline"
                    and row["backend"] == name
                    and row["edit"] == edit
                    and not row["warmup"]
                )
                / 1e6,
            }
            for name, _, _ in configs
            for edit in ["clean", "body", "signature"]
        ]
        report["runtime"] = [
            {
                "backend": name,
                "median_ms": statistics.median(
                    row["wall_ns"]
                    for row in rows
                    if row["phase"] == "runtime"
                    and row["backend"] == name
                    and row.get("edit") == "runtime-paired"
                    and not row["warmup"]
                )
                / 1e6,
            }
            for name in [*(c[0] for c in configs), "rust-O0", "rust-O2"]
        ]
        report["passed"] = True
    finally:
        report["host"]["load_end"] = os.getloadavg()
        report["source_sha256"] = {
            str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in [
                *sorted((SEED / "src").glob("*.rs")),
                *sorted((SEED / "tests").glob("*.rs")),
                SEED / "Cargo.toml",
                SEED / "Cargo.lock",
                Path(__file__).resolve(),
            ]
        }
        opts.output.parent.mkdir(parents=True, exist_ok=True)
        opts.output.write_text(json.dumps(report, indent=2) + "\n")
    print(
        json.dumps(
            {
                "passed": report["passed"],
                "summary": report["summary"],
                "runtime": report["runtime"],
                "scaling_4096": report["scaling"][-2:],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
