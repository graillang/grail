"""Export inferred contracts, hide producer bodies, and run the client corpus."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from contracts import canonical, decode
from fixtures import clients, providers
from infer import infer
from oracle import check

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "research/evidence/contracts02-20261030"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    artifact, stats = infer(providers())
    (OUT / "input-ir.json").write_text(json.dumps(providers(), indent=2) + "\n")
    (OUT / "contracts.json").write_text(json.dumps(artifact, indent=2) + "\n")
    (OUT / "clients.json").write_text(json.dumps(clients(), indent=2) + "\n")
    inputs = HERE / ".work/consumer-inputs"
    inputs.mkdir(parents=True, exist_ok=True)
    for name in ["model.py", "contracts.py", "client.py", "consumer.py"]:
        shutil.copyfile(HERE / name, inputs / name)
    for name in ["contracts.json", "clients.json"]:
        shutil.copyfile(OUT / name, inputs / name)
    expected = {
        "model.py",
        "contracts.py",
        "client.py",
        "consumer.py",
        "contracts.json",
        "clients.json",
    }
    assert {p.name for p in inputs.iterdir()} == expected
    # Reuse the inspected filesystem/network sandbox, but mount ONLY consumer files.
    sys.path.insert(0, str(HERE.parent / "memory01"))
    import sandbox

    run = sandbox.run(
        [
            "/usr/bin/python3",
            "/experiment/consumer.py",
            "/experiment/contracts.json",
            "/experiment/clients.json",
        ],
        work=HERE / ".work/consumer-work",
        inputs=inputs,
        rust=False,
    )
    if run.returncode:
        print(run.stdout)
        raise RuntimeError(run.stderr)
    result = json.loads(run.stdout)
    assert (
        not result["provider_body_visible"] and not result["inference_module_visible"]
    )
    assert all(r["matched"] for r in result["results"])
    result["concrete_reference"] = check(providers(), decode(artifact))
    result["inference_stats"] = stats
    result["canonical_contract_bytes"] = len(canonical(artifact))
    (OUT / "isolated-consumer.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
