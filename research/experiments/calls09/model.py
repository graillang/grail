"""Small hypothetical call-admission policies; not a Grail frontend or an extension of IR 05."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from research.experiments.contracts02.model import Ty
from research.experiments.transforms05.infer import infer
from research.experiments.transforms05.value import Value

# The callee's entry-relative contract comes from the existing, tested producer.
PRESERVE = infer(
    {
        "name": "preserve",
        "params": [
            {"mode": "mut", "type": {"list": "view"}},
            {"mode": "take", "type": "unit"},
        ],
        "result": "unit",
        "body": [],
        "return": {"unit": True},
    }
)
ACTIONS = ("nop", "append_b", "append_c", "clear", "replace_c", "drop")


@dataclass(frozen=True)
class Policy:
    name: str
    snapshot_early: bool = False
    defer_value_loan: bool = False
    ignore_copy_alias: bool = False


POLICIES = (
    Policy("late_state_eager_values"),
    Policy("early_state", snapshot_early=True),
    Policy("late_value_loan", defer_value_loan=True),
    Policy("ignore_copy_loan_at_activation", ignore_copy_alias=True),
)
MODES = ("place", "materialized_value", "place_and_value")


def analyze(actions: tuple[str, ...], mode: str, policy: Policy) -> dict[str, Any]:
    assert mode in MODES
    roots: frozenset[str] | None = frozenset({"a"})
    early = roots
    has_view = mode != "place"
    for action in actions:
        assert action in ACTIONS
        if action == "nop":
            continue
        if roots is None:
            return {"accepted": False, "reason": "argument uses moved target"}
        if has_view and not policy.defer_value_loan:
            return {
                "accepted": False,
                "reason": "materialized view already loans storage during argument evaluation",
            }
        if action == "append_b":
            roots = roots | {"b"}
        elif action == "append_c":
            roots = roots | {"c"}
        elif action == "clear":
            roots = frozenset()
        elif action == "replace_c":
            roots = frozenset({"c"})
        elif action == "drop":
            roots = None
    # A named place must still be initialized when the access is actually formed.
    if roots is None:
        return {"accepted": False, "reason": "target moved before activation"}
    if mode == "place_and_value" and not policy.ignore_copy_alias:
        return {
            "accepted": False,
            "reason": "incoming storage view aliases mutable access at activation",
        }
    if mode == "place":
        snapshot = early if policy.snapshot_early else roots
        _, post = PRESERVE.apply(
            [Value(Ty.parse({"list": "view"}), {("*",): snapshot}), Value(Ty("unit"))]
        )
        roots = post[0].flows.get(("*",), frozenset())
    return {"accepted": True, "post_roots": sorted(roots)}


def concrete(actions: tuple[str, ...], mode: str) -> dict[str, Any]:
    """Concrete list contents and storage epoch, without applying dependency contracts."""
    data: list[str] | None = ["a"]
    epoch = 0
    captured_epoch = epoch if mode != "place" else None
    events = []
    if mode in {"place", "place_and_value"}:
        events.append("capture place cache")
    if mode != "place":
        events.append("materialize storage view at epoch 0")
    for action in actions:
        if action == "nop":
            events.append("nop")
            continue
        if data is None:
            return {
                "valid_call": False,
                "reason": "argument uses moved target",
                "events": events,
            }
        if action.startswith("append_"):
            data = [*data, action[-1]]
        elif action == "clear":
            data = []
        elif action == "replace_c":
            data = ["c"]
        elif action == "drop":
            data = None
        else:
            raise AssertionError("unknown concrete action")
        # This model explicitly chooses storage-invalidating mutations, not in-capacity push.
        epoch += 1
        events.append(f"{action}: storage epoch {epoch}")
    if data is None:
        return {
            "valid_call": False,
            "reason": "target unavailable at activation",
            "events": events,
        }
    if captured_epoch is not None and captured_epoch != epoch:
        return {
            "valid_call": False,
            "reason": "materialized view references obsolete storage epoch",
            "events": events,
        }
    if mode == "place_and_value":
        # A callee may clear its unique input then inspect its other, assumed-disjoint view.
        return {
            "valid_call": False,
            "reason": "mutable/storage-view argument overlap; clear-then-read would invalidate view",
            "events": events,
        }
    return {
        "valid_call": True,
        "actual_roots": sorted(set(data)),
        "events": [*events, "activate call with current storage"],
    }
