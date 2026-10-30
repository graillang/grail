"""CLI admits only serialized contracts and explicit-liveness client traces, never provider bodies."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

from research.experiments.contracts02.model import Rejected, Ty
from research.experiments.transforms05.client import call, dependencies
from research.experiments.transforms05.contract import decode
from research.experiments.transforms05.value import Value


def check(case: Any, contracts: Any) -> dict[str, Any]:
    storage = {
        name: Value[str](
            Ty.parse(raw["type"]),
            {tuple(r["path"]): frozenset(r["roots"]) for r in raw["flows"]},
        )
        for name, raw in case["initial"].items()
    }
    generations: dict[str, int] = {}
    try:
        for action in case["actions"]:
            if "call" in action:
                arguments = [
                    (a["slot"], tuple(a.get("path", []))) for a in action["args"]
                ]
                call(contracts[action["call"]], storage, arguments, action.get("dest"))
            elif "drop" in action:
                del storage[action["drop"]]
            elif "source" in action:
                owner = action["owner"]
                storage[action["source"]] = Value(
                    Ty("view"),
                    {(): frozenset({f"{owner}#{generations.get(owner, 0)}"})},
                )
            elif "end" in action:
                owner = action["end"]
                if any(
                    root.rsplit("#", 1)[0] == owner for root in dependencies(storage)
                ):
                    raise Rejected("ending a source still required by retained data")
                generations[owner] = generations.get(owner, 0) + 1
            elif "use" in action:
                for roots in storage[action["use"]].flows.values():
                    for root in roots:
                        owner, gen = root.rsplit("#", 1)
                        if generations.get(owner, 0) != int(gen):
                            raise Rejected("using an expired generation")
            else:
                raise Rejected("unknown client operation")
        return {"name": case["name"], "accepted": True}
    except Rejected as error:
        return {"name": case["name"], "accepted": False, "reason": str(error)}


def main() -> None:
    contracts = decode(json.loads(Path(sys.argv[1]).read_text()))
    cases = json.loads(Path(sys.argv[2]).read_text())
    print(json.dumps([check(case, contracts) for case in cases], sort_keys=True))


if __name__ == "__main__":
    main()
