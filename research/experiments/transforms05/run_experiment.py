"""Reproduce bounded contract, concrete execution and body-hidden client comparisons."""

from __future__ import annotations

import copy
import hashlib
import itertools
import json
import random
import shutil
from pathlib import Path
from typing import Any

from research.experiments.contracts02.model import Ty
from research.experiments.memory01 import sandbox
from research.experiments.transforms05.contract import Contract, canonical, decode
from research.experiments.transforms05.fixtures import arg, definitions, procedure
from research.experiments.transforms05.infer import infer
from research.experiments.transforms05.oracle import (
    Concrete,
    Token,
    branches,
    client_trace,
    make,
    observe,
    run,
)
from research.experiments.transforms05.value import Value

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "research/evidence/transforms05-20261030"


def generated(seed: int, count: int) -> list[Any]:
    rng = random.Random(seed)
    result = []
    seq = {"list": "view"}
    for index in range(count):
        counter = 0

        def step() -> dict[str, Any]:
            nonlocal counter
            counter += 1
            dest = f"tmp{counter}"
            choice = rng.randrange(7)
            if choice == 0:
                return {"op": "clear", "target": arg(0)}
            if choice == 1:
                return {
                    "op": "append",
                    "target": arg(0),
                    "value": {"read": arg(rng.choice([1, 2]))},
                }
            if choice == 2:
                return {
                    "op": "replace",
                    "target": arg(0),
                    "value": {"empty": seq},
                    "dest": dest,
                }
            if choice == 3:
                return {"op": "take_all", "target": arg(0), "dest": dest}
            if choice == 4:
                return {
                    "op": "call",
                    "fn": "clear",
                    "args": [{"place": arg(0)}],
                    "dest": dest,
                }
            if choice == 5:
                return {
                    "op": "call",
                    "fn": "append",
                    "args": [
                        {"place": arg(0)},
                        {"value": {"read": arg(rng.choice([1, 2]))}},
                    ],
                    "dest": dest,
                }
            return {
                "op": "call",
                "fn": "swap",
                "args": [{"place": arg(0)}, {"place": {"local": "spare"}}],
                "dest": dest,
            }

        body: list[Any] = [{"op": "let", "name": "spare", "value": {"empty": seq}}]
        returned = {"unit": True}
        return_type: Any = "unit"
        if index % 3 == 0:
            body.append(
                {
                    "op": "replace",
                    "target": arg(0),
                    "value": {"empty": seq},
                    "dest": "saved",
                }
            )
            returned, return_type = {"move": {"local": "saved"}}, seq
        for j in range(rng.randint(1, 10)):
            if j < 2 and rng.random() < 0.5:
                body.append({"op": "branch", "then": [step()], "else": [step()]})
            else:
                body.append(step())
        if index % 3 == 2:
            body.append({"op": "take_all", "target": arg(0), "dest": "saved"})
            returned, return_type = {"move": {"local": "saved"}}, seq
        result.append(
            procedure(
                f"generated_{index}",
                [seq, "view", "view"],
                ["mut", "read", "read"],
                return_type,
                body,
                returned,
            )
        )
    return result


def abstract(value: Concrete) -> Value[Token]:
    return Value(value.ty, observe(value))


def covered(actual: Concrete, upper: Value[Token]) -> bool:
    return actual.ty == upper.ty and all(
        roots <= upper.flows.get(p, frozenset()) for p, roots in observe(actual).items()
    )


def compare(providers: list[Any], contracts: dict[str, Contract]) -> dict[str, Any]:
    source = {f["name"]: f for f in providers}
    types = [
        Ty("unit"),
        Ty("view"),
        Ty.parse({"record": {"a": "view", "b": "view"}}),
        Ty.parse({"list": "view"}),
        Ty.parse({"record": {"a": {"list": "view"}, "b": "view"}}),
        Ty.parse({"list": {"record": {"a": "view", "b": "view"}}}),
    ]
    executions = 0
    output_positions = 0
    rows = []
    for fn in providers:
        count = 0
        choices_count = branches(fn, source)
        for ground in (
            types if not fn["name"].startswith("generated_") else [Ty("view")]
        ):
            for size in [0, 1, 2]:
                arguments = [
                    make(Ty.parse(p["type"]).substitute({"T": ground}), f"arg{i}", size)
                    for i, p in enumerate(fn["params"])
                ]
                inferred_result, inferred_post = contracts[fn["name"]].apply(
                    [abstract(v) for v in arguments]
                )
                for bits in itertools.product([False, True], repeat=choices_count):
                    result, post = run(fn, arguments, source, iter(bits))
                    assert covered(result, inferred_result), (
                        fn["name"],
                        bits,
                        "result",
                    )
                    assert post.keys() == inferred_post.keys()
                    assert all(
                        covered(value, inferred_post[i]) for i, value in post.items()
                    ), (fn["name"], bits, "post")
                    count += 1
                    output_positions += 1 + len(post)
        rows.append(
            {
                "name": fn["name"],
                "concrete_executions": count,
                "branch_choice_bits": choices_count,
                "contract_bytes": len(canonical(contracts[fn["name"]].raw())),
            }
        )
        executions += count
    return {
        "seed": 20261030,
        "providers": len(providers),
        "concrete_executions": executions,
        "result_and_post_values_checked": output_positions,
        "missing_dependency_mismatches": 0,
        "cases": rows,
    }


