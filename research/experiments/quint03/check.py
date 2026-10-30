"""Check expected static diagnostics and seeded model counterexamples."""

from __future__ import annotations

import hashlib
import json
import shutil

from run import HERE, MODULES, OUT, quint


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cases = []
    for name, error in [
        ("cancel_scope", None),
        ("callback_effect", None),
        ("invalid_callback_effect", "QNT200"),
        ("invalid_pure", "QNT200"),
        ("invalid_double_update", "QNT202"),
    ]:
        args = ["typecheck", f"/experiment/{name}.qnt"]
        result = quint(args)
        expected = (
            result.returncode == 0
            if error is None
            else result.returncode != 0 and error in result.stderr
        )
        cases.append(
            {
                "name": name,
                "kind": "static",
                "command": args,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "matched": expected,
            }
        )
    for step, bad in [
        ("step_safe", False),
        ("step_early_release", True),
        ("step_reallocate", True),
    ]:
        trace = step + ".itf.json"
        args = [
            "run",
            "/experiment/cancel_scope.qnt",
            "--step=" + step,
            "--invariant=validLoan",
            "--backend=typescript",
            "--seed=20261030",
            "--max-samples=1000",
            "--max-steps=12",
            "--out-itf=/work/" + trace,
        ]
        result = quint(args)
        expected = (
            (result.returncode != 0 and "Invariant violated" in result.stderr)
            if bad
            else (result.returncode == 0 and "No violation found" in result.stdout)
        )
        states = []
        if bad:
            data = json.loads((HERE / ".work" / trace).read_text())
            states = data["states"]
            last = states[-1]
            assert last["loan"] is True
            assert (
                last["loanGeneration"] != last["generation"] or last["alive"] is False
            )
            shutil.copyfile(HERE / ".work" / trace, OUT / trace)
        cases.append(
            {
                "name": step,
                "kind": "sampled_simulation",
                "command": args,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "counterexample_states": len(states),
                "matched": expected,
            }
        )
    package = MODULES / "@informalsystems/quint"
    manifest = json.loads((package / "package.json").read_text())
    report = {
        "tool": "@informalsystems/quint",
        "installed_version": manifest["version"],
        "runtime": "Bun 1.4.4",
        "simulation_backend": "typescript",
        "source_checkout_version": "0.33.1; inspected, not executed",
        "matching_source_tag": "v0.30.0 (0482e47c82a5c540843858f9edfbab3da4d64521)",
        "cases": cases,
        "node26_attempt": "Failed loading local yargs dependency under Node 26.12.1; no files patched; Bun worked",
        "verification": "Static mode checks and sampled simulations only; no Apalache/TLC verification or safety theorem",
        "source_sha256": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(HERE.glob("*.qnt"))
        },
        "cli_sha256": hashlib.sha256(
            (package / "dist/src/cli.js").read_bytes()
        ).hexdigest(),
    }
    (OUT / "quint-experiment.json").write_text(json.dumps(report, indent=2) + "\n")
    print(
        json.dumps(
            {
                "matched": sum(c["matched"] for c in cases),
                "total": len(cases),
                "cases": [
                    (c["name"], c["matched"], c.get("counterexample_states"))
                    for c in cases
                ],
            },
            indent=2,
        )
    )
    if not all(c["matched"] for c in cases):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
