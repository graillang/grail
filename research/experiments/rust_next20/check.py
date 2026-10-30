"""Compare stable Rust, explicit next checking, and pinned modern nightly; not a benchmark."""

from __future__ import annotations

import hashlib
import json
import subprocess
import urllib.request
from pathlib import Path

from research.experiments.memory01 import sandbox

HERE = Path(__file__).resolve().parent
OUT = sandbox.ROOT / "research/evidence/rust-next20-20261030"
URLS = [
    "https://blog.rust-lang.org/2026/08/04/enabling-polonius-alpha-on-nightly/",
    "https://blog.rust-lang.org/2026/08/21/enabling-next-solver-on-nightly/",
    "https://goals.rust-lang.org/2026/polonius.html",
    "https://goals.rust-lang.org/2026/next-solver.html",
    "https://static.rust-lang.org/dist/2026-10-29/channel-rust-nightly.toml",
]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    work = HERE / ".work"
    inputs = work / "inputs"
    inputs.mkdir(parents=True, exist_ok=True)
    nightly = work / "rustup/toolchains/nightly-2026-10-29-x86_64-unknown-linux-gnu"
    stable = Path(
        subprocess.check_output(
            ["rustup", "which", "--toolchain", "stable", "rustc"], text=True
        ).strip()
    ).parent.parent
    assert (nightly / "bin/rustc").is_file(), (
        "install the pinned toolchain in the experiment-local RUSTUP_HOME first"
    )
    sources = [
        *sorted(HERE.glob("*.rs")),
        *[
            HERE.parent / "referents14" / f"{name}.rs"
            for name in [
                "helper_replace",
                "temporary_restore",
                "temporary_escape",
                "direct_reset",
            ]
        ],
    ]
    for src in sources:
        (inputs / src.name).write_bytes(src.read_bytes())
    configurations = [
        ("stable-default", stable, []),
        ("stable-next", stable, ["-Zpolonius=next", "-Znext-solver=globally"]),
        ("nightly-default", nightly, []),
        ("nightly-next", nightly, ["-Zpolonius=next", "-Znext-solver=globally"]),
        ("nightly-legacy", nightly, ["-Zpolonius=no", "-Znext-solver=no"]),
        ("nightly-polonius-only", nightly, ["-Zpolonius=next", "-Znext-solver=no"]),
        ("nightly-solver-only", nightly, ["-Zpolonius=no", "-Znext-solver=globally"]),
    ]
    report = {
        "scope": "targeted capability controls, not a Rust soundness proof or compiler-performance benchmark",
        "sources": {},
        "toolchains": {},
        "cases": [],
    }
    for label, tool, flags in configurations:
        version = subprocess.check_output([str(tool / "bin/rustc"), "-Vv"], text=True)
        report["toolchains"][label] = {
            "version": version,
            "flags": flags,
            "compiler_sha256": hashlib.sha256(
                (tool / "bin/rustc").read_bytes()
            ).hexdigest(),
        }
        # Validate flag availability independently: an unsupported switch is not a language rejection.
        (inputs / "flag_control.rs").write_text("fn main() {}\n")
        root = work / label
        root.mkdir(exist_ok=True)
        control = sandbox.run(
            [
                "env",
                "RUSTC_BOOTSTRAP=1",
                "/src/bin/rustc",
                *flags,
                "/experiment/flag_control.rs",
                "-o",
                "/work/control",
            ],
            source=tool,
            work=root,
            inputs=inputs,
            rust=False,
        )
        report["toolchains"][label]["flag_control"] = {
            "exit": control.returncode,
            "stderr": control.stderr,
        }
        if control.returncode:
            continue
        for src in sources:
            name = src.stem
            cmd = [
                "env",
                "RUSTC_BOOTSTRAP=1",
                "/src/bin/rustc",
                "--edition=2024",
                *flags,
                "--error-format=json",
                f"/experiment/{src.name}",
                "-o",
                f"/work/{name}",
            ]
            result = sandbox.run(cmd, source=tool, work=root, inputs=inputs, rust=False)
            row = {
                "configuration": label,
                "case": name,
                "command": cmd,
                "exit": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "codes": [],
                "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
            }
            for line in result.stderr.splitlines():
                try:
                    diagnostic = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if diagnostic.get("level") == "error" and diagnostic.get("code"):
                    row["codes"].append(diagnostic["code"]["code"])
            if result.returncode == 0 and name in [
                "get_default",
                "conditional_reborrow",
                "tail_cursor",
                "direct_reset",
            ]:
                p = sandbox.run([f"/work/{name}"], work=root, rust=False, inputs=inputs)
                row["runtime"] = {
                    "exit": p.returncode,
                    "stdout": p.stdout,
                    "stderr": p.stderr,
                }
                assert p.returncode == 0, row
            report["cases"].append(row)
    for index, url in enumerate(URLS):
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read()
        (work / f"source-{index}.txt").write_bytes(data)
        report["sources"][url] = {
            "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
            "snapshot": f".work/source-{index}.txt",
        }
    report["unsafe_escape_controls_rejected"] = all(
        r["exit"] != 0 for r in report["cases"] if r["case"] == "temporary_escape"
    )
    assert report["unsafe_escape_controls_rejected"], (
        "unsafe escape accepted; never execute it"
    )
    report["runner_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    (OUT / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
    for label, _, _ in configurations:
        print(
            label,
            [
                (r["case"], r["exit"] == 0, r["codes"])
                for r in report["cases"]
                if r["configuration"] == label
            ],
        )


if __name__ == "__main__":
    main()