def raw_value(ty: Any, flows: dict[tuple[str, ...], list[str]]) -> dict[str, Any]:
    return {
        "type": ty,
        "flows": [{"path": list(p), "roots": roots} for p, roots in flows.items()],
    }


def clients() -> list[Any]:
    seq = {"list": "view"}
    cache = raw_value(seq, {("*",): ["old#0"]})
    new = raw_value(seq, {("*",): ["new#0"]})
    view = raw_value("view", {(): ["new#0"]})
    use = lambda name: {"use": name}
    end = lambda name: {"end": name}
    call = lambda name, args, dest=None: {
        "call": name,
        "args": [{"slot": a} for a in args],
        "dest": dest,
    }
    return [
        {
            "name": "clear_end_old_reuse_same_owner",
            "expected": True,
            "initial": {"cache": cache},
            "actions": [
                call("clear", ["cache"]),
                end("old"),
                {"source": "fresh", "owner": "old"},
                call("append", ["cache", "fresh"]),
                use("cache"),
            ],
        },
        {
            "name": "append_keeps_old",
            "expected": False,
            "initial": {"cache": cache, "incoming": view},
            "actions": [
                call("append", ["cache", "incoming"]),
                end("old"),
                use("cache"),
            ],
        },
        {
            "name": "replace_drop_old_end_old_use_new",
            "expected": True,
            "initial": {"cache": cache, "incoming": new},
            "actions": [
                call("replace_all", ["cache", "incoming"], "saved"),
                {"drop": "saved"},
                end("old"),
                use("cache"),
            ],
        },
        {
            "name": "replace_returned_old_still_borrows",
            "expected": False,
            "initial": {"cache": cache, "incoming": new},
            "actions": [
                call("replace_all", ["cache", "incoming"], "saved"),
                end("old"),
                use("saved"),
            ],
        },
        {
            "name": "replace_old_independent_of_new",
            "expected": True,
            "initial": {"cache": cache, "incoming": new},
            "actions": [
                call("replace_all", ["cache", "incoming"], "saved"),
                {"drop": "cache"},
                end("new"),
                use("saved"),
            ],
        },
        {
            "name": "take_all_return_retains_old",
            "expected": False,
            "initial": {"cache": cache},
            "actions": [call("take_all", ["cache"], "saved"), end("old"), use("saved")],
        },
        {
            "name": "take_all_discard_releases_old",
            "expected": True,
            "initial": {"cache": cache},
            "actions": [call("take_all", ["cache"]), end("old"), use("cache")],
        },
        {
            "name": "maybe_clear_cannot_assume_clear",
            "expected": False,
            "initial": {"cache": cache},
            "actions": [call("maybe_clear", ["cache"]), end("old"), use("cache")],
        },
        {
            "name": "aliased_mutable_swap",
            "expected": False,
            "initial": {"cache": cache},
            "actions": [call("swap", ["cache", "cache"])],
        },
        {
            "name": "clear_left_preserve_right",
            "expected": True,
            "initial": {
                "pair": raw_value(
                    {"record": {"left": seq, "right": seq}},
                    {("left", "*"): ["old#0"], ("right", "*"): ["new#0"]},
                )
            },
            "actions": [call("clear_left", ["pair"]), end("old"), use("pair")],
        },
    ]


