"""Check symbolic summary substitution against a freshly compiled core10 module."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from research.experiments.core10 import check as core
from research.experiments.memory01 import sandbox

HERE = Path(__file__).resolve().parent
WORK = HERE / ".work"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--output", type=Path)
    opts = parser.parse_args()
    tool = core.fetch() if opts.fetch else core.WORK / core.PIN["directory"]
    inputs = WORK / "inputs"
    inputs.mkdir(parents=True, exist_ok=True)
    sources = [
        core.HERE / "Core.lean",
        HERE / "Instantiation.lean",
        HERE / "Routes.lean",
    ]
    hashes = {}
    for source in sources:
        data = source.read_bytes()
        (inputs / source.name).write_bytes(data)
        hashes[str(source.relative_to(sandbox.ROOT))] = hashlib.sha256(data).hexdigest()
    version = sandbox.run(
        ["/src/bin/lean", "--version"],
        source=tool,
        inputs=inputs,
        work=WORK / "run",
        rust=False,
    )
    reports = []
    for source in sources:
        args = [
            "/usr/bin/env",
            "LEAN_PATH=/work",
            "/src/bin/lean",
            "--root=/experiment",
            "-DwarningAsError=true",
        ]
        if source != sources[-1]:
            args += ["-o", "/work/" + source.stem + ".olean"]
        args += ["/experiment/" + source.name]
        result = sandbox.run(
            args,
            source=tool,
            inputs=inputs,
            work=WORK / "run",
            rust=False,
        )
        reports.append(
            {
                "module": source.name,
                "command": args,
                "exit": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
            }
        )
        if result.returncode:
            break
    axioms = {}
    for report in reports:
        for name, used in re.findall(
            r"^'(GrailCore\.[\w.]+)' (?:does not depend on any axioms|depends on axioms: \[(.*?)\])$",
            report["stdout"],
            re.MULTILINE,
        ):
            axioms[name] = used.split(", ") if used else []
    required = {
        "GrailCore." + n
        for n in [
            "preservation",
            "checked_contract",
            "public_bound",
            "absent_root",
            "tracked_valid",
            "forged_empty_is_false",
            "wrong_old_return_is_false",
        ]
    } | {
        "GrailCore.Symbolic." + n
        for n in [
            "changed_snapshot_loses_source",
            "instantiate_analyze",
            "instantiate_below",
            "summary_application",
            "imported_summary",
            "imported_public",
        ]
    }
    required |= {
        "GrailCore.Routes." + n
        for n in [
            "sliced_iff_forward",
            "descendant_exact",
            "no_unrelated_output",
            "forward_union",
            "instantiate_forward",
            "forward_supported",
            "replace_project",
            "replace_outside",
        ]
    }
    audit = set(axioms) == required and all(
        set(used) <= {"propext", "Quot.sound"} for used in axioms.values()
    )
    for source in inputs.glob("*.lean"):
        audit = audit and not re.search(
            r"\b(sorry|admit|axiom|unsafe)\b|skipKernelTC", source.read_text()
        )
    ok = (
        not version.returncode
        and f"version {core.PIN['version']}" in version.stdout
        and len(reports) == len(sources)
        and all(not r["exit"] for r in reports)
        and bool(audit)
    )
    report = {
        "toolchain": core.PIN,
        "version": version.stdout.strip(),
        "source_sha256": hashes,
        "theorem_axioms": axioms,
        "axiom_audit_passed": bool(audit),
        "passed": ok,
        "modules": reports,
        "compiler_sha256": hashlib.sha256((tool / "bin/lean").read_bytes()).hexdigest(),
        "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "isolation": "bubblewrap; no network/home; immutable input snapshots; fresh Core.olean and Instantiation.olean",
    }
    if opts.output:
        opts.output.parent.mkdir(parents=True, exist_ok=True)
        opts.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
