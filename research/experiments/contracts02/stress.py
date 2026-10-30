"""Seeded finite falsification of producer summaries and client invalidation rules."""

from __future__ import annotations

import copy
import json
import random
from pathlib import Path
from typing import Any

from client import Checker
from contracts import decode
from fixtures import borrow, call, function, invoke, owner, providers, use
from infer import infer
from model import Rejected, Ty
from oracle import Concrete, Semantics, check

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[2] / "research/evidence/contracts02-20261030"


def random_view(rng: random.Random, depth: int) -> dict[str, Any]:
    if depth == 0:
        return borrow(rng.randrange(4))
    branch = rng.randrange(5)
    if branch == 0:
        return {"choice": [random_view(rng, depth - 1), random_view(rng, depth - 1)]}
    if branch == 1:
        return call("identity", random_view(rng, depth - 1))
    if branch == 2:
        return {
            "get": {
                "value": {
                    "record": {
                        "kept": random_view(rng, depth - 1),
                        "discarded": borrow(rng.randrange(4)),
                    }
                },
                "path": ["kept"],
            }
        }
    if branch == 3:
        return {
            "get": {
                "value": {"capture": {"kept": random_view(rng, depth - 1)}},
                "path": ["kept"],
            }
        }
    return borrow(rng.randrange(4))


def concrete_client(
    steps: list[dict[str, Any]], semantic: Semantics
) -> tuple[bool, int]:
    # Independent operational generation model: an invalidated allocation gets a new epoch.
    states: list[tuple[dict[str, int | None], dict[str, Concrete]]] = [({}, {})]
    for step in steps:
        next_states = []
        for owners, values in states:
            op = step["op"]
            if op == "owner":
                owners[step["name"]] = 0
            elif op in {"invalidate", "end"}:
                name = step["owner"]
                if owners.get(name) is None:
                    return False, len(states)
                old = owners[name]
                assert old is not None
                owners[name] = None if op == "end" else old + 1
            elif op == "call":
                args = []
                for arg in step["args"]:
                    name = arg["var"]
                    if owners.get(name) is None:
                        return False, len(states)
                    args.append(Concrete(Ty("bytes"), f"{name}@{owners[name]}"))
                for result in semantic.call(step["fn"], args, 8):
                    branch = values.copy()
                    branch[step["dest"]] = result
                    next_states.append((owners.copy(), branch))
                continue
            elif op == "use":
                if step["var"] not in values:
                    return False, len(states)
                for atoms in values[step["var"]].dependencies().values():
                    for atom in atoms:
                        name, epoch = atom.rsplit("@", 1)
                        if owners.get(name) != int(epoch):
                            return False, len(states)
            elif op == "drop":
                if step["var"] not in values:
                    return False, len(states)
                del values[step["var"]]
            else:
                raise ValueError("unsupported stress client operation")
            next_states.append((owners, values))
        states = next_states
    return True, len(states)


def main() -> None:
    rng = random.Random(20261030)
    base = providers()
    artifact, _ = infer(base)
    summaries = decode(artifact)
    producer_results = []
    for i in range(200):
        f = function(
            "random",
            ["bytes"] * 4,
            {"record": {"left": "view", "right": "view"}},
            {"record": {"left": random_view(rng, 4), "right": random_view(rng, 4)}},
        )
        definitions = [*base, f]
        exported, _ = infer(definitions)
        result = check(definitions, decode(exported), names={"random"})
        # Included recursive base probes have explicitly reported fuel cutoffs.
        if (
            result["failures"]
            or result["no_results"]
            or result["truncated_cartesian_products"]
        ):
            raise AssertionError({"case": i, "result": result})
        producer_results.append({"case": i, **result})
    semantic = Semantics(base)
    client_results = []
    for i in range(1000):
        steps = [owner("a"), owner("b")]
        names = []
        for j in range(4):
            if j and rng.random() < 0.5:
                steps.append(
                    {
                        "op": rng.choice(["invalidate", "end"]),
                        "owner": rng.choice(["a", "b"]),
                    }
                )
            name = "v" + str(j)
            names.append(name)
            steps.append(
                invoke(name, "choose", rng.choice(["a", "b"]), rng.choice(["a", "b"]))
            )
            if rng.random() < 0.5:
                steps.append(use(rng.choice(names)))
        for _ in range(3):
            if rng.random() < 0.5:
                steps.append({"op": "invalidate", "owner": rng.choice(["a", "b"])})
            steps.append(use(rng.choice(names)))
        safe, traces = concrete_client(copy.deepcopy(steps), semantic)
        decisions = []
        for indexed in [False, True]:
            try:
                Checker(summaries, steps, indexed=indexed).check()
                accepted = True
            except Rejected:
                accepted = False
            decisions.append(accepted)
        if decisions[0] != decisions[1] or decisions[0] and not safe:
            raise AssertionError(
                {"case": i, "steps": steps, "safe": safe, "decisions": decisions}
            )
        client_results.append(
            {
                "case": i,
                "concretely_safe": safe,
                "accepted": decisions[0],
                "terminal_traces_or_counterexample_frontier": traces,
            }
        )
    result = {
        "seed": 20261030,
        "producer_cases": producer_results,
        "client_cases": client_results,
        "false_accepts": sum(
            c["accepted"] and not c["concretely_safe"] for c in client_results
        ),
        "false_rejects_in_narrow_client_grammar": sum(
            not c["accepted"] and c["concretely_safe"] for c in client_results
        ),
        "warning": "Finite testing only. Producer recursion cutoffs are explicit; no truncated products or zero-result cases counted.",
    }
    (OUT / "stress.json").write_text(json.dumps(result, indent=2) + "\n")
    print(
        json.dumps(
            {
                "producer_cases": len(producer_results),
                "client_cases": len(client_results),
                "concrete_returns": sum(
                    c["concrete_returns_checked"] for c in producer_results
                ),
                "false_accepts": result["false_accepts"],
                "false_rejects": result["false_rejects_in_narrow_client_grammar"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
