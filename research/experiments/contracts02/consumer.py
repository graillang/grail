"""Check serialized clients; deliberately does not import the producer/inference module."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from client import Checker
from contracts import decode
from model import Rejected


def main() -> None:
    summaries = decode(json.loads(Path(sys.argv[1]).read_text()))
    results = []
    for case in json.loads(Path(sys.argv[2]).read_text()):
        error = None
        try:
            Checker(summaries, case["steps"]).check()
            accepted = True
        except Rejected as exc:
            accepted, error = False, str(exc)
        results.append(
            {
                "name": case["name"],
                "accepted": accepted,
                "error": error,
                "matched": accepted == case["accept"],
            }
        )
    print(
        json.dumps(
            {
                "provider_body_visible": any(
                    Path("/experiment", name).exists()
                    for name in ["providers.json", "input-ir.json", "fixtures.py"]
                ),
                "inference_module_visible": Path("/experiment/infer.py").exists(),
                "results": results,
            },
            indent=2,
        )
    )
    if not all(r["matched"] for r in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
