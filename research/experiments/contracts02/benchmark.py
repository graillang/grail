"""Synthetic scaling tests for this Python representation, not Grail compile-speed claims."""

from __future__ import annotations

import json
import statistics
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

from client import Checker
from contracts import canonical, decode
from fixtures import borrow, call, function, invoke, owner, p, providers, use
from infer import infer
from model import Info, Ty

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[2] / "research/evidence/contracts02-20261030"


def timed(action: Callable[[], Any]) -> tuple[Any, dict[str, Any]]:
    action()  # warmup, excluded
    samples = []
    value = None
    for _ in range(5):
        start = time.perf_counter_ns()
        value = action()
        samples.append((time.perf_counter_ns() - start) / 1e6)
    return value, {
        "median_ms": statistics.median(samples),
        "min_ms": min(samples),
        "max_ms": max(samples),
        "samples_ms": samples,
    }


def main() -> None:
    result: dict[str, Any] = {
        "scope": "Python typed-IR prototype scaling, warm process, shared host",
        "chain": [],
        "sets": [],
        "generic": [],
        "client_index": [],
    }
    for n in [16, 64, 256, 1024]:
        defs = [
            function(
                f"f{i}",
                ["bytes"],
                "view",
                borrow(0) if i == n - 1 else call(f"f{i + 1}", p(0)),
            )
            for i in range(n)
        ]
        measured, timing = timed(lambda defs=defs: infer(defs))
        artifact, stats = measured
        result["chain"].append(
            {
                "functions": n,
                "input_bytes": len(canonical(defs)),
                "contract_bytes": len(canonical(artifact)),
                **stats,
                **timing,
            }
        )
    for n in [8, 32, 128]:
        for pattern in ["shared", "distinct"]:
            body = {
                "record": {
                    f"f{i}": {
                        "choice": [
                            borrow(j) for j in range(n) if pattern == "shared" or j != i
                        ]
                    }
                    for i in range(n)
                }
            }
            defs = [
                function(
                    "wide",
                    ["bytes"] * n,
                    {"record": {f"f{i}": "view" for i in range(n)}},
                    body,
                )
            ]
            measured, timing = timed(lambda defs=defs: infer(defs))
            artifact, stats = measured
            summary = decode(artifact)["wide"]
            result["sets"].append(
                {
                    "fields": n,
                    "sources": n,
                    "pattern": pattern,
                    "input_ir_bytes": len(canonical(defs)),
                    "interned_function_bytes": len(canonical(summary.raw())),
                    "uninterned_function_bytes": len(
                        canonical(summary.raw(intern=False))
                    ),
                    "distinct_sets": len(summary.raw()["source_sets"]),
                    **stats,
                    **timing,
                }
            )
    artifact, _ = infer(providers())
    summaries = decode(artifact)
    identity = summaries["identity"]
    for n in [16, 64, 256, 1024]:
        ty = Ty.parse({"record": {f"f{i}": "view" for i in range(n)}})
        actual = Info.parameter(42, ty)
        value, timing = timed(lambda actual=actual: identity.apply([actual]))
        assert value.ty == ty and value.flows == actual.flows
        result["generic"].append(
            {
                "actual_fields": n,
                "generic_function_bytes": len(canonical(identity.raw())),
                "instantiated_paths": len(value.flows),
                **timing,
            }
        )
    for n in [64, 256, 1024]:
        steps = []
        for i in range(n):
            steps += [
                owner(f"a{i}"),
                invoke(f"v{i}", "first", f"a{i}"),
                use(f"v{i}"),
                {"op": "invalidate", "owner": f"a{i}"},
            ]
        for indexed in [False, True]:
            _, timing = timed(
                lambda steps=steps, indexed=indexed: Checker(
                    summaries, steps, indexed=indexed
                ).check()
            )
            result["client_index"].append(
                {"owners": n, "steps": len(steps), "indexed": indexed, **timing}
            )
    (OUT / "scaling.json").write_text(json.dumps(result, indent=2) + "\n")
    for category, rows in result.items():
        if isinstance(rows, list):
            print(
                category,
                json.dumps(
                    [
                        {k: v for k, v in row.items() if k != "samples_ms"}
                        for row in rows
                    ]
                ),
            )


if __name__ == "__main__":
    main()
