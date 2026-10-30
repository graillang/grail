"""Check the research preservation model with a pinned, isolated Lean kernel."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import tarfile
import urllib.request
from pathlib import Path

from research.experiments.memory01 import sandbox

HERE = Path(__file__).resolve().parent
WORK = HERE / ".work"
PIN = json.loads((HERE / "toolchain.json").read_text())


def fetch() -> Path:
    """Fetch only the pinned official archive into disposable project-local storage."""
    WORK.mkdir(exist_ok=True)
    if shutil.disk_usage(WORK).free < 10 * 1024**3:
        raise RuntimeError("need 10 GiB free before unpacking Lean")
    archive = WORK / "lean.tar.zst"
    if not archive.exists():
        request = urllib.request.Request(
            PIN["url"], headers={"User-Agent": "grail-research"}
        )
        with (
            urllib.request.urlopen(request, timeout=60) as response,
            archive.open("wb") as out,
        ):
            total = 0
            while block := response.read(1024**2):
                total += len(block)
                if total > PIN["archive_bytes"]:
                    raise RuntimeError("download exceeds pinned size")
                out.write(block)
    with archive.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if archive.stat().st_size != PIN["archive_bytes"] or digest != PIN["sha256"]:
        raise RuntimeError(
            "Lean archive size/hash mismatch; remove incomplete owned archive"
        )
    tool = WORK / PIN["directory"]
    if not tool.exists():
        with tarfile.open(archive, "r:zst") as tar:
            members = tar.getmembers()
            if sum(m.size for m in members) > 8 * 1024**3:
                raise RuntimeError("toolchain exceeds extraction budget")
            if any(Path(m.name).parts[0] != PIN["directory"] for m in members):
                raise RuntimeError("unexpected archive root")
            tar.extractall(WORK, members=members, filter="data")
    return tool


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--output", type=Path)
    opts = parser.parse_args()
    tool = fetch() if opts.fetch else WORK / PIN["directory"]
    if not (tool / "bin/lean").is_file():
        raise SystemExit("run with --fetch to obtain the pinned local toolchain")
    version = sandbox.run(
        ["/src/bin/lean", "--version"],
        source=tool,
        inputs=HERE,
        work=WORK / "run",
        rust=False,
    )
    result = sandbox.run(
        ["/src/bin/lean", "-DwarningAsError=true", "/experiment/Core.lean"],
        source=tool,
        inputs=HERE,
        work=WORK / "run",
        rust=False,
    )
    axioms = {}
    for name, used in re.findall(
        r"^'GrailCore\.(\w+)' (?:does not depend on any axioms|depends on axioms: \[(.*?)\])$",
        result.stdout,
        re.MULTILINE,
    ):
        axioms[name] = used.split(", ") if used else []
    required = {
        "preservation",
        "checked_contract",
        "public_bound",
        "absent_root",
        "tracked_valid",
        "forged_empty_is_false",
        "wrong_old_return_is_false",
    }
    audit_ok = set(axioms) == required and all(
        set(used) <= {"propext"} for used in axioms.values()
    )
    source = (HERE / "Core.lean").read_text()
    audit_ok = audit_ok and not re.search(
        r"\b(sorry|admit|axiom|unsafe)\b|skipKernelTC", source
    )
    report = {
        "toolchain": PIN,
        "version": version.stdout.strip(),
        "theorem_axioms": axioms,
        "axiom_audit_passed": bool(audit_ok),
        "compiler_sha256": hashlib.sha256((tool / "bin/lean").read_bytes()).hexdigest(),
        "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "source_sha256": hashlib.sha256((HERE / "Core.lean").read_bytes()).hexdigest(),
        "command": ["lean", "-DwarningAsError=true", "Core.lean"],
        "exit": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
        "isolation": "bubblewrap; no network/home; read-only compiler and experiment",
    }
    if opts.output:
        opts.output.parent.mkdir(parents=True, exist_ok=True)
        opts.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if version.returncode or f"version {PIN['version']}" not in version.stdout:
        raise SystemExit("unexpected Lean version")
    raise SystemExit(result.returncode or (0 if audit_ok else 1))


if __name__ == "__main__":
    main()
