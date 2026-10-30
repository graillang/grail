"""Finite comparison of delayed-activation policies and concrete caller observations."""

from __future__ import annotations

import hashlib
import itertools
import json
import subprocess
from pathlib import Path

from research.experiments.calls09.model import (
    ACTIONS,
    MODES,
    POLICIES,
    PRESERVE,
    analyze,
    concrete,
)
from research.experiments.memory01 import sandbox

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "research/evidence/calls09-20261030"


def main() -> None:
    sequences = [
        xs for length in range(4) for xs in itertools.product(ACTIONS, repeat=length)
    ]
    rows = []
    for policy in POLICIES:
        totals = {
            "invalid_call_accepted": 0,
            "valid_call_rejected": 0,
            "missing_post_sources": 0,
            "extra_post_sources": 0,
        }
        witnesses = {}
        for mode in MODES:
            for actions in sequences:
                static = analyze(actions, mode, policy)
                actual = concrete(actions, mode)
                problems = []
                if not static["accepted"] and actual["valid_call"]:
                    problems.append("valid_call_rejected")
                if static["accepted"] and not actual["valid_call"]:
                    problems.append("invalid_call_accepted")
                if static["accepted"] and actual["valid_call"]:
                    predicted, support = (
                        set(static["post_roots"]),
                        set(actual["actual_roots"]),
                    )
                    if support - predicted:
                        problems.append("missing_post_sources")
                    if predicted - support:
                        problems.append("extra_post_sources")
                for problem in problems:
                    totals[problem] += 1
                    if problem not in witnesses:
                        witness = {
                            "mode": mode,
                            "argument_effects": list(actions),
                            "analysis": static,
                            "concrete": actual,
                        }
                        if problem == "missing_post_sources":
                            missing = min(
                                set(actual["actual_roots"]) - set(static["post_roots"])
                            )
                            generations = {root: 0 for root in ("a", "b", "c")}
                            retained = [(root, 0) for root in actual["actual_roots"]]
                            generations[missing] += 1
                            read_valid = all(
                                generations[root] == generation
                                for root, generation in retained
                            )
                            assert (
                                not read_valid and missing not in static["post_roots"]
                            )
                            witness["suffix_read_valid"] = read_valid
                            witness["unsafe_suffix"] = [
                                f"end source {missing}",
                                "observe retained cache view into ended source",
                            ]
                        witnesses[problem] = witness
        rows.append(
            {
                "policy": policy.name,
                "comparisons": len(sequences) * len(MODES),
                **totals,
                "first_witnesses": witnesses,
            }
        )
    assert all(
        rows[0][key] == 0
        for key in [
            "invalid_call_accepted",
            "valid_call_rejected",
            "missing_post_sources",
            "extra_post_sources",
        ]
    )
    assert rows[1]["missing_post_sources"] and rows[1]["extra_post_sources"]
    assert rows[2]["invalid_call_accepted"] and rows[3]["invalid_call_accepted"]
    OUT.mkdir(parents=True, exist_ok=True)
    rust_rows = []
    for name, expected in [
        ("method_len", None),
        ("method_nested_mut", "E0499"),
        ("materialized_view", "E0502"),
        ("entry_alias", "E0502"),
        ("moved_target", "E0505"),
    ]:
        args = [
            "rustc",
            "--edition=2024",
            "--error-format=json",
            "/experiment/" + name + ".rs",
            "-o",
            "/work/" + name,
        ]
        compiled = sandbox.run(args, inputs=HERE, work=HERE / ".work")
        diagnostics = [json.loads(line) for line in compiled.stderr.splitlines()]
        codes = {
            d["code"]["code"]
            for d in diagnostics
            if d.get("code") and d.get("level") == "error"
        }
        matched = (
            compiled.returncode == 0
            if expected is None
            else compiled.returncode != 0 and expected in codes
        )
        execution = None
        if compiled.returncode == 0:
            ran = sandbox.run(["/work/" + name], inputs=HERE, work=HERE / ".work")
            execution = {
                "returncode": ran.returncode,
                "stdout": ran.stdout,
                "stderr": ran.stderr,
            }
            matched &= ran.returncode == 0
        assert matched, (name, compiled.stderr)
        rust_rows.append(
            {
                "name": name,
                "expected_error": expected,
                "matched": matched,
                "command": args,
                "returncode": compiled.returncode,
                "diagnostics": diagnostics,
                "execution": execution,
            }
        )
    dependencies = [
        "research/experiments/contracts02/model.py",
        *[
            "research/experiments/transforms05/" + name + ".py"
            for name in ["infer", "contract", "value"]
        ],
    ]
    hashes = {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(HERE.iterdir())
        if p.suffix in {".py", ".rs"}
    }
    hashes["research/experiments/memory01/sandbox.py"] = hashlib.sha256(
        (HERE.parent / "memory01/sandbox.py").read_bytes()
    ).hexdigest()
    hashes.update(
        {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in dependencies}
    )
    report = {
        "scope": "finite hypothetical call policies, stable named place only; not Grail semantics or a bug in transforms05",
        "argument_effect_bound": 3,
        "effect_sequences": len(sequences),
        "rows": rows,
        "rust_comparison": rust_rows,
        "compiler": subprocess.check_output(["rustc", "-Vv"], text=True),
        "source_sha256": hashes,
        "entry_relative_contract": PRESERVE.raw(),
    }
    (OUT / "checks.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(json.dumps(rows, indent=2))


if __name__ == "__main__":
    main()