def isolated(module: Any, cases: list[Any]) -> dict[str, Any]:
    bundle = HERE / ".work/consumer-input"
    work = HERE / ".work/consumer-work"
    bundle.mkdir(parents=True, exist_ok=True)
    allowed = [
        "research/experiments/contracts02/model.py",
        *[
            f"research/experiments/transforms05/{name}.py"
            for name in ["consumer", "client", "contract", "value"]
        ],
    ]
    for path in allowed:
        target = bundle / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / path, target)
    (bundle / "contracts.json").write_bytes(canonical(module))
    (bundle / "clients.json").write_bytes(canonical(cases))
    inventory = sorted(
        str(p.relative_to(bundle)) for p in bundle.rglob("*") if p.is_file()
    )
    assert inventory == sorted([*allowed, "contracts.json", "clients.json"]), inventory
    result = sandbox.run(
        [
            "env",
            "PYTHONPATH=/experiment",
            "python3",
            "-B",
            "-m",
            "research.experiments.transforms05.consumer",
            "/experiment/contracts.json",
            "/experiment/clients.json",
        ],
        inputs=bundle,
        work=work,
        rust=False,
        timeout=60,
    )
    assert result.returncode == 0, result.stderr
    rows = json.loads(result.stdout)
    assert all(
        row["accepted"] == case["expected"]
        for row, case in zip(rows, cases, strict=True)
    ), rows
    return {
        "provider_bodies_available": False,
        "mounted_code_files": allowed,
        "mounted_file_inventory": inventory,
        "returncode": result.returncode,
        "matched": len(rows),
        "total": len(rows),
        "cases": rows,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fixtures = definitions()
    providers = fixtures + generated(20261030, 200)
    contracts = {}
    for fn in providers:
        contract = infer(fn, contracts)
        contracts[contract.name] = contract
    module = {"schema": 1, "contracts": [c.raw() for c in contracts.values()]}
    decoded = decode(module)
    report = compare(providers, decoded)
    source = {f["name"]: f for f in providers}
    client_rows = []
    for case in clients():
        bits = sum(
            branches(source[a["call"]], source) for a in case["actions"] if "call" in a
        )
        outcomes = [
            client_trace(case, source, iter(choices))
            for choices in itertools.product([False, True], repeat=bits)
        ]
        assert all(outcomes) == case["expected"], (case["name"], outcomes)
        client_rows.append(
            {
                "name": case["name"],
                "concrete_executions": len(outcomes),
                "all_safe": all(outcomes),
            }
        )
    # A valid schema does not certify that a producer's memory contract describes its body.
    honest_preserve = procedure("clear", [{"list": {"var": "T"}}], ["mut"], "unit", [])
    old = make(Ty.parse({"list": "view"}), "old", 1)
    actual, post = run(honest_preserve, [old], {"clear": honest_preserve}, iter(()))
    claimed, claimed_post = decoded["clear"].apply([abstract(old)])
    forgery = {
        "schema_accepts_empty_post_for_noop": True,
        "concrete_oracle_detects_missing_dependency": not covered(
            post[0], claimed_post[0]
        ),
        "producer_refinement_rejects_noop_as_clear": not infer(honest_preserve).refines(
            decoded["clear"]
        ),
    }
    assert covered(actual, claimed) and all(forgery.values())
    forged_source = {**source, "clear": honest_preserve}
    forgery["client_trace_exposes_false_accept"] = not client_trace(
        clients()[0], forged_source, iter(())
    )
    assert forgery["client_trace_exposes_false_accept"]
    alternate = copy.deepcopy(fixtures[1])
    alternate["body"] = [{"op": "take_all", "target": arg(0), "dest": "discard"}]
    stability = {
        "different_body_sha256": hashlib.sha256(canonical(alternate)).hexdigest()
        != hashlib.sha256(canonical(fixtures[1])).hexdigest(),
        "same_dependency_interface_hash": infer(alternate).fingerprint()
        == decoded["clear"].fingerprint(),
    }
    assert all(stability.values())
    consumer = isolated(
        {"schema": 1, "contracts": [decoded[f["name"]].raw() for f in fixtures]},
        clients(),
    )
    for name, data in [
        ("providers", providers),
        ("contracts", module),
        ("differential", report),
        ("clients", clients()),
        ("consumer", consumer),
        ("concrete-clients", client_rows),
        ("trust-and-stability", {"forgery": forgery, "interface_stability": stability}),
    ]:
        (OUT / f"{name}.json").write_text(
            json.dumps(data, indent=2, sort_keys=True) + "\n"
        )
    hashes = {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(HERE.glob("*.py"))
    }
    hashes["research/experiments/contracts02/model.py"] = hashlib.sha256(
        (HERE.parent / "contracts02/model.py").read_bytes()
    ).hexdigest()
    hashes["research/experiments/memory01/sandbox.py"] = hashlib.sha256(
        (HERE.parent / "memory01/sandbox.py").read_bytes()
    ).hexdigest()
    (OUT / "manifest.json").write_text(
        json.dumps(
            {
                "source_sha256": hashes,
                "command": "python -m research.experiments.transforms05.run_experiment",
                "module_bytes": len(canonical(module)),
                "scope": "finite shared view-data mutation; not a soundness proof",
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )
    print(
        json.dumps(
            {
                "providers": len(providers),
                "concrete_executions": report["concrete_executions"],
                "missing_dependencies": 0,
                "isolated_clients_matched": consumer["matched"],
                "forgery": forgery,
                "interface_stability": stability,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
