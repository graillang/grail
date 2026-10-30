"""Compile/run isolated ownership/projection probes against exact already-cached crate sources."""

from __future__ import annotations

import hashlib
import json
import subprocess
import tarfile
from pathlib import Path
from typing import Any

from research.experiments.memory01 import sandbox

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "research/evidence/bundle07-20261030"

CASES = {
    "covariant_projection": "pass",
    "invariant_projection": "invariant",
    "owned_ast_move": "E0507",
    "exclusive_duplicate": "E0596",
    "exclusive_read": "pass",
    "cell_owned_ast": "pass",
    "cell_inline_owner": "pass",
    "cell_invariant_callback": "pass",
    "cell_callback_str": "pass",
    "cell_bad_covariance": "invariant",
    "cell_escape_invariant": "lifetime",
    "cell_insert_short": "E0597",
    "cell_capture_outside": "E0597",
    "cell_projection_outlives": "E0505",
    "cell_drop_order": "pass",
    "yoke_owned_cart": "pass",
    "yoke_borrowed_cart": "pass",
    "yoke_cannot_own_borrowed": "lifetime",
}


def messages(diagnostic: Any) -> list[str]:
    return [
        diagnostic.get("message", ""),
        *[
            message
            for child in diagnostic.get("children", [])
            for message in messages(child)
        ],
    ]


def library(name: str, version: str, edition: str, flags: list[str]) -> dict[str, Any]:
    matches = list((Path.home() / ".cargo/registry/src").glob(f"*/{name}-{version}"))
    if len(matches) != 1:
        raise RuntimeError(
            f"Expected exactly one cached {name}-{version}; found {len(matches)}; no packages installed"
        )
    source = matches[0]
    expected_packages = {
        "self_cell": "2ab42ca02749e120097e328d91d415325bdf43b1c72c4c8badf37375fe40a813",
        "stable_deref_trait": "6ce2be8dc25455e1f91df71bfa12ad37d7af1092ae736f3a6cd0e37bc7810596",
        "yoke": "709fe23a0424b6a435d82152b1bd3fdfb0833487d5fa90d05d42762a9891fef5",
    }
    archive = (
        source.parents[2] / "cache" / source.parent.name / (source.name + ".crate")
    )
    package_checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    assert package_checksum == expected_packages[name], "unexpected package archive"
    hashes = {}
    with tarfile.open(archive) as package:
        for path in sorted((source / "src").rglob("*.rs")):
            relative = str(path.relative_to(source))
            hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
            original = package.extractfile(source.name + "/" + relative)
            assert original is not None
            assert hashes[relative] == hashlib.sha256(original.read()).hexdigest(), (
                relative
            )
    args = [
        "rustc",
        "--crate-name",
        name,
        "--crate-type=rlib",
        "--edition=" + edition,
        "/src/src/lib.rs",
        "-o",
        "/work/lib" + name + ".rlib",
        *flags,
    ]
    result = sandbox.run(args, source=source, inputs=HERE, work=HERE / ".work")
    assert result.returncode == 0, result.stderr
    return {
        "name": name,
        "version": version,
        "vcs": json.loads((source / ".cargo_vcs_info.json").read_text()),
        "registry_package_checksum": package_checksum,
        "source_sha256": hashes,
        "command": args,
        "compile_returncode": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    libraries = [
        library("self_cell", "1.3.0", "2018", []),
        library("stable_deref_trait", "1.2.1", "2015", ["--cfg", 'feature="alloc"']),
        library(
            "yoke",
            "0.8.3",
            "2021",
            [
                "--cfg",
                'feature="alloc"',
                "--extern",
                "stable_deref_trait=/work/libstable_deref_trait.rlib",
                "-L",
                "dependency=/work",
            ],
        ),
    ]
    results = []
    assert {p.stem for p in HERE.glob("*.rs")} == set(CASES)
    for name, expected in CASES.items():
        flags = []
        if name.startswith("cell_"):
            flags = ["--extern", "self_cell=/work/libself_cell.rlib"]
        if name.startswith("yoke_"):
            flags = ["--extern", "yoke=/work/libyoke.rlib", "-L", "dependency=/work"]
        args = [
            "rustc",
            "--edition=2024",
            "--error-format=json",
            "/experiment/" + name + ".rs",
            "-o",
            "/work/" + name,
            *flags,
        ]
        compiled = sandbox.run(args, inputs=HERE, work=HERE / ".work")
        diagnostics = [json.loads(line) for line in compiled.stderr.splitlines()]
        codes = {
            d["code"]["code"]
            for d in diagnostics
            if d.get("code") and d.get("level") == "error"
        }
        explanations = [
            message
            for d in diagnostics
            if d.get("level") == "error"
            for message in messages(d)
        ]
        matched = (
            compiled.returncode == 0
            if expected == "pass"
            else (
                compiled.returncode != 0
                and (
                    expected in codes
                    or (
                        expected in {"invariant", "lifetime"}
                        and any(expected in message for message in explanations)
                    )
                )
            )
        )
        execution = None
        if compiled.returncode == 0:
            ran = sandbox.run(["/work/" + name], inputs=HERE, work=HERE / ".work")
            matched &= ran.returncode == 0
            execution = {
                "returncode": ran.returncode,
                "stdout": ran.stdout,
                "stderr": ran.stderr,
            }
        results.append(
            {
                "name": name,
                "expected": expected,
                "matched": matched,
                "command": args,
                "compile_returncode": compiled.returncode,
                "diagnostics": diagnostics,
                "execution": execution,
            }
        )
        assert matched, (name, compiled.stderr, execution)
    source_hashes = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(HERE.iterdir())
        if p.suffix in {".rs", ".py"}
    }
    source_hashes["../memory01/sandbox.py"] = hashlib.sha256(
        (HERE.parent / "memory01/sandbox.py").read_bytes()
    ).hexdigest()
    report = {
        "scope": "Rust API/projection distinctions, not a Grail implementation or crate soundness proof",
        "compiler": subprocess.check_output(["rustc", "-Vv"], text=True),
        "libraries": libraries,
        "matched": sum(r["matched"] for r in results),
        "total": len(results),
        "source_sha256": source_hashes,
        "cases": results,
    }
    (OUT / "checks.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(
        json.dumps(
            {
                "matched": report["matched"],
                "total": report["total"],
                "accepted": sum(r["expected"] == "pass" for r in results),
                "rejected": sum(r["expected"] != "pass" for r in results),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
