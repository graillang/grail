"""Run the installed Quint in a network/home-isolated sandbox; no installation."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "research/evidence/prior-art03-20261030"
MODULES = Path("/home/shulgin/.bun/install/global/node_modules")
_spec = importlib.util.spec_from_file_location(
    "grail_experiment_sandbox", HERE.parent / "memory01/sandbox.py"
)
assert _spec is not None and _spec.loader is not None
sandbox = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sandbox)


def quint(args: list[str]) -> subprocess.CompletedProcess[str]:
    command = sandbox.command(
        [
            "/usr/bin/bun",
            "/quint/node_modules/@informalsystems/quint/dist/src/cli.js",
            *args,
        ],
        work=HERE / ".work",
        inputs=HERE,
        rust=False,
    )
    index = command.index("--")
    command[index:index] = ["--ro-bind", str(MODULES), "/quint/node_modules"]
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        timeout=90,
        preexec_fn=sandbox.limits,
        check=False,
    )


if __name__ == "__main__":
    result = quint(sys.argv[1:])
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)
    raise SystemExit(result.returncode)
