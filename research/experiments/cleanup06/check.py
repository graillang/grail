"""Exhaustive reachability of the small cleanup model, not a runtime/compiler proof."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from research.experiments.cleanup06.model import explore

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[2] / "research/evidence/cleanup06-20261030"


def main() -> None:
    results = []
    for count in [1, 2, 3]:
        for policy in ["scope_owned", "handle_only", "clear_on_any_ack"]:
            result = explore(policy, count)
            should_fail = policy == "handle_only" or (
                policy == "clear_on_any_ack" and count >= 2
            )
            assert bool(result["unsafe_states"]) == should_fail, result
            assert result["exit_drops_all_user_handles"], result
            assert result["normal_exit_states"] and result["error_exit_states"], result
            assert result["pending_error_stall"], result
            if policy == "scope_owned":
                assert result["active_operations_always_registered"], result
            results.append(result)
    OUT.mkdir(parents=True, exist_ok=True)
    report = {
        "scope": "all reachable states of this finite model for 1, 2 and 3 operations; not all programs or operation counts",
        "results": results,
        "source_sha256": {
            p.name: hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(HERE.glob("*.py"))
        },
    }
    (OUT / "reachability.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n"
    )
    print(
        json.dumps(
            [
                {
                    k: r[k]
                    for k in [
                        "policy",
                        "operation_bound",
                        "reachable_states",
                        "unsafe_states",
                    ]
                }
                for r in results
            ],
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
