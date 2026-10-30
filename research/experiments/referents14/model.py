"""Finite single-cell dependency/authority model; not a source or heap checker."""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass, replace

POLICIES = (
    "monotone",
    "storage_only",
    "carrier_local",
    "carrier_writeback",
    "place_state",
)


WRITES = {
    "write": "C",
    "replace": "C",
    "direct_reset": "C",
    "restore": "A",
    "restore_replace": "A",
    "direct_restore": "A",
}


@dataclass(frozen=True)
class World:
    alive: frozenset[str] = frozenset({"A", "C"})
    cell: str | None = "A"  # None means storage B was released.
    pointer: bool = False
    returned: str | None = None


@dataclass(frozen=True)
class Bounds:
    cell: frozenset[str] = frozenset({"A"})
    pointer: frozenset[str] = frozenset()
    returned: frozenset[str] = frozenset()


def actions(w: World) -> list[str]:
    result = ["expire_" + r for r in sorted(w.alive)]
    if w.cell is not None:
        result += ["free_cell"]
        result += ["end", "read_pointer"] if w.pointer else ["borrow", "read_cell"]
        if "C" in w.alive:
            result += ["write", "replace"] if w.pointer else ["direct_reset"]
    if w.cell is not None and "A" in w.alive:
        result += ["restore", "restore_replace"] if w.pointer else ["direct_restore"]
    if w.returned is not None:
        result += ["read_returned", "drop_returned"]
    return result


def concrete(w: World, action: str) -> World:
    if action.startswith("expire_"):
        return replace(w, alive=w.alive - {action[-1]})
    if action == "free_cell":
        return replace(w, cell=None)
    if action == "borrow":
        return replace(w, pointer=True)
    if action == "end":
        return replace(w, pointer=False)
    if action in WRITES:
        return replace(
            w,
            cell=WRITES[action],
            returned=w.cell if "replace" in action else w.returned,
        )
    if action == "drop_returned":
        return replace(w, returned=None)
    return w


def valid(w: World) -> bool:
    return (
        (not w.pointer or w.cell is not None)
        and (w.cell is None or w.cell in w.alive)
        and (w.returned is None or w.returned in w.alive)
    )


def needed(policy: str, w: World, b: Bounds) -> frozenset[str]:
    if w.cell is None:
        data = frozenset()
    elif not w.pointer or policy == "place_state":
        data = b.cell
    elif policy == "storage_only":
        data = frozenset()
    else:
        data = b.pointer
    return data | b.returned


def transform(policy: str, b: Bounds, action: str) -> Bounds:
    if action == "borrow":
        return replace(
            b,
            pointer=frozenset()
            if policy in {"place_state", "storage_only"}
            else b.cell,
        )
    if action == "end":
        back = b.pointer if policy in {"carrier_writeback", "monotone"} else b.cell
        return replace(b, cell=back, pointer=frozenset())
    if action == "free_cell":
        return replace(b, cell=frozenset())
    if action == "drop_returned":
        return replace(b, returned=frozenset())
    if action in {"direct_reset", "direct_restore"}:
        return replace(b, cell=frozenset({WRITES[action]}))
    if action in {"write", "replace", "restore", "restore_replace"}:
        old = b.cell if policy in {"place_state", "storage_only"} else b.pointer
        result = old if "replace" in action else b.returned
        new = frozenset({WRITES[action]})
        if policy in {"place_state", "storage_only"}:
            return replace(b, cell=new, returned=result)
        if policy == "monotone":
            new |= b.pointer
        return replace(b, pointer=new, returned=result)
    return b


def step(policy: str, w: World, b: Bounds, action: str) -> tuple[bool, World, Bounds]:
    after = concrete(w, action)
    post = transform(policy, b, action)
    # Every policy retains storage B for the one affine pointer. Parent access
    # and creation of a second pointer are excluded by the common action rules.
    permit = not (action == "free_cell" and w.pointer)
    permit &= needed(policy, after, post) <= after.alive
    return permit, after, post


def explore(policy: str) -> dict:
    initial = (World(), Bounds())
    queue: deque[tuple[tuple[World, Bounds], tuple[str, ...]]] = deque([(initial, ())])
    seen = {initial}
    unsafe = []
    rejected = []
    transitions = 0
    while queue:
        (w, b), path = queue.popleft()
        for action in actions(w):
            transitions += 1
            permit, after, post = step(policy, w, b, action)
            safe = valid(after)
            trace = (*path, action)
            if permit and not safe:
                unsafe.append(trace)
            if not permit and safe:
                rejected.append(trace)
            # Only accepted, concretely valid prefixes can establish an accepted
            # counterexample. Stop at the first validity violation/rejection.
            if permit and safe and (after, post) not in seen:
                seen.add((after, post))
                queue.append(((after, post), trace))
    return {
        "states": len(seen),
        "transitions": transitions,
        "unsafe_accepted": len(unsafe),
        "safe_rejected": len(rejected),
        "shortest_unsafe": unsafe[0] if unsafe else None,
        "shortest_rejection": rejected[0] if rejected else None,
    }


TRACES = {
    "restore_short_source": (
        "borrow",
        "write",
        "restore",
        "expire_C",
        "read_pointer",
        "end",
        "read_cell",
    ),
    "keep_short_source": ("borrow", "write", "expire_C", "read_pointer"),
    "overwrite_and_resume": (
        "borrow",
        "write",
        "expire_A",
        "read_pointer",
        "end",
        "read_cell",
    ),
    "retained_old": ("borrow", "replace", "expire_A", "read_returned"),
    "dropped_old": (
        "borrow",
        "replace",
        "drop_returned",
        "expire_A",
        "read_pointer",
        "end",
        "read_cell",
    ),
    "old_survives_cell": (
        "borrow",
        "replace",
        "end",
        "free_cell",
        "expire_C",
        "read_returned",
    ),
    "missing_current_source": ("borrow", "expire_A", "read_pointer"),
    "missing_writeback": ("borrow", "write", "end", "expire_C", "read_cell"),
}


def trace(policy: str, commands: tuple[str, ...]) -> dict:
    w, b = World(), Bounds()
    rejected = None
    violation = None
    for index, action in enumerate(commands):
        assert action in actions(w), (commands, index)
        permit, w, b = step(policy, w, b, action)
        if not permit and rejected is None:
            rejected = index
        if not valid(w) and violation is None:
            violation = index
    return {
        "accepted": rejected is None,
        "first_rejection": rejected,
        "concretely_valid": violation is None,
        "first_violation": violation,
    }


def check() -> dict:
    results = {p: explore(p) for p in POLICIES}
    for name in ("carrier_writeback", "place_state"):
        assert results[name]["unsafe_accepted"] == results[name]["safe_rejected"] == 0
    assert results["storage_only"]["unsafe_accepted"] > 0
    assert results["carrier_local"]["unsafe_accepted"] > 0
    assert results["monotone"]["unsafe_accepted"] == 0
    assert results["monotone"]["safe_rejected"] > 0
    return results


if __name__ == "__main__":
    import json

    print(json.dumps(check(), indent=2))
